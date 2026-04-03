'use strict';

const express = require('express');
const router  = express.Router();
const db      = require('../db');
const auth    = require('../middleware/auth');
const { computeFraudScore, computePayout } = require('../services/riskEngine');

function claimToJson(row) {
  return {
    id:          row.id,
    workerId:    row.worker_id,
    alertId:     row.alert_id,
    status:      row.status,
    amount:      parseFloat(row.amount),
    fraudScore:  parseFloat(row.fraud_score),
    createdAt:   row.created_at,
    resolvedAt:  row.resolved_at,
    triggerType: row.trigger_type,
    zone:        row.zone,
    reviewNote:  row.review_note,
  };
}

// ── GET /claims/my ──────────────────────────────────────────────────────
// Get all claims for the authenticated worker.
router.get('/my', auth, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT c.*, da.trigger_type as trigger_type_from_alert
       FROM claims c
       LEFT JOIN disruption_alerts da ON da.id = c.alert_id
       WHERE c.worker_id = $1
       ORDER BY c.created_at DESC`,
      [req.workerId]
    );
    res.json(result.rows.map(claimToJson));
  } catch (err) {
    console.error('Claims fetch error:', err);
    res.status(500).json({ message: 'Could not fetch claims' });
  }
});

// ── GET /claims/:id ─────────────────────────────────────────────────────
router.get('/:id', auth, async (req, res) => {
  try {
    const result = await db.query(
      'SELECT * FROM claims WHERE id = $1 AND worker_id = $2',
      [req.params.id, req.workerId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Claim not found' });
    }
    res.json(claimToJson(result.rows[0]));
  } catch (err) {
    res.status(500).json({ message: 'Could not fetch claim' });
  }
});

// ── POST /claims/submit ─────────────────────────────────────────────────
// Worker submits GPS + photo for a specific alert.
// This is the manual verification flow (Tier 2 soft-flag support).
router.post('/submit', auth, async (req, res) => {
  try {
    const { alertId, gpsLat, gpsLng, imageBase64, deviceId } = req.body;

    if (!alertId) {
      return res.status(400).json({ message: 'alertId is required' });
    }

    // 1. Fetch alert
    const alertRes = await db.query(
      'SELECT * FROM disruption_alerts WHERE id = $1', [alertId]
    );
    if (alertRes.rows.length === 0) {
      return res.status(404).json({ message: 'Alert not found' });
    }
    const alert = alertRes.rows[0];

    // 2. Fetch worker
    const workerRes = await db.query(
      'SELECT * FROM workers WHERE id = $1', [req.workerId]
    );
    const worker = workerRes.rows[0];

    // 3. Check subscription + KYC
    if (!worker.kyc_complete) {
      return res.status(403).json({ message: 'KYC not complete' });
    }
    if (!worker.subscribed) {
      return res.status(403).json({ message: 'Not subscribed to a plan' });
    }

    // 4. Prevent duplicate claims for same worker + alert
    const dupCheck = await db.query(
      'SELECT id FROM claims WHERE worker_id = $1 AND alert_id = $2',
      [req.workerId, alertId]
    );
    if (dupCheck.rows.length > 0) {
      return res.json(claimToJson(
        (await db.query('SELECT * FROM claims WHERE id = $1', [dupCheck.rows[0].id])).rows[0]
      ));
    }

    // 5. Run fraud scoring
    // Real checks:
    // - gpsMatchZone: does GPS coord fall inside alert zone bounding box?
    // - isMockLocation: sent by Flutter SDK (we trust device flag)
    // - workerOnlineBefore: check if worker had any order activity in past 90 min
    //   (in production: query platform API)

    const gpsMatchZone = _gpsInZone(gpsLat, gpsLng, alert.zone);

    // Image analysis: in production, call FastAPI CNN + NetVLAD endpoint
    // In demo: accept all images (imageBase64 presence = submitted)
    const imageSubmitted = Boolean(imageBase64 && imageBase64.length > 100);

    // Check claim history for fraud pattern
    const recentClaims = await db.query(
      `SELECT COUNT(*) FROM claims
       WHERE worker_id = $1
         AND created_at > NOW() - INTERVAL '7 days'`,
      [req.workerId]
    );
    const claimsThisWeek = parseInt(recentClaims.rows[0].count);

    const fraudScore = computeFraudScore({
      gpsMatchZone,
      isMockLocation:      false, // Flutter app sends this — backend trusts device
      workerOnlineBefore:  true,  // production: query platform API
      orderActivityRecent: claimsThisWeek < 4,
      deviceFingerprintNew: false,
      timestampAnomalous:  false,
    });

    // 6. Determine claim status from fraud score
    let status;
    let reviewNote = null;
    if (fraudScore < 0.3) {
      status = 'approved';
    } else if (fraudScore <= 0.7) {
      status = 'fraudCheck';
      reviewNote = `Fraud score ${fraudScore.toFixed(2)} — held for secondary verification. Resolved within 4 hours.`;
    } else {
      status = 'blocked';
      reviewNote = 'Multiple fraud signals detected. Admin review initiated.';
    }

    // 7. Compute payout amount
    const amount = computePayout({
      weeklyEarningsAvg: parseFloat(worker.weekly_earnings_avg),
      disruptionHours:   3,
      payoutPct:         parseFloat(alert.payout_pct),
    });

    // 8. Insert claim
    const claimResult = await db.query(
      `INSERT INTO claims
         (worker_id, alert_id, status, amount, fraud_score,
          gps_lat, gps_lng, device_id, trigger_type, zone, review_note)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [
        req.workerId, alertId, status, amount, fraudScore,
        gpsLat || null, gpsLng || null,
        deviceId || null,
        alert.trigger_type, alert.zone,
        reviewNote,
      ]
    );

    const claim = claimResult.rows[0];

    // 9. If approved, initiate payout (Razorpay in production)
    if (status === 'approved') {
      await _initiatePayout(claim, worker);
    }

    res.status(201).json(claimToJson(claim));

  } catch (err) {
    console.error('Claim submit error:', err);
    res.status(500).json({ message: 'Could not submit claim' });
  }
});

// ── POST /claims/:id/appeal ─────────────────────────────────────────────
// Worker appeals a held or blocked claim.
router.post('/:id/appeal', auth, async (req, res) => {
  try {
    const claimRes = await db.query(
      'SELECT * FROM claims WHERE id = $1 AND worker_id = $2',
      [req.params.id, req.workerId]
    );
    if (claimRes.rows.length === 0) {
      return res.status(404).json({ message: 'Claim not found' });
    }

    const claim = claimRes.rows[0];
    if (!['held', 'fraudCheck', 'blocked'].includes(claim.status)) {
      return res.status(400).json({ message: 'Only held or blocked claims can be appealed' });
    }

    // In production: create appeal record, notify admin
    // In demo: move back to pending
    const updated = await db.query(
      `UPDATE claims SET
         status      = 'fraudCheck',
         review_note = 'Worker appeal submitted. Under admin review.',
         updated_at  = NOW()
       WHERE id = $1 RETURNING *`,
      [claim.id]
    );

    res.json(claimToJson(updated.rows[0]));

  } catch (err) {
    res.status(500).json({ message: 'Appeal failed' });
  }
});

// ── Internal: initiate Razorpay payout ─────────────────────────────────
async function _initiatePayout(claim, worker) {
  try {
    // In production:
    // const razorpay = new Razorpay({ key_id, key_secret });
    // await razorpay.payouts.create({ account_number, amount, currency, mode: 'UPI', ... });

    // Demo: just mark as paid
    await db.query(
      `UPDATE claims SET
         status      = 'paid',
         resolved_at = NOW()
       WHERE id = $1`,
      [claim.id]
    );

    console.log(`[Payout] ₹${claim.amount} → ${worker.upi_id} (claim ${claim.id})`);
  } catch (err) {
    console.error('[Payout] Failed:', err.message);
  }
}

// ── Internal: GPS zone check ─────────────────────────────────────────────
// In production: proper polygon geofencing via Google Maps / Mapbox
function _gpsInZone(lat, lng, zone) {
  if (!lat || !lng) return false;
  lat = parseFloat(lat);
  lng = parseFloat(lng);

  const zoneBounds = {
    'Zone 1 — North':   { latMin: 13.10, latMax: 13.20, lngMin: 80.20, lngMax: 80.27 },
    'Zone 2 — South':   { latMin: 12.98, latMax: 13.02, lngMin: 80.24, lngMax: 80.27 },
    'Zone 3 — East':    { latMin: 13.03, latMax: 13.07, lngMin: 80.26, lngMax: 80.30 },
    'Zone 4 — Central': { latMin: 13.02, latMax: 13.09, lngMin: 80.22, lngMax: 80.28 },
    'Zone 5 — West':    { latMin: 13.04, latMax: 13.12, lngMin: 80.15, lngMax: 80.22 },
  };

  const bounds = zoneBounds[zone];
  if (!bounds) return true; // unknown zone → don't penalise

  return (
    lat >= bounds.latMin && lat <= bounds.latMax &&
    lng >= bounds.lngMin && lng <= bounds.lngMax
  );
}

module.exports = router;
