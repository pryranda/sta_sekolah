'use strict';

const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const config = require('../config');
const { query, queryOne } = require('../db');
const { ok, fail, asyncHandler } = require('../utils/helpers');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

/** Bangun objek `user` yang disimpan app di SharedPreferences. */
async function buildUserPayload(user) {
  const base = {
    id: user.id,
    username: user.username,
    nama: user.nama || user.username,
    role: user.role,
    role_name: user.role_name || user.role,
    email: user.email || '',
    jabatan: user.jabatan || '',
    sekolah_id: user.sekolah_id,
  };

  if (user.role === 'siswa') {
    const s = await queryOne(
      `SELECT s.id, s.nis, s.nisn, s.kelas_id, s.foto_url, k.nama_kelas
         FROM siswa s LEFT JOIN kelas k ON k.id = s.kelas_id
        WHERE s.user_id = ? LIMIT 1`,
      [user.id]
    );
    if (s) {
      // app memakai user['id'] sebagai siswa_id pada endpoint SPP
      base.id = s.id;
      base.user_id = user.id;
      base.siswa_id = s.id;
      base.nis = s.nis;
      base.nisn = s.nisn;
      base.kelas_id = s.kelas_id;
      base.nama_kelas = s.nama_kelas;
      base.foto_url = s.foto_url;
    }
  } else if (user.role === 'guru') {
    const g = await queryOne(`SELECT id, nip, no_hp FROM guru WHERE user_id = ? LIMIT 1`, [user.id]);
    if (g) {
      base.user_id = user.id;
      base.guru_id = g.id;
      base.nip = g.nip;
      base.no_hp = g.no_hp;
    }
  } else if (user.role === 'orang_tua') {
    const o = await queryOne(`SELECT id FROM orang_tua WHERE user_id = ? LIMIT 1`, [user.id]);
    if (o) {
      base.user_id = user.id;
      base.orang_tua_id = o.id;
    }
  } else if (user.role === 'superadmin') {
    // Admin aplikasi: tidak terikat pada satu sekolah.
    base.user_id = user.id;
    base.sekolah_id = user.sekolah_id || '';
    const total = await queryOne(`SELECT COUNT(*) AS c FROM sekolah`);
    base.jumlah_sekolah = total ? Number(total.c) : 0;
  } else {
    base.user_id = user.id;
  }

  return base;
}

// ====================================================================
// POST /api/auth/login
// ====================================================================
router.post('/login', asyncHandler(async (req, res) => {
  const username = (req.body.username || '').trim();
  const password = req.body.password || '';

  if (!username || !password) {
    return fail(res, 'Username dan password wajib diisi', 400);
  }

  const user = await queryOne(
    `SELECT * FROM users WHERE username = ? LIMIT 1`,
    [username]
  );

  if (!user) return fail(res, 'Username atau password salah', 401);
  if (!user.is_active) return fail(res, 'Akun tidak aktif, hubungi admin', 403);

  const match = await bcrypt.compare(password, user.password);
  if (!match) return fail(res, 'Username atau password salah', 401);

  const token = jwt.sign(
    { sub: user.id, role: user.role, sekolah_id: user.sekolah_id },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn }
  );

  const payload = await buildUserPayload(user);
  return ok(res, { token, user: payload }, 'Login berhasil');
}));

// ====================================================================
// GET /api/auth/profile
// ====================================================================
router.get('/profile', authenticate, asyncHandler(async (req, res) => {
  const payload = await buildUserPayload(req.user);
  return ok(res, payload, 'Profil berhasil dimuat');
}));

// ====================================================================
// PUT /api/auth/change-password
// ====================================================================
router.put('/change-password', authenticate, asyncHandler(async (req, res) => {
  const currentPassword = req.body.currentPassword || req.body.current_password || '';
  const newPassword = req.body.newPassword || req.body.new_password || '';

  if (!currentPassword || !newPassword) {
    return fail(res, 'Password lama dan password baru wajib diisi', 400);
  }
  if (String(newPassword).length < 6) {
    return fail(res, 'Password baru minimal 6 karakter', 400);
  }

  const row = await queryOne(`SELECT password FROM users WHERE id = ?`, [req.user.id]);
  const match = await bcrypt.compare(currentPassword, row.password);
  if (!match) return fail(res, 'Password lama tidak sesuai', 400);

  const hash = await bcrypt.hash(newPassword, 10);
  await query(`UPDATE users SET password = ? WHERE id = ?`, [hash, req.user.id]);

  return ok(res, null, 'Password berhasil diubah');
}));

// ====================================================================
// POST /api/auth/logout  (stateless; disediakan agar app tidak 404)
// ====================================================================
router.post('/logout', authenticate, (req, res) => ok(res, null, 'Logout berhasil'));

module.exports = router;
module.exports.buildUserPayload = buildUserPayload;
