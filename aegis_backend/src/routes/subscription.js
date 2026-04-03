'use strict';

const express = require('express');
const router  = express.Router();
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

// ── POST /subscription/activate ─────────────────────────────────────────
// Activates weekly plan. In production this initiates a Razorpay
// UPI AutoPay mandate. In demo mode it simply marks subscribed = true.
router.post('/activate', auth, async (req, res) => {
  try {
    const { planTier, weeklyPremium } = req.body;

    // Validate plan tier
    const validTiers = ['basic', 'standard', 'premium'];
    if (!validTiers.includes(planTier)) {
      return res.status(400).json({ message: 'Invalid plan tier' });
    }

    if (!weeklyPremium || weeklyPremium < 1) {
      return res.status(400).json({ message: 'Invalid premium amount' });
    }

    // In production: initiate Razorpay UPI AutoPay mandate here
    // const mandate = await razorpay.subscriptions.create({ ... });

    const result = await db.query(
      `UPDATE workers SET
         subscribed     = true,
         plan_tier      = $1,
         weekly_premium = $2,
         updated_at     = NOW()
       WHERE id = $3 RETURNING *`,
      [planTier, weeklyPremium, req.workerId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Worker not found' });
    }

    res.json(workerToJson(result.rows[0]));

  } catch (err) {
    console.error('Subscription error:', err);
    res.status(500).json({ message: 'Could not activate subscription' });
  }
});

// ── DELETE /subscription/cancel ─────────────────────────────────────────
router.delete('/cancel', auth, async (req, res) => {
  try {
    await db.query(
      `UPDATE workers SET subscribed = false, updated_at = NOW()
       WHERE id = $1`,
      [req.workerId]
    );
    res.json({ message: 'Subscription cancelled' });
  } catch (err) {
    res.status(500).json({ message: 'Could not cancel subscription' });
  }
});

module.exports = router;
