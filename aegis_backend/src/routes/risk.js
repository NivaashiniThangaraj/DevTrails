'use strict';

const express = require('express');
const router  = express.Router();
const auth    = require('../middleware/auth');
const { computeRiskScore } = require('../services/riskEngine');

// ── POST /risk/score ────────────────────────────────────────────────────
// Accepts live weather + worker profile, returns risk score + premium.
router.post('/score', auth, async (req, res) => {
  try {
    const {
      city, zone, weeklyEarningsAvg,
      rainfallMm, tempC, aqi,
      orderDropPct, earningsDropPct,
      monsoonSeason,
    } = req.body;

    const result = computeRiskScore({
      zone:              zone || 'Zone 4 — Central',
      weeklyEarningsAvg: parseFloat(weeklyEarningsAvg) || 4500,
      rainfallMm:        parseFloat(rainfallMm) || 0,
      tempC:             parseFloat(tempC) || 32,
      aqi:               parseInt(aqi) || 50,
      orderDropPct:      parseFloat(orderDropPct) || 0,
      earningsDropPct:   parseFloat(earningsDropPct) || 0,
      monsoonSeason:     Boolean(monsoonSeason),
    });

    res.json(result);

  } catch (err) {
    console.error('Risk score error:', err);
    res.status(500).json({ message: 'Could not compute risk score' });
  }
});

module.exports = router;
