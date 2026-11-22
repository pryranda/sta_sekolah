'use strict';

const express = require('express');
const { query, queryOne } = require('../db');
const {
  ok, fail, asyncHandler, uuid, nowDateTimeStr, toNum, toIntOrNull,
} = require('../utils/helpers');
const { authenticate, requireRole } = require('../middleware/auth');

const router = express.Router();

// Semua endpoint butuh login. Pembatasan role dilakukan per-route karena
// beberapa endpoint di bawah /parent juga dipakai oleh dashboard siswa.
router.use(authenticate);

const onlyOrtu = requireRole('orang_tua', 'admin');

async function resolveOrtu(req, res) {
  if (req.ortu) return req.ortu;
  if (req.user.role === 'admin' && req.query.orang_tua_id) {
    const o = await queryOne(`SELECT * FROM orang_tua WHERE id = ?`, [req.query.orang_tua_id]);
    if (o) return o;
  }
  fail(res, 'Data orang tua tidak tertaut dengan akun ini', 404);
  return null;
}

/** Daftar id anak milik orang tua tersebut. */
async function anakIds(ortuId) {
  const rows = await query(
    `SELECT siswa_id FROM siswa_orang_tua WHERE orang_tua_id = ?`, [ortuId]
  );
  return rows.map((r) => r.siswa_id);
}

async function listAnak(ortuId) {
  return query(
    `SELECT s.id, s.nama, s.nis, s.nisn, s.kelas_id, s.foto_url, s.jenis_kelamin,
            k.nama_kelas, k.nama_kelas AS kelas, k.tingkat, k.tahun_ajaran
       FROM siswa_orang_tua so
       JOIN siswa s ON s.id = so.siswa_id
       LEFT JOIN kelas k ON k.id = s.kelas_id
      WHERE so.orang_tua_id = ?
      ORDER BY s.nama`,
    [ortuId]
  );
}

/**
 * Izinkan akses data seorang siswa bila:
 *  - pemanggil adalah orang tua dari siswa tersebut, ATAU
 *  - pemanggil adalah siswa itu sendiri (dashboard siswa memakai route /parent/anak/:id/spp),
 *  - atau admin.
 * Mengembalikan true bila diizinkan; jika tidak, response error sudah dikirim.
 */
async function canAccessAnak(req, res, anakId) {
  if (req.user.role === 'admin') return true;

  if (req.user.role === 'siswa') {
    if (req.siswa && req.siswa.id === anakId) return true;
    fail(res, 'Anda hanya dapat mengakses data sendiri', 403);
    return false;
  }

  if (req.user.role === 'orang_tua') {
    const o = req.ortu;
    if (!o) { fail(res, 'Data orang tua tidak tertaut dengan akun ini', 404); return false; }
    const row = await queryOne(
      `SELECT 1 AS ok FROM siswa_orang_tua WHERE orang_tua_id = ? AND siswa_id = ?`,
      [o.id, anakId]
    );
    if (row) return true;
    fail(res, 'Siswa tersebut bukan anak Anda', 403);
    return false;
  }

  fail(res, 'Akses ditolak', 403);
  return false;
}

/** Pastikan anakId adalah anak dari ortu (dipakai modul lain). */
async function assertAnak(ortuId, anakId) {
  const row = await queryOne(
    `SELECT 1 AS ok FROM siswa_orang_tua WHERE orang_tua_id = ? AND siswa_id = ?`,
    [ortuId, anakId]
  );
  return !!row;
}

function mapOrtuProfile(o) {
  return {
    id: o.id,
    nama: o.nama_ibu || o.nama_ayah || o.nama_wali || 'Orang Tua',
    nama_ibu: o.nama_ibu || '',
    pekerjaan_ibu: o.pekerjaan_ibu || '',
    hp_ibu: o.hp_ibu || '',
    tahun_lahir_ibu: o.tahun_lahir_ibu,
    jenjang_pendidikan_ibu: o.jenjang_pendidikan_ibu,
    penghasilan_ibu: o.penghasilan_ibu,
    nik_ibu: o.nik_ibu || '',

    nama_ayah: o.nama_ayah || '',
    pekerjaan_ayah: o.pekerjaan_ayah || '',
    hp_ayah: o.hp_ayah || '',
    tahun_lahir_ayah: o.tahun_lahir_ayah,
    jenjang_pendidikan_ayah: o.jenjang_pendidikan_ayah,
    penghasilan_ayah: o.penghasilan_ayah,
    nik_ayah: o.nik_ayah || '',

    nama_wali: o.nama_wali || '',
    pekerjaan_wali: o.pekerjaan_wali || '',
    tahun_lahir_wali: o.tahun_lahir_wali,
    jenjang_pendidikan_wali: o.jenjang_pendidikan_wali,
    penghasilan_wali: o.penghasilan_wali,

    alamat: o.alamat || '',
    email: o.email || '',
  };
}

// ====================================================================
// PENGUMUMAN — dipakai oleh orang tua DAN dashboard siswa
// ====================================================================
router.get('/pengumuman', asyncHandler(async (req, res) => {
  const params = [req.user.id, req.user.sekolah_id];
  const where = ['p.sekolah_id = ?'];

  if (req.query.kategori) { where.push('p.kategori = ?'); params.push(req.query.kategori); }
  if (req.query.prioritas) { where.push('p.prioritas = ?'); params.push(req.query.prioritas); }

  const rows = await query(
    `SELECT p.id, p.judul, p.isi, p.kategori, p.prioritas, p.target_role, p.created_at,
            (pr.id IS NOT NULL) AS is_read
       FROM pengumuman p
       LEFT JOIN pengumuman_read pr ON pr.pengumuman_id = p.id AND pr.user_id = ?
      WHERE ${where.join(' AND ')}
      ORDER BY FIELD(p.prioritas,'tinggi','normal','rendah'), p.created_at DESC
      LIMIT 100`,
    params
  );

  const pengumuman = rows.map((r) => ({ ...r, is_read: !!r.is_read }));
  const belumDibaca = pengumuman.filter((p) => !p.is_read).length;

  return ok(res, {
    pengumuman,
    stats: {
      total: pengumuman.length,
      belum_dibaca: belumDibaca,
      sudah_dibaca: pengumuman.length - belumDibaca,
    },
  }, 'Pengumuman berhasil dimuat');
}));

router.post('/pengumuman/:pengumumanId/read', asyncHandler(async (req, res) => {
  const peng = await queryOne(`SELECT id FROM pengumuman WHERE id = ?`, [req.params.pengumumanId]);
  if (!peng) return fail(res, 'Pengumuman tidak ditemukan', 404);

  await query(
    `INSERT INTO pengumuman_read (id, pengumuman_id, user_id)
     VALUES (?,?,?)
     ON DUPLICATE KEY UPDATE read_at = CURRENT_TIMESTAMP`,
    [uuid(), peng.id, req.user.id]
  );

  return ok(res, { pengumuman_id: peng.id, is_read: true }, 'Pengumuman ditandai sudah dibaca');
}));

// ====================================================================
// GET /api/parent/profile  &  /profile/detail
// ====================================================================
router.get(['/profile', '/profile/detail'], onlyOrtu, asyncHandler(async (req, res) => {
  const o = await resolveOrtu(req, res); if (!o) return;
  return ok(res, mapOrtuProfile(o), 'Profil orang tua berhasil dimuat');
}));

// ====================================================================
// PUT /api/parent/profile
// ====================================================================
router.put('/profile', onlyOrtu, asyncHandler(async (req, res) => {
  const o = await resolveOrtu(req, res); if (!o) return;
  const b = req.body || {};

  const textFields = [
    'nama_ibu', 'pekerjaan_ibu', 'hp_ibu', 'jenjang_pendidikan_ibu', 'penghasilan_ibu', 'nik_ibu',
    'nama_ayah', 'pekerjaan_ayah', 'hp_ayah', 'jenjang_pendidikan_ayah', 'penghasilan_ayah', 'nik_ayah',
    'nama_wali', 'pekerjaan_wali', 'jenjang_pendidikan_wali', 'penghasilan_wali',
    'alamat', 'email',
  ];
  const intFields = ['tahun_lahir_ibu', 'tahun_lahir_ayah', 'tahun_lahir_wali'];

  const sets = [];
  const vals = [];
  for (const f of textFields) {
    if (b[f] !== undefined) { sets.push(`${f} = ?`); vals.push(b[f] === '' ? null : b[f]); }
  }
  for (const f of intFields) {
    if (b[f] !== undefined) { sets.push(`${f} = ?`); vals.push(toIntOrNull(b[f])); }
  }

  if (!sets.length) return fail(res, 'Tidak ada data yang diubah', 400);

  vals.push(o.id);
  await query(`UPDATE orang_tua SET ${sets.join(', ')} WHERE id = ?`, vals);

  // sinkronkan email & nama tampilan ke tabel users
  if ((b.email !== undefined || b.nama_ibu !== undefined) && o.user_id) {
    await query(
      `UPDATE users SET email = COALESCE(?, email), nama = COALESCE(?, nama) WHERE id = ?`,
      [b.email || null, b.nama_ibu || null, o.user_id]
    );
  }

  const updated = await queryOne(`SELECT * FROM orang_tua WHERE id = ?`, [o.id]);
  return ok(res, mapOrtuProfile(updated), 'Profil berhasil disimpan');
}));

// ====================================================================
// GET /api/parent/anak
// ====================================================================
router.get('/anak', onlyOrtu, asyncHandler(async (req, res) => {
  const o = await resolveOrtu(req, res); if (!o) return;
  const anak = await listAnak(o.id);
  return ok(res, { anak, total: anak.length }, 'Data anak berhasil dimuat');
}));

// ====================================================================
// GET /api/parent/dashboard
// ====================================================================
router.get('/dashboard', onlyOrtu, asyncHandler(async (req, res) => {
  const o = await resolveOrtu(req, res); if (!o) return;
  const anak = await listAnak(o.id);

  const dashboard = [];
  for (const a of anak) {
    const abs = await queryOne(
      `SELECT
         SUM(status = 'hadir' OR status = 'terlambat') AS hadir,
         SUM(status = 'izin')  AS izin,
         SUM(status = 'sakit') AS sakit,
         SUM(status = 'alpha') AS alpha,
         COUNT(*) AS total
       FROM absensi WHERE siswa_id = ?`,
      [a.id]
    );
    const nil = await queryOne(
      `SELECT AVG(nilai_akhir) AS rata_rata, COUNT(*) AS total_mapel
         FROM nilai WHERE siswa_id = ?`,
      [a.id]
    );
    const tunggakan = await queryOne(
      `SELECT COALESCE(SUM(nominal_akhir),0) AS total
         FROM tagihan WHERE siswa_id = ? AND status = 'belum_bayar'`,
      [a.id]
    );
    const tugasAktif = a.kelas_id ? await queryOne(
      `SELECT COUNT(*) AS total FROM tugas t
        WHERE t.kelas_id = ? AND t.status = 'aktif'
          AND t.id NOT IN (SELECT tugas_id FROM tugas_submission WHERE siswa_id = ?)`,
      [a.kelas_id, a.id]
    ) : { total: 0 };

    dashboard.push({
      anak: {
        id: a.id, nama: a.nama, nis: a.nis,
        kelas: a.nama_kelas || '-', nama_kelas: a.nama_kelas || '-',
        kelas_id: a.kelas_id, foto_url: a.foto_url,
      },
      absensi: {
        hadir: toNum(abs?.hadir), izin: toNum(abs?.izin),
        sakit: toNum(abs?.sakit), alpha: toNum(abs?.alpha), total: toNum(abs?.total),
      },
      nilai: {
        rata_rata: nil?.rata_rata != null ? Math.round(toNum(nil.rata_rata) * 100) / 100 : 0,
        total_mapel: toNum(nil?.total_mapel),
      },
      spp: { tunggakan: toNum(tunggakan?.total) },
      tugas: { belum_dikerjakan: toNum(tugasAktif?.total) },
    });
  }

  return ok(res, { jumlah_anak: anak.length, dashboard }, 'Dashboard berhasil dimuat');
}));

// ====================================================================
// GET /api/parent/anak/:anakId/jadwal
// ====================================================================
router.get('/anak/:anakId/jadwal', asyncHandler(async (req, res) => {
  if (!(await canAccessAnak(req, res, req.params.anakId))) return;

  const siswa = await queryOne(`SELECT kelas_id FROM siswa WHERE id = ?`, [req.params.anakId]);
  if (!siswa || !siswa.kelas_id) return ok(res, { jadwal: [] }, 'Anak belum memiliki kelas');

  const rows = await query(
    `SELECT j.id, j.hari, j.jam_mulai, j.jam_selesai, j.ruangan, j.keterangan,
            m.nama_mapel, m.kode_mapel, g.nama AS guru_nama, k.nama_kelas
       FROM jadwal j
       LEFT JOIN mapel m ON m.id = j.mapel_id
       LEFT JOIN guru  g ON g.id = j.guru_id
       LEFT JOIN kelas k ON k.id = j.kelas_id
      WHERE j.kelas_id = ?
      ORDER BY FIELD(j.hari,'Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'), j.jam_mulai`,
    [siswa.kelas_id]
  );

  return ok(res, { jadwal: rows, total: rows.length }, 'Jadwal anak berhasil dimuat');
}));

// ====================================================================
// GET /api/parent/anak/:anakId/absensi?bulan=&tahun=
// ====================================================================
router.get('/anak/:anakId/absensi', asyncHandler(async (req, res) => {
  if (!(await canAccessAnak(req, res, req.params.anakId))) return;

  const where = ['a.siswa_id = ?'];
  const params = [req.params.anakId];
  if (req.query.bulan) { where.push('MONTH(a.tanggal) = ?'); params.push(toNum(req.query.bulan)); }
  if (req.query.tahun) { where.push('YEAR(a.tanggal) = ?');  params.push(toNum(req.query.tahun)); }

  const absensi = await query(
    `SELECT a.id, a.tanggal, a.status, a.jam_masuk, a.jam_pulang, a.keterangan,
            a.approval_status, a.approval_note
       FROM absensi a
      WHERE ${where.join(' AND ')}
      ORDER BY a.tanggal DESC LIMIT 400`,
    params
  );

  const rekapRow = await queryOne(
    `SELECT
       SUM(status = 'hadir' OR status = 'terlambat') AS hadir,
       SUM(status = 'izin')  AS izin,
       SUM(status = 'sakit') AS sakit,
       SUM(status = 'alpha') AS alpha,
       COUNT(*) AS total
     FROM absensi a WHERE ${where.join(' AND ')}`,
    params
  );

  return ok(res, {
    absensi,
    rekap: {
      hadir: toNum(rekapRow?.hadir), izin: toNum(rekapRow?.izin),
      sakit: toNum(rekapRow?.sakit), alpha: toNum(rekapRow?.alpha),
      total: toNum(rekapRow?.total),
    },
  }, 'Absensi anak berhasil dimuat');
}));

// ====================================================================
// GET /api/parent/anak/:anakId/nilai?page=&limit=&semester=&tahun_ajaran=
// ====================================================================
router.get('/anak/:anakId/nilai', asyncHandler(async (req, res) => {
  if (!(await canAccessAnak(req, res, req.params.anakId))) return;

  const page = Math.max(1, parseInt(toNum(req.query.page, 1), 10));
  const limit = Math.max(1, Math.min(parseInt(toNum(req.query.limit, 100), 10), 500));
  const offset = (page - 1) * limit;

  const where = ['n.siswa_id = ?'];
  const params = [req.params.anakId];
  if (req.query.semester) { where.push('n.semester = ?'); params.push(toNum(req.query.semester, 1)); }
  if (req.query.tahun_ajaran) { where.push('n.tahun_ajaran = ?'); params.push(req.query.tahun_ajaran); }

  const totalRow = await queryOne(
    `SELECT COUNT(*) AS total FROM nilai n WHERE ${where.join(' AND ')}`, params
  );
  const total = toNum(totalRow?.total);

  const nilai = await query(
    `SELECT n.id, n.mapel_id, n.semester, n.tahun_ajaran,
            n.nilai_tugas, n.nilai_uts, n.nilai_uas, n.nilai_akhir, n.predikat,
            m.nama_mapel, m.kode_mapel, g.nama AS guru_nama
       FROM nilai n
       JOIN mapel m ON m.id = n.mapel_id
       LEFT JOIN guru g ON g.id = n.guru_id
      WHERE ${where.join(' AND ')}
      ORDER BY n.semester DESC, m.nama_mapel
      LIMIT ${limit} OFFSET ${offset}`,
    params
  );

  return ok(res, {
    nilai,
    pagination: {
      page, limit, total,
      total_pages: Math.max(1, Math.ceil(total / limit)),
      has_next: page * limit < total,
    },
  }, 'Nilai anak berhasil dimuat');
}));

// ====================================================================
// GET /api/parent/anak/:anakId/spp?tahun=
// (juga dipakai dashboard siswa untuk dirinya sendiri)
// ====================================================================
router.get('/anak/:anakId/spp', asyncHandler(async (req, res) => {
  if (!(await canAccessAnak(req, res, req.params.anakId))) return;

  const where = ['t.siswa_id = ?'];
  const params = [req.params.anakId];
  if (req.query.tahun) { where.push('t.periode_tahun = ?'); params.push(toNum(req.query.tahun)); }

  const tagihan = await query(
    `SELECT t.id, t.periode_bulan, t.periode_tahun, t.nominal, t.diskon, t.nominal_akhir,
            t.tanggal_jatuh_tempo, t.status,
            jp.nama AS jenis_pembayaran, jp.id AS jenis_pembayaran_id,
            COALESCE((SELECT SUM(p.jumlah_bayar) FROM pembayaran p
                       WHERE p.tagihan_id = t.id AND p.status = 'approved'), 0) AS terbayar
       FROM tagihan t
       JOIN jenis_pembayaran jp ON jp.id = t.jenis_pembayaran_id
      WHERE ${where.join(' AND ')}
      ORDER BY t.periode_tahun, t.periode_bulan`,
    params
  );

  const totalTagihan = tagihan.reduce((s, t) => s + toNum(t.nominal_akhir), 0);
  const totalBayar = tagihan.reduce((s, t) => s + toNum(t.terbayar), 0);

  return ok(res, {
    tagihan,
    ringkasan: {
      total_tagihan: totalTagihan,
      total_bayar: totalBayar,
      tunggakan: Math.max(0, totalTagihan - totalBayar),
      jumlah_tagihan: tagihan.length,
      lunas: tagihan.filter((t) => t.status === 'lunas').length,
      belum_bayar: tagihan.filter((t) => t.status === 'belum_bayar').length,
      menunggu_verifikasi: tagihan.filter((t) => t.status === 'menunggu_verifikasi').length,
    },
  }, 'Data SPP anak berhasil dimuat');
}));

// ====================================================================
// GET /api/parent/approval/pending   (data = LIST, plus field `count`)
// ====================================================================
router.get('/approval/pending', onlyOrtu, asyncHandler(async (req, res) => {
  const o = await resolveOrtu(req, res); if (!o) return;
  const ids = await anakIds(o.id);
  if (!ids.length) return ok(res, [], 'Tidak ada permohonan', { count: 0 });

  const rows = await query(
    `SELECT a.id, a.siswa_id, a.tanggal, a.status, a.keterangan, a.approval_status,
            a.created_at, s.nama AS nama_siswa, s.nis, k.nama_kelas
       FROM absensi a
       JOIN siswa s ON s.id = a.siswa_id
       LEFT JOIN kelas k ON k.id = s.kelas_id
      WHERE a.siswa_id IN (${ids.map(() => '?').join(',')})
        AND a.approval_status = 'pending'
      ORDER BY a.tanggal DESC`,
    ids
  );

  return ok(res, rows, 'Daftar permohonan berhasil dimuat', { count: rows.length });
}));

// ====================================================================
// POST /api/parent/approval/:absensiId   { action: approve|reject, note }
// ====================================================================
router.post('/approval/:absensiId', onlyOrtu, asyncHandler(async (req, res) => {
  const o = await resolveOrtu(req, res); if (!o) return;
  const action = (req.body?.action || '').toLowerCase();

  if (!['approve', 'approved', 'reject', 'rejected'].includes(action)) {
    return fail(res, "Action harus 'approve' atau 'reject'", 400);
  }
  const isApprove = action.startsWith('approve');

  const absen = await queryOne(
    `SELECT a.*, s.nama AS nama_siswa FROM absensi a
       JOIN siswa s ON s.id = a.siswa_id
      WHERE a.id = ? LIMIT 1`,
    [req.params.absensiId]
  );
  if (!absen) return fail(res, 'Data permohonan tidak ditemukan', 404);
  if (req.user.role !== 'admin' && !(await assertAnak(o.id, absen.siswa_id))) {
    return fail(res, 'Siswa tersebut bukan anak Anda', 403);
  }
  if (absen.approval_status !== 'pending') {
    return fail(res, 'Permohonan ini sudah diproses', 409);
  }

  // Ditolak -> dicatat alpha, karena ketidakhadiran tanpa izin yang disetujui.
  const newStatus = isApprove ? absen.status : 'alpha';

  await query(
    `UPDATE absensi
        SET approval_status = ?, status = ?, approval_note = ?, approved_by = ?, approved_at = ?
      WHERE id = ?`,
    [isApprove ? 'approved' : 'rejected', newStatus, req.body?.note || null,
     req.user.id, nowDateTimeStr(), absen.id]
  );

  const row = await queryOne(
    `SELECT a.id, a.tanggal, a.status, a.keterangan, a.approval_status, a.approval_note,
            s.nama AS nama_siswa
       FROM absensi a JOIN siswa s ON s.id = a.siswa_id WHERE a.id = ?`,
    [absen.id]
  );

  return ok(res, row, isApprove
    ? `Permohonan ${absen.status} untuk ${absen.nama_siswa} disetujui`
    : `Permohonan ${absen.nama_siswa} ditolak`);
}));

module.exports = router;
module.exports.listAnak = listAnak;
module.exports.anakIds = anakIds;
module.exports.assertAnak = assertAnak;
