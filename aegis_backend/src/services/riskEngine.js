'use strict';

const ZONE_FACTORS = {
  'Zone 1 — North':   1.05,
  'Zone 2 — South':   1.00,
  'Zone 3 — East':    1.00,
  'Zone 4 — Central': 1.10,
  'Zone 5 — West':    0.95,
};

// Now an async function because it calls the Python API
async function computeRiskScore({
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
  let mlRiskScore = 0;
  let mlBand = 'low';

  try {
    // 1. Prepare data for the Python ML Service
    const mlPayload = {
      worker: { worker_id: "W-ML-EVAL" },
      location: { lat: 13.08, lon: 80.27 }, // Defaults for geographic context
      external_disruption: {
        weather: {
          temp_c: tempC,
          feels_like_c: tempC + 2, 
          rainfall_mm: rainfallMm
        },
        air_quality: {
          pm25: aqi * 0.5, // Rough conversion for the model
          pm10: aqi
        },
        traffic: { traffic_index: 50 }
      },
      business_impact: {
        avg_daily_earnings: weeklyEarningsAvg / 6,
        expected_hours: 10
      }
    };

    // 2. Fetch live ML Prediction from Python (Port 8000)
    // Note: Requires Node.js 18+ for native fetch
    const response = await fetch('http://localhost:8000/api/v1/full-analysis', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(mlPayload)
    });

    if (response.ok) {
        const mlData = await response.json();
        mlRiskScore = mlData.risk_analysis.risk_score;
        mlBand = mlData.risk_analysis.risk_level.toLowerCase();
    } else {
        console.error("Python ML service returned an error, using fallback.");
        mlRiskScore = (rainfallMm > 65 || tempC > 41) ? 8 : 2;
        mlBand = mlRiskScore >= 8 ? 'high' : 'low';
    }
  } catch (error) {
    console.error("Failed to connect to Python ML service. Is it running on port 8000?", error.message);
    mlRiskScore = (rainfallMm > 65 || tempC > 41) ? 8 : 2;
    mlBand = mlRiskScore >= 8 ? 'high' : 'low';
  }

  // 3. Normalise ML score (0-10) to 0-100 scale for legacy frontend compatibility
  const riskScore100 = Math.min(100, Math.round((mlRiskScore / 10) * 100));

  // 4. RiskMultiplier = 1 + 0.4 × min(mlRiskScore/8, 1)
  const riskMultiplier = +(1 + 0.4 * Math.min(mlRiskScore / 8, 1)).toFixed(2);

  // 5. Business Logic & Premium Calculation
  const loyaltyFactor = hasClaimsLast12Weeks ? 1.0 : 0.85;
  const zoneFactor = ZONE_FACTORS[zone] || 1.0;
  const seasonFactor = monsoonSeason ? 1.3 : 1.0;
  const base = weeklyEarningsAvg * 0.0075;

  const weeklyPremium = Math.round(
    Math.min(100, Math.max(13, base * riskMultiplier * loyaltyFactor * zoneFactor * seasonFactor))
  );

  const dailyEarnings = weeklyEarningsAvg / 6;
  const dailyCoverage = Math.round(dailyEarnings * 0.80);
  const maxWeekly = dailyCoverage * 2;

  // 6. Return standard format exactly as the Flutter models.dart expects
  return {
    score: riskScore100,
    multiplier: riskMultiplier,
    weeklyPremium,
    dailyCoverage,
    maxWeekly,
    breakdown: { "ml_engine_prediction_score": mlRiskScore },
    band: mlBand,
  };
}

function computePayout({ weeklyEarningsAvg, disruptionHours, payoutPct }) {
  const hourlyRate = weeklyEarningsAvg / (6 * 10);
  return Math.round(hourlyRate * disruptionHours * payoutPct);
}

function computeFraudScore({
  gpsMatchZone = true,
  isMockLocation = false,
  workerOnlineBefore = true,
  orderActivityRecent = true,
  deviceFingerprintNew = false,
  timestampAnomalous = false,
}) {
  let score = 0;
  if (isMockLocation)         score += 0.45;
  if (!gpsMatchZone)          score += 0.25;
  if (!workerOnlineBefore)    score += 0.20;
  if (!orderActivityRecent)   score += 0.15;
  if (deviceFingerprintNew)   score += 0.10;
  if (timestampAnomalous)     score += 0.10;
  return Math.min(1, +score.toFixed(3));
}

module.exports = { computeRiskScore, computePayout, computeFraudScore };