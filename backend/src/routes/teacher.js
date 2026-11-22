'use strict';

const express = require('express');
const { query, queryOne } = require('../db');
const {
  ok, fail, asyncHandler, uuid, todayStr, nowTimeStr, nowDateTimeStr,
  toNum, hitungNilaiAkhir, predikat,
} = require('../utils/helpers');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate, requireRole('guru', 'admin'));

/** Guru yang sedang login (admin boleh mengirim ?guru_id=). */
async function resolveGuru(req, res) {
  if (req.guru) return req.guru;
  if (req.user.role === 'admin' && req.query.guru_id) {
    const g = await queryOne(`SELECT * FROM guru WHERE id = ?`, [req.query.guru_id]);
    if (g) return g;
  }
  fail(res, 'Data guru tidak tertaut dengan akun ini', 404);
  return null;
}

// ====================================================================
// GET /api/teacher/profile
// ====================================================================
router.get('/profile', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;

  const kelasWali = await query(
    `SELECT id, nama_kelas, tingkat FROM kelas WHERE wali_kelas_id = ?`, [g.id]
  );
  const mapel = await query(
    `SELECT m.id, m.nama_mapel, m.kode_mapel
       FROM guru_mapel gm JOIN mapel m ON m.id = gm.mapel_id
      WHERE gm.guru_id = ? ORDER BY m.nama_mapel`,
    [g.id]
  );

  return ok(res, {
    id: g.id,
    user_id: g.user_id,
    nama: g.nama || '',
    fullName: g.nama || '',
    nip: g.nip || '',
    email: g.email || req.user.email || '',
    no_hp: g.no_hp || '',
    jenis_kelamin: g.jenis_kelamin,
    alamat: g.alamat || '',
    foto_url: g.foto_url || '',
    status: g.status,
    kelas_wali: kelasWali,
    mapel,
  }, 'Profil guru berhasil dimuat');
}));

// ====================================================================
// GET /api/teacher/jadwal
// ====================================================================
router.get('/jadwal', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;

  const rows = await query(
    `SELECT j.id, j.hari, j.jam_mulai, j.jam_selesai, j.ruangan, j.keterangan,
            j.tahun_ajaran, j.semester,
            j.kelas_id, k.nama_kelas, k.tingkat,
            j.mapel_id, m.nama_mapel, m.kode_mapel,
            j.guru_id, g.nama AS guru_nama
       FROM jadwal j
       JOIN kelas k ON k.id = j.kelas_id
       LEFT JOIN mapel m ON m.id = j.mapel_id
       LEFT JOIN guru  g ON g.id = j.guru_id
      WHERE j.guru_id = ?
      ORDER BY FIELD(j.hari,'Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'), j.jam_mulai`,
    [g.id]
  );

  return ok(res, { jadwal: rows, total: rows.length }, 'Jadwal guru berhasil dimuat');
}));

// ====================================================================
// GET /api/teacher/kelas  (daftar kelas yang diajar / diampu)
// ====================================================================
router.get('/kelas', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;
  const rows = await query(
    `SELECT DISTINCT k.id, k.nama_kelas AS nama, k.nama_kelas, k.tingkat, k.tahun_ajaran
       FROM kelas k
       LEFT JOIN jadwal j ON j.kelas_id = k.id
      WHERE j.guru_id = ? OR k.wali_kelas_id = ?
      ORDER BY k.tingkat, k.nama_kelas`,
    [g.id, g.id]
  );
  return ok(res, rows, 'Daftar kelas berhasil dimuat');
}));

// ====================================================================
// GET /api/teacher/kelas/:kelasId/siswa
// ====================================================================
router.get('/kelas/:kelasId/siswa', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;

  const rows = await query(
    `SELECT s.id, s.nama, s.nis, s.nisn, s.jenis_kelamin, s.foto_url,
            s.kelas_id, k.nama_kelas
       FROM siswa s
       LEFT JOIN kelas k ON k.id = s.kelas_id
      WHERE s.kelas_id = ? AND s.status = 'aktif'
      ORDER BY s.nama`,
    [req.params.kelasId]
  );

  return ok(res, { siswa: rows, total: rows.length }, 'Daftar siswa berhasil dimuat');
}));

// ====================================================================
// POST /api/teacher/nilai
// ====================================================================
router.post('/nilai', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;
  const b = req.body || {};

  if (!b.siswa_id || !b.mapel_id) {
    return fail(res, 'siswa_id dan mapel_id wajib diisi', 400);
  }

  const siswa = await queryOne(`SELECT id FROM siswa WHERE id = ?`, [b.siswa_id]);
  if (!siswa) return fail(res, 'Siswa tidak ditemukan', 404);
  const mapel = await queryOne(`SELECT id FROM mapel WHERE id = ?`, [b.mapel_id]);
  if (!mapel) return fail(res, 'Mata pelajaran tidak ditemukan', 404);

  const nTugas = toNum(b.nilai_tugas);
  const nUts = toNum(b.nilai_uts);
  const nUas = toNum(b.nilai_uas);

  for (const [label, v] of [['tugas', nTugas], ['UTS', nUts], ['UAS', nUas]]) {
    if (v < 0 || v > 100) return fail(res, `Nilai ${label} harus antara 0 - 100`, 400);
  }

  const semester = toNum(b.semester, 1);
  const tahunAjaran = b.tahun_ajaran || null;
  const akhir = hitungNilaiAkhir(nTugas, nUts, nUas);
  const pred = predikat(akhir);

  const existing = await queryOne(
    `SELECT id FROM nilai
      WHERE siswa_id = ? AND mapel_id = ? AND semester = ?
        AND (tahun_ajaran = ? OR (tahun_ajaran IS NULL AND ? IS NULL))`,
    [b.siswa_id, b.mapel_id, semester, tahunAjaran, tahunAjaran]
  );

  if (existing) {
    await query(
      `UPDATE nilai
          SET guru_id = ?, nilai_tugas = ?, nilai_uts = ?, nilai_uas = ?,
              nilai_akhir = ?, predikat = ?, catatan = ?
        WHERE id = ?`,
      [g.id, nTugas, nUts, nUas, akhir, pred, b.catatan || null, existing.id]
    );
  } else {
    await query(
      `INSERT INTO nilai
         (id, siswa_id, mapel_id, guru_id, semester, tahun_ajaran,
          nilai_tugas, nilai_uts, nilai_uas, nilai_akhir, predikat, catatan)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
      [uuid(), b.siswa_id, b.mapel_id, g.id, semester, tahunAjaran,
       nTugas, nUts, nUas, akhir, pred, b.catatan || null]
    );
  }

  const row = await queryOne(
    `SELECT n.*, m.nama_mapel, m.kode_mapel, s.nama AS nama_siswa
       FROM nilai n
       JOIN mapel m ON m.id = n.mapel_id
       JOIN siswa s ON s.id = n.siswa_id
      WHERE n.siswa_id = ? AND n.mapel_id = ? AND n.semester = ?
        AND (n.tahun_ajaran = ? OR (n.tahun_ajaran IS NULL AND ? IS NULL))`,
    [b.siswa_id, b.mapel_id, semester, tahunAjaran, tahunAjaran]
  );

  return ok(res, row, `Nilai berhasil disimpan (akhir ${akhir}, predikat ${pred})`);
}));

// ====================================================================
// GET /api/teacher/nilai/:siswaId/mapel/:mapelId
// ====================================================================
router.get('/nilai/:siswaId/mapel/:mapelId', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;

  const params = [req.params.siswaId, req.params.mapelId];
  const where = ['n.siswa_id = ?', 'n.mapel_id = ?'];
  if (req.query.semester) { where.push('n.semester = ?'); params.push(toNum(req.query.semester, 1)); }
  if (req.query.tahun_ajaran) { where.push('n.tahun_ajaran = ?'); params.push(req.query.tahun_ajaran); }

  const row = await queryOne(
    `SELECT n.*, m.nama_mapel, m.kode_mapel
       FROM nilai n JOIN mapel m ON m.id = n.mapel_id
      WHERE ${where.join(' AND ')}
      ORDER BY n.updated_at DESC LIMIT 1`,
    params
  );

  if (!row) return ok(res, null, 'Belum ada nilai tersimpan');
  return ok(res, row, 'Nilai ditemukan');
}));

// ====================================================================
// GET /api/teacher/absensi/kelas/:kelasId
// Bentuk: data.absensi = [{ id: <siswa_id>, nama, nis, absensi: [...] }]
// ====================================================================
router.get('/absensi/kelas/:kelasId', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;

  const siswa = await query(
    `SELECT id, nama, nis FROM siswa
      WHERE kelas_id = ? AND status = 'aktif' ORDER BY nama`,
    [req.params.kelasId]
  );
  if (!siswa.length) return ok(res, { absensi: [], total_siswa: 0 }, 'Belum ada siswa di kelas ini');

  const placeholders = siswa.map(() => '?').join(',');
  const params = siswa.map((s) => s.id);
  const filters = [`a.siswa_id IN (${placeholders})`];
  if (req.query.bulan) { filters.push('MONTH(a.tanggal) = ?'); params.push(toNum(req.query.bulan)); }
  if (req.query.tahun) { filters.push('YEAR(a.tanggal) = ?');  params.push(toNum(req.query.tahun)); }

  const rows = await query(
    `SELECT a.id, a.siswa_id, a.tanggal, a.status, a.jam_masuk, a.jam_pulang,
            a.keterangan, a.approval_status
       FROM absensi a
      WHERE ${filters.join(' AND ')}
      ORDER BY a.tanggal DESC`,
    params
  );

  const bySiswa = new Map(siswa.map((s) => [s.id, { id: s.id, nama: s.nama, nis: s.nis, absensi: [] }]));
  for (const r of rows) {
    const entry = bySiswa.get(r.siswa_id);
    if (entry) entry.absensi.push(r);
  }

  const absensi = Array.from(bySiswa.values());
  return ok(res, { absensi, total_siswa: siswa.length }, 'Rekap absensi kelas berhasil dimuat');
}));

// ====================================================================
// POST /api/teacher/absensi/kelas/:kelasId  (input absensi manual)
// body: { tanggal, items: [{siswa_id, status, keterangan}] }
// ====================================================================
router.post('/absensi/kelas/:kelasId', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;
  const b = req.body || {};
  const tanggal = b.tanggal || todayStr();
  const items = Array.isArray(b.items) ? b.items : [];

  if (!items.length) return fail(res, 'Daftar absensi kosong', 400);

  let saved = 0;
  for (const it of items) {
    if (!it.siswa_id || !it.status) continue;
    await query(
      `INSERT INTO absensi (id, siswa_id, kelas_id, tanggal, status, keterangan, approval_status)
       VALUES (?,?,?,?,?,?, '')
       ON DUPLICATE KEY UPDATE status = VALUES(status), keterangan = VALUES(keterangan)`,
      [uuid(), it.siswa_id, req.params.kelasId, tanggal, it.status, it.keterangan || null]
    );
    saved += 1;
  }

  return ok(res, { tersimpan: saved, tanggal }, `${saved} data absensi tersimpan`);
}));

// ====================================================================
// ABSENSI GURU (diri sendiri)
// ====================================================================
router.get('/absensi/today', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;

  const row = await queryOne(
    `SELECT id, tanggal, jam_masuk, jam_keluar, status, keterangan
       FROM absensi_guru WHERE guru_id = ? AND tanggal = ?`,
    [g.id, todayStr()]
  );

  return ok(res, row || null, row ? 'Absensi hari ini' : 'Belum absen hari ini');
}));

router.get('/absensi/history', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;
  const limit = Math.max(1, Math.min(parseInt(toNum(req.query.limit, 60), 10), 365));

  const rows = await query(
    `SELECT id, tanggal, jam_masuk, jam_keluar, status, keterangan
       FROM absensi_guru WHERE guru_id = ?
      ORDER BY tanggal DESC LIMIT ${limit}`,
    [g.id]
  );

  return ok(res, rows, 'Riwayat absensi berhasil dimuat');
}));

router.post('/absensi/checkin', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;
  const tanggal = todayStr();

  const existing = await queryOne(
    `SELECT * FROM absensi_guru WHERE guru_id = ? AND tanggal = ?`, [g.id, tanggal]
  );
  if (existing && existing.jam_masuk) return fail(res, 'Anda sudah check-in hari ini', 409);

  const jamMasuk = nowTimeStr();
  if (existing) {
    await query(`UPDATE absensi_guru SET jam_masuk = ?, status = 'hadir' WHERE id = ?`,
      [jamMasuk, existing.id]);
  } else {
    await query(
      `INSERT INTO absensi_guru (id, guru_id, tanggal, jam_masuk, status)
       VALUES (?,?,?,?, 'hadir')`,
      [uuid(), g.id, tanggal, jamMasuk]
    );
  }

  const row = await queryOne(
    `SELECT id, tanggal, jam_masuk, jam_keluar, status FROM absensi_guru
      WHERE guru_id = ? AND tanggal = ?`, [g.id, tanggal]
  );
  return ok(res, row, `Check-in berhasil pada ${jamMasuk.slice(0, 5)}`);
}));

router.post('/absensi/checkout', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;
  const tanggal = todayStr();

  const existing = await queryOne(
    `SELECT * FROM absensi_guru WHERE guru_id = ? AND tanggal = ?`, [g.id, tanggal]
  );
  if (!existing || !existing.jam_masuk) return fail(res, 'Anda belum check-in hari ini', 400);
  if (existing.jam_keluar) return fail(res, 'Anda sudah check-out hari ini', 409);

  const jamKeluar = nowTimeStr();
  await query(`UPDATE absensi_guru SET jam_keluar = ? WHERE id = ?`, [jamKeluar, existing.id]);

  const row = await queryOne(
    `SELECT id, tanggal, jam_masuk, jam_keluar, status FROM absensi_guru WHERE id = ?`,
    [existing.id]
  );
  return ok(res, row, `Check-out berhasil pada ${jamKeluar.slice(0, 5)}`);
}));

// ====================================================================
// GET /api/teacher/tugas/:tugasId/submissions
// ====================================================================
router.get('/tugas/:tugasId/submissions', asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;

  const tugas = await queryOne(
    `SELECT t.*, k.nama_kelas, m.nama_mapel
       FROM tugas t
       JOIN kelas k ON k.id = t.kelas_id
       LEFT JOIN mapel m ON m.id = t.mapel_id
      WHERE t.id = ? LIMIT 1`,
    [req.params.tugasId]
  );
  if (!tugas) return fail(res, 'Tugas tidak ditemukan', 404);

  const submissions = await query(
    `SELECT sub.id, sub.tugas_id, sub.siswa_id, sub.file_nama, sub.file_url,
            sub.catatan, sub.submitted_at, sub.nilai, sub.feedback, sub.graded_at,
            s.nama AS siswa_nama, s.nis
       FROM tugas_submission sub
       JOIN siswa s ON s.id = sub.siswa_id
      WHERE sub.tugas_id = ?
      ORDER BY sub.submitted_at DESC`,
    [tugas.id]
  );

  const belumSubmit = await query(
    `SELECT s.id, s.nama, s.nis
       FROM siswa s
      WHERE s.kelas_id = ? AND s.status = 'aktif'
        AND s.id NOT IN (SELECT siswa_id FROM tugas_submission WHERE tugas_id = ?)
      ORDER BY s.nama`,
    [tugas.kelas_id, tugas.id]
  );

  const totalRow = await queryOne(
    `SELECT COUNT(*) AS total FROM siswa WHERE kelas_id = ? AND status = 'aktif'`,
    [tugas.kelas_id]
  );

  return ok(res, {
    tugas: {
      id: tugas.id, judul: tugas.judul, deskripsi: tugas.deskripsi,
      deadline: tugas.deadline, nama_kelas: tugas.nama_kelas, nama_mapel: tugas.nama_mapel,
    },
    submissions,
    belum_submit: belumSubmit,
    total_siswa: toNum(totalRow?.total),
    total_submitted: submissions.length,
    total_graded: submissions.filter((s) => s.nilai !== null).length,
  }, 'Daftar pengumpulan berhasil dimuat');
}));

// ====================================================================
// POST /api/teacher/submission/:submissionId/nilai
// ====================================================================
const gradeSubmission = asyncHandler(async (req, res) => {
  const g = await resolveGuru(req, res); if (!g) return;
  const b = req.body || {};

  const sub = await queryOne(
    `SELECT * FROM tugas_submission WHERE id = ? LIMIT 1`, [req.params.submissionId]
  );
  if (!sub) return fail(res, 'Data pengumpulan tidak ditemukan', 404);

  const nilai = toNum(b.nilai, -1);
  if (nilai < 0 || nilai > 100) return fail(res, 'Nilai harus antara 0 - 100', 400);

  await query(
    `UPDATE tugas_submission
        SET nilai = ?, feedback = ?, graded_at = ?, graded_by = ?
      WHERE id = ?`,
    [nilai, b.feedback || null, nowDateTimeStr(), g.id, sub.id]
  );

  const row = await queryOne(
    `SELECT sub.*, s.nama AS siswa_nama
       FROM tugas_submission sub JOIN siswa s ON s.id = sub.siswa_id
      WHERE sub.id = ?`,
    [sub.id]
  );

  return ok(res, row, 'Nilai tugas berhasil disimpan');
});

router.post('/submission/:submissionId/nilai', gradeSubmission);

module.exports = router;
module.exports.gradeSubmission = gradeSubmission;
