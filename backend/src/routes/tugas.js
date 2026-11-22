'use strict';

const express = require('express');
const { query, queryOne } = require('../db');
const { ok, fail, asyncHandler, uuid, toNum } = require('../utils/helpers');
const { authenticate, requireRole } = require('../middleware/auth');
const { uploadTugas } = require('../middleware/upload');
const { listTugasSiswa, submitTugas } = require('./student');
const { gradeSubmission } = require('./teacher');

const router = express.Router();
router.use(authenticate);

// ====================================================================
// GURU
// ====================================================================
const onlyGuru = requireRole('guru', 'admin');

async function guruOf(req, res) {
  if (req.guru) return req.guru;
  if (req.user.role === 'admin') return null; // admin: lihat semua
  fail(res, 'Data guru tidak tertaut dengan akun ini', 404);
  return undefined; // sinyal error
}

router.get('/guru/tugas', onlyGuru, asyncHandler(async (req, res) => {
  const g = await guruOf(req, res);
  if (g === undefined) return;

  const where = [];
  const params = [];
  if (g) { where.push('t.guru_id = ?'); params.push(g.id); }
  else { where.push('t.sekolah_id = ?'); params.push(req.user.sekolah_id); }
  if (req.query.kelas_id) { where.push('t.kelas_id = ?'); params.push(req.query.kelas_id); }
  if (req.query.status) { where.push('t.status = ?'); params.push(req.query.status); }

  const rows = await query(
    `SELECT t.id, t.judul, t.deskripsi, t.deadline, t.status, t.created_at,
            t.kelas_id, k.nama_kelas,
            t.mapel_id, m.nama_mapel, m.kode_mapel,
            t.guru_id, g.nama AS guru_nama,
            (SELECT COUNT(*) FROM tugas_submission s WHERE s.tugas_id = t.id) AS total_submitted,
            (SELECT COUNT(*) FROM tugas_submission s WHERE s.tugas_id = t.id AND s.nilai IS NOT NULL) AS total_graded,
            (SELECT COUNT(*) FROM siswa sw WHERE sw.kelas_id = t.kelas_id AND sw.status = 'aktif') AS total_siswa
       FROM tugas t
       JOIN kelas k ON k.id = t.kelas_id
       LEFT JOIN mapel m ON m.id = t.mapel_id
       LEFT JOIN guru  g ON g.id = t.guru_id
      WHERE ${where.join(' AND ')}
      ORDER BY t.created_at DESC`,
    params
  );

  return ok(res, { tugas: rows, total: rows.length }, 'Daftar tugas berhasil dimuat');
}));

router.get('/guru/tugas/:tugasId', onlyGuru, asyncHandler(async (req, res) => {
  const row = await queryOne(
    `SELECT t.*, k.nama_kelas, m.nama_mapel, m.kode_mapel, g.nama AS guru_nama
       FROM tugas t
       JOIN kelas k ON k.id = t.kelas_id
       LEFT JOIN mapel m ON m.id = t.mapel_id
       LEFT JOIN guru  g ON g.id = t.guru_id
      WHERE t.id = ? LIMIT 1`,
    [req.params.tugasId]
  );
  if (!row) return fail(res, 'Tugas tidak ditemukan', 404);

  const submissions = await query(
    `SELECT sub.id, sub.siswa_id, s.nama AS siswa_nama, s.nis,
            sub.file_nama, sub.file_url, sub.catatan, sub.submitted_at,
            sub.nilai, sub.feedback
       FROM tugas_submission sub JOIN siswa s ON s.id = sub.siswa_id
      WHERE sub.tugas_id = ? ORDER BY sub.submitted_at DESC`,
    [row.id]
  );

  return ok(res, { ...row, submissions }, 'Detail tugas berhasil dimuat');
}));

router.post('/guru/tugas', onlyGuru, asyncHandler(async (req, res) => {
  const g = await guruOf(req, res);
  if (g === undefined) return;
  const b = req.body || {};

  if (!b.kelas_id) return fail(res, 'kelas_id wajib diisi', 400);
  if (!b.judul || !String(b.judul).trim()) return fail(res, 'Judul tugas wajib diisi', 400);

  const kelas = await queryOne(`SELECT id, sekolah_id FROM kelas WHERE id = ?`, [b.kelas_id]);
  if (!kelas) return fail(res, 'Kelas tidak ditemukan', 404);

  if (b.mapel_id) {
    const m = await queryOne(`SELECT id FROM mapel WHERE id = ?`, [b.mapel_id]);
    if (!m) return fail(res, 'Mata pelajaran tidak ditemukan', 404);
  }

  // 'YYYY-MM-DDTHH:mm:ss.sss' dari Flutter -> format MySQL DATETIME
  let deadline = null;
  if (b.deadline) {
    const d = new Date(b.deadline);
    if (!Number.isNaN(d.getTime())) {
      const p = (n) => String(n).padStart(2, '0');
      deadline = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ` +
                 `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
    }
  }

  const id = uuid();
  await query(
    `INSERT INTO tugas (id, sekolah_id, kelas_id, mapel_id, guru_id, judul, deskripsi, deadline, status)
     VALUES (?,?,?,?,?,?,?,?,?)`,
    [id, kelas.sekolah_id, b.kelas_id, b.mapel_id || null, g ? g.id : (b.guru_id || null),
     String(b.judul).trim(), b.deskripsi || null, deadline, b.status || 'aktif']
  );

  const row = await queryOne(
    `SELECT t.*, k.nama_kelas, m.nama_mapel, m.kode_mapel, g.nama AS guru_nama
       FROM tugas t
       JOIN kelas k ON k.id = t.kelas_id
       LEFT JOIN mapel m ON m.id = t.mapel_id
       LEFT JOIN guru  g ON g.id = t.guru_id
      WHERE t.id = ?`,
    [id]
  );

  return ok(res, row, 'Tugas berhasil dibuat');
}));

router.put('/guru/tugas/:tugasId', onlyGuru, asyncHandler(async (req, res) => {
  const b = req.body || {};
  const row = await queryOne(`SELECT * FROM tugas WHERE id = ?`, [req.params.tugasId]);
  if (!row) return fail(res, 'Tugas tidak ditemukan', 404);

  const sets = [];
  const vals = [];
  for (const f of ['judul', 'deskripsi', 'status', 'mapel_id', 'kelas_id']) {
    if (b[f] !== undefined) { sets.push(`${f} = ?`); vals.push(b[f] || null); }
  }
  if (b.deadline !== undefined) {
    const d = b.deadline ? new Date(b.deadline) : null;
    sets.push('deadline = ?');
    vals.push(d && !Number.isNaN(d.getTime())
      ? d.toISOString().slice(0, 19).replace('T', ' ')
      : null);
  }
  if (!sets.length) return fail(res, 'Tidak ada data yang diubah', 400);

  vals.push(row.id);
  await query(`UPDATE tugas SET ${sets.join(', ')} WHERE id = ?`, vals);

  const updated = await queryOne(`SELECT * FROM tugas WHERE id = ?`, [row.id]);
  return ok(res, updated, 'Tugas berhasil diperbarui');
}));

router.delete('/guru/tugas/:tugasId', onlyGuru, asyncHandler(async (req, res) => {
  const row = await queryOne(`SELECT id FROM tugas WHERE id = ?`, [req.params.tugasId]);
  if (!row) return fail(res, 'Tugas tidak ditemukan', 404);
  await query(`DELETE FROM tugas WHERE id = ?`, [row.id]);
  return ok(res, null, 'Tugas berhasil dihapus');
}));

// alias penilaian submission yang dipakai ApiService.gradeSubmission
router.post('/guru/tugas/submission/:submissionId/grade', onlyGuru, gradeSubmission);

// ====================================================================
// SISWA
// ====================================================================
const onlySiswa = requireRole('siswa');

router.get('/siswa/tugas', onlySiswa, asyncHandler(async (req, res) => {
  if (!req.siswa) return fail(res, 'Data siswa tidak tertaut dengan akun ini', 404);
  const rows = await listTugasSiswa(req.siswa);

  const tugas = rows.map((r) => ({
    ...r,
    nama_mapel: r.nama_mapel || '-',
    kode_mapel: r.kode_mapel || '',
    guru_nama: r.guru_nama || '-',
    sudah_submit: !!r.submission_id,
    status_pengerjaan: r.submission_id
      ? (r.nilai != null ? 'dinilai' : 'sudah_dikerjakan')
      : 'belum_dikerjakan',
  }));

  return ok(res, { tugas, total: tugas.length }, 'Tugas berhasil dimuat');
}));

router.get('/siswa/tugas/:tugasId/submission', onlySiswa, asyncHandler(async (req, res) => {
  if (!req.siswa) return fail(res, 'Data siswa tidak tertaut dengan akun ini', 404);
  const row = await queryOne(
    `SELECT id, tugas_id, siswa_id, file_nama, file_url, catatan,
            submitted_at, nilai, feedback, graded_at
       FROM tugas_submission WHERE tugas_id = ? AND siswa_id = ? LIMIT 1`,
    [req.params.tugasId, req.siswa.id]
  );
  if (!row) return ok(res, null, 'Belum ada pengumpulan');
  return ok(res, row, 'Pengumpulan ditemukan');
}));

router.post('/siswa/tugas/:tugasId/submit', onlySiswa, uploadTugas.single('file'), submitTugas);

// ====================================================================
// ORANG TUA
// ====================================================================
router.get('/orang-tua/anak/:anakId/tugas',
  requireRole('orang_tua', 'admin'),
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'admin') {
      if (!req.ortu) return fail(res, 'Data orang tua tidak tertaut dengan akun ini', 404);
      const rel = await queryOne(
        `SELECT 1 AS ok FROM siswa_orang_tua WHERE orang_tua_id = ? AND siswa_id = ?`,
        [req.ortu.id, req.params.anakId]
      );
      if (!rel) return fail(res, 'Siswa tersebut bukan anak Anda', 403);
    }

    const siswa = await queryOne(
      `SELECT id, kelas_id FROM siswa WHERE id = ? LIMIT 1`, [req.params.anakId]
    );
    if (!siswa) return fail(res, 'Siswa tidak ditemukan', 404);
    if (!siswa.kelas_id) return ok(res, { tugas: [] }, 'Anak belum memiliki kelas');

    const rows = await query(
      `SELECT t.id, t.judul, t.deskripsi, t.deadline, t.created_at,
              m.nama_mapel, m.kode_mapel, g.nama AS guru_nama, k.nama_kelas,
              sub.submitted_at, sub.nilai, sub.feedback, sub.file_nama
         FROM tugas t
         LEFT JOIN mapel m ON m.id = t.mapel_id
         LEFT JOIN guru  g ON g.id = t.guru_id
         LEFT JOIN kelas k ON k.id = t.kelas_id
         LEFT JOIN tugas_submission sub ON sub.tugas_id = t.id AND sub.siswa_id = ?
        WHERE t.kelas_id = ? AND t.status <> 'draft'
        ORDER BY t.deadline IS NULL, t.deadline DESC, t.created_at DESC`,
      [siswa.id, siswa.kelas_id]
    );

    const tugas = rows.map((r) => ({
      ...r,
      nama_mapel: r.nama_mapel || '-',
      guru_nama: r.guru_nama || '-',
      status: r.submitted_at
        ? (r.nilai != null ? 'dinilai' : 'sudah_dikerjakan')
        : 'belum_dikerjakan',
    }));

    const stats = {
      total: tugas.length,
      sudah_dikerjakan: tugas.filter((t) => t.status !== 'belum_dikerjakan').length,
      belum_dikerjakan: tugas.filter((t) => t.status === 'belum_dikerjakan').length,
      dinilai: tugas.filter((t) => t.status === 'dinilai').length,
    };

    return ok(res, { tugas, stats, total: tugas.length }, 'Tugas anak berhasil dimuat');
  })
);

module.exports = router;
