"""
main.py  –  Aegis ML microservice
Serves two endpoints:
  POST /predict/risk   → XGBoost risk score + premium calculation
  POST /predict/fraud  → Isolation Forest fraud score (0-1)

Run with:
  uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""

import json
import math
import os
from typing import Optional

import joblib
import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# ── Load models ──────────────────────────────────────────────────────────
BASE_DIR    = os.path.dirname(__file__)
MODELS_DIR  = os.path.join(BASE_DIR, 'models')

xgb_model   = joblib.load(os.path.join(MODELS_DIR, 'xgb_risk_model.joblib'))
iso_model   = joblib.load(os.path.join(MODELS_DIR, 'iso_fraud_model.joblib'))
scaler      = joblib.load(os.path.join(MODELS_DIR, 'scaler.joblib'))

with open(os.path.join(MODELS_DIR, 'feature_names.json')) as f:
    feature_cfg = json.load(f)

RISK_FEATURES  = feature_cfg['risk_features']
FRAUD_FEATURES = feature_cfg['fraud_features']

# ── Zone constants ───────────────────────────────────────────────────────
ZONE_FACTOR = {
    'Zone 1 — North':   1.05,
    'Zone 2 — South':   1.00,
    'Zone 3 — East':    1.00,
    'Zone 4 — Central': 1.10,
    'Zone 5 — West':    0.95,
}
ZONE_FLOOD_EVENTS = {
    'Zone 1 — North':   3,
    'Zone 2 — South':   2,
    'Zone 3 — East':    3,
    'Zone 4 — Central': 5,
    'Zone 5 — West':    1,
}

# ── App ──────────────────────────────────────────────────────────────────
app = FastAPI(title='Aegis ML Service', version='1.0.0')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_methods=['*'],
    allow_headers=['*'],
)

# ── Schemas ──────────────────────────────────────────────────────────────
class RiskRequest(BaseModel):
    zone:                str   = Field('Zone 4 — Central')
    month:               int   = Field(..., ge=1, le=12)
    rainfall_mm:         float = Field(0.0, ge=0)
    temp_c:              float = Field(32.0)
    wind_kmh:            float = Field(10.0, ge=0)
    aqi:                 int   = Field(80, ge=0)
    weekly_earnings_avg: float = Field(4500.0, ge=0)
    order_drop_pct:      float = Field(0.0, ge=0, le=1)
    hours_online:        float = Field(8.0, ge=0)
    claims_last_12w:     int   = Field(0, ge=0)
    has_claims_12w:      bool  = Field(False)

class RiskResponse(BaseModel):
    score:          int
    band:           str
    multiplier:     float
    weekly_premium: float
    daily_coverage: float
    max_weekly:     float
    breakdown:      dict
    model_used:     str

class FraudRequest(BaseModel):
    gps_zone_match:       float = Field(1.0, ge=0, le=1)
    movement_variance:    float = Field(0.5, ge=0, le=1)
    order_activity_score: float = Field(0.8, ge=0, le=1)
    app_session_mins:     float = Field(60.0, ge=0)
    claim_freq_7d:        int   = Field(0, ge=0)
    device_age_days:      float = Field(180.0, ge=0)
    login_hour:           float = Field(12.0, ge=0, le=24)
    gps_speed_kmh:        float = Field(15.0, ge=0)
    location_entropy:     float = Field(0.7, ge=0, le=1)
    orders_before_event:  float = Field(5.0, ge=0)
    is_mock_location:     bool  = Field(False)

class FraudResponse(BaseModel):
    fraud_score:  float   # 0.0 (clean) → 1.0 (fraud)
    verdict:      str     # approved | held | blocked
    signals:      dict
    model_used:   str

# ── Helpers ──────────────────────────────────────────────────────────────
def _compute_premium(
    risk_score: int,
    zone: str,
    weekly_earnings_avg: float,
    has_claims: bool,
    month: int,
) -> tuple[float, float, float, float]:
    """README formula: Premium = BASE × RiskMultiplier × LoyaltyFactor × ZoneFactor × SeasonFactor"""
    raw_score      = risk_score / 100 * 4.6         # un-normalise back to 0-4.6
    risk_mult      = 1.0 + 0.4 * min(raw_score / 8, 1.0)
    loyalty        = 1.0 if has_claims else 0.85
    zone_f         = ZONE_FACTOR.get(zone, 1.0)
    season_f       = 1.3 if month in [10, 11, 12] else (1.1 if month in [4, 5] else 1.0)

    base           = weekly_earnings_avg * 0.0075
    premium        = base * risk_mult * loyalty * zone_f * season_f
    premium        = max(13.0, min(100.0, premium))

    daily_earnings = weekly_earnings_avg / 6
    daily_coverage = daily_earnings * 0.80
    max_weekly     = daily_coverage * 2.0

    return (
        round(premium, 0),
        round(daily_coverage, 0),
        round(max_weekly, 0),
        round(risk_mult, 2),
    )

def _risk_band(score: int) -> str:
    if score < 25: return 'low'
    if score < 50: return 'medium'
    if score < 75: return 'high'
    return 'extreme'

def _fraud_verdict(score: float) -> str:
    if score < 0.30: return 'approved'
    if score <= 0.70: return 'held'
    return 'blocked'

# ── Endpoints ────────────────────────────────────────────────────────────
@app.get('/health')
def health():
    return {'status': 'ok', 'service': 'aegis-ml', 'models': ['xgb_risk', 'iso_fraud']}


@app.post('/predict/risk', response_model=RiskResponse)
def predict_risk(req: RiskRequest):
    """XGBoost risk score prediction.
    Returns 0-100 score + premium calculation using README formula.
    """
    is_monsoon = int(req.month in [10, 11, 12])
    is_summer  = int(req.month in [4, 5, 6])
    zf         = ZONE_FACTOR.get(req.zone, 1.0)
    zfe        = ZONE_FLOOD_EVENTS.get(req.zone, 2)

    zone_central = int(req.zone == 'Zone 4 — Central')
    zone_north   = int(req.zone == 'Zone 1 — North')
    zone_south   = int(req.zone == 'Zone 2 — South')
    zone_east    = int(req.zone == 'Zone 3 — East')
    zone_west    = int(req.zone == 'Zone 5 — West')

    X = np.array([[
        req.month, is_monsoon, is_summer,
        req.rainfall_mm, req.temp_c, req.wind_kmh, req.aqi,
        req.weekly_earnings_avg, req.order_drop_pct, req.hours_online,
        req.claims_last_12w, zfe, zf,
        zone_central, zone_north, zone_south, zone_east, zone_west,
    ]])

    raw_pred    = xgb_model.predict(X)[0]
    risk_score  = int(np.clip(round(raw_pred), 0, 100))

    # Compute premium using README formula on top of ML score
    premium, daily_cov, max_weekly, multiplier = _compute_premium(
        risk_score, req.zone, req.weekly_earnings_avg,
        req.has_claims_12w, req.month,
    )

    # Build breakdown of active conditions (for UI display)
    breakdown = {}
    if req.rainfall_mm > 65:      breakdown['rainfall_65mm']    = 1.0
    if req.temp_c > 41:           breakdown['temp_41c']          = 0.9
    if req.aqi > 300:             breakdown['aqi_300']           = 0.8
    if req.order_drop_pct > 0.30: breakdown['order_drop_30pct']  = 1.0

    return RiskResponse(
        score          = risk_score,
        band           = _risk_band(risk_score),
        multiplier     = multiplier,
        weekly_premium = premium,
        daily_coverage = daily_cov,
        max_weekly     = max_weekly,
        breakdown      = breakdown,
        model_used     = 'xgboost_v1',
    )


@app.post('/predict/fraud', response_model=FraudResponse)
def predict_fraud(req: FraudRequest):
    """Isolation Forest fraud / anomaly detection.
    Returns fraud_score 0→1 and verdict (approved / held / blocked).
    Mock location is a hard flag regardless of model score.
    """
    # Hard rule: mock location = instant block
    if req.is_mock_location:
        return FraudResponse(
            fraud_score = 0.95,
            verdict     = 'blocked',
            signals     = {'mock_location': True},
            model_used  = 'hard_rule',
        )

    X = np.array([[
        req.gps_zone_match,
        req.movement_variance,
        req.order_activity_score,
        req.app_session_mins,
        float(req.claim_freq_7d),
        req.device_age_days,
        req.login_hour,
        req.gps_speed_kmh,
        req.location_entropy,
        req.orders_before_event,
    ]])

    X_scaled    = scaler.transform(X)
    raw_score   = iso_model.score_samples(X_scaled)[0]   # negative = more anomalous

    # Calibrated normalisation using training data percentiles.
    # Scores below calib[p5] = clearly anomalous → fraud_score near 1.0
    # Scores above calib[max] = very normal → fraud_score near 0.0
    # Range: [min_score, max_score] mapped to [1.0, 0.0]
    score_min = calibration["min_score"]
    score_max = calibration["max_score"]
    score_range = score_max - score_min  # positive value
    fraud_score = float(np.clip((score_max - raw_score) / score_range, 0.0, 1.0))

    # Build signal dict for transparency
    signals = {
        'gps_zone_match':       round(req.gps_zone_match, 3),
        'movement_variance':    round(req.movement_variance, 3),
        'order_activity':       round(req.order_activity_score, 3),
        'claim_frequency_7d':   req.claim_freq_7d,
        'device_age_days':      round(req.device_age_days, 0),
        'orders_before_event':  round(req.orders_before_event, 1),
    }

    return FraudResponse(
        fraud_score = round(fraud_score, 3),
        verdict     = _fraud_verdict(fraud_score),
        signals     = signals,
        model_used  = 'isolation_forest_v1',
    )


# ── Run directly ─────────────────────────────────────────────────────────
if __name__ == '__main__':
    import uvicorn
    uvicorn.run('main:app', host='0.0.0.0', port=8000, reload=True)