'use strict';

const express = require('express');
const bcrypt = require('bcryptjs');

const config = require('../config');
const { query, queryOne, withTransaction } = require('../db');
const { ok, fail, asyncHandler, uuid, toNum } = require('../utils/helpers');
const { authenticate, requireRole } = require('../middleware/auth');
const { uploadLogo } = require('../middleware/upload');
const { requireScoped } = require('../utils/tenant');

const router = express.Router();

const onlySuperadmin = requireRole('superadmin');

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
// Publik (dipanggil sebelum login). Harus didefinisikan sebelum '/:id'.
// ====================================================================
router.get('/info', asyncHandler(async (req, res) => {
  const sekolahId = (req.query.sekolah_id || '').trim();

  if (sekolahId) {
    const row = await queryOne(`SELECT * FROM sekolah WHERE id = ? LIMIT 1`, [sekolahId]);
    if (!row) return fail(res, 'Sekolah tidak ditemukan', 404);
    return ok(res, mapSekolah(row), 'Data sekolah berhasil dimuat');
  }

  // Tanpa sekolah_id: hanya boleh menebak bila memang baru ada satu sekolah.
  // Begitu sistem dipakai banyak sekolah, menebak justru menampilkan sekolah
  // yang salah, jadi pemanggil wajib menyebut sekolah_id.
  const rows = await query(`SELECT * FROM sekolah ORDER BY created_at ASC LIMIT 2`);
  if (!rows.length) return fail(res, 'Data sekolah belum tersedia', 404);
  if (rows.length > 1) {
    return fail(res, 'Parameter sekolah_id wajib diisi karena terdapat lebih dari satu sekolah', 400);
  }

  return ok(res, mapSekolah(rows[0]), 'Data sekolah berhasil dimuat');
}));

// ====================================================================
// PUT /api/sekolah/lokasi  (admin sekolah sendiri)
// ====================================================================
router.put('/lokasi', authenticate, requireRole('admin', 'superadmin'),
  asyncHandler(async (req, res) => {
    const b = req.body || {};
    // Admin sekolah terkunci pada sekolahnya; hanya superadmin boleh menyebut lain.
    const sekolahId = req.user.role === 'superadmin' && b.sekolah_id
      ? b.sekolah_id
      : req.user.sekolah_id;

    const row = await requireScoped(req, res, 'sekolah', sekolahId, 'Sekolah');
    if (!row) return;

    await query(
      `UPDATE sekolah SET latitude = ?, longitude = ?, radius_maksimal = ? WHERE id = ?`,
      [
        b.latitude !== undefined ? toNum(b.latitude, row.latitude) : row.latitude,
        b.longitude !== undefined ? toNum(b.longitude, row.longitude) : row.longitude,
        b.radius_maksimal !== undefined
          ? toNum(b.radius_maksimal, row.radius_maksimal) : row.radius_maksimal,
        sekolahId,
      ]
    );

    const updated = await queryOne(`SELECT * FROM sekolah WHERE id = ?`, [sekolahId]);
    return ok(res, mapSekolah(updated), 'Lokasi sekolah berhasil diperbarui');
  })
);

// ====================================================================
// PUT /api/sekolah/info  (admin sekolah sendiri)
// ====================================================================
router.put('/info', authenticate, requireRole('admin', 'superadmin'),
  asyncHandler(async (req, res) => {
    const b = req.body || {};
    const sekolahId = req.user.role === 'superadmin' && b.sekolah_id
      ? b.sekolah_id
      : req.user.sekolah_id;

    const row = await requireScoped(req, res, 'sekolah', sekolahId, 'Sekolah');
    if (!row) return;

    const sets = []; const vals = [];
    for (const f of ['nama', 'alamat', 'telepon', 'email', 'website', 'logo_url',
                     'jam_masuk', 'jam_pulang']) {
      if (b[f] !== undefined) { sets.push(`${f} = ?`); vals.push(b[f] || null); }
    }
    if (!sets.length) return fail(res, 'Tidak ada data yang diubah', 400);

    vals.push(sekolahId);
    await query(`UPDATE sekolah SET ${sets.join(', ')} WHERE id = ?`, vals);

    const updated = await queryOne(`SELECT * FROM sekolah WHERE id = ?`, [sekolahId]);
    return ok(res, mapSekolah(updated), 'Profil sekolah berhasil diperbarui');
  })
);

// ====================================================================
// POST /api/sekolah/upload-logo   (multipart field: logo / file)
// ====================================================================
router.post('/upload-logo',
  authenticate,
  requireRole('admin', 'superadmin'),
  uploadLogo.fields([{ name: 'logo', maxCount: 1 }, { name: 'file', maxCount: 1 }]),
  asyncHandler(async (req, res) => {
    const f = (req.files?.logo?.[0]) || (req.files?.file?.[0]);
    if (!f) return fail(res, 'File logo tidak ditemukan pada request', 400);

    const url = `${config.baseUrl}/uploads/logo/${f.filename}`;
    return ok(res, {
      url,
      path: `/uploads/logo/${f.filename}`,
      filename: f.filename,
      original_name: f.originalname,
      size: f.size,
    }, 'Logo sekolah berhasil diunggah');
  })
);

// ====================================================================
// ADMIN APLIKASI (superadmin) — kelola daftar sekolah
// ====================================================================

/** GET /api/sekolah — daftar seluruh sekolah beserta ringkasan isinya. */
router.get('/', authenticate, onlySuperadmin, asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT s.*,
            (SELECT COUNT(*) FROM siswa x WHERE x.sekolah_id = s.id AND x.status = 'aktif') AS jumlah_siswa,
            (SELECT COUNT(*) FROM guru  x WHERE x.sekolah_id = s.id AND x.status = 'aktif') AS jumlah_guru,
            (SELECT COUNT(*) FROM kelas x WHERE x.sekolah_id = s.id) AS jumlah_kelas,
            (SELECT COUNT(*) FROM users x WHERE x.sekolah_id = s.id AND x.role = 'admin') AS jumlah_admin
       FROM sekolah s
      ORDER BY s.nama`
  );

  const data = rows.map((r) => ({
    ...mapSekolah(r),
    jumlah_siswa: toNum(r.jumlah_siswa),
    jumlah_guru: toNum(r.jumlah_guru),
    jumlah_kelas: toNum(r.jumlah_kelas),
    jumlah_admin: toNum(r.jumlah_admin),
    created_at: r.created_at,
  }));

  return ok(res, data, 'Daftar sekolah berhasil dimuat', { count: data.length });
}));

/**
 * POST /api/sekolah — daftarkan sekolah baru sekaligus akun admin pertamanya.
 * body: { nama, alamat?, telepon?, email?, website?, logo_url?,
 *         latitude?, longitude?, radius_maksimal?, jam_masuk?, jam_pulang?,
 *         admin_username, admin_password, admin_nama? }
 */
router.post('/', authenticate, onlySuperadmin, asyncHandler(async (req, res) => {
  const b = req.body || {};

  if (!b.nama || !String(b.nama).trim()) return fail(res, 'Nama sekolah wajib diisi', 400);

  const adminUsername = (b.admin_username || '').toString().trim();
  const adminPassword = String(b.admin_password || '');
  if (!adminUsername) return fail(res, 'Username admin sekolah wajib diisi', 400);
  if (adminPassword.length < 6) return fail(res, 'Password admin minimal 6 karakter', 400);

  const dupNama = await queryOne(`SELECT id FROM sekolah WHERE nama = ?`, [String(b.nama).trim()]);
  if (dupNama) return fail(res, `Sekolah "${String(b.nama).trim()}" sudah terdaftar`, 409);

  const dupUser = await queryOne(`SELECT id FROM users WHERE username = ?`, [adminUsername]);
  if (dupUser) return fail(res, `Username "${adminUsername}" sudah dipakai`, 409);

  const sekolahId = uuid();
  const userId = uuid();
  const hash = await bcrypt.hash(adminPassword, 10);

  await withTransaction(async (conn) => {
    await conn.execute(
      `INSERT INTO sekolah
         (id, nama, alamat, telepon, email, website, logo_url,
          latitude, longitude, radius_maksimal, jam_masuk, jam_pulang)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
      [sekolahId, String(b.nama).trim(), b.alamat || null, b.telepon || null,
       b.email || null, b.website || null, b.logo_url || null,
       toNum(b.latitude), toNum(b.longitude), toNum(b.radius_maksimal, 150),
       b.jam_masuk || '07:00:00', b.jam_pulang || '13:30:00']
    );
    await conn.execute(
      `INSERT INTO users (id, sekolah_id, username, password, role, role_name, nama, email, jabatan)
       VALUES (?,?,?,?, 'admin', 'Administrator', ?, ?, 'kepala_sekolah')`,
      [userId, sekolahId, adminUsername, hash,
       b.admin_nama || `Administrator ${String(b.nama).trim()}`, b.email || null]
    );
  });

  const row = await queryOne(`SELECT * FROM sekolah WHERE id = ?`, [sekolahId]);
  return ok(res, {
    ...mapSekolah(row),
    admin: { id: userId, username: adminUsername, role: 'admin' },
  }, `Sekolah ${row.nama} berhasil didaftarkan dengan admin "${adminUsername}"`);
}));

/** GET /api/sekolah/:id */
router.get('/:id', authenticate, onlySuperadmin, asyncHandler(async (req, res) => {
  const row = await queryOne(`SELECT * FROM sekolah WHERE id = ?`, [req.params.id]);
  if (!row) return fail(res, 'Sekolah tidak ditemukan', 404);

  const admins = await query(
    `SELECT id, username, nama, email, jabatan, is_active
       FROM users WHERE sekolah_id = ? AND role = 'admin' ORDER BY username`,
    [row.id]
  );

  return ok(res, { ...mapSekolah(row), admin: admins }, 'Detail sekolah berhasil dimuat');
}));

/** PUT /api/sekolah/:id */
router.put('/:id', authenticate, onlySuperadmin, asyncHandler(async (req, res) => {
  const b = req.body || {};
  const row = await queryOne(`SELECT * FROM sekolah WHERE id = ?`, [req.params.id]);
  if (!row) return fail(res, 'Sekolah tidak ditemukan', 404);

  const sets = []; const vals = [];
  for (const f of ['nama', 'alamat', 'telepon', 'email', 'website', 'logo_url',
                   'jam_masuk', 'jam_pulang']) {
    if (b[f] !== undefined) { sets.push(`${f} = ?`); vals.push(b[f] || null); }
  }
  for (const f of ['latitude', 'longitude', 'radius_maksimal']) {
    if (b[f] !== undefined) { sets.push(`${f} = ?`); vals.push(toNum(b[f])); }
  }
  if (!sets.length) return fail(res, 'Tidak ada data yang diubah', 400);

  vals.push(row.id);
  await query(`UPDATE sekolah SET ${sets.join(', ')} WHERE id = ?`, vals);

  const updated = await queryOne(`SELECT * FROM sekolah WHERE id = ?`, [row.id]);
  return ok(res, mapSekolah(updated), 'Sekolah berhasil diperbarui');
}));

/**
 * DELETE /api/sekolah/:id
 * Menghapus sekolah ikut menghapus SELURUH datanya (ON DELETE CASCADE),
 * jadi harus dikonfirmasi lewat body { konfirmasi: "<nama sekolah>" }.
 */
router.delete('/:id', authenticate, onlySuperadmin, asyncHandler(async (req, res) => {
  const row = await queryOne(`SELECT * FROM sekolah WHERE id = ?`, [req.params.id]);
  if (!row) return fail(res, 'Sekolah tidak ditemukan', 404);

  const konfirmasi = (req.body && req.body.konfirmasi) || '';
  if (konfirmasi !== row.nama) {
    return fail(res,
      `Penghapusan membuang seluruh data sekolah ini dan tidak dapat dibatalkan. `
      + `Kirim { "konfirmasi": "${row.nama}" } untuk melanjutkan.`, 400);
  }

  const stat = await queryOne(
    `SELECT (SELECT COUNT(*) FROM siswa WHERE sekolah_id = ?) AS siswa,
            (SELECT COUNT(*) FROM guru  WHERE sekolah_id = ?) AS guru,
            (SELECT COUNT(*) FROM users WHERE sekolah_id = ?) AS users`,
    [row.id, row.id, row.id]
  );

  await query(`DELETE FROM sekolah WHERE id = ?`, [row.id]);

  return ok(res, {
    terhapus: {
      sekolah: row.nama,
      siswa: toNum(stat?.siswa), guru: toNum(stat?.guru), akun: toNum(stat?.users),
    },
  }, `Sekolah ${row.nama} beserta seluruh datanya telah dihapus`);
}));

module.exports = router;
module.exports.mapSekolah = mapSekolah;
