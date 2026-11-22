'use strict';

/**
 * Pemagar data antar sekolah (multi-tenant).
 *
 * Endpoint yang menerima UUID di URL tidak boleh mengambil baris begitu saja:
 * UUID milik sekolah lain akan ikut terbaca. Helper di sini mengambil baris
 * HANYA bila baris itu memang milik sekolah pemanggil.
 *
 * Peran `superadmin` dikecualikan karena memang bekerja lintas sekolah.
 */

const { queryOne } = require('../db');
const { fail } = require('./helpers');

/**
 * Untuk tiap tabel: bagian SELECT..FROM..JOIN, kolom id, dan kolom sekolah.
 * Tabel tanpa kolom sekolah_id sendiri ditelusuri lewat relasinya.
 */
const SCOPES = {
  kelas:      { from: 'kelas k',       id: 'k.id',   sekolah: 'k.sekolah_id',  select: 'k.*' },
  mapel:      { from: 'mapel m',       id: 'm.id',   sekolah: 'm.sekolah_id',  select: 'm.*' },
  guru:       { from: 'guru g',        id: 'g.id',   sekolah: 'g.sekolah_id',  select: 'g.*' },
  siswa:      { from: 'siswa s',       id: 's.id',   sekolah: 's.sekolah_id',  select: 's.*' },
  orang_tua:  { from: 'orang_tua o',   id: 'o.id',   sekolah: 'o.sekolah_id',  select: 'o.*' },
  tugas:      { from: 'tugas t',       id: 't.id',   sekolah: 't.sekolah_id',  select: 't.*' },
  jadwal:     { from: 'jadwal j',      id: 'j.id',   sekolah: 'j.sekolah_id',  select: 'j.*' },
  pengumuman: { from: 'pengumuman p',  id: 'p.id',   sekolah: 'p.sekolah_id',  select: 'p.*' },
  hari_libur: { from: 'hari_libur h',  id: 'h.id',   sekolah: 'h.sekolah_id',  select: 'h.*' },
  tagihan:    { from: 'tagihan t',     id: 't.id',   sekolah: 't.sekolah_id',  select: 't.*' },
  pembayaran: { from: 'pembayaran p',  id: 'p.id',   sekolah: 'p.sekolah_id',  select: 'p.*' },
  sekolah:    { from: 'sekolah sk',    id: 'sk.id',  sekolah: 'sk.id',         select: 'sk.*' },
  jenis_pembayaran: {
    from: 'jenis_pembayaran jp', id: 'jp.id', sekolah: 'jp.sekolah_id', select: 'jp.*',
  },

  // --- tabel tanpa kolom sekolah_id: telusuri lewat relasi ---
  guru_mapel: {
    from: 'guru_mapel gm JOIN guru g ON g.id = gm.guru_id',
    id: 'gm.id', sekolah: 'g.sekolah_id', select: 'gm.*',
  },
  tugas_submission: {
    from: 'tugas_submission sub JOIN tugas t ON t.id = sub.tugas_id',
    id: 'sub.id', sekolah: 't.sekolah_id', select: 'sub.*',
  },
  absensi: {
    from: 'absensi a JOIN siswa s ON s.id = a.siswa_id',
    id: 'a.id', sekolah: 's.sekolah_id', select: 'a.*',
  },
  nilai: {
    from: 'nilai n JOIN siswa s ON s.id = n.siswa_id',
    id: 'n.id', sekolah: 's.sekolah_id', select: 'n.*',
  },
  absensi_guru: {
    from: 'absensi_guru ag JOIN guru g ON g.id = ag.guru_id',
    id: 'ag.id', sekolah: 'g.sekolah_id', select: 'ag.*',
  },
};

/** Apakah pemanggil bekerja lintas sekolah? */
const isSuperadmin = (req) => !!req.user && req.user.role === 'superadmin';

/**
 * Ambil satu baris milik sekolah pemanggil.
 * Mengembalikan baris, atau null bila tidak ada / milik sekolah lain.
 */
async function findScoped(req, table, id) {
  if (!id) return null;
  const sc = SCOPES[table];
  if (!sc) throw new Error(`Tabel "${table}" belum terdaftar di SCOPES`);

  if (isSuperadmin(req)) {
    return queryOne(`SELECT ${sc.select} FROM ${sc.from} WHERE ${sc.id} = ? LIMIT 1`, [id]);
  }
  return queryOne(
    `SELECT ${sc.select} FROM ${sc.from} WHERE ${sc.id} = ? AND ${sc.sekolah} = ? LIMIT 1`,
    [id, req.user.sekolah_id]
  );
}

/**
 * Seperti findScoped, tetapi langsung mengirim 404 bila tidak ditemukan.
 * Mengembalikan baris, atau null bila response sudah dikirim.
 *
 *   const kelas = await requireScoped(req, res, 'kelas', req.params.kelasId, 'Kelas');
 *   if (!kelas) return;
 */
async function requireScoped(req, res, table, id, label = 'Data') {
  const row = await findScoped(req, table, id);
  if (!row) {
    // Pesan sengaja sama untuk "tidak ada" dan "milik sekolah lain", supaya
    // keberadaan data sekolah lain tidak bisa ditebak dari response.
    fail(res, `${label} tidak ditemukan`, 404);
    return null;
  }
  return row;
}

/**
 * sekolah_id yang boleh ditulis oleh pemanggil.
 * Admin sekolah selalu terkunci pada sekolahnya sendiri walaupun mengirim
 * sekolah_id lain di body; hanya superadmin yang boleh menentukan.
 */
function targetSekolahId(req, requested) {
  if (isSuperadmin(req) && requested) return requested;
  return req.user.sekolah_id;
}

module.exports = { findScoped, requireScoped, targetSekolahId, isSuperadmin, SCOPES };
