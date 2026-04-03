# Aegis Backend — Node.js + Express + PostgreSQL

Parametric trigger engine, claims processing, fraud scoring, and worker auth for the Aegis Flutter app.

---

## Quick Start

### 1. Install dependencies
```bash
cd aegis_backend
npm install
```

### 2. Set up PostgreSQL

**Free options (no local install needed):**
- [Supabase](https://supabase.com) — free tier, generous limits
- [Neon](https://neon.tech) — serverless Postgres, free tier
- [Railway](https://railway.app) — free $5 credits/month

After creating a database, copy the connection string.

### 3. Create tables
```bash
# Paste your DATABASE_URL and run the schema
psql "your_database_url_here" -f schema.sql
```

Or open your database's SQL editor and paste the contents of `schema.sql`.

### 4. Configure environment
```bash
cp .env.example .env
```

Edit `.env`:
```
DATABASE_URL=postgresql://user:pass@host:5432/dbname
JWT_SECRET=any_long_random_string
OWM_API_KEY=your_key_from_openweathermap.org
PORT=3000
```

Get a free OpenWeatherMap API key at [openweathermap.org/api](https://openweathermap.org/api) — takes 30 seconds.

### 5. Start the server
```bash
# Development (auto-restart on changes)
npm run dev

# Production
npm start
```

Server starts on `http://localhost:3000`.  
Health check: `GET http://localhost:3000/health`

---

## Connecting the Flutter App

In `lib/services/api_service.dart`, update:

```dart
// Android emulator → your machine's localhost
static const _base = 'http://10.0.2.2:3000';

// Physical device on same WiFi → your machine's LAN IP
// static const _base = 'http://192.168.1.X:3000';

// Deployed backend
// static const _base = 'https://your-backend.onrender.com';

// Replace with your OWM key
static const _owmKey = 'your_openweathermap_key';
```

---

## API Reference

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/otp/request` | Send OTP to phone. Returns OTP in demo mode. |
| POST | `/auth/otp/verify` | Verify OTP → returns JWT + worker |
| POST | `/auth/register` | Create/update worker profile |

### Worker
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/worker/profile` | ✓ | Get current worker |
| PATCH | `/worker/profile` | ✓ | Update profile |
| POST | `/worker/kyc` | ✓ | Submit Aadhaar (simulated) |

### Risk
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/risk/score` | ✓ | Compute risk score + premium |

### Subscription
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/subscription/activate` | ✓ | Subscribe to a plan |
| DELETE | `/subscription/cancel` | ✓ | Cancel subscription |

### Triggers
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/triggers/alerts?zone=` | ✓ | Get active alerts for zone |
| GET | `/triggers/all` | ✓ | All alerts (last 24h) |
| POST | `/triggers/poll` | ✓ | Manually trigger poll cycle |
| POST | `/triggers/simulate` | ✓ | Simulate disruption (dev only) |

### Claims
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/claims/my` | ✓ | All claims for worker |
| GET | `/claims/:id` | ✓ | Single claim status |
| POST | `/claims/submit` | ✓ | Submit GPS + photo claim |
| POST | `/claims/:id/appeal` | ✓ | Appeal held/blocked claim |

---

## Trigger Simulation (Testing)

To test the full flow without waiting for real weather:

```bash
# Get a JWT first (from OTP verify)
TOKEN="your_jwt_here"

# Simulate heavy rainfall in Zone 4
curl -X POST http://localhost:3000/triggers/simulate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"triggerType":"heavyRainfall","zone":"Zone 4 — Central","city":"Chennai","payoutPct":0.8}'
```

This creates an active alert and auto-triggers claims for all subscribed workers in that zone. The Flutter app will pick it up on the next poll or manual refresh.

---

## Architecture

```
Flutter App
    ↓ JWT authenticated requests
Express Server (server.js)
    ├── /auth      → OTP + JWT
    ├── /worker    → Profile + KYC
    ├── /risk      → Score + premium
    ├── /subscription → Plan activation
    ├── /triggers  → Alert fetch + simulate
    └── /claims    → Submit + status + appeal
         ↓
    riskEngine.js  → Premium formula + fraud score
    triggerEngine.js → 30-min OWM poll + dual-gate + auto-claims
         ↓
    PostgreSQL     → Workers, alerts, claims
```

---

## Deploying to Production

### Render.com (free tier)
1. Push code to GitHub
2. New Web Service → connect repo → set `src/server.js` as start command
3. Add all `.env` variables in Render's environment panel
4. Use Render's free PostgreSQL or connect Supabase

### Railway.app
```bash
npm install -g @railway/cli
railway login
railway init
railway up
```

### Environment variables for production
```
NODE_ENV=production
DATABASE_URL=<your production db url>
JWT_SECRET=<long random string>
OWM_API_KEY=<your key>
USE_REAL_SMS=false
PORT=3000
```

---

## Fraud Score Thresholds (README §5)

| Score | Status | Action |
|-------|--------|--------|
| < 0.30 | Auto-approved | Instant payout via Razorpay |
| 0.30 – 0.70 | Held | Secondary verification, resolved within 4 hours |
| > 0.70 | Blocked | Admin review, worker notified |
