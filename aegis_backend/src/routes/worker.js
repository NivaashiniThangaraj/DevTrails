'use strict';

const express = require('express');
const router  = express.Router();
const bcrypt  = require('bcryptjs');
const db      = require('../db');
const auth    = require('../middleware/auth');

function workerToJson(row) {
  return {
    id:                row.id,
    name:              row.name,
    phone:             row.phone,
    platform:          row.platform,
    city:              row.city,
    zone:              row.zone,
    upiId:             row.upi_id,
    kycComplete:       row.kyc_complete,
    subscribed:        row.subscribed,
    planTier:          row.plan_tier,
    weeklyPremium:     parseFloat(row.weekly_premium),
    weeklyEarningsAvg: parseFloat(row.weekly_earnings_avg),
    riskScore:         row.risk_score,
  };
}

// ── GET /worker/profile ─────────────────────────────────────────────────
router.get('/profile', auth, async (req, res) => {
  try {
    const result = await db.query(
      'SELECT * FROM workers WHERE id = $1', [req.workerId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Worker not found' });
    }
    res.json(workerToJson(result.rows[0]));
  } catch (err) {
    console.error('Profile error:', err);
    res.status(500).json({ message: 'Could not fetch profile' });
  }
});

// ── PATCH /worker/profile ───────────────────────────────────────────────
// Update name, platform, city, zone, upiId
router.patch('/profile', auth, async (req, res) => {
  try {
    const { name, platform, city, zone, upiId } = req.body;
    const result = await db.query(
      `UPDATE workers SET
         name      = COALESCE($1, name),
         platform  = COALESCE($2, platform),
         city      = COALESCE($3, city),
         zone      = COALESCE($4, zone),
         upi_id    = COALESCE($5, upi_id),
         updated_at = NOW()
       WHERE id = $6 RETURNING *`,
      [name, platform, city, zone, upiId, req.workerId]
    );
    res.json(workerToJson(result.rows[0]));
  } catch (err) {
    console.error('Profile update error:', err);
    res.status(500).json({ message: 'Could not update profile' });
  }
});

// ── POST /worker/kyc ────────────────────────────────────────────────────
// Simulates Aadhaar e-KYC via DigiLocker.
// In production: call DigiLocker OAuth API and verify Aadhaar.
// In demo: accept any 12-digit number and mark KYC complete.
router.post('/kyc', auth, async (req, res) => {
  try {
    const { aadhaarNumber, workerId } = req.body;

    if (!aadhaarNumber || aadhaarNumber.replace(/\s/g, '').length !== 12) {
      return res.status(400).json({ message: 'Enter a valid 12-digit Aadhaar number' });
    }

    // Store hashed Aadhaar (never store plaintext)
    const aadhaarHash = await bcrypt.hash(aadhaarNumber.replace(/\s/g, ''), 10);

    const result = await db.query(
      `UPDATE workers SET
         kyc_complete  = true,
         aadhaar_hash  = $1,
         updated_at    = NOW()
       WHERE id = $2 RETURNING *`,
      [aadhaarHash, req.workerId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Worker not found' });
    }

    res.json(workerToJson(result.rows[0]));

  } catch (err) {
    console.error('KYC error:', err);
    res.status(500).json({ message: 'KYC verification failed' });
  }
});

module.exports = router;
