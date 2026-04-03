'use strict';

const express = require('express');
const router  = express.Router();
const db      = require('../db');
const auth    = require('../middleware/auth');
const { runPollCycle } = require('../services/triggerEngine');

function alertToJson(row) {
  return {
    id:          row.id,
    type:        row.trigger_type,
    zone:        row.zone,
    city:        row.city,
    detectedAt:  row.detected_at,
    severity:    parseFloat(row.severity),
    payoutPct:   parseFloat(row.payout_pct),
    gate1Pass:   row.gate1_pass,
    gate2Pass:   row.gate2_pass,
    description: row.description,
    status:      row.status,
  };
}

// ── GET /triggers/alerts?zone= ──────────────────────────────────────────
// Returns active alerts for the worker's zone.
router.get('/alerts', async (req, res) => {
  try {
    const { zone } = req.query;

    // Normalize function (VERY IMPORTANT)
    const normalize = (z) =>
      z?.replace(/[—–]/g, '-')  // replace em dash / en dash → hyphen
        .trim()
        .toLowerCase();

    let searchZone = normalize(zone);

    // If zone not provided, get from DB (optional)
    if (!searchZone) {
      const workerRes = await db.query(
        'SELECT zone FROM workers WHERE id = $1',
        [req.workerId]
      );
      searchZone = normalize(workerRes.rows[0]?.zone);
    }

    const result = await db.query(
      `SELECT * FROM disruption_alerts
       WHERE LOWER(REPLACE(zone, '—', '-')) = $1
       AND status = 'active'
       ORDER BY detected_at DESC
       LIMIT 10`,
      [searchZone]
    );

    res.json(result.rows.map(alertToJson));

  } catch (err) {
    console.error('Alerts fetch error:', err);
    res.status(500).json({ message: 'Could not fetch alerts' });
  }
});

// ── GET /triggers/all ───────────────────────────────────────────────────
// Returns all recent alerts regardless of zone (last 24 hours).
router.get('/all', auth, async (req, res) => {
  try {
    const result = await db.query(
      `SELECT * FROM disruption_alerts
       WHERE detected_at > NOW() - INTERVAL '24 hours'
       ORDER BY detected_at DESC`
    );
    res.json(result.rows.map(alertToJson));
  } catch (err) {
    res.status(500).json({ message: 'Could not fetch alerts' });
  }
});

// ── POST /triggers/poll ─────────────────────────────────────────────────
// Manually trigger a poll cycle (admin / testing).
router.post('/poll', auth, async (req, res) => {
  try {
    // Run async, don't wait
    runPollCycle().catch(console.error);
    res.json({ message: 'Poll cycle initiated' });
  } catch (err) {
    res.status(500).json({ message: 'Poll failed' });
  }
});

// ── POST /triggers/simulate ─────────────────────────────────────────────
// Simulate a disruption event for testing (dev only).
router.post('/simulate', async (req, res) => {
  if (process.env.NODE_ENV === 'production') {
    return res.status(403).json({ message: 'Not available in production' });
  }

  try {
    const {
      triggerType = 'heavyRainfall',
      zone = 'Zone 4 - Central',
      city = 'Chennai',
      payoutPct = 0.8,
    } = req.body;

    const result = await db.query(
      `INSERT INTO disruption_alerts
         (trigger_type, zone, city, severity, payout_pct,
          gate1_pass, gate2_pass, description, status)
       VALUES ($1, $2, $3, 0.9, $4, true, true, $5, 'active')
       RETURNING *`,
      [
        triggerType, zone, city, payoutPct,
        `[SIMULATED] ${triggerType} in ${zone}`,
      ]
    );

    // Auto-trigger claims immediately
    const { autoTriggerClaims } = require('../services/triggerEngine');
    // Note: triggerEngine exports autoTriggerClaims only in module scope
    // For simulation we directly insert claims
    const workers = await db.query(
      `SELECT * FROM workers
       WHERE zone = $1 AND subscribed = true AND kyc_complete = true`,
      [zone]
    );

    for (const w of workers.rows) {
      const hourlyRate = parseFloat(w.weekly_earnings_avg) / 60;
      const amount = Math.round(hourlyRate * 3 * payoutPct);
      await db.query(
        `INSERT INTO claims
           (worker_id, alert_id, status, amount, fraud_score, trigger_type, zone)
         VALUES ($1, $2, 'pending', $3, 0.05, $4, $5)
         ON CONFLICT DO NOTHING`,
        [w.id, result.rows[0].id, amount, triggerType, zone]
      );
    }

    res.status(201).json({
      alert: alertToJson(result.rows[0]),
      claimsCreated: workers.rows.length,
    });

  } catch (err) {
    console.error('Simulate error:', err);
    res.status(500).json({ message: 'Simulation failed' });
  }
});

module.exports = router;
