'use strict';

const express = require('express');
const config = require('../config');
const { query, queryOne, withTransaction } = require('../db');
const {
  ok, fail, asyncHandler, uuid, nowDateTimeStr, todayStr, toNum,
} = require('../utils/helpers');
const { authenticate, requireRole } = require('../middleware/auth');
const { uploadBukti } = require('../middleware/upload');

const router = express.Router();
router.use(authenticate);

const onlyOrtu = requireRole('orang_tua', 'admin');
const onlyAdmin = requireRole('admin');

// ====================================================================
// GET /api/spp/parent/tagihan
// ====================================================================
router.get('/parent/tagihan', onlyOrtu, asyncHandler(async (req, res) => {
  let anak;
  if (req.user.role === 'admin') {
    anak = await query(
      `SELECT s.id, s.nama, s.nis, s.kelas_id, k.nama_kelas
         FROM siswa s LEFT JOIN kelas k ON k.id = s.kelas_id
        WHERE s.sekolah_id = ? AND s.status = 'aktif' ORDER BY s.nama LIMIT 200`,
      [req.user.sekolah_id]
    );
  } else {
    if (!req.ortu) return fail(res, 'Data orang tua tidak tertaut dengan akun ini', 404);
    anak = await query(
      `SELECT s.id, s.nama, s.nis, s.kelas_id, k.nama_kelas
         FROM siswa_orang_tua so
         JOIN siswa s ON s.id = so.siswa_id
         LEFT JOIN kelas k ON k.id = s.kelas_id
        WHERE so.orang_tua_id = ? ORDER BY s.nama`,
      [req.ortu.id]
    );
  }

  if (!anak.length) {
    return ok(res, { anak: [], tagihan: [], stats_per_anak: {} }, 'Belum ada data anak');
  }

  const ids = anak.map((a) => a.id);
  const ph = ids.map(() => '?').join(',');

  const rows = await query(
    `SELECT t.id, t.siswa_id, t.jenis_pembayaran_id, t.periode_bulan, t.periode_tahun,
            t.nominal, t.diskon, t.nominal_akhir, t.tanggal_jatuh_tempo, t.status,
            jp.nama AS jenis_pembayaran, jp.kode AS kode_pembayaran,
            s.nama AS nama_siswa, s.nis, k.nama_kelas,
            COALESCE((SELECT SUM(p.jumlah_bayar) FROM pembayaran p
                       WHERE p.tagihan_id = t.id AND p.status = 'approved'), 0) AS terbayar
       FROM tagihan t
       JOIN jenis_pembayaran jp ON jp.id = t.jenis_pembayaran_id
       JOIN siswa s ON s.id = t.siswa_id
       LEFT JOIN kelas k ON k.id = s.kelas_id
      WHERE t.siswa_id IN (${ph}) AND t.status <> 'batal'
      ORDER BY t.periode_tahun DESC, t.periode_bulan DESC, jp.nama`,
    ids
  );

  const tagihan = rows.map((t) => ({
    ...t,
    // Satu tagihan = satu jenis pembayaran; `items` dipakai app untuk rincian.
    items: [{
      nama: t.jenis_pembayaran,
      nominal: toNum(t.nominal_akhir),
      jenis_pembayaran_id: t.jenis_pembayaran_id,
    }],
  }));

  const stats_per_anak = {};
  for (const a of anak) {
    const milik = tagihan.filter((t) => t.siswa_id === a.id);
    const totalNominal = milik.reduce((s, t) => s + toNum(t.nominal_akhir), 0);
    const totalTerbayar = milik.reduce((s, t) => s + toNum(t.terbayar), 0);
    stats_per_anak[a.id] = {
      total_nominal: totalNominal,
      total_terbayar: totalTerbayar,
      tunggakan: Math.max(0, totalNominal - totalTerbayar),
      jumlah_tagihan: milik.length,
      lunas: milik.filter((t) => t.status === 'lunas').length,
      belum_bayar: milik.filter((t) => t.status === 'belum_bayar').length,
      menunggu_verifikasi: milik.filter((t) => t.status === 'menunggu_verifikasi').length,
    };
  }

  return ok(res, { anak, tagihan, stats_per_anak }, 'Data tagihan berhasil dimuat');
}));

// ====================================================================
// POST /api/spp/upload-bukti   (multipart field: bukti / file)
// ====================================================================
router.post('/upload-bukti',
  uploadBukti.fields([{ name: 'bukti', maxCount: 1 }, { name: 'file', maxCount: 1 }]),
  asyncHandler(async (req, res) => {
    const f = (req.files?.bukti?.[0]) || (req.files?.file?.[0]);
    if (!f) return fail(res, 'File bukti tidak ditemukan pada request', 400);

    const url = `${config.baseUrl}/uploads/bukti/${f.filename}`;
    return ok(res, {
      url,
      path: `/uploads/bukti/${f.filename}`,
      filename: f.filename,
      original_name: f.originalname,
      size: f.size,
    }, 'Bukti berhasil diunggah');
  })
);

// ====================================================================
// POST /api/spp/parent/pembayaran
// ====================================================================
router.post('/parent/pembayaran', onlyOrtu, asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.tagihan_id) return fail(res, 'tagihan_id wajib diisi', 400);

  const tagihan = await queryOne(
    `SELECT t.*, s.nama AS nama_siswa FROM tagihan t
       JOIN siswa s ON s.id = t.siswa_id WHERE t.id = ? LIMIT 1`,
    [b.tagihan_id]
  );
  if (!tagihan) return fail(res, 'Tagihan tidak ditemukan', 404);

  if (req.user.role !== 'admin') {
    if (!req.ortu) return fail(res, 'Data orang tua tidak tertaut dengan akun ini', 404);
    const rel = await queryOne(
      `SELECT 1 AS ok FROM siswa_orang_tua WHERE orang_tua_id = ? AND siswa_id = ?`,
      [req.ortu.id, tagihan.siswa_id]
    );
    if (!rel) return fail(res, 'Tagihan ini bukan milik anak Anda', 403);
  }

  if (tagihan.status === 'lunas') return fail(res, 'Tagihan ini sudah lunas', 409);

  const pending = await queryOne(
    `SELECT id FROM pembayaran WHERE tagihan_id = ? AND status = 'pending' LIMIT 1`,
    [tagihan.id]
  );
  if (pending) return fail(res, 'Sudah ada pembayaran yang menunggu verifikasi untuk tagihan ini', 409);

  const jumlah = toNum(b.jumlah_bayar, toNum(tagihan.nominal_akhir));
  if (jumlah <= 0) return fail(res, 'Jumlah bayar tidak valid', 400);

  const id = uuid();
  await withTransaction(async (conn) => {
    await conn.execute(
      `INSERT INTO pembayaran
         (id, sekolah_id, tagihan_id, siswa_id, dibayar_oleh, jumlah_bayar, metode_bayar,
          nomor_referensi, catatan, bukti_transfer_url, tanggal_bayar, status)
       VALUES (?,?,?,?,?,?,?,?,?,?,?, 'pending')`,
      [id, tagihan.sekolah_id, tagihan.id, tagihan.siswa_id, req.user.id, jumlah,
       b.metode_bayar || 'transfer_bank', b.nomor_referensi || null, b.catatan || null,
       b.bukti_transfer_url || null, nowDateTimeStr()]
    );
    await conn.execute(
      `UPDATE tagihan SET status = 'menunggu_verifikasi' WHERE id = ?`, [tagihan.id]
    );
  });

  const row = await queryOne(`SELECT * FROM pembayaran WHERE id = ?`, [id]);
  return ok(res, row, 'Bukti pembayaran terkirim. Menunggu verifikasi admin.');
}));

// ====================================================================
// GET /api/spp/parent/pembayaran  (riwayat)
// ====================================================================
router.get('/parent/pembayaran', onlyOrtu, asyncHandler(async (req, res) => {
  if (req.user.role !== 'admin' && !req.ortu) {
    return fail(res, 'Data orang tua tidak tertaut dengan akun ini', 404);
  }

  const rows = req.user.role === 'admin'
    ? await query(
        `SELECT p.*, s.nama AS nama_siswa FROM pembayaran p
           JOIN siswa s ON s.id = p.siswa_id
          WHERE p.sekolah_id = ? ORDER BY p.tanggal_bayar DESC LIMIT 200`,
        [req.user.sekolah_id])
    : await query(
        `SELECT p.*, s.nama AS nama_siswa, jp.nama AS jenis_pembayaran,
                t.periode_bulan, t.periode_tahun
           FROM pembayaran p
           JOIN siswa s ON s.id = p.siswa_id
           JOIN tagihan t ON t.id = p.tagihan_id
           JOIN jenis_pembayaran jp ON jp.id = t.jenis_pembayaran_id
           JOIN siswa_orang_tua so ON so.siswa_id = p.siswa_id
          WHERE so.orang_tua_id = ? ORDER BY p.tanggal_bayar DESC LIMIT 200`,
        [req.ortu.id]);

  return ok(res, rows, 'Riwayat pembayaran berhasil dimuat');
}));

// ====================================================================
// ADMIN - JENIS PEMBAYARAN
// ====================================================================
router.get('/admin/jenis-pembayaran', onlyAdmin, asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT id, nama, kode, nominal_default, tipe, is_active
       FROM jenis_pembayaran
      WHERE sekolah_id = ? AND is_active = 1
      ORDER BY nama`,
    [req.user.sekolah_id]
  );
  return ok(res, rows, 'Jenis pembayaran berhasil dimuat');
}));

router.post('/admin/jenis-pembayaran', onlyAdmin, asyncHandler(async (req, res) => {
  const b = req.body || {};
  if (!b.nama) return fail(res, 'Nama jenis pembayaran wajib diisi', 400);

  const id = uuid();
  await query(
    `INSERT INTO jenis_pembayaran (id, sekolah_id, nama, kode, nominal_default, tipe)
     VALUES (?,?,?,?,?,?)`,
    [id, req.user.sekolah_id, b.nama, b.kode || null,
     toNum(b.nominal_default), b.tipe || 'bulanan']
  );

  const row = await queryOne(`SELECT * FROM jenis_pembayaran WHERE id = ?`, [id]);
  return ok(res, row, 'Jenis pembayaran berhasil ditambahkan');
}));

router.put('/admin/jenis-pembayaran/:id', onlyAdmin, asyncHandler(async (req, res) => {
  const b = req.body || {};
  const row = await queryOne(`SELECT * FROM jenis_pembayaran WHERE id = ?`, [req.params.id]);
  if (!row) return fail(res, 'Jenis pembayaran tidak ditemukan', 404);

  const sets = []; const vals = [];
  for (const f of ['nama', 'kode', 'tipe']) {
    if (b[f] !== undefined) { sets.push(`${f} = ?`); vals.push(b[f]); }
  }
  if (b.nominal_default !== undefined) { sets.push('nominal_default = ?'); vals.push(toNum(b.nominal_default)); }
  if (b.is_active !== undefined) { sets.push('is_active = ?'); vals.push(b.is_active ? 1 : 0); }
  if (!sets.length) return fail(res, 'Tidak ada data yang diubah', 400);

  vals.push(row.id);
  await query(`UPDATE jenis_pembayaran SET ${sets.join(', ')} WHERE id = ?`, vals);
  const updated = await queryOne(`SELECT * FROM jenis_pembayaran WHERE id = ?`, [row.id]);
  return ok(res, updated, 'Jenis pembayaran berhasil diperbarui');
}));

// ====================================================================
// ADMIN - GENERATE TAGIHAN (satu jenis pembayaran, rentang bulan)
// ====================================================================
function akhirBulan(tahun, bulan) {
  const d = new Date(tahun, bulan, 0); // bulan 1-12 -> hari terakhir
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

router.post('/admin/tagihan/generate-massal', onlyAdmin, asyncHandler(async (req, res) => {
  const b = req.body || {};
  const tahun = toNum(b.tahun, new Date().getFullYear());
  const bulanMulai = toNum(b.bulan_mulai, 1);
  const bulanSelesai = toNum(b.bulan_selesai, 12);

  if (!b.jenis_pembayaran_id) return fail(res, 'jenis_pembayaran_id wajib diisi', 400);
  if (bulanMulai < 1 || bulanSelesai > 12 || bulanMulai > bulanSelesai) {
    return fail(res, 'Rentang bulan tidak valid', 400);
  }

  const jp = await queryOne(
    `SELECT * FROM jenis_pembayaran WHERE id = ? AND sekolah_id = ?`,
    [b.jenis_pembayaran_id, req.user.sekolah_id]
  );
  if (!jp) return fail(res, 'Jenis pembayaran tidak ditemukan', 404);

  const nominal = b.nominal_override !== null && b.nominal_override !== undefined
    ? toNum(b.nominal_override)
    : toNum(jp.nominal_default);
  if (nominal < 0) return fail(res, 'Nominal tidak boleh negatif', 400);

  const siswaFilter = ['s.sekolah_id = ?', "s.status = 'aktif'"];
  const siswaParams = [req.user.sekolah_id];
  if (b.kelas_id) { siswaFilter.push('s.kelas_id = ?'); siswaParams.push(b.kelas_id); }
  if (b.tingkat) { siswaFilter.push('k.tingkat = ?'); siswaParams.push(toNum(b.tingkat)); }

  const siswa = await query(
    `SELECT s.id FROM siswa s LEFT JOIN kelas k ON k.id = s.kelas_id
      WHERE ${siswaFilter.join(' AND ')}`,
    siswaParams
  );
  if (!siswa.length) return fail(res, 'Tidak ada siswa aktif yang memenuhi kriteria', 400);

  let dibuat = 0;
  let dilewati = 0;

  await withTransaction(async (conn) => {
    for (let bulan = bulanMulai; bulan <= bulanSelesai; bulan += 1) {
      const jatuhTempo = akhirBulan(tahun, bulan);
      for (const s of siswa) {
        const [result] = await conn.execute(
          `INSERT IGNORE INTO tagihan
             (id, sekolah_id, siswa_id, jenis_pembayaran_id, periode_bulan, periode_tahun,
              nominal, diskon, nominal_akhir, tanggal_jatuh_tempo, status)
           VALUES (?,?,?,?,?,?,?,0,?,?, 'belum_bayar')`,
          [uuid(), req.user.sekolah_id, s.id, jp.id, bulan, tahun,
           nominal, nominal, jatuhTempo]
        );
        if (result.affectedRows > 0) dibuat += 1; else dilewati += 1;
      }
    }
  });

  return ok(res, {
    tagihan_dibuat: dibuat,
    tagihan_dilewati: dilewati,
    total_siswa: siswa.length,
    nominal_per_tagihan: nominal,
    total_nominal: dibuat * nominal,
    jenis_pembayaran: jp.nama,
    periode: { tahun, bulan_mulai: bulanMulai, bulan_selesai: bulanSelesai },
  }, `${dibuat} tagihan berhasil dibuat${dilewati ? `, ${dilewati} dilewati (sudah ada)` : ''}`);
}));

// ====================================================================
// ADMIN - GENERATE SEMUA JENIS PEMBAYARAN SEKALIGUS
// body: { tahun, bulan_mulai, bulan_selesai, nominal_overrides: { <jpId>: nominal } }
// ====================================================================
router.post('/admin/tagihan/generate-all', onlyAdmin, asyncHandler(async (req, res) => {
  const b = req.body || {};
  const tahun = toNum(b.tahun, new Date().getFullYear());
  const bulanMulai = toNum(b.bulan_mulai, 1);
  const bulanSelesai = toNum(b.bulan_selesai, 12);
  const overrides = b.nominal_overrides || {};

  if (bulanMulai < 1 || bulanSelesai > 12 || bulanMulai > bulanSelesai) {
    return fail(res, 'Rentang bulan tidak valid', 400);
  }

  const jenisList = await query(
    `SELECT * FROM jenis_pembayaran WHERE sekolah_id = ? AND is_active = 1 ORDER BY nama`,
    [req.user.sekolah_id]
  );
  if (!jenisList.length) return fail(res, 'Belum ada jenis pembayaran aktif', 400);

  const siswa = await query(
    `SELECT id FROM siswa WHERE sekolah_id = ? AND status = 'aktif'`,
    [req.user.sekolah_id]
  );
  if (!siswa.length) return fail(res, 'Tidak ada siswa aktif', 400);

  const summary = [];
  let totalDibuat = 0;

  await withTransaction(async (conn) => {
    for (const jp of jenisList) {
      const ov = overrides[jp.id];
      const nominal = ov !== undefined && ov !== null ? toNum(ov) : toNum(jp.nominal_default);
      let dibuat = 0;

      for (let bulan = bulanMulai; bulan <= bulanSelesai; bulan += 1) {
        const jatuhTempo = akhirBulan(tahun, bulan);
        for (const s of siswa) {
          const [result] = await conn.execute(
            `INSERT IGNORE INTO tagihan
               (id, sekolah_id, siswa_id, jenis_pembayaran_id, periode_bulan, periode_tahun,
                nominal, diskon, nominal_akhir, tanggal_jatuh_tempo, status)
             VALUES (?,?,?,?,?,?,?,0,?,?, 'belum_bayar')`,
            [uuid(), req.user.sekolah_id, s.id, jp.id, bulan, tahun,
             nominal, nominal, jatuhTempo]
          );
          if (result.affectedRows > 0) dibuat += 1;
        }
      }

      totalDibuat += dibuat;
      summary.push({
        jenis_pembayaran_id: jp.id,
        jenis_pembayaran: jp.nama,
        tagihan_dibuat: dibuat,
        nominal_per_tagihan: nominal,
        total_nominal: dibuat * nominal,
      });
    }
  });

  return ok(res, {
    total_tagihan_dibuat: totalDibuat,
    total_siswa: siswa.length,
    total_nominal: summary.reduce((s, x) => s + x.total_nominal, 0),
    summary,
    periode: { tahun, bulan_mulai: bulanMulai, bulan_selesai: bulanSelesai },
  }, `${totalDibuat} tagihan berhasil dibuat untuk ${siswa.length} siswa`);
}));

// ====================================================================
// ADMIN - PEMBAYARAN MENUNGGU VERIFIKASI
// ====================================================================
router.get('/admin/pembayaran/pending', onlyAdmin, asyncHandler(async (req, res) => {
  const rows = await query(
    `SELECT p.id, p.tagihan_id, p.siswa_id, p.jumlah_bayar, p.metode_bayar,
            p.nomor_referensi, p.catatan, p.bukti_transfer_url, p.tanggal_bayar, p.status,
            s.nama AS nama_siswa, s.nis, k.nama_kelas,
            jp.nama AS jenis_pembayaran,
            t.periode_bulan, t.periode_tahun, t.nominal_akhir,
            COALESCE(ot.nama_ibu, ot.nama_ayah, ot.nama_wali, u.nama, '-') AS nama_orang_tua
       FROM pembayaran p
       JOIN tagihan t ON t.id = p.tagihan_id
       JOIN jenis_pembayaran jp ON jp.id = t.jenis_pembayaran_id
       JOIN siswa s ON s.id = p.siswa_id
       LEFT JOIN kelas k ON k.id = s.kelas_id
       LEFT JOIN users u ON u.id = p.dibayar_oleh
       LEFT JOIN orang_tua ot ON ot.user_id = p.dibayar_oleh
      WHERE p.sekolah_id = ? AND p.status = 'pending'
      ORDER BY p.tanggal_bayar ASC`,
    [req.user.sekolah_id]
  );

  return ok(res, rows, 'Daftar pembayaran menunggu verifikasi', { count: rows.length });
}));

// ====================================================================
// ADMIN - VERIFIKASI PEMBAYARAN
// body: { action: 'approved'|'rejected'|'approve'|'reject', note }
// ====================================================================
router.post('/admin/pembayaran/:pembayaranId/verify', onlyAdmin, asyncHandler(async (req, res) => {
  const action = (req.body?.action || '').toLowerCase();
  if (!['approve', 'approved', 'reject', 'rejected'].includes(action)) {
    return fail(res, "Action harus 'approved' atau 'rejected'", 400);
  }
  const isApprove = action.startsWith('approve');

  const bayar = await queryOne(
    `SELECT p.*, t.nominal_akhir, s.nama AS nama_siswa
       FROM pembayaran p
       JOIN tagihan t ON t.id = p.tagihan_id
       JOIN siswa s ON s.id = p.siswa_id
      WHERE p.id = ? LIMIT 1`,
    [req.params.pembayaranId]
  );
  if (!bayar) return fail(res, 'Data pembayaran tidak ditemukan', 404);
  if (bayar.status !== 'pending') return fail(res, 'Pembayaran ini sudah diverifikasi', 409);

  await withTransaction(async (conn) => {
    await conn.execute(
      `UPDATE pembayaran
          SET status = ?, verified_by = ?, verified_at = ?, verify_note = ?
        WHERE id = ?`,
      [isApprove ? 'approved' : 'rejected', req.user.id, nowDateTimeStr(),
       req.body?.note || null, bayar.id]
    );

    if (isApprove) {
      const [sumRows] = await conn.execute(
        `SELECT COALESCE(SUM(jumlah_bayar),0) AS total FROM pembayaran
          WHERE tagihan_id = ? AND status = 'approved'`,
        [bayar.tagihan_id]
      );
      const terbayar = toNum(sumRows[0]?.total);
      const status = terbayar >= toNum(bayar.nominal_akhir) ? 'lunas' : 'belum_bayar';
      await conn.execute(`UPDATE tagihan SET status = ? WHERE id = ?`, [status, bayar.tagihan_id]);
    } else {
      // kembalikan ke belum_bayar kalau tidak ada pembayaran pending lain
      const [pend] = await conn.execute(
        `SELECT COUNT(*) AS c FROM pembayaran
          WHERE tagihan_id = ? AND status = 'pending' AND id <> ?`,
        [bayar.tagihan_id, bayar.id]
      );
      if (toNum(pend[0]?.c) === 0) {
        const [appr] = await conn.execute(
          `SELECT COALESCE(SUM(jumlah_bayar),0) AS total FROM pembayaran
            WHERE tagihan_id = ? AND status = 'approved'`,
          [bayar.tagihan_id]
        );
        const status = toNum(appr[0]?.total) >= toNum(bayar.nominal_akhir) ? 'lunas' : 'belum_bayar';
        await conn.execute(`UPDATE tagihan SET status = ? WHERE id = ?`, [status, bayar.tagihan_id]);
      }
    }
  });

  const row = await queryOne(`SELECT * FROM pembayaran WHERE id = ?`, [bayar.id]);
  return ok(res, row, isApprove
    ? `Pembayaran ${bayar.nama_siswa} disetujui`
    : `Pembayaran ${bayar.nama_siswa} ditolak`);
}));

// ====================================================================
// ADMIN - LAPORAN KEUANGAN
// GET /api/spp/admin/laporan?bulan=&tahun=
// ====================================================================
router.get('/admin/laporan', onlyAdmin, asyncHandler(async (req, res) => {
  const now = new Date();
  const bulan = toNum(req.query.bulan, now.getMonth() + 1);
  const tahun = toNum(req.query.tahun, now.getFullYear());
  const sekolahId = req.user.sekolah_id;

  const ringkasanRow = await queryOne(
    `SELECT COUNT(*) AS total_tagihan,
            SUM(status = 'lunas')               AS lunas,
            SUM(status = 'belum_bayar')         AS belum_bayar,
            SUM(status = 'menunggu_verifikasi') AS menunggu_verifikasi,
            COALESCE(SUM(nominal_akhir),0)      AS total_nominal
       FROM tagihan
      WHERE sekolah_id = ? AND periode_bulan = ? AND periode_tahun = ? AND status <> 'batal'`,
    [sekolahId, bulan, tahun]
  );

  const terbayarRow = await queryOne(
    `SELECT COALESCE(SUM(p.jumlah_bayar),0) AS total
       FROM pembayaran p JOIN tagihan t ON t.id = p.tagihan_id
      WHERE t.sekolah_id = ? AND t.periode_bulan = ? AND t.periode_tahun = ?
        AND p.status = 'approved'`,
    [sekolahId, bulan, tahun]
  );

  const totalTagihan = toNum(ringkasanRow?.total_tagihan);
  const lunas = toNum(ringkasanRow?.lunas);
  const totalNominal = toNum(ringkasanRow?.total_nominal);
  const totalTerbayar = toNum(terbayarRow?.total);

  const ringkasan = {
    total_tagihan: totalTagihan,
    lunas,
    belum_bayar: toNum(ringkasanRow?.belum_bayar),
    menunggu_verifikasi: toNum(ringkasanRow?.menunggu_verifikasi),
    total_nominal: totalNominal,
    total_terbayar: totalTerbayar,
    tunggakan: Math.max(0, totalNominal - totalTerbayar),
    persentase_pembayaran: totalNominal > 0
      ? Math.round((totalTerbayar / totalNominal) * 10000) / 100
      : 0,
  };

  const bayarBulanIni = await queryOne(
    `SELECT COUNT(*) AS total_pembayaran,
            COALESCE(SUM(jumlah_bayar),0) AS total_terima,
            SUM(DATE(tanggal_bayar) = ?)  AS pembayaran_hari_ini
       FROM pembayaran
      WHERE sekolah_id = ? AND status = 'approved'
        AND MONTH(tanggal_bayar) = ? AND YEAR(tanggal_bayar) = ?`,
    [todayStr(), sekolahId, bulan, tahun]
  );

  const detailPerJenis = await query(
    `SELECT jp.id, jp.nama,
            COUNT(t.id)                     AS total_tagihan,
            SUM(t.status = 'lunas')         AS lunas,
            SUM(t.status = 'belum_bayar')   AS belum_bayar,
            COALESCE(SUM(t.nominal_akhir),0) AS total_nominal,
            COALESCE((SELECT SUM(p.jumlah_bayar) FROM pembayaran p
                       JOIN tagihan t2 ON t2.id = p.tagihan_id
                      WHERE t2.jenis_pembayaran_id = jp.id
                        AND t2.periode_bulan = ? AND t2.periode_tahun = ?
                        AND p.status = 'approved'), 0) AS total_terbayar
       FROM jenis_pembayaran jp
       LEFT JOIN tagihan t ON t.jenis_pembayaran_id = jp.id
            AND t.periode_bulan = ? AND t.periode_tahun = ? AND t.status <> 'batal'
      WHERE jp.sekolah_id = ?
      GROUP BY jp.id, jp.nama
      ORDER BY jp.nama`,
    [bulan, tahun, bulan, tahun, sekolahId]
  );

  const perKelas = await query(
    `SELECT k.id, k.nama_kelas,
            COUNT(t.id)                      AS total_tagihan,
            SUM(t.status = 'lunas')          AS lunas,
            COALESCE(SUM(t.nominal_akhir),0) AS total_nominal,
            COALESCE((SELECT SUM(p.jumlah_bayar)
                        FROM pembayaran p
                        JOIN tagihan t2 ON t2.id = p.tagihan_id
                        JOIN siswa s2 ON s2.id = t2.siswa_id
                       WHERE s2.kelas_id = k.id
                         AND t2.periode_bulan = ? AND t2.periode_tahun = ?
                         AND p.status = 'approved'), 0) AS total_terbayar
       FROM kelas k
       LEFT JOIN siswa s ON s.kelas_id = k.id AND s.status = 'aktif'
       LEFT JOIN tagihan t ON t.siswa_id = s.id
            AND t.periode_bulan = ? AND t.periode_tahun = ? AND t.status <> 'batal'
      WHERE k.sekolah_id = ?
      GROUP BY k.id, k.nama_kelas
      ORDER BY k.tingkat, k.nama_kelas`,
    [bulan, tahun, bulan, tahun, sekolahId]
  );

  const topTunggakan = await query(
    `SELECT s.id, s.nama, s.nis, k.nama_kelas,
            COUNT(t.id)                      AS jumlah_tagihan,
            COALESCE(SUM(t.nominal_akhir),0) AS total_tunggakan
       FROM siswa s
       LEFT JOIN kelas k ON k.id = s.kelas_id
       JOIN tagihan t ON t.siswa_id = s.id AND t.status = 'belum_bayar'
      WHERE s.sekolah_id = ? AND s.status = 'aktif'
      GROUP BY s.id, s.nama, s.nis, k.nama_kelas
      ORDER BY total_tunggakan DESC
      LIMIT 10`,
    [sekolahId]
  );

  return ok(res, {
    periode: { bulan, tahun },
    ringkasan,
    pembayaran_bulan_ini: {
      total_pembayaran: toNum(bayarBulanIni?.total_pembayaran),
      total_terima: toNum(bayarBulanIni?.total_terima),
      pembayaran_hari_ini: toNum(bayarBulanIni?.pembayaran_hari_ini),
    },
    detail_per_jenis: detailPerJenis,
    per_kelas: perKelas,
    top_tunggakan: topTunggakan,
  }, 'Laporan keuangan berhasil dimuat');
}));

// ====================================================================
// ADMIN - DAFTAR TAGIHAN (filter)
// ====================================================================
router.get('/admin/tagihan', onlyAdmin, asyncHandler(async (req, res) => {
  const where = ['t.sekolah_id = ?'];
  const params = [req.user.sekolah_id];
  if (req.query.bulan) { where.push('t.periode_bulan = ?'); params.push(toNum(req.query.bulan)); }
  if (req.query.tahun) { where.push('t.periode_tahun = ?'); params.push(toNum(req.query.tahun)); }
  if (req.query.status) { where.push('t.status = ?'); params.push(req.query.status); }
  if (req.query.kelas_id) { where.push('s.kelas_id = ?'); params.push(req.query.kelas_id); }

  const rows = await query(
    `SELECT t.*, s.nama AS nama_siswa, s.nis, k.nama_kelas, jp.nama AS jenis_pembayaran
       FROM tagihan t
       JOIN siswa s ON s.id = t.siswa_id
       LEFT JOIN kelas k ON k.id = s.kelas_id
       JOIN jenis_pembayaran jp ON jp.id = t.jenis_pembayaran_id
      WHERE ${where.join(' AND ')}
      ORDER BY t.periode_tahun DESC, t.periode_bulan DESC, s.nama
      LIMIT 1000`,
    params
  );

  return ok(res, rows, 'Daftar tagihan berhasil dimuat', { count: rows.length });
}));

module.exports = router;
