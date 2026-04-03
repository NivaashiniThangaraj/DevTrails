'use strict';

const axios = require('axios');
const db    = require('../db');

const OWM_KEY = process.env.OWM_API_KEY;

// City → [lat, lng] for OWM AQI API
const CITY_COORDS = {
  'Chennai':   [13.0827, 80.2707],
  'Mumbai':    [19.0760, 72.8777],
  'Delhi':     [28.6139, 77.2090],
  'Bengaluru': [12.9716, 77.5946],
  'Hyderabad': [17.3850, 78.4867],
};

// Payout percentages per trigger type (README §3)
const PAYOUT_PCT = {
  heavyRainfall:    0.80,
  severeFlooding:   1.00,
  extremeHeat:      0.75,
  cyclone:          1.00,
  hazardousAqi:     0.80,
  curfew:           0.90,
  transportStrike:  0.75,
  zoneSuspension:   0.85,
};

// ── Weather fetch ────────────────────────────────────────────────────────
async function fetchWeather(city) {
  if (!OWM_KEY || OWM_KEY === 'your_openweathermap_api_key') {
    // Return realistic demo data when no key set
    return {
      tempC:       32.5,
      rainfallMm:  0,
      windKmh:     12,
      description: 'partly cloudy',
    };
  }

  try {
    const res = await axios.get(
      `https://api.openweathermap.org/data/2.5/weather`,
      { params: { q: `${city},IN`, appid: OWM_KEY, units: 'metric' }, timeout: 8000 }
    );
    const d = res.data;
    return {
      tempC:       d.main.temp,
      rainfallMm:  d.rain?.['3h'] || d.rain?.['1h'] || 0,
      windKmh:     (d.wind?.speed || 0) * 3.6,
      description: d.weather?.[0]?.description || '',
    };
  } catch (e) {
    console.warn(`[TriggerEngine] Weather fetch failed for ${city}:`, e.message);
    return { tempC: 32, rainfallMm: 0, windKmh: 10, description: '' };
  }
}

async function fetchAqi(city) {
  if (!OWM_KEY || OWM_KEY === 'your_openweathermap_api_key') return 80;
  try {
    const [lat, lng] = CITY_COORDS[city] || [13.0827, 80.2707];
    const res = await axios.get(
      `https://api.openweathermap.org/data/2.5/air_pollution`,
      { params: { lat, lon: lng, appid: OWM_KEY }, timeout: 8000 }
    );
    // Map OWM 1-5 → CPCB-style numeric
    const owm = res.data.list?.[0]?.main?.aqi || 1;
    return [25, 75, 150, 250, 375][owm - 1] || 50;
  } catch (e) {
    return 80;
  }
}

// ── Gate evaluation (README §3) ──────────────────────────────────────────
function evaluateGates({ tempC, rainfallMm, windKmh, aqi, orderDropPct }) {
  const triggers = [];

  // Gate 1: external signal
  let gate1 = false;
  let triggerType = null;
  let payoutPct = 0;

  if (rainfallMm >= 120) {
    gate1 = true; triggerType = 'severeFlooding'; payoutPct = PAYOUT_PCT.severeFlooding;
  } else if (rainfallMm >= 65) {
    gate1 = true; triggerType = 'heavyRainfall'; payoutPct = PAYOUT_PCT.heavyRainfall;
  } else if (windKmh >= 60) {
    gate1 = true; triggerType = 'cyclone'; payoutPct = PAYOUT_PCT.cyclone;
  } else if (tempC >= 41) {
    gate1 = true; triggerType = 'extremeHeat'; payoutPct = PAYOUT_PCT.extremeHeat;
  } else if (aqi >= 300) {
    gate1 = true; triggerType = 'hazardousAqi'; payoutPct = PAYOUT_PCT.hazardousAqi;
  }

  if (!gate1) return { gate1: false, gate2: false, triggerType: null, payoutPct: 0 };

  // Gate 2: business impact
  // In production: real order volume from platform APIs
  // In demo: simulate 35% drop during weather events
  const simulatedOrderDrop = gate1 ? 0.35 : 0;
  const gate2 = simulatedOrderDrop > 0.30;

  return { gate1, gate2, triggerType, payoutPct };
}

// ── Create disruption alert ──────────────────────────────────────────────
async function createAlert({ city, zone, triggerType, payoutPct, gate1, gate2, description }) {
  // Avoid duplicate active alerts for the same zone + type
  const existing = await db.query(
    `SELECT id FROM disruption_alerts
     WHERE zone = $1 AND trigger_type = $2 AND status = 'active'
       AND detected_at > NOW() - INTERVAL '2 hours'`,
    [zone, triggerType]
  );
  if (existing.rows.length > 0) return null; // already alerted

  const result = await db.query(
    `INSERT INTO disruption_alerts
       (trigger_type, zone, city, severity, payout_pct, gate1_pass, gate2_pass, description, status)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'active')
     RETURNING *`,
    [
      triggerType, zone, city,
      0.8, payoutPct, gate1, gate2,
      description || `${triggerType} detected in ${zone}`,
    ]
  );
  return result.rows[0];
}

// ── Auto-trigger claims for subscribed workers ───────────────────────────
async function autoTriggerClaims(alert, weeklyEarningsAvg = 4500) {
  if (!alert.gate1_pass || !alert.gate2_pass) return;

  // Get all subscribed workers in the alert zone
  const workers = await db.query(
    `SELECT id, zone, weekly_earnings_avg, plan_tier, weekly_premium
     FROM workers
     WHERE zone = $1 AND subscribed = true AND kyc_complete = true`,
    [alert.zone]
  );

  for (const w of workers.rows) {
    // Skip if claim already exists for this worker + alert
    const exists = await db.query(
      'SELECT id FROM claims WHERE worker_id = $1 AND alert_id = $2',
      [w.id, alert.id]
    );
    if (exists.rows.length > 0) continue;

    // Compute payout (README formula)
    const hourlyRate = parseFloat(w.weekly_earnings_avg) / (6 * 10);
    const disruptionHours = 3; // default 3 hours per event
    const amount = Math.round(hourlyRate * disruptionHours * alert.payout_pct);

    // Fraud score = 0.1 for auto-triggered (no GPS/photo to check yet)
    const fraudScore = 0.10;
    const status = 'pending';

    await db.query(
      `INSERT INTO claims
         (worker_id, alert_id, status, amount, fraud_score, trigger_type, zone)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [w.id, alert.id, status, amount, fraudScore, alert.trigger_type, alert.zone]
    );
  }

  console.log(`[TriggerEngine] Auto-triggered claims for ${workers.rows.length} workers in ${alert.zone}`);
}

// ── Main poll function ────────────────────────────────────────────────────
// Called every 30 minutes per README spec.
async function runPollCycle() {
  console.log('[TriggerEngine] Running poll cycle at', new Date().toISOString());

  // Get unique cities with subscribed workers
  const citiesRes = await db.query(
    `SELECT DISTINCT city, zone FROM workers
     WHERE subscribed = true AND kyc_complete = true`
  );

  for (const row of citiesRes.rows) {
    const { city, zone } = row;
    try {
      const [weather, aqi] = await Promise.all([
        fetchWeather(city),
        fetchAqi(city),
      ]);

      const gates = evaluateGates({
        tempC: weather.tempC,
        rainfallMm: weather.rainfallMm,
        windKmh: weather.windKmh,
        aqi,
        orderDropPct: 0,
      });

      if (gates.gate1) {
        const desc = `${gates.triggerType} detected — ${city} ${zone}. Gate 1: ✓ Gate 2: ${gates.gate2 ? '✓' : '✗'}`;
        console.log(`[TriggerEngine] ${desc}`);

        const alert = await createAlert({
          city, zone,
          triggerType: gates.triggerType,
          payoutPct: gates.payoutPct,
          gate1: gates.gate1,
          gate2: gates.gate2,
          description: desc,
        });

        if (alert && gates.gate1 && gates.gate2) {
          await autoTriggerClaims(alert);
        }
      }

      // Auto-resolve old active alerts that no longer meet threshold
      if (!gates.gate1) {
        await db.query(
          `UPDATE disruption_alerts
           SET status = 'resolved', resolved_at = NOW()
           WHERE zone = $1 AND status = 'active'
             AND detected_at < NOW() - INTERVAL '1 hour'`,
          [zone]
        );
      }

    } catch (err) {
      console.error(`[TriggerEngine] Error for ${city}/${zone}:`, err.message);
    }
  }
}

// ── Start polling loop ────────────────────────────────────────────────────
function startTriggerEngine() {
  console.log('[TriggerEngine] Starting — polling every 30 minutes');
  runPollCycle(); // run immediately on start
  setInterval(runPollCycle, 30 * 60 * 1000); // then every 30 min
}

module.exports = { startTriggerEngine, runPollCycle, fetchWeather, fetchAqi };
