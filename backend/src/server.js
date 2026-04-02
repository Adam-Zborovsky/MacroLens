require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const helmet  = require('helmet');
const morgan  = require('morgan');

const { connectDB }    = require('./config/db');
const { errorHandler } = require('./middleware/errorHandler');

const capturesRouter = require('./routes/captures');
const mealsRouter    = require('./routes/meals');
const usersRouter    = require('./routes/users');
const barcodeRouter  = require('./routes/barcode');

const app  = express();
const PORT = process.env.PORT || 3000;

// ─── Security & parsing ──────────────────────────────────────────────────────
app.use(helmet());
app.use(cors({ origin: process.env.ALLOWED_ORIGINS?.split(',') ?? '*' }));
app.use(express.json({ limit: '25mb' })); // Accommodates base64 image payloads
app.use(morgan('dev'));

// ─── Health check ────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ONLINE', service: 'MacroLens API', timestamp: new Date().toISOString() });
});

// ─── Routes ──────────────────────────────────────────────────────────────────
app.use('/api/v1/captures',          capturesRouter);
app.use('/api/v1/meals',             mealsRouter);
app.use('/api/v1/users',             usersRouter);
app.use('/api/v1/barcode',           barcodeRouter);

// ─── 404 ─────────────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    error: {
      code: 'ERR_ROUTE_NOT_FOUND',
      message: `${req.method} ${req.path} does not exist in this API.`,
    },
  });
});

// ─── Error handler ───────────────────────────────────────────────────────────
app.use(errorHandler);

// ─── Boot ────────────────────────────────────────────────────────────────────
async function boot() {
  await connectDB();
  app.listen(PORT, () => {
    console.log(`[API] MacroLens API running on port ${PORT}`);
    console.log(`[API] Gemini model: gemini-2.5-flash`);
  });
}

boot();

module.exports = app;
