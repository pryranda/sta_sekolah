'use strict';

const express = require('express');
const { query, queryOne } = require('../db');
const { ok, fail, asyncHandler, toNum } = require('../utils/helpers');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

function mapSekolah(row) {
  return {
    id: row.id,
    nama: row.nama || '',
    alamat: row.alamat || '',
    telepon: row.telepon || '',
    email: row.email || '',
    website: row.website || '',
    logo_url: row.logo_url || '',
    latitude: row.latitude !== null ? String(row.latitude) : '0',
    longitude: row.longitude !== null ? String(row.longitude) : '0',
    radius_maksimal: row.radius_maksimal !== null ? String(row.radius_maksimal) : '0',
    jam_masuk: row.jam_masuk || null,
    jam_pulang: row.jam_pulang || null,
  };
}

// ====================================================================
// GET /api/sekolah/info?sekolah_id=...
// Dipanggil tanpa token saat splash, dan dengan token setelah login.
// ====================================================================
router.get('/info', asyncHandler(async (req, res) => {
  const sekolahId = (req.query.sekolah_id || '').trim();

  let row;
  if (sekolahId) {
    row = await queryOne(`SELECT * FROM sekolah WHERE id = ? LIMIT 1`, [sekolahId]);
  }
  // fallback: sekolah pertama (instalasi single-tenant)
  if (!row) {
    row = await queryOne(`SELECT * FROM sekolah ORDER BY created_at ASC LIMIT 1`);
  }
  if (!row) return fail(res, 'Data sekolah belum tersedia', 404);

  return ok(res, mapSekolah(row), 'Data sekolah berhasil dimuat');
}));

// ====================================================================
// PUT /api/sekolah/lokasi  (admin)
// ====================================================================
router.put('/lokasi', authenticate, requireRole('admin'), asyncHandler(async (req, res) => {
  const b = req.body || {};
  const sekolahId = b.sekolah_id || req.user.sekolah_id;

  const row = await queryOne(`SELECT * FROM sekolah WHERE id = ? LIMIT 1`, [sekolahId]);
  if (!row) return fail(res, 'Sekolah tidak ditemukan', 404);

  await query(
    `UPDATE sekolah
        SET latitude = ?, longitude = ?, radius_maksimal = ?
      WHERE id = ?`,
    [
      b.latitude !== undefined ? toNum(b.latitude, row.latitude) : row.latitude,
      b.longitude !== undefined ? toNum(b.longitude, row.longitude) : row.longitude,
      b.radius_maksimal !== undefined ? toNum(b.radius_maksimal, row.radius_maksimal) : row.radius_maksimal,
      sekolahId,
    ]
  );

  const updated = await queryOne(`SELECT * FROM sekolah WHERE id = ?`, [sekolahId]);
  return ok(res, mapSekolah(updated), 'Lokasi sekolah berhasil diperbarui');
}));

// ====================================================================
// PUT /api/sekolah/info  (admin) - update profil sekolah
// ====================================================================
router.put('/info', authenticate, requireRole('admin'), asyncHandler(async (req, res) => {
  const b = req.body || {};
  const sekolahId = b.sekolah_id || req.user.sekolah_id;
  const row = await queryOne(`SELECT * FROM sekolah WHERE id = ? LIMIT 1`, [sekolahId]);
  if (!row) return fail(res, 'Sekolah tidak ditemukan', 404);

  const fields = ['nama', 'alamat', 'telepon', 'email', 'website', 'logo_url'];
  const sets = [];
  const vals = [];
  for (const f of fields) {
    if (b[f] !== undefined) { sets.push(`${f} = ?`); vals.push(b[f]); }
  }
  if (!sets.length) return fail(res, 'Tidak ada data yang diubah', 400);

  vals.push(sekolahId);
  await query(`UPDATE sekolah SET ${sets.join(', ')} WHERE id = ?`, vals);

  const updated = await queryOne(`SELECT * FROM sekolah WHERE id = ?`, [sekolahId]);
  return ok(res, mapSekolah(updated), 'Profil sekolah berhasil diperbarui');
}));

module.exports = router;
module.exports.mapSekolah = mapSekolah;
