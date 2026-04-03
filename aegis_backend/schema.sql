-- Run this in your PostgreSQL database before starting the server
-- Works with Supabase, Neon, Railway, or local PostgreSQL

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Workers table
CREATE TABLE IF NOT EXISTS workers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT NOT NULL DEFAULT '',
  phone           TEXT UNIQUE NOT NULL,
  platform        TEXT NOT NULL DEFAULT 'Swiggy',
  city            TEXT NOT NULL DEFAULT 'Chennai',
  zone            TEXT NOT NULL DEFAULT 'Zone 4 — Central',
  upi_id          TEXT NOT NULL DEFAULT '',
  kyc_complete    BOOLEAN NOT NULL DEFAULT false,
  aadhaar_hash    TEXT,
  subscribed      BOOLEAN NOT NULL DEFAULT false,
  plan_tier       TEXT NOT NULL DEFAULT 'standard',
  weekly_premium  NUMERIC(10,2) NOT NULL DEFAULT 0,
  weekly_earnings_avg NUMERIC(10,2) NOT NULL DEFAULT 4500,
  risk_score      INTEGER NOT NULL DEFAULT 50,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- OTP store (short-lived)
CREATE TABLE IF NOT EXISTS otps (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone      TEXT NOT NULL,
  otp        TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used       BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Disruption alerts (created by trigger engine)
CREATE TABLE IF NOT EXISTS disruption_alerts (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trigger_type TEXT NOT NULL,
  zone         TEXT NOT NULL,
  city         TEXT NOT NULL DEFAULT 'Chennai',
  severity     NUMERIC(4,2) NOT NULL DEFAULT 0.5,
  payout_pct   NUMERIC(4,2) NOT NULL DEFAULT 0.8,
  gate1_pass   BOOLEAN NOT NULL DEFAULT false,
  gate2_pass   BOOLEAN NOT NULL DEFAULT false,
  description  TEXT NOT NULL DEFAULT '',
  status       TEXT NOT NULL DEFAULT 'active',
  detected_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at  TIMESTAMPTZ
);

-- Claims
CREATE TABLE IF NOT EXISTS claims (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  worker_id    UUID NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
  alert_id     UUID NOT NULL REFERENCES disruption_alerts(id),
  status       TEXT NOT NULL DEFAULT 'pending',
  amount       NUMERIC(10,2) NOT NULL DEFAULT 0,
  fraud_score  NUMERIC(4,3) NOT NULL DEFAULT 0,
  gps_lat      NUMERIC(10,7),
  gps_lng      NUMERIC(10,7),
  device_id    TEXT,
  image_stored TEXT,
  trigger_type TEXT NOT NULL DEFAULT '',
  zone         TEXT NOT NULL DEFAULT '',
  review_note  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at  TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_workers_phone ON workers(phone);
CREATE INDEX IF NOT EXISTS idx_claims_worker ON claims(worker_id);
CREATE INDEX IF NOT EXISTS idx_claims_status ON claims(status);
CREATE INDEX IF NOT EXISTS idx_alerts_zone ON disruption_alerts(zone, status);
CREATE INDEX IF NOT EXISTS idx_otps_phone ON otps(phone, used);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS workers_updated_at ON workers;
CREATE TRIGGER workers_updated_at
  BEFORE UPDATE ON workers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
