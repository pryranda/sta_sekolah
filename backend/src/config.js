'use strict';

// Semua konfigurasi diambil dari environment (lihat deploy/sta-api.service).
module.exports = {
  port: parseInt(process.env.PORT || '5001', 10),
  baseUrl: process.env.BASE_URL || 'http://10.0.0.39:5001',

  db: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    user: process.env.DB_USER || 'sta_app',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'sta_sekolah',
  },

  jwt: {
    secret: process.env.JWT_SECRET || 'sta-sekolah-dev-secret-change-me',
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
  },

  uploadDir: process.env.UPLOAD_DIR || require('path').join(__dirname, '..', 'uploads'),
};
