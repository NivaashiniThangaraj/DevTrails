'use strict';

// Mirrors the README formula exactly:
// Weekly Premium = BASE × RiskMultiplier × LoyaltyFactor × ZoneFactor × SeasonFactor

const ZONE_FACTORS = {
  'Zone 1 — North':   1.05,
  'Zone 2 — South':   1.00,
  'Zone 3 — East':    1.00,
  'Zone 4 — Central': 1.10,
  'Zone 5 — West':    0.95,
};

const WEIGHTS = {
  rainfall_65mm:    1.0,
  temp_41c:         0.9,
  aqi_300:          0.8,
  order_drop_30pct: 1.0,
  earnings_drop_20: 0.9,
};

function computeRiskScore({
  zone,
  weeklyEarningsAvg = 4500,
  rainfallMm = 0,
  tempC = 32,
  aqi = 50,
  orderDropPct = 0,
  earningsDropPct = 0,
  hasClaimsLast12Weeks = false,
  monsoonSeason = false,
}) {
  // 1. Active conditions
  const conditions = {};
  if (rainfallMm > 65)        conditions.rainfall_65mm    = WEIGHTS.rainfall_65mm;
  if (tempC > 41)             conditions.temp_41c          = WEIGHTS.temp_41c;
  if (aqi > 300)              conditions.aqi_300           = WEIGHTS.aqi_300;
  if (orderDropPct > 0.30)    conditions.order_drop_30pct  = WEIGHTS.order_drop_30pct;
  if (earningsDropPct > 0.20) conditions.earnings_drop_20  = WEIGHTS.earnings_drop_20;

  // 2. Raw score → normalise to 0-100
  const rawScore = Object.values(conditions).reduce((a, b) => a + b, 0);
  const maxPossible = Object.values(WEIGHTS).reduce((a, b) => a + b, 0);
  const riskScore = Math.min(100, Math.round((rawScore / maxPossible) * 100));

  // 3. RiskMultiplier = 1 + 0.4 × min(rawScore/8, 1)
  const riskMultiplier = +(1 + 0.4 * Math.min(rawScore / 8, 1)).toFixed(2);

  // 4. Loyalty factor
  const loyaltyFactor = hasClaimsLast12Weeks ? 1.0 : 0.85;

  // 5. Zone factor
  const zoneFactor = ZONE_FACTORS[zone] || 1.0;

  // 6. Season factor
  const seasonFactor = monsoonSeason ? 1.3 : 1.0;

  // 7. BASE = weeklyEarningsAvg × 0.75%
  const base = weeklyEarningsAvg * 0.0075;

  // 8. Final premium clamped to ₹13–₹100
  const weeklyPremium = Math.round(
    Math.min(100, Math.max(13,
      base * riskMultiplier * loyaltyFactor * zoneFactor * seasonFactor
    ))
  );

  // 9. Coverage
  const dailyEarnings = weeklyEarningsAvg / 6;
  const dailyCoverage = Math.round(dailyEarnings * 0.80);
  const maxWeekly = dailyCoverage * 2;

  // 10. Band
  let band = 'low';
  if (riskScore >= 75) band = 'extreme';
  else if (riskScore >= 50) band = 'high';
  else if (riskScore >= 25) band = 'medium';

  return {
    score: riskScore,
    multiplier: riskMultiplier,
    weeklyPremium,
    dailyCoverage,
    maxWeekly,
    breakdown: conditions,
    band,
  };
}

// Payout = (VerifiedHourlyRate × DisruptionHoursLost) × PayoutPct
function computePayout({ weeklyEarningsAvg, disruptionHours, payoutPct }) {
  const hourlyRate = weeklyEarningsAvg / (6 * 10);
  return Math.round(hourlyRate * disruptionHours * payoutPct);
}

// Fraud score — Isolation Forest simulation
// In production this calls the Python FastAPI ML service
function computeFraudScore({
  gpsMatchZone = true,
  isMockLocation = false,
  workerOnlineBefore = true,
  orderActivityRecent = true,
  deviceFingerprintNew = false,
  timestampAnomalous = false,
}) {
  let score = 0;
  if (isMockLocation)         score += 0.45; // hard flag
  if (!gpsMatchZone)          score += 0.25;
  if (!workerOnlineBefore)    score += 0.20;
  if (!orderActivityRecent)   score += 0.15;
  if (deviceFingerprintNew)   score += 0.10;
  if (timestampAnomalous)     score += 0.10;
  return Math.min(1, +score.toFixed(3));
}

module.exports = { computeRiskScore, computePayout, computeFraudScore };
