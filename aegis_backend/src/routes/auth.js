'use strict';

const express = require('express');
const router  = express.Router();
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const db      = require('../db');

// ── Helpers ─────────────────────────────────────────────────────────────
function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function signToken(workerId) {
  return jwt.sign({ workerId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  });
}

function workerToJson(row) {
  return {
    id:                 row.id,
    name:               row.name,
    phone:              row.phone,
    platform:           row.platform,
    city:               row.city,
    zone:               row.zone,
    upiId:              row.upi_id,
    kycComplete:        row.kyc_complete,
    subscribed:         row.subscribed,
    planTier:           row.plan_tier,
    weeklyPremium:      parseFloat(row.weekly_premium),
    weeklyEarningsAvg:  parseFloat(row.weekly_earnings_avg),
    riskScore:          row.risk_score,
  };
}

// ── POST /auth/otp/request ──────────────────────────────────────────────
// Sends (or in test mode returns) a 6-digit OTP for the phone number.
router.post('/otp/request', async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) return res.status(400).json({ message: 'Phone is required' });

    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Invalidate old OTPs for this phone
    await db.query(
      'UPDATE otps SET used = true WHERE phone = $1 AND used = false',
      [phone]
    );

    // Store new OTP
    await db.query(
      'INSERT INTO otps (phone, otp, expires_at) VALUES ($1, $2, $3)',
      [phone, otp, expiresAt]
    );

    // In production: send via Twilio / MSG91
    // In test/dev mode: return OTP in response body for demo
    if (process.env.USE_REAL_SMS === 'true') {
      // TODO: integrate SMS provider here
      // await smsService.send(phone, `Your Aegis OTP is ${otp}`);
      return res.json({ message: 'OTP sent', otp: '' });
    }

    // Demo mode — return OTP so the Flutter app can display it
    console.log(`[OTP] ${phone} → ${otp}`);
    return res.json({ message: 'OTP sent (demo mode)', otp });

  } catch (err) {
    console.error('OTP request error:', err);
    res.status(500).json({ message: 'Failed to send OTP' });
  }
});

// ── POST /auth/otp/verify ───────────────────────────────────────────────
// Verifies OTP and returns worker + JWT. Creates account if new.
router.post('/otp/verify', async (req, res) => {
  try {
    const { phone, otp } = req.body;
    if (!phone || !otp) {
      return res.status(400).json({ message: 'Phone and OTP are required' });
    }

    // Check OTP
    const otpRes = await db.query(
      `SELECT * FROM otps
       WHERE phone = $1 AND otp = $2 AND used = false
         AND expires_at > NOW()
       ORDER BY created_at DESC LIMIT 1`,
      [phone, otp]
    );

    if (otpRes.rows.length === 0) {
      return res.status(400).json({ message: 'Invalid or expired OTP' });
    }

    // Mark as used
    await db.query('UPDATE otps SET used = true WHERE id = $1', [otpRes.rows[0].id]);

    // Find or create worker
    let workerRes = await db.query(
      'SELECT * FROM workers WHERE phone = $1', [phone]
    );

    let worker;
    if (workerRes.rows.length === 0) {
      // New worker — create minimal record
      const insert = await db.query(
        `INSERT INTO workers (phone) VALUES ($1) RETURNING *`,
        [phone]
      );
      worker = insert.rows[0];
    } else {
      worker = workerRes.rows[0];
    }

    const token = signToken(worker.id);
    return res.json({ token, worker: workerToJson(worker) });

  } catch (err) {
    console.error('OTP verify error:', err);
    res.status(500).json({ message: 'Verification failed' });
  }
});

// ── POST /auth/register ─────────────────────────────────────────────────
// Creates or updates worker profile after OTP verify.
router.post('/register', async (req, res) => {
  try {
    const { name, phone, platform, city, zone, upiId } = req.body;
    if (!phone) return res.status(400).json({ message: 'Phone is required' });

    // Upsert worker
    const result = await db.query(
      `INSERT INTO workers (phone, name, platform, city, zone, upi_id)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (phone) DO UPDATE SET
         name      = EXCLUDED.name,
         platform  = EXCLUDED.platform,
         city      = EXCLUDED.city,
         zone      = EXCLUDED.zone,
         upi_id    = EXCLUDED.upi_id,
         updated_at = NOW()
       RETURNING *`,
      [phone, name || '', platform || 'Swiggy',
       city || 'Chennai', zone || 'Zone 4 — Central', upiId || '']
    );

    const worker = result.rows[0];
    const token  = signToken(worker.id);
    return res.status(201).json({ token, worker: workerToJson(worker) });

  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ message: 'Registration failed' });
  }
});

module.exports = router;
