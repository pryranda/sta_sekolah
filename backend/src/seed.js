'use strict';

/**
 * Mengisi database dengan data awal yang konsisten dengan aplikasi Flutter.
 *
 *   node src/seed.js          -> isi data bila database masih kosong
 *   node src/seed.js --force  -> hapus data lama lalu isi ulang
 *
 * Password akun contoh diambil dari environment SEED_PASSWORD
 * (default: "sekolah123"). Ganti setelah login pertama.
 */

const bcrypt = require('bcryptjs');
const { pool, query, queryOne } = require('./db');
const { uuid, todayStr, hitungNilaiAkhir, predikat } = require('./utils/helpers');

const PASSWORD = process.env.SEED_PASSWORD || 'sekolah123';
const FORCE = process.argv.includes('--force');

const TAHUN_AJARAN = '2026/2027';
const SEMESTER = 1;

const MAPEL = [
  { nama: 'Pendidikan Agama Islam', kode: 'PAI', jam: 4 },
  { nama: 'Al-Islam', kode: 'ALIS', jam: 2 },
  { nama: 'Baca Tulis Quran', kode: 'BTQ', jam: 3 },
  { nama: 'Tahfidz', kode: 'TFZ', jam: 4 },
  { nama: 'Bahasa Indonesia', kode: 'BIND', jam: 6 },
  { nama: 'Bahasa Inggris', kode: 'BING', jam: 4 },
  { nama: 'Bahasa Sunda', kode: 'BSND', jam: 2 },
  { nama: 'Bahasa Arab', kode: 'ARAB', jam: 2 },
  { nama: 'Matematika', kode: 'MTK', jam: 6 },
  { nama: 'IPAS', kode: 'IPAS', jam: 4 },
  { nama: 'Pendidikan Pancasila', kode: 'PPKN', jam: 2 },
  { nama: 'Seni Budaya', kode: 'SBDP', jam: 2 },
  { nama: 'PJOK', kode: 'PJOK', jam: 3 },
];

const GURU = [
  { nama: 'Ahmad Fauzi, S.Pd.', nip: '198501012010011001', jk: 'L', mapel: ['MTK', 'IPAS'] },
  { nama: 'Siti Aminah, S.Pd.', nip: '198702152011012002', jk: 'P', mapel: ['BIND', 'BSND'] },
  { nama: 'Budi Santoso, S.Pd.', nip: '198903102012011003', jk: 'L', mapel: ['BING', 'ARAB'] },
  { nama: 'Nurul Hidayah, S.Pd.I', nip: '199004222013012004', jk: 'P', mapel: ['PAI', 'ALIS'] },
  { nama: 'Muhammad Rizki, S.Pd.', nip: '199105182014011005', jk: 'L', mapel: ['BTQ', 'TFZ'] },
  { nama: 'Dewi Lestari, S.Pd.', nip: '199206252015012006', jk: 'P', mapel: ['PPKN', 'SBDP'] },
  { nama: 'Agus Permana, S.Or.', nip: '199307302016011007', jk: 'L', mapel: ['PJOK'] },
  { nama: 'Rina Marlina, S.Pd.', nip: '199408122017012008', jk: 'P', mapel: ['MTK', 'BIND'] },
];

const NAMA_SISWA_L = [
  'Abdul Rahman', 'Bagas Pratama', 'Candra Wijaya', 'Dimas Saputra', 'Eka Nugraha',
  'Farhan Maulana', 'Gilang Ramadhan', 'Hadi Firmansyah', 'Ilham Kurniawan', 'Joko Susilo',
];
const NAMA_SISWA_P = [
  'Anisa Putri', 'Bella Safira', 'Cantika Dewi', 'Dinda Ayu', 'Elsa Fitriani',
  'Fitri Handayani', 'Gita Permatasari', 'Hanifah Zahra', 'Indah Pertiwi', 'Jasmine Azzahra',
];

const JENIS_PEMBAYARAN = [
  { nama: 'SPP Bulanan', kode: 'SPP', nominal: 250000, tipe: 'bulanan' },
  { nama: 'Uang Kegiatan', kode: 'KEG', nominal: 50000, tipe: 'bulanan' },
  { nama: 'Uang Makan / Katering', kode: 'KTR', nominal: 300000, tipe: 'bulanan' },
  { nama: 'Ekstrakurikuler', kode: 'EKS', nominal: 35000, tipe: 'bulanan' },
];

const PENGUMUMAN = [
  {
    judul: 'Jadwal Penilaian Tengah Semester',
    isi: 'Penilaian Tengah Semester akan dilaksanakan mulai tanggal 8 sampai 13 Desember 2026. '
      + 'Mohon orang tua mendampingi putra-putri dalam persiapan belajar di rumah.',
    kategori: 'akademik', prioritas: 'tinggi',
  },
  {
    judul: 'Pembayaran SPP Bulan Ini',
    isi: 'Pembayaran SPP bulan ini dapat dilakukan melalui transfer bank dan diunggah '
      + 'melalui menu SPP pada aplikasi. Batas pembayaran tanggal 10 setiap bulan.',
    kategori: 'keuangan', prioritas: 'normal',
  },
  {
    judul: 'Kegiatan Jumat Bersih',
    isi: 'Setiap hari Jumat pekan pertama diadakan kegiatan Jumat Bersih. '
      + 'Siswa diharapkan membawa peralatan kebersihan ringan.',
    kategori: 'kegiatan', prioritas: 'rendah',
  },
  {
    judul: 'Libur Nasional',
    isi: 'Sesuai kalender pendidikan, kegiatan belajar mengajar diliburkan pada hari libur nasional. '
      + 'Daftar lengkap dapat dilihat pada menu kalender.',
    kategori: 'umum', prioritas: 'normal',
  },
];

const HARI_LIBUR = [
  { tanggal: '2026-12-25', keterangan: 'Hari Raya Natal' },
  { tanggal: '2027-01-01', keterangan: 'Tahun Baru 2027' },
  { tanggal: '2027-03-19', keterangan: 'Hari Raya Nyepi' },
  { tanggal: '2027-05-01', keterangan: 'Hari Buruh Internasional' },
];

const pad = (n, w = 3) => String(n).padStart(w, '0');

async function kosongkan() {
  const tables = [
    'pembayaran', 'tagihan', 'jenis_pembayaran',
    'pengumuman_read', 'pengumuman',
    'tugas_submission', 'tugas',
    'nilai', 'absensi', 'absensi_guru',
    'jadwal', 'schedule_config', 'hari_libur',
    'siswa_orang_tua', 'orang_tua', 'siswa',
    'guru_mapel', 'mapel', 'kelas', 'guru',
    'users', 'sekolah',
  ];
  await query('SET FOREIGN_KEY_CHECKS = 0');
  for (const t of tables) await query(`DELETE FROM ${t}`);
  await query('SET FOREIGN_KEY_CHECKS = 1');
  console.log('  data lama dihapus');
}

async function main() {
  console.log('=== SEED STA SEKOLAH ===');

  const existing = await queryOne(`SELECT COUNT(*) AS c FROM sekolah`);
  if (existing && existing.c > 0) {
    if (!FORCE) {
      console.log('Database sudah berisi data. Jalankan dengan --force untuk mengisi ulang.');
      await pool.end();
      return;
    }
    await kosongkan();
  }

  const hash = await bcrypt.hash(PASSWORD, 10);

  // ---------------------------------------------------------------- sekolah
  const sekolahId = uuid();
  await query(
    `INSERT INTO sekolah
       (id, nama, alamat, telepon, email, website, logo_url,
        latitude, longitude, radius_maksimal, jam_masuk, jam_pulang)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
    [sekolahId, 'SD Islam Terpadu Saranatama',
     'Jl. Pendidikan No. 25, Cimahi, Jawa Barat 40512',
     '022-6652100', 'info@sta.sch.id', 'https://sta.sch.id', '',
     -6.8841000, 107.5413000, 200, '07:00:00', '13:30:00']
  );
  console.log('  sekolah dibuat');

  // ---------------------------------------------------------------- admin
  const adminUserId = uuid();
  await query(
    `INSERT INTO users (id, sekolah_id, username, password, role, role_name, nama, email, jabatan)
     VALUES (?,?,?,?, 'admin', 'Administrator', ?, ?, ?)`,
    [adminUserId, sekolahId, 'admin', hash, 'Administrator Sekolah', 'admin@sta.sch.id', 'kepala_sekolah']
  );
  const keuanganUserId = uuid();
  await query(
    `INSERT INTO users (id, sekolah_id, username, password, role, role_name, nama, email, jabatan)
     VALUES (?,?,?,?, 'admin', 'Admin Keuangan', ?, ?, ?)`,
    [keuanganUserId, sekolahId, 'keuangan', hash, 'Bendahara Sekolah', 'keuangan@sta.sch.id', 'keuangan']
  );
  console.log('  2 akun admin dibuat');

  // ---------------------------------------------------------------- mapel
  const mapelId = {};
  for (const m of MAPEL) {
    const id = uuid();
    mapelId[m.kode] = id;
    await query(
      `INSERT INTO mapel (id, sekolah_id, nama_mapel, kode_mapel, jam_per_pekan)
       VALUES (?,?,?,?,?)`,
      [id, sekolahId, m.nama, m.kode, m.jam]
    );
  }
  console.log(`  ${MAPEL.length} mata pelajaran dibuat`);

  // ---------------------------------------------------------------- guru
  const guruIds = [];
  let guruNo = 1;
  for (const g of GURU) {
    const userId = uuid();
    const guruId = uuid();
    const username = `guru${pad(guruNo, 2)}`;
    await query(
      `INSERT INTO users (id, sekolah_id, username, password, role, role_name, nama, email)
       VALUES (?,?,?,?, 'guru', 'Guru', ?, ?)`,
      [userId, sekolahId, username, hash, g.nama, `${username}@sta.sch.id`]
    );
    await query(
      `INSERT INTO guru (id, sekolah_id, user_id, nama, nip, email, no_hp, jenis_kelamin, alamat)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [guruId, sekolahId, userId, g.nama, g.nip, `${username}@sta.sch.id`,
       `08${pad(1000000 + guruNo * 137, 9)}`, g.jk, 'Cimahi, Jawa Barat']
    );
    for (const kode of g.mapel) {
      await query(
        `INSERT INTO guru_mapel (id, guru_id, mapel_id) VALUES (?,?,?)`,
        [uuid(), guruId, mapelId[kode]]
      );
    }
    guruIds.push(guruId);
    guruNo += 1;
  }
  console.log(`  ${GURU.length} guru dibuat (username guru01..guru0${GURU.length})`);

  // ---------------------------------------------------------------- kelas
  const kelasIds = [];
  for (let tingkat = 1; tingkat <= 6; tingkat += 1) {
    const id = uuid();
    await query(
      `INSERT INTO kelas (id, sekolah_id, nama_kelas, tingkat, kapasitas, tahun_ajaran, wali_kelas_id, ruangan)
       VALUES (?,?,?,?,?,?,?,?)`,
      [id, sekolahId, `${tingkat}A`, tingkat, 28, TAHUN_AJARAN,
       guruIds[(tingkat - 1) % guruIds.length], `R-${pad(tingkat, 2)}`]
    );
    kelasIds.push({ id, tingkat, nama: `${tingkat}A` });
  }
  console.log('  6 kelas dibuat (1A - 6A)');

  // ---------------------------------------------------------------- siswa + orang tua
  const siswaAll = [];
  let nisCounter = 1;
  let ortuCounter = 1;

  for (const kelas of kelasIds) {
    for (let i = 0; i < 5; i += 1) {
      const isL = i % 2 === 0;
      const nama = isL
        ? NAMA_SISWA_L[(kelas.tingkat * 2 + i) % NAMA_SISWA_L.length]
        : NAMA_SISWA_P[(kelas.tingkat * 2 + i) % NAMA_SISWA_P.length];
      const namaLengkap = `${nama} ${kelas.tingkat}${String.fromCharCode(65 + i)}`;

      const nis = `2026${pad(nisCounter, 4)}`;
      const userId = uuid();
      const siswaId = uuid();

      await query(
        `INSERT INTO users (id, sekolah_id, username, password, role, role_name, nama, email)
         VALUES (?,?,?,?, 'siswa', 'Siswa', ?, ?)`,
        [userId, sekolahId, nis, hash, namaLengkap, `${nis}@siswa.sta.sch.id`]
      );
      await query(
        `INSERT INTO siswa
           (id, sekolah_id, user_id, kelas_id, nama, nis, nisn, tempat_lahir, tanggal_lahir,
            jenis_kelamin, agama, alamat, no_hp, email, tahun_ajaran, semester, status)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?, 'aktif')`,
        [siswaId, sekolahId, userId, kelas.id, namaLengkap, nis, `00${pad(nisCounter, 8)}`,
         'Cimahi', `${2026 - 6 - kelas.tingkat}-0${(i % 9) + 1}-1${(i % 9)}`,
         isL ? 'L' : 'P', 'Islam', `Jl. Melati No. ${nisCounter}, Cimahi`,
         `08${pad(2000000 + nisCounter * 311, 9)}`, `${nis}@siswa.sta.sch.id`,
         TAHUN_AJARAN, SEMESTER]
      );

      // satu akun orang tua per siswa
      const ortuUserId = uuid();
      const ortuId = uuid();
      const ortuUsername = `ortu${pad(ortuCounter, 3)}`;
      await query(
        `INSERT INTO users (id, sekolah_id, username, password, role, role_name, nama, email)
         VALUES (?,?,?,?, 'orang_tua', 'Orang Tua', ?, ?)`,
        [ortuUserId, sekolahId, ortuUsername, hash, `Ibu ${nama}`, `${ortuUsername}@sta.sch.id`]
      );
      await query(
        `INSERT INTO orang_tua
           (id, sekolah_id, user_id, nama_ibu, pekerjaan_ibu, hp_ibu, tahun_lahir_ibu,
            jenjang_pendidikan_ibu, penghasilan_ibu, nik_ibu,
            nama_ayah, pekerjaan_ayah, hp_ayah, tahun_lahir_ayah,
            jenjang_pendidikan_ayah, penghasilan_ayah, nik_ayah,
            alamat, email)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [ortuId, sekolahId, ortuUserId,
         `Ibu ${nama}`, 'Ibu Rumah Tangga', `08${pad(3000000 + ortuCounter * 211, 9)}`, 1990,
         'SMA/SMK', 'Rp 1.000.000 - Rp 3.000.000', `32770${pad(ortuCounter, 11)}`,
         `Bapak ${nama}`, 'Karyawan Swasta', `08${pad(4000000 + ortuCounter * 173, 9)}`, 1988,
         'S1', 'Rp 3.000.000 - Rp 5.000.000', `32770${pad(ortuCounter + 500, 11)}`,
         `Jl. Melati No. ${nisCounter}, Cimahi`, `${ortuUsername}@sta.sch.id`]
      );
      await query(
        `INSERT INTO siswa_orang_tua (id, siswa_id, orang_tua_id) VALUES (?,?,?)`,
        [uuid(), siswaId, ortuId]
      );

      siswaAll.push({ id: siswaId, nama: namaLengkap, nis, kelas_id: kelas.id, tingkat: kelas.tingkat });
      nisCounter += 1;
      ortuCounter += 1;
    }
  }
  console.log(`  ${siswaAll.length} siswa + ${siswaAll.length} akun orang tua dibuat`);

  // ---------------------------------------------------------------- jadwal
  const { generateJadwal } = require('./utils/scheduler');
  const hasilJadwal = await generateJadwal({
    sekolahId,
    kelasIds: kelasIds.map((k) => k.id),
    hariList: ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'],
    tahunAjaran: TAHUN_AJARAN,
    semester: SEMESTER,
    config: null,
  });
  console.log(`  jadwal: ${hasilJadwal.ok ? hasilJadwal.message : hasilJadwal.message}`);

  // ---------------------------------------------------------------- nilai
  let nilaiCount = 0;
  const mapelUtama = ['BIND', 'MTK', 'IPAS', 'BING', 'PAI'];
  for (const s of siswaAll) {
    for (const kode of mapelUtama) {
      const base = 70 + ((s.nis.charCodeAt(7) + kode.charCodeAt(0)) % 25);
      const nt = Math.min(100, base + 5);
      const nu = Math.min(100, base);
      const na = Math.min(100, base + 3);
      const akhir = hitungNilaiAkhir(nt, nu, na);
      await query(
        `INSERT INTO nilai
           (id, siswa_id, mapel_id, guru_id, semester, tahun_ajaran,
            nilai_tugas, nilai_uts, nilai_uas, nilai_akhir, predikat)
         VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
        [uuid(), s.id, mapelId[kode], guruIds[0], SEMESTER, TAHUN_AJARAN,
         nt, nu, na, akhir, predikat(akhir)]
      );
      nilaiCount += 1;
    }
  }
  console.log(`  ${nilaiCount} data nilai dibuat`);

  // ---------------------------------------------------------------- absensi 20 hari kerja terakhir
  let absensiCount = 0;
  const hariKerja = [];
  const cursor = new Date();
  while (hariKerja.length < 20) {
    const wd = cursor.getDay();
    if (wd >= 1 && wd <= 5) hariKerja.push(todayStr(cursor));
    cursor.setDate(cursor.getDate() - 1);
  }

  for (const s of siswaAll) {
    for (let i = 0; i < hariKerja.length; i += 1) {
      const seed = (s.nis.charCodeAt(7) + i * 7) % 20;
      let status = 'hadir';
      if (seed === 3) status = 'izin';
      else if (seed === 7) status = 'sakit';
      else if (seed === 11) status = 'alpha';

      const hadir = status === 'hadir';
      await query(
        `INSERT INTO absensi
           (id, siswa_id, kelas_id, tanggal, status, jam_masuk, jam_pulang, keterangan, approval_status)
         VALUES (?,?,?,?,?,?,?,?,?)`,
        [uuid(), s.id, s.kelas_id, hariKerja[i], status,
         hadir ? `06:${pad(40 + (seed % 19), 2)}:00` : null,
         hadir ? '13:35:00' : null,
         hadir ? null : `Keterangan ${status}`,
         hadir ? '' : 'approved']
      );
      absensiCount += 1;
    }
  }
  console.log(`  ${absensiCount} data absensi dibuat (20 hari kerja terakhir)`);

  // satu permohonan izin menunggu approval orang tua (untuk menguji alur approval)
  const besok = new Date();
  besok.setDate(besok.getDate() + 1);
  await query(
    `INSERT INTO absensi (id, siswa_id, kelas_id, tanggal, status, keterangan, approval_status)
     VALUES (?,?,?,?, 'izin', ?, 'pending')`,
    [uuid(), siswaAll[0].id, siswaAll[0].kelas_id, todayStr(besok),
     'Mengantar orang tua ke rumah sakit']
  );

  // ---------------------------------------------------------------- absensi guru
  for (const gid of guruIds) {
    for (let i = 0; i < 5; i += 1) {
      await query(
        `INSERT INTO absensi_guru (id, guru_id, tanggal, jam_masuk, jam_keluar, status)
         VALUES (?,?,?,?,?, 'hadir')`,
        [uuid(), gid, hariKerja[i], `06:${pad(30 + i * 3, 2)}:00`, '14:10:00']
      );
    }
  }
  console.log('  absensi guru dibuat');

  // ---------------------------------------------------------------- tugas
  let tugasCount = 0;
  for (const kelas of kelasIds) {
    for (const kode of ['BIND', 'MTK']) {
      const deadline = new Date();
      deadline.setDate(deadline.getDate() + 7);
      const id = uuid();
      await query(
        `INSERT INTO tugas (id, sekolah_id, kelas_id, mapel_id, guru_id, judul, deskripsi, deadline, status)
         VALUES (?,?,?,?,?,?,?,?, 'aktif')`,
        [id, sekolahId, kelas.id, mapelId[kode], guruIds[0],
         `Latihan ${kode} Kelas ${kelas.nama}`,
         `Kerjakan soal latihan ${kode} halaman 24-26. Unggah hasil pekerjaan dalam format PDF atau foto.`,
         `${todayStr(deadline)} 23:59:00`]
      );
      tugasCount += 1;
    }
  }
  console.log(`  ${tugasCount} tugas dibuat`);

  // ---------------------------------------------------------------- jenis pembayaran + tagihan
  const jpIds = [];
  for (const jp of JENIS_PEMBAYARAN) {
    const id = uuid();
    jpIds.push({ id, ...jp });
    await query(
      `INSERT INTO jenis_pembayaran (id, sekolah_id, nama, kode, nominal_default, tipe)
       VALUES (?,?,?,?,?,?)`,
      [id, sekolahId, jp.nama, jp.kode, jp.nominal, jp.tipe]
    );
  }

  const tahunTagihan = new Date().getFullYear();
  const bulanSekarang = new Date().getMonth() + 1;
  let tagihanCount = 0;

  for (const s of siswaAll) {
    for (let bulan = Math.max(1, bulanSekarang - 2); bulan <= bulanSekarang; bulan += 1) {
      for (const jp of jpIds) {
        const akhirBulan = new Date(tahunTagihan, bulan, 0);
        const lunas = bulan < bulanSekarang;
        await query(
          `INSERT INTO tagihan
             (id, sekolah_id, siswa_id, jenis_pembayaran_id, periode_bulan, periode_tahun,
              nominal, diskon, nominal_akhir, tanggal_jatuh_tempo, status)
           VALUES (?,?,?,?,?,?,?,0,?,?,?)`,
          [uuid(), sekolahId, s.id, jp.id, bulan, tahunTagihan,
           jp.nominal, jp.nominal, todayStr(akhirBulan),
           lunas ? 'lunas' : 'belum_bayar']
        );
        tagihanCount += 1;
      }
    }
  }
  console.log(`  ${jpIds.length} jenis pembayaran, ${tagihanCount} tagihan dibuat`);

  // pembayaran yang sudah lunas -> catat approved
  const tagihanLunas = await query(
    `SELECT id, sekolah_id, siswa_id, nominal_akhir FROM tagihan WHERE status = 'lunas'`
  );
  for (const t of tagihanLunas) {
    await query(
      `INSERT INTO pembayaran
         (id, sekolah_id, tagihan_id, siswa_id, jumlah_bayar, metode_bayar,
          nomor_referensi, tanggal_bayar, status, verified_by, verified_at)
       VALUES (?,?,?,?,?, 'transfer_bank', ?, NOW(), 'approved', ?, NOW())`,
      [uuid(), t.sekolah_id, t.id, t.siswa_id, t.nominal_akhir,
       `TRF${Math.floor(Math.random() * 900000 + 100000)}`, keuanganUserId]
    );
  }

  // dua pembayaran menunggu verifikasi (untuk menguji layar verifikasi admin)
  const tagihanBelum = await query(
    `SELECT t.id, t.sekolah_id, t.siswa_id, t.nominal_akhir, s.user_id
       FROM tagihan t JOIN siswa s ON s.id = t.siswa_id
      WHERE t.status = 'belum_bayar' LIMIT 2`
  );
  for (const t of tagihanBelum) {
    const ortu = await queryOne(
      `SELECT ot.user_id FROM siswa_orang_tua so JOIN orang_tua ot ON ot.id = so.orang_tua_id
        WHERE so.siswa_id = ? LIMIT 1`,
      [t.siswa_id]
    );
    await query(
      `INSERT INTO pembayaran
         (id, sekolah_id, tagihan_id, siswa_id, dibayar_oleh, jumlah_bayar, metode_bayar,
          nomor_referensi, catatan, tanggal_bayar, status)
       VALUES (?,?,?,?,?,?, 'transfer_bank', ?, ?, NOW(), 'pending')`,
      [uuid(), t.sekolah_id, t.id, t.siswa_id, ortu?.user_id || null, t.nominal_akhir,
       `TRF${Math.floor(Math.random() * 900000 + 100000)}`, 'Transfer via mobile banking']
    );
    await query(`UPDATE tagihan SET status = 'menunggu_verifikasi' WHERE id = ?`, [t.id]);
  }
  console.log('  pembayaran contoh dibuat (lunas + menunggu verifikasi)');

  // ---------------------------------------------------------------- pengumuman & hari libur
  for (const p of PENGUMUMAN) {
    await query(
      `INSERT INTO pengumuman (id, sekolah_id, judul, isi, kategori, prioritas, target_role, created_by)
       VALUES (?,?,?,?,?,?, 'semua', ?)`,
      [uuid(), sekolahId, p.judul, p.isi, p.kategori, p.prioritas, adminUserId]
    );
  }
  for (const h of HARI_LIBUR) {
    await query(
      `INSERT INTO hari_libur (id, sekolah_id, tanggal, keterangan) VALUES (?,?,?,?)`,
      [uuid(), sekolahId, h.tanggal, h.keterangan]
    );
  }
  console.log(`  ${PENGUMUMAN.length} pengumuman, ${HARI_LIBUR.length} hari libur dibuat`);

  // ---------------------------------------------------------------- ringkasan
  console.log('\n=== SELESAI ===');
  console.log(`sekolah_id : ${sekolahId}`);
  console.log('Akun contoh (semua memakai SEED_PASSWORD):');
  console.log('  admin      : admin');
  console.log('  keuangan   : keuangan');
  console.log(`  guru       : guru01 .. guru${pad(GURU.length, 2)}`);
  console.log(`  siswa      : 2026${pad(1, 4)} .. 2026${pad(siswaAll.length, 4)}  (username = NIS)`);
  console.log(`  orang tua  : ortu001 .. ortu${pad(siswaAll.length, 3)}`);
  console.log('Segera ubah password setelah login pertama.');

  await pool.end();
}

main().catch(async (err) => {
  console.error('SEED GAGAL:', err.message);
  console.error(err.stack);
  try { await pool.end(); } catch (_) { /* ignore */ }
  process.exit(1);
});
