'use strict';

const path = require('path');
const fs = require('fs');
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');

const config = require('./config');
const { pool } = require('./db');

const app = express();

app.set('trust proxy', true);
app.use(cors());
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan(':remote-addr :method :url :status :response-time ms'));

// --- static uploads -------------------------------------------------
for (const sub of ['', 'bukti', 'tugas', 'logo']) {
  fs.mkdirSync(path.join(config.uploadDir, sub), { recursive: true });
}
app.use('/uploads', express.static(config.uploadDir, { maxAge: '1h' }));

// --- healthcheck ----------------------------------------------------
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ success: true, message: 'API aktif', data: { db: 'ok', time: new Date().toISOString() } });
  } catch (err) {
    res.status(500).json({ success: false, message: `Database error: ${err.message}`, data: null });
  }
});

// --- routes ---------------------------------------------------------
app.use('/api/auth', require('./routes/auth'));
app.use('/api/sekolah', require('./routes/sekolah'));
app.use('/api/student', require('./routes/student'));
app.use('/api/teacher', require('./routes/teacher'));
app.use('/api/parent', require('./routes/parent'));
app.use('/api/tugas', require('./routes/tugas'));
app.use('/api/spp', require('./routes/spp'));
app.use('/api/admin', require('./routes/admin'));

// --- 404 ------------------------------------------------------------
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Endpoint tidak ditemukan: ${req.method} ${req.originalUrl}`,
    data: null,
  });
});

// --- error handler --------------------------------------------------
app.use((err, req, res, _next) => {
  console.error('[ERROR]', req.method, req.originalUrl, '-', err.message);
  if (err.stack) console.error(err.stack);
  const status = err.status || 500;
  res.status(status).json({
    success: false,
    message: err.expose ? err.message : (err.message || 'Internal server error'),
    data: null,
  });
});

const server = app.listen(config.port, '0.0.0.0', () => {
  console.log(`STA Sekolah API listening on 0.0.0.0:${config.port}`);
  console.log(`Database: ${config.db.user}@${config.db.host}:${config.db.port}/${config.db.database}`);
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    console.log(`${sig} diterima, menutup server...`);
    server.close(() => pool.end().then(() => process.exit(0)).catch(() => process.exit(0)));
  });
}

module.exports = app;
