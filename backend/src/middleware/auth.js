'use strict';

const jwt = require('jsonwebtoken');
const config = require('../config');
const { queryOne } = require('../db');
const { fail } = require('../utils/helpers');

/**
 * Memverifikasi Bearer token lalu mengisi:
 *   req.user   -> baris users
 *   req.siswa  -> baris siswa      (role siswa)
 *   req.guru   -> baris guru       (role guru)
 *   req.ortu   -> baris orang_tua  (role orang_tua)
 */
async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7).trim() : null;

    if (!token) return fail(res, 'Token tidak ditemukan', 401);

    let payload;
    try {
      payload = jwt.verify(token, config.jwt.secret);
    } catch (e) {
      return fail(res, 'Token tidak valid atau sudah kedaluwarsa', 401);
    }

    const user = await queryOne(
      `SELECT id, sekolah_id, username, role, role_name, nama, email, jabatan, is_active
         FROM users WHERE id = ? LIMIT 1`,
      [payload.sub]
    );

    if (!user) return fail(res, 'User tidak ditemukan', 401);
    if (!user.is_active) return fail(res, 'Akun tidak aktif', 403);

    req.user = user;

    if (user.role === 'siswa') {
      req.siswa = await queryOne(
        `SELECT s.*, k.nama_kelas, k.tingkat, k.tahun_ajaran AS kelas_tahun_ajaran,
                g.nama AS wali_kelas
           FROM siswa s
           LEFT JOIN kelas k ON k.id = s.kelas_id
           LEFT JOIN guru  g ON g.id = k.wali_kelas_id
          WHERE s.user_id = ? LIMIT 1`,
        [user.id]
      );
    } else if (user.role === 'guru') {
      req.guru = await queryOne(`SELECT * FROM guru WHERE user_id = ? LIMIT 1`, [user.id]);
    } else if (user.role === 'orang_tua') {
      req.ortu = await queryOne(`SELECT * FROM orang_tua WHERE user_id = ? LIMIT 1`, [user.id]);
    }

    return next();
  } catch (err) {
    return next(err);
  }
}

/** Batasi endpoint untuk role tertentu. */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user) return fail(res, 'Belum terautentikasi', 401);
    if (!roles.includes(req.user.role)) {
      return fail(res, `Akses ditolak untuk role ${req.user.role}`, 403);
    }
    return next();
  };
}

module.exports = { authenticate, requireRole };
