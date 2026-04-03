'use strict';

require('dotenv').config();

const express     = require('express');
const cors        = require('cors');
const helmet      = require('helmet');
const morgan      = require('morgan');
const rateLimit   = require('express-rate-limit');

const db          = require('./db');
const { startTriggerEngine } = require('./services/triggerEngine');

// ── Route modules ────────────────────────────────────────────────────────
const authRoutes         = require('./routes/auth');
const workerRoutes       = require('./routes/worker');
const riskRoutes         = require('./routes/risk');
const subscriptionRoutes = require('./routes/subscription');
const triggerRoutes      = require('./routes/triggers');
const claimsRoutes       = require('./routes/claims');
const chatRoutes         = require('./routes/chat'); // ✅ ADD THIS

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Security & middleware ────────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors({ origin: '*' }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Rate limiting ────────────────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many requests — please try again later' },
});

const authLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 10,
  message: { message: 'Too many OTP requests — please wait 10 minutes' },
});

app.use(limiter);

// ── Health check ─────────────────────────────────────────────────────────
app.get('/health', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.json({
      status:  'ok',
      service: 'aegis-backend',
      db:      'connected',
      ts:      new Date().toISOString(),
    });
  } catch (err) {
    res.status(503).json({ status: 'error', db: 'disconnected' });
  }
});

// ── Routes ────────────────────────────────────────────────────────────────
app.use('/auth',         authLimiter, authRoutes);
app.use('/worker',       workerRoutes);
app.use('/risk',         riskRoutes);
app.use('/subscription', subscriptionRoutes);
app.use('/triggers',     triggerRoutes);
app.use('/claims',       claimsRoutes);
app.use('/chat',         chatRoutes); // ✅ ADD THIS LINE

// ── 404 handler ───────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ message: `Route ${req.method} ${req.path} not found` });
});

// ── Global error handler ─────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('[Unhandled error]', err);
  res.status(500).json({
    message: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message,
  });
});

// ── Start ─────────────────────────────────────────────────────────────────
async function start() {
  try {
    await db.query('SELECT 1');
    console.log('[DB] PostgreSQL connected');
  } catch (err) {
    console.error('[DB] Connection failed:', err.message);
    process.exit(1);
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[Server] Aegis backend running on port ${PORT}`);
  });

  startTriggerEngine();
}

start();

module.exports = app;