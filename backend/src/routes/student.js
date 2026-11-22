'use strict';

const express = require('express');
const config = require('../config');
const { query, queryOne } = require('../db');
const {
  ok, fail, asyncHandler, uuid, todayStr, nowTimeStr, nowDateTimeStr,
  toNum, jarakMeter,
} = require('../utils/helpers');
const { authenticate, requireRole } = require('../middleware/auth');
const { uploadTugas } = require('../middleware/upload');

const router = express.Router();
router.use(authenticate, requireRole('siswa'));

/** Pastikan profil siswa tertaut dengan user yang login. */
function needSiswa(req, res) {
  if (!req.siswa) {
    fail(res, 'Data siswa tidak tertaut dengan akun ini', 404);
    return null;
  }
  return req.siswa;
}

// ====================================================================
// GET /api/student/profile
// ====================================================================
router.get('/profile', asyncHandler(async (req, res) => {
  const s = needSiswa(req, res); if (!s) return;

  return ok(res, {
    id: s.id,
    user_id: req.user.id,
    nama: s.nama || '',
    nis: s.nis || '',
    nisn: s.nisn || '',
    email: s.email || req.user.email || '',
    kelas_id: s.kelas_id,
    kelas: s.nama_kelas || '',
    nama_kelas: s.nama_kelas || '',
    tingkat: s.tingkat,
    tahun_ajaran: s.tahun_ajaran || s.kelas_tahun_ajaran || '',
    semester: s.semester != null ? String(s.semester) : '1',
    wali_kelas: s.wali_kelas || '',
    foto_url: s.foto_url || '',
    jenis_kelamin: s.jenis_kelamin,
    tempat_lahir: s.tempat_lahir || '',
    tanggal_lahir: s.tanggal_lahir,
    agama: s.agama || '',
    alamat: s.alamat || '',
    no_hp: s.no_hp || '',
    status: s.status,
  }, 'Profil siswa berhasil dimuat');
}));

// ====================================================================
// GET /api/student/jadwal
// ====================================================================
router.get('/jadwal', asyncHandler(async (req, res) => {
  const s = needSiswa(req, res); if (!s) return;
  if (!s.kelas_id) return ok(res, { jadwal: [] }, 'Siswa belum memiliki kelas');

  const rows = await query(
    `SELECT j.id, j.hari, j.jam_mulai, j.jam_selesai, j.ruangan, j.keterangan,
            j.tahun_ajaran, j.semester,
            j.mapel_id, m.nama_mapel, m.kode_mapel,
            j.guru_id, g.nama AS guru_nama,
            j.kelas_id, k.nama_kelas
       FROM jadwal j
       LEFT JOIN mapel m ON m.id = j.mapel_id
       LEFT JOIN guru  g ON g.id = j.guru_id
       LEFT JOIN kelas k ON k.id = j.kelas_id
      WHERE j.kelas_id = ?
      ORDER BY FIELD(j.hari,'Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'), j.jam_mulai`,
    [s.kelas_id]
  );

  const jadwal = rows.map((r) => ({
    ...r,
    nama_mapel: r.nama_mapel || r.keterangan || 'Kegiatan Sekolah',
    kode_mapel: r.kode_mapel || '',
    guru_nama: r.guru_nama || '-',
    ruangan: r.ruangan || '-',
  }));

  return ok(res, { jadwal, total: jadwal.length }, 'Jadwal berhasil dimuat');
}));

// ====================================================================
// GET /api/student/absensi
// ====================================================================
router.get('/absensi', asyncHandler(async (req, res) => {
  const s = needSiswa(req, res); if (!s) return;

  const where = ['a.siswa_id = ?'];
  const params = [s.id];
  if (req.query.bulan) { where.push('MONTH(a.tanggal) = ?'); params.push(toNum(req.query.bulan)); }
  if (req.query.tahun) { where.push('YEAR(a.tanggal) = ?');  params.push(toNum(req.query.tahun)); }

  const sekolah = await queryOne(`SELECT jam_masuk FROM sekolah WHERE id = ?`, [s.sekolah_id]);
  const batas = sekolah?.jam_masuk || '07:00:00';

  const absensi = await query(
    `SELECT a.id, a.tanggal, a.status, a.jam_masuk, a.jam_pulang, a.keterangan,
            a.approval_status, a.approval_note, a.latitude, a.longitude, a.jarak,
            (a.jam_masuk IS NOT NULL AND a.jam_masuk > ?) AS is_terlambat
       FROM absensi a
      WHERE ${where.join(' AND ')}
      ORDER BY a.tanggal DESC
      LIMIT 400`,
    [batas, ...params]
  );
  for (const a of absensi) a.is_terlambat = !!a.is_terlambat;

  const rekapRow = await queryOne(
    `SELECT
       SUM(status = 'hadir' OR status = 'terlambat') AS hadir,
       SUM(status = 'izin')  AS izin,
       SUM(status = 'sakit') AS sakit,
       SUM(status = 'alpha') AS alpha,
       COUNT(*)              AS total
     FROM absensi
     WHERE siswa_id = ?`,
    [s.id]
  );

  const rekap = {
    hadir: toNum(rekapRow?.hadir),
    izin: toNum(rekapRow?.izin),
    sakit: toNum(rekapRow?.sakit),
    alpha: toNum(rekapRow?.alpha),
    total: toNum(rekapRow?.total),
  };

  return ok(res, { absensi, rekap }, 'Absensi berhasil dimuat');
}));

// --------------------------------------------------------------------
// Validasi radius lokasi sekolah
// --------------------------------------------------------------------
async function cekRadius(sekolahId, lat, lon) {
  const sekolah = await queryOne(
    `SELECT latitude, longitude, radius_maksimal FROM sekolah WHERE id = ?`,
    [sekolahId]
  );
  if (!sekolah) return { ok: true, jarak: null };

  const sLat = toNum(sekolah.latitude), sLon = toNum(sekolah.longitude);
  const radius = toNum(sekolah.radius_maksimal, 0);

  // Jika sekolah / perangkat tidak mengirim koordinat, lewati validasi.
  if (!sLat || !sLon || !radius) return { ok: true, jarak: null };
  const uLat = toNum(lat, 0), uLon = toNum(lon, 0);
  if (!uLat || !uLon) return { ok: true, jarak: null };

  const jarak = jarakMeter(uLat, uLon, sLat, sLon);
  return { ok: jarak <= radius, jarak, radius };
}

// ====================================================================
// POST /api/student/absensi/checkin
// ====================================================================
router.post('/absensi/checkin', asyncHandler(async (req, res) => {
  const s = needSiswa(req, res); if (!s) return;
  const b = req.body || {};
  const tanggal = todayStr();

  const existing = await queryOne(
    `SELECT * FROM absensi WHERE siswa_id = ? AND tanggal = ?`,
    [s.id, tanggal]
  );
  if (existing && existing.jam_masuk) {
    return fail(res, 'Anda sudah melakukan check-in hari ini', 409);
  }

  const cek = await cekRadius(s.sekolah_id, b.latitude, b.longitude);
  if (!cek.ok) {
    return fail(res, `Anda berada ${cek.jarak}m dari sekolah. Maksimal ${cek.radius}m.`, 400);
  }

  const jamMasuk = nowTimeStr();
  const sekolah = await queryOne(`SELECT jam_masuk FROM sekolah WHERE id = ?`, [s.sekolah_id]);
  const batas = sekolah?.jam_masuk || '07:00:00';
  const terlambat = jamMasuk > batas;

  // Status tetap dibatasi pada nilai yang dikenal aplikasi
  // (hadir / izin / sakit / alpha). Keterlambatan dilaporkan lewat
  // field `is_terlambat`, bukan sebagai status tersendiri, supaya siswa
  // yang datang terlambat tetap terhitung hadir di seluruh layar.
  const status = (b.status && b.status !== 'hadir') ? b.status : 'hadir';

  const jarakStr = b.jarak != null ? String(b.jarak) : (cek.jarak != null ? String(cek.jarak) : null);

  if (existing) {
    await query(
      `UPDATE absensi
          SET status = ?, jam_masuk = ?, keterangan = ?, latitude = ?, longitude = ?,
              jarak = ?, device = ?, approval_status = ''
        WHERE id = ?`,
      [status, jamMasuk, b.keterangan || null, b.latitude || null, b.longitude || null,
       jarakStr, b.device || 'Flutter Mobile', existing.id]
    );
  } else {
    await query(
      `INSERT INTO absensi
         (id, siswa_id, kelas_id, tanggal, status, jam_masuk, keterangan,
          latitude, longitude, jarak, device, approval_status)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,'')`,
      [uuid(), s.id, s.kelas_id, tanggal, status, jamMasuk, b.keterangan || null,
       b.latitude || null, b.longitude || null, jarakStr, b.device || 'Flutter Mobile']
    );
  }

  const row = await queryOne(
    `SELECT id, tanggal, status, jam_masuk, jam_pulang, keterangan, approval_status
       FROM absensi WHERE siswa_id = ? AND tanggal = ?`,
    [s.id, tanggal]
  );

  return ok(res, { ...row, is_terlambat: terlambat },
    terlambat
      ? `Check-in berhasil pada ${jamMasuk.slice(0, 5)} (terlambat dari ${batas.slice(0, 5)})`
      : `Check-in berhasil pada ${jamMasuk.slice(0, 5)}`);
}));

// ====================================================================
// POST /api/student/absensi/checkout
// ====================================================================
router.post('/absensi/checkout', asyncHandler(async (req, res) => {
  const s = needSiswa(req, res); if (!s) return;
  const tanggal = todayStr();

  const existing = await queryOne(
    `SELECT * FROM absensi WHERE siswa_id = ? AND tanggal = ?`,
    [s.id, tanggal]
  );
  if (!existing || !existing.jam_masuk) {
    return fail(res, 'Anda belum melakukan check-in hari ini', 400);
  }
  if (existing.jam_pulang) {
    return fail(res, 'Anda sudah melakukan check-out hari ini', 409);
  }

  const jamPulang = nowTimeStr();
  await query(`UPDATE absensi SET jam_pulang = ? WHERE id = ?`, [jamPulang, existing.id]);

  const row = await queryOne(
    `SELECT id, tanggal, status, jam_masuk, jam_pulang, keterangan, approval_status
       FROM absensi WHERE id = ?`,
    [existing.id]
  );

  return ok(res, row, `Check-out berhasil pada ${jamPulang.slice(0, 5)}`);
}));

// ====================================================================
// POST /api/student/absensi/request  (izin/sakit -> approval orang tua)
// ====================================================================
router.post('/absensi/request', asyncHandler(async (req, res) => {
  const s = needSiswa(req, res); if (!s) return;
  const b = req.body || {};

  const status = (b.status || '').toLowerCase();
  if (!['izin', 'sakit'].includes(status)) {
    return fail(res, 'Status permohonan harus izin atau sakit', 400);
  }
  if (!b.keterangan) return fail(res, 'Keterangan wajib diisi', 400);

  const tanggal = b.tanggal || todayStr();

  const existing = await queryOne(
    `SELECT * FROM absensi WHERE siswa_id = ? AND tanggal = ?`,
    [s.id, tanggal]
  );

  if (existing) {
    if (existing.jam_masuk) {
      return fail(res, 'Anda sudah tercatat hadir pada tanggal tersebut', 409);
    }
    if (existing.approval_status === 'pending') {
      return fail(res, 'Sudah ada permohonan yang menunggu persetujuan untuk tanggal ini', 409);
    }
    await query(
      `UPDATE absensi
          SET status = ?, keterangan = ?, approval_status = 'pending',
              approval_note = NULL, approved_by = NULL, approved_at = NULL
        WHERE id = ?`,
      [status, b.keterangan, existing.id]
    );
  } else {
    await query(
      `INSERT INTO absensi (id, siswa_id, kelas_id, tanggal, status, keterangan, approval_status)
       VALUES (?,?,?,?,?,?, 'pending')`,
      [uuid(), s.id, s.kelas_id, tanggal, status, b.keterangan]
    );
  }

  const row = await queryOne(
    `SELECT id, tanggal, status, keterangan, approval_status
       FROM absensi WHERE siswa_id = ? AND tanggal = ?`,
    [s.id, tanggal]
  );

  return ok(res, row, 'Permohonan terkirim. Menunggu persetujuan orang tua.');
}));

// ====================================================================
// GET /api/student/nilai?semester=&tahun_ajaran=
// data berupa LIST (sesuai pemakaian di NilaiScreen)
// ====================================================================
router.get('/nilai', asyncHandler(async (req, res) => {
  const s = needSiswa(req, res); if (!s) return;

  const where = ['n.siswa_id = ?'];
  const params = [s.id];
  if (req.query.semester) { where.push('n.semester = ?'); params.push(toNum(req.query.semester, 1)); }
  if (req.query.tahun_ajaran) { where.push('n.tahun_ajaran = ?'); params.push(req.query.tahun_ajaran); }

  const rows = await query(
    `SELECT n.id, n.siswa_id, n.mapel_id, n.semester, n.tahun_ajaran,
            n.nilai_tugas, n.nilai_uts, n.nilai_uas, n.nilai_akhir, n.predikat,
            m.nama_mapel, m.kode_mapel, g.nama AS guru_nama, n.updated_at
       FROM nilai n
       JOIN mapel m ON m.id = n.mapel_id
       LEFT JOIN guru g ON g.id = n.guru_id
      WHERE ${where.join(' AND ')}
      ORDER BY m.nama_mapel`,
    params
  );

  return ok(res, rows, 'Nilai berhasil dimuat');
}));

// ====================================================================
// GET /api/student/tugas
// ====================================================================
async function listTugasSiswa(siswa) {
  if (!siswa.kelas_id) return [];
  return query(
    `SELECT t.id, t.judul, t.deskripsi, t.deadline, t.status, t.created_at,
            t.mapel_id, m.nama_mapel, m.kode_mapel,
            t.guru_id, g.nama AS guru_nama,
            t.kelas_id, k.nama_kelas,
            sub.id AS submission_id, sub.submitted_at, sub.nilai, sub.feedback,
            sub.file_nama, sub.file_url, sub.catatan
       FROM tugas t
       LEFT JOIN mapel m ON m.id = t.mapel_id
       LEFT JOIN guru  g ON g.id = t.guru_id
       LEFT JOIN kelas k ON k.id = t.kelas_id
       LEFT JOIN tugas_submission sub ON sub.tugas_id = t.id AND sub.siswa_id = ?
      WHERE t.kelas_id = ? AND t.status <> 'draft'
      ORDER BY t.deadline IS NULL, t.deadline DESC, t.created_at DESC`,
    [siswa.id, siswa.kelas_id]
  );
}

router.get('/tugas', asyncHandler(async (req, res) => {
  const s = needSiswa(req, res); if (!s) return;
  const rows = await listTugasSiswa(s);

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

// ====================================================================
// GET /api/student/tugas/:tugasId/submission
// ====================================================================
router.get('/tugas/:tugasId/submission', asyncHandler(async (req, res) => {
  const s = needSiswa(req, res); if (!s) return;

  const row = await queryOne(
    `SELECT id, tugas_id, siswa_id, file_nama, file_url, catatan,
            submitted_at, nilai, feedback, graded_at
       FROM tugas_submission
      WHERE tugas_id = ? AND siswa_id = ? LIMIT 1`,
    [req.params.tugasId, s.id]
  );

  if (!row) return ok(res, null, 'Belum ada pengumpulan');
  return ok(res, row, 'Pengumpulan ditemukan');
}));

// ====================================================================
// POST /api/student/tugas/:tugasId/submit  (multipart: file, catatan)
// ====================================================================
const submitTugas = asyncHandler(async (req, res) => {
  const s = needSiswa(req, res); if (!s) return;

  const tugas = await queryOne(`SELECT * FROM tugas WHERE id = ? LIMIT 1`, [req.params.tugasId]);
  if (!tugas) return fail(res, 'Tugas tidak ditemukan', 404);
  if (tugas.kelas_id !== s.kelas_id) return fail(res, 'Tugas ini bukan untuk kelas Anda', 403);

  const file = req.file;
  const catatan = (req.body && req.body.catatan) || null;
  if (!file && !catatan) return fail(res, 'File atau catatan wajib diisi', 400);

  const fileNama = file ? (file.originalname || file.filename) : null;
  const fileUrl = file ? `${config.baseUrl}/uploads/tugas/${file.filename}` : null;
  const submittedAt = nowDateTimeStr();

  const existing = await queryOne(
    `SELECT id FROM tugas_submission WHERE tugas_id = ? AND siswa_id = ?`,
    [tugas.id, s.id]
  );

  if (existing) {
    await query(
      `UPDATE tugas_submission
          SET file_nama = COALESCE(?, file_nama),
              file_url  = COALESCE(?, file_url),
              catatan   = ?,
              submitted_at = ?,
              nilai = NULL, feedback = NULL, graded_at = NULL, graded_by = NULL
        WHERE id = ?`,
      [fileNama, fileUrl, catatan, submittedAt, existing.id]
    );
  } else {
    await query(
      `INSERT INTO tugas_submission
         (id, tugas_id, siswa_id, file_nama, file_url, catatan, submitted_at)
       VALUES (?,?,?,?,?,?,?)`,
      [uuid(), tugas.id, s.id, fileNama, fileUrl, catatan, submittedAt]
    );
  }

  const row = await queryOne(
    `SELECT id, tugas_id, siswa_id, file_nama, file_url, catatan, submitted_at, nilai, feedback
       FROM tugas_submission WHERE tugas_id = ? AND siswa_id = ?`,
    [tugas.id, s.id]
  );

  const telat = tugas.deadline && new Date(submittedAt) > new Date(tugas.deadline);
  return ok(res, row, telat ? 'Tugas terkirim (melewati deadline)' : 'Tugas berhasil dikumpulkan');
});

router.post('/tugas/:tugasId/submit', uploadTugas.single('file'), submitTugas);

module.exports = router;
module.exports.listTugasSiswa = listTugasSiswa;
module.exports.submitTugas = submitTugas;
