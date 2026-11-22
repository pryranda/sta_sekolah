'use strict';

const express = require('express');
const bcrypt = require('bcryptjs');

const { query, queryOne, withTransaction } = require('../db');
const {
  ok, fail, asyncHandler, uuid, toNum, toIntOrNull,
} = require('../utils/helpers');
const { authenticate, requireRole } = require('../middleware/auth');
const { generateJadwal, DEFAULT_CONFIG } = require('../utils/scheduler');

const router = express.Router();
router.use(authenticate, requireRole('admin'));

// ====================================================================
// GURU
// ====================================================================
router.get('/guru', asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT g.id, g.user_id, g.nama, g.nip, g.email, g.no_hp, g.jenis_kelamin,
            g.alamat, g.foto_url, g.status, u.username,
            (SELECT COUNT(*) FROM guru_mapel gm WHERE gm.guru_id = g.id) AS jumlah_mapel
       FROM guru g
       LEFT JOIN users u ON u.id = g.user_id
      WHERE g.sekolah_id = ?
      ORDER BY g.nama`,
    [req.user.sekolah_id]
  );
  return ok(res, rows, 'Data guru berhasil dimuat');
}));

router.post('/guru', asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.nama || !String(b.nama).trim()) return fail(res, 'Nama guru wajib diisi', 400);

  const username = (b.username || b.nip || b.email || '').toString().trim();
  if (!username) return fail(res, 'Username/NIP wajib diisi untuk akun login', 400);

  const dup = await queryOne(`SELECT id FROM users WHERE username = ?`, [username]);
  if (dup) return fail(res, `Username "${username}" sudah dipakai`, 409);

  const password = b.password && String(b.password).length >= 6
    ? String(b.password)
    : null;
  if (!password) return fail(res, 'Password minimal 6 karakter', 400);

  const userId = uuid();
  const guruId = uuid();
  const hash = await bcrypt.hash(password, 10);

  await withTransaction(async (conn) => {
    await conn.execute(
      `INSERT INTO users (id, sekolah_id, username, password, role, role_name, nama, email)
       VALUES (?,?,?,?, 'guru', 'Guru', ?, ?)`,
      [userId, req.user.sekolah_id, username, hash, String(b.nama).trim(), b.email || null]
    );
    await conn.execute(
      `INSERT INTO guru (id, sekolah_id, user_id, nama, nip, email, no_hp, jenis_kelamin, alamat)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [guruId, req.user.sekolah_id, userId, String(b.nama).trim(), b.nip || null,
       b.email || null, b.no_hp || null, b.jenis_kelamin === 'P' ? 'P' : 'L', b.alamat || null]
    );
  });

  const row = await queryOne(
    `SELECT g.*, u.username FROM guru g LEFT JOIN users u ON u.id = g.user_id WHERE g.id = ?`,
    [guruId]
  );
  return ok(res, row, `Guru ${row.nama} berhasil ditambahkan (username: ${username})`);
}));

router.put('/guru/:id', asyncHandler(async (req, res) => {
  const b = req.body || {};
  const guru = await queryOne(
    `SELECT * FROM guru WHERE id = ? AND sekolah_id = ?`, [req.params.id, req.user.sekolah_id]
  );
  if (!guru) return fail(res, 'Guru tidak ditemukan', 404);

  const sets = []; const vals = [];
  for (const f of ['nama', 'nip', 'email', 'no_hp', 'alamat', 'status']) {
    if (b[f] !== undefined) { sets.push(`${f} = ?`); vals.push(b[f] || null); }
  }
  if (b.jenis_kelamin !== undefined) {
    sets.push('jenis_kelamin = ?'); vals.push(b.jenis_kelamin === 'P' ? 'P' : 'L');
  }
  if (!sets.length) return fail(res, 'Tidak ada data yang diubah', 400);

  vals.push(guru.id);
  await query(`UPDATE guru SET ${sets.join(', ')} WHERE id = ?`, vals);

  if (guru.user_id && (b.nama !== undefined || b.email !== undefined)) {
    await query(
      `UPDATE users SET nama = COALESCE(?, nama), email = COALESCE(?, email) WHERE id = ?`,
      [b.nama || null, b.email || null, guru.user_id]
    );
  }
  if (b.password && String(b.password).length >= 6 && guru.user_id) {
    const hash = await bcrypt.hash(String(b.password), 10);
    await query(`UPDATE users SET password = ? WHERE id = ?`, [hash, guru.user_id]);
  }

  const row = await queryOne(`SELECT * FROM guru WHERE id = ?`, [guru.id]);
  return ok(res, row, 'Data guru berhasil diperbarui');
}));

router.delete('/guru/:id', asyncHandler(async (req, res) => {
  const guru = await queryOne(
    `SELECT * FROM guru WHERE id = ? AND sekolah_id = ?`, [req.params.id, req.user.sekolah_id]
  );
  if (!guru) return fail(res, 'Guru tidak ditemukan', 404);

  const wali = await queryOne(`SELECT COUNT(*) AS c FROM kelas WHERE wali_kelas_id = ?`, [guru.id]);
  if (toNum(wali?.c) > 0) {
    return fail(res, 'Guru masih menjadi wali kelas. Ganti wali kelas terlebih dahulu.', 409);
  }

  await withTransaction(async (conn) => {
    await conn.execute(`DELETE FROM guru WHERE id = ?`, [guru.id]);
    if (guru.user_id) await conn.execute(`DELETE FROM users WHERE id = ?`, [guru.user_id]);
  });

  return ok(res, null, `Guru ${guru.nama} berhasil dihapus`);
}));

// ====================================================================
// MAPEL
// ====================================================================
router.get('/mapel', asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT id, nama_mapel, kode_mapel, tingkat, jam_per_pekan
       FROM mapel WHERE sekolah_id = ? ORDER BY nama_mapel`,
    [req.user.sekolah_id]
  );
  return ok(res, rows, 'Data mata pelajaran berhasil dimuat');
}));

router.post('/mapel', asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.nama_mapel) return fail(res, 'Nama mata pelajaran wajib diisi', 400);
  if (!b.kode_mapel) return fail(res, 'Kode mata pelajaran wajib diisi', 400);

  const id = uuid();
  await query(
    `INSERT INTO mapel (id, sekolah_id, nama_mapel, kode_mapel, tingkat, jam_per_pekan)
     VALUES (?,?,?,?,?,?)`,
    [id, req.user.sekolah_id, b.nama_mapel, String(b.kode_mapel).toUpperCase(),
     toIntOrNull(b.tingkat), toNum(b.jam_per_pekan, 2)]
  );

  const row = await queryOne(`SELECT * FROM mapel WHERE id = ?`, [id]);
  return ok(res, row, 'Mata pelajaran berhasil ditambahkan');
}));

router.put('/mapel/:id', asyncHandler(async (req, res) => {
  const b = req.body || {};
  const row = await queryOne(
    `SELECT * FROM mapel WHERE id = ? AND sekolah_id = ?`, [req.params.id, req.user.sekolah_id]
  );
  if (!row) return fail(res, 'Mata pelajaran tidak ditemukan', 404);

  const sets = []; const vals = [];
  if (b.nama_mapel !== undefined) { sets.push('nama_mapel = ?'); vals.push(b.nama_mapel); }
  if (b.kode_mapel !== undefined) { sets.push('kode_mapel = ?'); vals.push(String(b.kode_mapel).toUpperCase()); }
  if (b.tingkat !== undefined) { sets.push('tingkat = ?'); vals.push(toIntOrNull(b.tingkat)); }
  if (b.jam_per_pekan !== undefined) { sets.push('jam_per_pekan = ?'); vals.push(toNum(b.jam_per_pekan, 2)); }
  if (!sets.length) return fail(res, 'Tidak ada data yang diubah', 400);

  vals.push(row.id);
  await query(`UPDATE mapel SET ${sets.join(', ')} WHERE id = ?`, vals);
  const updated = await queryOne(`SELECT * FROM mapel WHERE id = ?`, [row.id]);
  return ok(res, updated, 'Mata pelajaran berhasil diperbarui');
}));

router.delete('/mapel/:id', asyncHandler(async (req, res) => {
  const row = await queryOne(
    `SELECT * FROM mapel WHERE id = ? AND sekolah_id = ?`, [req.params.id, req.user.sekolah_id]
  );
  if (!row) return fail(res, 'Mata pelajaran tidak ditemukan', 404);
  await query(`DELETE FROM mapel WHERE id = ?`, [row.id]);
  return ok(res, null, `Mata pelajaran ${row.nama_mapel} berhasil dihapus`);
}));

// ====================================================================
// GURU - MAPEL MAPPING
// ====================================================================
router.get('/guru-mapel', asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT gm.id, gm.guru_id, gm.mapel_id,
            g.nama AS guru_nama, g.nip,
            m.nama_mapel, m.kode_mapel
       FROM guru_mapel gm
       JOIN guru  g ON g.id = gm.guru_id
       JOIN mapel m ON m.id = gm.mapel_id
      WHERE g.sekolah_id = ?
      ORDER BY g.nama, m.nama_mapel`,
    [req.user.sekolah_id]
  );
  return ok(res, rows, 'Data mapping guru-mapel berhasil dimuat');
}));

router.post('/guru-mapel', asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.guru_id || !b.mapel_id) return fail(res, 'guru_id dan mapel_id wajib diisi', 400);

  const guru = await queryOne(`SELECT id, nama FROM guru WHERE id = ?`, [b.guru_id]);
  if (!guru) return fail(res, 'Guru tidak ditemukan', 404);
  const mapel = await queryOne(`SELECT id, nama_mapel FROM mapel WHERE id = ?`, [b.mapel_id]);
  if (!mapel) return fail(res, 'Mata pelajaran tidak ditemukan', 404);

  const dup = await queryOne(
    `SELECT id FROM guru_mapel WHERE guru_id = ? AND mapel_id = ?`, [b.guru_id, b.mapel_id]
  );
  if (dup) return fail(res, `${guru.nama} sudah diampukan pada ${mapel.nama_mapel}`, 409);

  const id = uuid();
  await query(
    `INSERT INTO guru_mapel (id, guru_id, mapel_id) VALUES (?,?,?)`,
    [id, b.guru_id, b.mapel_id]
  );

  const row = await queryOne(
    `SELECT gm.id, gm.guru_id, gm.mapel_id, g.nama AS guru_nama, m.nama_mapel, m.kode_mapel
       FROM guru_mapel gm JOIN guru g ON g.id = gm.guru_id JOIN mapel m ON m.id = gm.mapel_id
      WHERE gm.id = ?`,
    [id]
  );
  return ok(res, row, `${guru.nama} berhasil diampukan pada ${mapel.nama_mapel}`);
}));

router.delete('/guru-mapel/:id', asyncHandler(async (req, res) => {
  const row = await queryOne(`SELECT * FROM guru_mapel WHERE id = ?`, [req.params.id]);
  if (!row) return fail(res, 'Data mapping tidak ditemukan', 404);
  await query(`DELETE FROM guru_mapel WHERE id = ?`, [row.id]);
  return ok(res, null, 'Mapping berhasil dihapus');
}));

// ====================================================================
// KELAS
// ====================================================================
router.get('/kelas', asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT k.id, k.nama_kelas, k.tingkat, k.kapasitas, k.tahun_ajaran, k.ruangan,
            k.wali_kelas_id, g.nama AS wali_kelas,
            (SELECT COUNT(*) FROM siswa s WHERE s.kelas_id = k.id AND s.status = 'aktif') AS jumlah_siswa
       FROM kelas k
       LEFT JOIN guru g ON g.id = k.wali_kelas_id
      WHERE k.sekolah_id = ?
      ORDER BY k.tingkat, k.nama_kelas`,
    [req.user.sekolah_id]
  );
  return ok(res, rows, 'Data kelas berhasil dimuat');
}));

router.post('/kelas', asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.nama_kelas) return fail(res, 'Nama kelas wajib diisi', 400);

  const id = uuid();
  await query(
    `INSERT INTO kelas (id, sekolah_id, nama_kelas, tingkat, kapasitas, tahun_ajaran, wali_kelas_id, ruangan)
     VALUES (?,?,?,?,?,?,?,?)`,
    [id, req.user.sekolah_id, b.nama_kelas, toNum(b.tingkat, 1), toNum(b.kapasitas, 28),
     b.tahun_ajaran || null, b.wali_kelas_id || null, b.ruangan || null]
  );

  const row = await queryOne(
    `SELECT k.*, g.nama AS wali_kelas FROM kelas k
       LEFT JOIN guru g ON g.id = k.wali_kelas_id WHERE k.id = ?`,
    [id]
  );
  return ok(res, row, `Kelas ${row.nama_kelas} berhasil dibuat`);
}));

router.put('/kelas/:id', asyncHandler(async (req, res) => {
  const b = req.body || {};
  const kelas = await queryOne(
    `SELECT * FROM kelas WHERE id = ? AND sekolah_id = ?`, [req.params.id, req.user.sekolah_id]
  );
  if (!kelas) return fail(res, 'Kelas tidak ditemukan', 404);

  const sets = []; const vals = [];
  if (b.nama_kelas !== undefined) { sets.push('nama_kelas = ?'); vals.push(b.nama_kelas); }
  if (b.tingkat !== undefined) { sets.push('tingkat = ?'); vals.push(toNum(b.tingkat, 1)); }
  if (b.kapasitas !== undefined) { sets.push('kapasitas = ?'); vals.push(toNum(b.kapasitas, 28)); }
  if (b.tahun_ajaran !== undefined) { sets.push('tahun_ajaran = ?'); vals.push(b.tahun_ajaran || null); }
  if (b.wali_kelas_id !== undefined) { sets.push('wali_kelas_id = ?'); vals.push(b.wali_kelas_id || null); }
  if (b.ruangan !== undefined) { sets.push('ruangan = ?'); vals.push(b.ruangan || null); }
  if (!sets.length) return fail(res, 'Tidak ada data yang diubah', 400);

  vals.push(kelas.id);
  await query(`UPDATE kelas SET ${sets.join(', ')} WHERE id = ?`, vals);

  const row = await queryOne(
    `SELECT k.*, g.nama AS wali_kelas FROM kelas k
       LEFT JOIN guru g ON g.id = k.wali_kelas_id WHERE k.id = ?`,
    [kelas.id]
  );
  return ok(res, row, 'Kelas berhasil diperbarui');
}));

router.delete('/kelas/:id', asyncHandler(async (req, res) => {
  const kelas = await queryOne(
    `SELECT * FROM kelas WHERE id = ? AND sekolah_id = ?`, [req.params.id, req.user.sekolah_id]
  );
  if (!kelas) return fail(res, 'Kelas tidak ditemukan', 404);

  const siswa = await queryOne(
    `SELECT COUNT(*) AS c FROM siswa WHERE kelas_id = ? AND status = 'aktif'`, [kelas.id]
  );
  if (toNum(siswa?.c) > 0) {
    return fail(res, `Kelas masih memiliki ${toNum(siswa.c)} siswa aktif. Pindahkan siswa terlebih dahulu.`, 409);
  }

  await query(`DELETE FROM kelas WHERE id = ?`, [kelas.id]);
  return ok(res, null, `Kelas ${kelas.nama_kelas} berhasil dihapus`);
}));

// ====================================================================
// SISWA
// ====================================================================
router.get('/siswa', asyncHandler(async (req, res) => {
  const where = ['s.sekolah_id = ?'];
  const params = [req.user.sekolah_id];

  if (req.query.kelas_id) { where.push('s.kelas_id = ?'); params.push(req.query.kelas_id); }
  if (req.query.tingkat) { where.push('k.tingkat = ?'); params.push(toNum(req.query.tingkat)); }
  if (req.query.status) { where.push('s.status = ?'); params.push(req.query.status); }
  if (req.query.search) {
    where.push('(s.nama LIKE ? OR s.nis LIKE ? OR s.nisn LIKE ?)');
    const like = `%${req.query.search}%`;
    params.push(like, like, like);
  }

  // Data orang tua diambil lewat subquery agar tidak menduplikasi baris siswa
  // (dan tetap aman terhadap sql_mode ONLY_FULL_GROUP_BY pada MySQL 8).
  const ortuSub = (kolom) =>
    `(SELECT ot.${kolom} FROM siswa_orang_tua so
        JOIN orang_tua ot ON ot.id = so.orang_tua_id
       WHERE so.siswa_id = s.id ORDER BY so.id LIMIT 1) AS ${kolom}`;

  const rows = await query(
    `SELECT s.id, s.user_id, s.nama, s.nis, s.nisn, s.tempat_lahir, s.tanggal_lahir,
            s.jenis_kelamin, s.agama, s.alamat, s.no_hp, s.email, s.foto_url,
            s.status, s.kelas_id, k.nama_kelas, k.tingkat, u.username,
            ${ortuSub('nama_ibu')}, ${ortuSub('nama_ayah')},
            ${ortuSub('hp_ibu')},   ${ortuSub('hp_ayah')}
       FROM siswa s
       LEFT JOIN kelas k ON k.id = s.kelas_id
       LEFT JOIN users u ON u.id = s.user_id
      WHERE ${where.join(' AND ')}
      ORDER BY k.tingkat, k.nama_kelas, s.nama`,
    params
  );
  return ok(res, rows, 'Data siswa berhasil dimuat');
}));

router.get('/siswa/:id', asyncHandler(async (req, res) => {
  const row = await queryOne(
    `SELECT s.*, k.nama_kelas, k.tingkat, u.username
       FROM siswa s
       LEFT JOIN kelas k ON k.id = s.kelas_id
       LEFT JOIN users u ON u.id = s.user_id
      WHERE s.id = ? AND s.sekolah_id = ? LIMIT 1`,
    [req.params.id, req.user.sekolah_id]
  );
  if (!row) return fail(res, 'Siswa tidak ditemukan', 404);

  const ortu = await queryOne(
    `SELECT ot.* FROM siswa_orang_tua so JOIN orang_tua ot ON ot.id = so.orang_tua_id
      WHERE so.siswa_id = ? LIMIT 1`,
    [row.id]
  );

  return ok(res, { ...row, orang_tua: ortu || null }, 'Detail siswa berhasil dimuat');
}));

router.post('/siswa', asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.nama || !String(b.nama).trim()) return fail(res, 'Nama siswa wajib diisi', 400);
  if (!b.nis) return fail(res, 'NIS wajib diisi', 400);

  const dupNis = await queryOne(
    `SELECT id FROM siswa WHERE sekolah_id = ? AND nis = ?`, [req.user.sekolah_id, b.nis]
  );
  if (dupNis) return fail(res, `NIS ${b.nis} sudah terdaftar`, 409);

  const username = (b.username || b.nis).toString().trim();
  const password = String(b.password || b.nis || '');
  if (password.length < 6) return fail(res, 'Password minimal 6 karakter', 400);

  const dupUser = await queryOne(`SELECT id FROM users WHERE username = ?`, [username]);
  if (dupUser) return fail(res, `Username "${username}" sudah dipakai`, 409);

  const userId = uuid();
  const siswaId = uuid();
  const hash = await bcrypt.hash(password, 10);

  await withTransaction(async (conn) => {
    await conn.execute(
      `INSERT INTO users (id, sekolah_id, username, password, role, role_name, nama, email)
       VALUES (?,?,?,?, 'siswa', 'Siswa', ?, ?)`,
      [userId, req.user.sekolah_id, username, hash, String(b.nama).trim(), b.email || null]
    );
    await conn.execute(
      `INSERT INTO siswa
         (id, sekolah_id, user_id, kelas_id, nama, nis, nisn, tempat_lahir, tanggal_lahir,
          jenis_kelamin, agama, alamat, no_hp, email, tahun_ajaran, status)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?, 'aktif')`,
      [siswaId, req.user.sekolah_id, userId, b.kelas_id || null, String(b.nama).trim(),
       b.nis, b.nisn || null, b.tempat_lahir || null, b.tanggal_lahir || null,
       b.jenis_kelamin === 'P' ? 'P' : 'L', b.agama || null, b.alamat || null,
       b.no_hp || null, b.email || null, b.tahun_ajaran || null]
    );
  });

  const row = await queryOne(
    `SELECT s.*, k.nama_kelas, u.username FROM siswa s
       LEFT JOIN kelas k ON k.id = s.kelas_id
       LEFT JOIN users u ON u.id = s.user_id
      WHERE s.id = ?`,
    [siswaId]
  );
  return ok(res, row, `Siswa ${row.nama} berhasil ditambahkan (username: ${username})`);
}));

router.put('/siswa/:id', asyncHandler(async (req, res) => {
  const b = req.body || {};
  const siswa = await queryOne(
    `SELECT * FROM siswa WHERE id = ? AND sekolah_id = ?`, [req.params.id, req.user.sekolah_id]
  );
  if (!siswa) return fail(res, 'Siswa tidak ditemukan', 404);

  if (b.nis && b.nis !== siswa.nis) {
    const dup = await queryOne(
      `SELECT id FROM siswa WHERE sekolah_id = ? AND nis = ? AND id <> ?`,
      [req.user.sekolah_id, b.nis, siswa.id]
    );
    if (dup) return fail(res, `NIS ${b.nis} sudah dipakai siswa lain`, 409);
  }

  const sets = []; const vals = [];
  const simple = ['nama', 'nis', 'nisn', 'tempat_lahir', 'agama', 'alamat',
                  'no_hp', 'email', 'tahun_ajaran', 'status', 'foto_url'];
  for (const f of simple) {
    if (b[f] !== undefined) { sets.push(`${f} = ?`); vals.push(b[f] === '' ? null : b[f]); }
  }
  if (b.tanggal_lahir !== undefined) {
    sets.push('tanggal_lahir = ?');
    vals.push(b.tanggal_lahir ? String(b.tanggal_lahir).slice(0, 10) : null);
  }
  if (b.jenis_kelamin !== undefined) {
    sets.push('jenis_kelamin = ?'); vals.push(b.jenis_kelamin === 'P' ? 'P' : 'L');
  }
  if (b.kelas_id !== undefined) { sets.push('kelas_id = ?'); vals.push(b.kelas_id || null); }
  if (b.semester !== undefined) { sets.push('semester = ?'); vals.push(toNum(b.semester, 1)); }

  if (!sets.length) return fail(res, 'Tidak ada data yang diubah', 400);

  vals.push(siswa.id);
  await query(`UPDATE siswa SET ${sets.join(', ')} WHERE id = ?`, vals);

  if (siswa.user_id) {
    if (b.nama !== undefined || b.email !== undefined) {
      await query(
        `UPDATE users SET nama = COALESCE(?, nama), email = COALESCE(?, email) WHERE id = ?`,
        [b.nama || null, b.email || null, siswa.user_id]
      );
    }
    if (b.password && String(b.password).length >= 6) {
      const hash = await bcrypt.hash(String(b.password), 10);
      await query(`UPDATE users SET password = ? WHERE id = ?`, [hash, siswa.user_id]);
    }
  }

  const row = await queryOne(
    `SELECT s.*, k.nama_kelas FROM siswa s LEFT JOIN kelas k ON k.id = s.kelas_id WHERE s.id = ?`,
    [siswa.id]
  );
  return ok(res, row, 'Data siswa berhasil diperbarui');
}));

router.delete('/siswa/:id', asyncHandler(async (req, res) => {
  const siswa = await queryOne(
    `SELECT * FROM siswa WHERE id = ? AND sekolah_id = ?`, [req.params.id, req.user.sekolah_id]
  );
  if (!siswa) return fail(res, 'Siswa tidak ditemukan', 404);

  await withTransaction(async (conn) => {
    await conn.execute(`DELETE FROM siswa WHERE id = ?`, [siswa.id]);
    if (siswa.user_id) await conn.execute(`DELETE FROM users WHERE id = ?`, [siswa.user_id]);
  });

  return ok(res, null, `Siswa ${siswa.nama} berhasil dihapus`);
}));

// ====================================================================
// SCHEDULE
// ====================================================================
router.get('/schedule/config', asyncHandler(async (req, res) => {
  const row = await queryOne(
    `SELECT config FROM schedule_config WHERE sekolah_id = ?`, [req.user.sekolah_id]
  );

  let config = DEFAULT_CONFIG;
  if (row && row.config) {
    config = typeof row.config === 'string' ? JSON.parse(row.config) : row.config;
  }

  return ok(res, {
    ...config,
    hari_tersedia: ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'],
  }, 'Konfigurasi jadwal berhasil dimuat');
}));

router.put('/schedule/config', asyncHandler(async (req, res) => {
  const config = req.body?.config || req.body;
  if (!config || typeof config !== 'object') return fail(res, 'Konfigurasi tidak valid', 400);

  await query(
    `INSERT INTO schedule_config (sekolah_id, config) VALUES (?, ?)
     ON DUPLICATE KEY UPDATE config = VALUES(config)`,
    [req.user.sekolah_id, JSON.stringify(config)]
  );

  return ok(res, config, 'Konfigurasi jadwal berhasil disimpan');
}));

router.post('/schedule/generate', asyncHandler(async (req, res) => {
  const b = req.body || {};
  const kelasIds = Array.isArray(b.kelas_ids) ? b.kelas_ids : [];
  const hariList = Array.isArray(b.hari_list) && b.hari_list.length
    ? b.hari_list
    : ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'];

  if (!kelasIds.length) return fail(res, 'Pilih minimal satu kelas', 400);

  const result = await generateJadwal({
    sekolahId: req.user.sekolah_id,
    kelasIds,
    hariList,
    tahunAjaran: b.tahun_ajaran || null,
    semester: toNum(b.semester, 1),
    config: b.config || null,
  });

  if (!result.ok) return fail(res, result.message, 400);

  return ok(res, result.data, result.message);
}));

router.get('/schedule/kelas/:kelasId', asyncHandler(async (req, res) => {
  const where = ['j.kelas_id = ?'];
  const params = [req.params.kelasId];
  if (req.query.hari) { where.push('j.hari = ?'); params.push(req.query.hari); }
  if (req.query.tahun_ajaran) { where.push('j.tahun_ajaran = ?'); params.push(req.query.tahun_ajaran); }
  if (req.query.semester) { where.push('j.semester = ?'); params.push(toNum(req.query.semester, 1)); }

  const rows = await query(
    `SELECT j.id, j.hari, j.jam_mulai, j.jam_selesai, j.ruangan, j.keterangan,
            j.tahun_ajaran, j.semester, j.is_manual,
            j.kelas_id, k.nama_kelas,
            j.mapel_id, m.nama_mapel, m.kode_mapel,
            j.guru_id, g.nama AS guru_nama
       FROM jadwal j
       JOIN kelas k ON k.id = j.kelas_id
       LEFT JOIN mapel m ON m.id = j.mapel_id
       LEFT JOIN guru  g ON g.id = j.guru_id
      WHERE ${where.join(' AND ')}
      ORDER BY FIELD(j.hari,'Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'), j.jam_mulai`,
    params
  );

  return ok(res, rows, 'Jadwal kelas berhasil dimuat');
}));

router.put('/schedule/:id', asyncHandler(async (req, res) => {
  const b = req.body || {};
  const row = await queryOne(`SELECT * FROM jadwal WHERE id = ?`, [req.params.id]);
  if (!row) return fail(res, 'Slot jadwal tidak ditemukan', 404);

  const mapelId = b.mapel_id || null;
  const guruId = b.guru_id || null;
  const jamMulai = b.jam_mulai ? `${String(b.jam_mulai).slice(0, 5)}:00` : row.jam_mulai;
  const jamSelesai = b.jam_selesai ? `${String(b.jam_selesai).slice(0, 5)}:00` : row.jam_selesai;

  // Cek bentrok: guru yang sama di hari & jam yang sama pada kelas lain
  if (guruId) {
    const bentrok = await queryOne(
      `SELECT j.id, k.nama_kelas FROM jadwal j JOIN kelas k ON k.id = j.kelas_id
        WHERE j.guru_id = ? AND j.hari = ? AND j.id <> ?
          AND j.jam_mulai < ? AND j.jam_selesai > ?
        LIMIT 1`,
      [guruId, row.hari, row.id, jamSelesai, jamMulai]
    );
    if (bentrok) {
      return fail(res, `Guru sudah mengajar di kelas ${bentrok.nama_kelas} pada jam tersebut`, 409);
    }
  }

  await query(
    `UPDATE jadwal SET mapel_id = ?, guru_id = ?, jam_mulai = ?, jam_selesai = ?, is_manual = 1
      WHERE id = ?`,
    [mapelId, guruId, jamMulai, jamSelesai, row.id]
  );

  const updated = await queryOne(
    `SELECT j.*, m.nama_mapel, m.kode_mapel, g.nama AS guru_nama
       FROM jadwal j LEFT JOIN mapel m ON m.id = j.mapel_id LEFT JOIN guru g ON g.id = j.guru_id
      WHERE j.id = ?`,
    [row.id]
  );
  return ok(res, updated, 'Jadwal berhasil diperbarui');
}));

router.delete('/schedule/manual/:id', asyncHandler(async (req, res) => {
  const row = await queryOne(`SELECT * FROM jadwal WHERE id = ?`, [req.params.id]);
  if (!row) return fail(res, 'Slot jadwal tidak ditemukan', 404);
  await query(`DELETE FROM jadwal WHERE id = ?`, [row.id]);
  return ok(res, null, 'Slot jadwal berhasil dihapus');
}));

router.delete('/schedule/kelas/:kelasId', asyncHandler(async (req, res) => {
  const result = await query(`DELETE FROM jadwal WHERE kelas_id = ?`, [req.params.kelasId]);
  return ok(res, { dihapus: result.affectedRows ?? 0 }, 'Jadwal kelas berhasil dikosongkan');
}));

// ====================================================================
// HARI LIBUR
// ====================================================================
router.get('/holidays', asyncHandler(async (req, res) => {
  const where = ['sekolah_id = ?'];
  const params = [req.user.sekolah_id];
  if (req.query.tahun) { where.push('YEAR(tanggal) = ?'); params.push(toNum(req.query.tahun)); }

  const rows = await query(
    `SELECT id, tanggal, keterangan FROM hari_libur
      WHERE ${where.join(' AND ')} ORDER BY tanggal`,
    params
  );
  return ok(res, rows, 'Data hari libur berhasil dimuat');
}));

router.post('/holidays', asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.tanggal) return fail(res, 'Tanggal wajib diisi', 400);

  const tanggal = String(b.tanggal).slice(0, 10);
  const dup = await queryOne(
    `SELECT id FROM hari_libur WHERE sekolah_id = ? AND tanggal = ?`,
    [req.user.sekolah_id, tanggal]
  );
  if (dup) return fail(res, 'Tanggal tersebut sudah terdaftar sebagai hari libur', 409);

  const id = uuid();
  await query(
    `INSERT INTO hari_libur (id, sekolah_id, tanggal, keterangan) VALUES (?,?,?,?)`,
    [id, req.user.sekolah_id, tanggal, b.keterangan || null]
  );

  const row = await queryOne(`SELECT id, tanggal, keterangan FROM hari_libur WHERE id = ?`, [id]);
  return ok(res, row, 'Hari libur berhasil ditambahkan');
}));

router.delete('/holidays/:id', asyncHandler(async (req, res) => {
  const row = await queryOne(
    `SELECT * FROM hari_libur WHERE id = ? AND sekolah_id = ?`,
    [req.params.id, req.user.sekolah_id]
  );
  if (!row) return fail(res, 'Hari libur tidak ditemukan', 404);
  await query(`DELETE FROM hari_libur WHERE id = ?`, [row.id]);
  return ok(res, null, 'Hari libur berhasil dihapus');
}));

// ====================================================================
// PENGUMUMAN (admin)
// ====================================================================
router.get('/pengumuman', asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT p.*, (SELECT COUNT(*) FROM pengumuman_read pr WHERE pr.pengumuman_id = p.id) AS dibaca_oleh
       FROM pengumuman p WHERE p.sekolah_id = ? ORDER BY p.created_at DESC LIMIT 200`,
    [req.user.sekolah_id]
  );
  return ok(res, rows, 'Pengumuman berhasil dimuat');
}));

router.post('/pengumuman', asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.judul) return fail(res, 'Judul pengumuman wajib diisi', 400);

  const id = uuid();
  await query(
    `INSERT INTO pengumuman (id, sekolah_id, judul, isi, kategori, prioritas, target_role, created_by)
     VALUES (?,?,?,?,?,?,?,?)`,
    [id, req.user.sekolah_id, b.judul, b.isi || null, b.kategori || 'umum',
     ['rendah', 'normal', 'tinggi'].includes(b.prioritas) ? b.prioritas : 'normal',
     b.target_role || 'semua', req.user.id]
  );

  const row = await queryOne(`SELECT * FROM pengumuman WHERE id = ?`, [id]);
  return ok(res, row, 'Pengumuman berhasil dipublikasikan');
}));

router.delete('/pengumuman/:id', asyncHandler(async (req, res) => {
  const row = await queryOne(
    `SELECT * FROM pengumuman WHERE id = ? AND sekolah_id = ?`,
    [req.params.id, req.user.sekolah_id]
  );
  if (!row) return fail(res, 'Pengumuman tidak ditemukan', 404);
  await query(`DELETE FROM pengumuman WHERE id = ?`, [row.id]);
  return ok(res, null, 'Pengumuman berhasil dihapus');
}));

// ====================================================================
// ORANG TUA (admin): daftar & penautan ke siswa
// ====================================================================
router.get('/orang-tua', asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT ot.*, u.username,
            (SELECT COUNT(*) FROM siswa_orang_tua so WHERE so.orang_tua_id = ot.id) AS jumlah_anak
       FROM orang_tua ot LEFT JOIN users u ON u.id = ot.user_id
      WHERE ot.sekolah_id = ? ORDER BY COALESCE(ot.nama_ibu, ot.nama_ayah, ot.nama_wali)`,
    [req.user.sekolah_id]
  );
  return ok(res, rows, 'Data orang tua berhasil dimuat');
}));

router.post('/orang-tua', asyncHandler(async (req, res) => {
  const b = req.body || {};
  const nama = b.nama_ibu || b.nama_ayah || b.nama_wali;
  if (!nama) return fail(res, 'Minimal salah satu nama (ibu/ayah/wali) wajib diisi', 400);

  const username = (b.username || '').toString().trim();
  if (!username) return fail(res, 'Username wajib diisi', 400);
  const password = String(b.password || '');
  if (password.length < 6) return fail(res, 'Password minimal 6 karakter', 400);

  const dup = await queryOne(`SELECT id FROM users WHERE username = ?`, [username]);
  if (dup) return fail(res, `Username "${username}" sudah dipakai`, 409);

  const userId = uuid();
  const ortuId = uuid();
  const hash = await bcrypt.hash(password, 10);

  await withTransaction(async (conn) => {
    await conn.execute(
      `INSERT INTO users (id, sekolah_id, username, password, role, role_name, nama, email)
       VALUES (?,?,?,?, 'orang_tua', 'Orang Tua', ?, ?)`,
      [userId, req.user.sekolah_id, username, hash, nama, b.email || null]
    );
    await conn.execute(
      `INSERT INTO orang_tua
         (id, sekolah_id, user_id, nama_ibu, hp_ibu, nama_ayah, hp_ayah, nama_wali, alamat, email)
       VALUES (?,?,?,?,?,?,?,?,?,?)`,
      [ortuId, req.user.sekolah_id, userId, b.nama_ibu || null, b.hp_ibu || null,
       b.nama_ayah || null, b.hp_ayah || null, b.nama_wali || null, b.alamat || null, b.email || null]
    );

    const anak = Array.isArray(b.siswa_ids) ? b.siswa_ids : [];
    for (const siswaId of anak) {
      await conn.execute(
        `INSERT IGNORE INTO siswa_orang_tua (id, siswa_id, orang_tua_id) VALUES (?,?,?)`,
        [uuid(), siswaId, ortuId]
      );
    }
  });

  const row = await queryOne(`SELECT * FROM orang_tua WHERE id = ?`, [ortuId]);
  return ok(res, row, `Akun orang tua berhasil dibuat (username: ${username})`);
}));

router.post('/orang-tua/:id/anak', asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.siswa_id) return fail(res, 'siswa_id wajib diisi', 400);

  const ortu = await queryOne(
    `SELECT id FROM orang_tua WHERE id = ? AND sekolah_id = ?`,
    [req.params.id, req.user.sekolah_id]
  );
  if (!ortu) return fail(res, 'Orang tua tidak ditemukan', 404);

  const siswa = await queryOne(
    `SELECT id, nama FROM siswa WHERE id = ? AND sekolah_id = ?`,
    [b.siswa_id, req.user.sekolah_id]
  );
  if (!siswa) return fail(res, 'Siswa tidak ditemukan', 404);

  await query(
    `INSERT IGNORE INTO siswa_orang_tua (id, siswa_id, orang_tua_id) VALUES (?,?,?)`,
    [uuid(), siswa.id, ortu.id]
  );

  return ok(res, { siswa_id: siswa.id, orang_tua_id: ortu.id }, `${siswa.nama} berhasil ditautkan`);
}));

router.delete('/orang-tua/:id/anak/:siswaId', asyncHandler(async (req, res) => {
  await query(
    `DELETE FROM siswa_orang_tua WHERE orang_tua_id = ? AND siswa_id = ?`,
    [req.params.id, req.params.siswaId]
  );
  return ok(res, null, 'Penautan berhasil dihapus');
}));

// ====================================================================
// RINGKASAN DASHBOARD ADMIN
// ====================================================================
router.get('/dashboard', asyncHandler(async (req, res) => {
  const sekolahId = req.user.sekolah_id;
  const [siswa, guru, kelas, mapel] = await Promise.all([
    queryOne(`SELECT COUNT(*) AS c FROM siswa WHERE sekolah_id = ? AND status = 'aktif'`, [sekolahId]),
    queryOne(`SELECT COUNT(*) AS c FROM guru  WHERE sekolah_id = ? AND status = 'aktif'`, [sekolahId]),
    queryOne(`SELECT COUNT(*) AS c FROM kelas WHERE sekolah_id = ?`, [sekolahId]),
    queryOne(`SELECT COUNT(*) AS c FROM mapel WHERE sekolah_id = ?`, [sekolahId]),
  ]);

  const pendingBayar = await queryOne(
    `SELECT COUNT(*) AS c FROM pembayaran WHERE sekolah_id = ? AND status = 'pending'`, [sekolahId]
  );

  return ok(res, {
    total_siswa: toNum(siswa?.c),
    total_guru: toNum(guru?.c),
    total_kelas: toNum(kelas?.c),
    total_mapel: toNum(mapel?.c),
    pembayaran_pending: toNum(pendingBayar?.c),
  }, 'Ringkasan berhasil dimuat');
}));

module.exports = router;
