# STA Sekolah — REST API

Backend untuk aplikasi Flutter `sta_sekolah`. Dibangun dengan Node.js + Express + MySQL 8
dan dirancang mengikuti bentuk response yang sudah diharapkan oleh aplikasi
(`{ "success": bool, "message": string, "data": … }`).

Server aktif: **http://192.168.25.61:5001/api**

---

## 1. Struktur

```
backend/
├── package.json
├── sql/schema.sql              # skema database (22 tabel)
├── deploy/sta-api.service      # unit systemd
└── src/
    ├── server.js               # entry point, middleware, error handler
    ├── config.js               # konfigurasi dari environment
    ├── db.js                   # connection pool + helper transaksi
    ├── seed.js                 # data awal (sekolah, user, kelas, dst.)
    ├── middleware/
    │   ├── auth.js             # verifikasi JWT + pembatasan role
    │   └── upload.js           # multer untuk bukti bayar & lampiran tugas
    ├── utils/
    │   ├── helpers.js          # response, tanggal, perhitungan nilai
    │   └── scheduler.js        # generator jadwal pelajaran otomatis
    └── routes/
        ├── auth.js      sekolah.js  student.js  teacher.js
        └── parent.js    tugas.js    spp.js      admin.js
```

## 2. Menjalankan

### Di server (sudah terpasang)

```bash
systemctl status sta-api
```

Perintah lain yang sering dipakai:

```bash
systemctl restart sta-api
```

```bash
tail -f /var/log/sta-api.log
```

### Di komputer lokal

```bash
cd backend && npm install
```

Lalu jalankan dengan environment yang menunjuk ke database Anda:

```bash
DB_HOST=127.0.0.1 DB_USER=sta_app DB_PASSWORD=... DB_NAME=sta_sekolah PORT=5001 npm start
```

## 3. Konfigurasi

Dibaca dari environment (lihat `src/config.js`). Di server, nilai non-rahasia ada di
`/etc/systemd/system/sta-api.service`, sedangkan `DB_PASSWORD` dan `JWT_SECRET`
disimpan terpisah di `/etc/sta-api.env` (mode 600) supaya tidak masuk repositori.

| Variabel | Default | Keterangan |
|---|---|---|
| `PORT` | `5001` | Port HTTP |
| `BASE_URL` | `http://192.168.25.61:5001` | Dipakai untuk menyusun URL file yang diunggah |
| `DB_HOST` / `DB_PORT` | `127.0.0.1` / `3306` | MySQL |
| `DB_NAME` / `DB_USER` | `sta_sekolah` / `sta_app` | MySQL |
| `DB_PASSWORD` | — | Wajib, dari `/etc/sta-api.env` |
| `JWT_SECRET` | — | Wajib, dari `/etc/sta-api.env` |
| `JWT_EXPIRES_IN` | `30d` | Masa berlaku token |
| `UPLOAD_DIR` | `<backend>/uploads` | Lokasi file unggahan |
| `TZ` | `Asia/Jakarta` | Zona waktu (memengaruhi jam absensi) |

## 4. Database

Skema dibuat dari `sql/schema.sql`. Semua primary key memakai `CHAR(36)` (UUID v4)
karena aplikasi memperlakukan semua id sebagai string.

Tabel inti: `sekolah`, `users`, `guru`, `mapel`, `guru_mapel`, `kelas`, `siswa`,
`orang_tua`, `siswa_orang_tua`, `jadwal`, `schedule_config`, `absensi`,
`absensi_guru`, `nilai`, `tugas`, `tugas_submission`, `pengumuman`,
`pengumuman_read`, `jenis_pembayaran`, `tagihan`, `pembayaran`, `hari_libur`.

Mengisi ulang data contoh:

```bash
cd /opt/sta-api && set -a && . /etc/sta-api.env && set +a && SEED_PASSWORD='GantiIni123' node src/seed.js --force
```

> `--force` menghapus **seluruh** data lama lebih dulu.

## 5. Autentikasi

`POST /api/auth/login` mengembalikan `data.token` (JWT) dan `data.user`.
Semua endpoint lain memerlukan header `Authorization: Bearer <token>`.

Objek `user` memuat `sekolah_id` (dipakai `SchoolService`), `role`, `role_name`,
`nama`, `jabatan`, dan — khusus siswa — `id` yang berisi **id siswa** (bukan id user),
karena dashboard siswa memakainya untuk memanggil endpoint SPP.

Role: `siswa`, `guru`, `orang_tua`, `admin`.
Untuk admin, `jabatan = 'keuangan'` membuka menu keuangan di aplikasi.

## 6. Daftar endpoint

### Auth & Sekolah
| Method | Path |
|---|---|
| POST | `/api/auth/login` |
| GET | `/api/auth/profile` |
| PUT | `/api/auth/change-password` |
| POST | `/api/auth/logout` |
| GET | `/api/sekolah/info?sekolah_id=` |
| PUT | `/api/sekolah/lokasi` · `/api/sekolah/info` *(admin)* |
| GET | `/api/health` |

### Siswa
| Method | Path | Bentuk `data` |
|---|---|---|
| GET | `/api/student/profile` | objek |
| GET | `/api/student/jadwal` | `{ jadwal: [] }` |
| GET | `/api/student/absensi` | `{ absensi: [], rekap: {} }` |
| POST | `/api/student/absensi/checkin` | objek absensi |
| POST | `/api/student/absensi/checkout` | objek absensi |
| POST | `/api/student/absensi/request` | objek absensi |
| GET | `/api/student/nilai?semester=&tahun_ajaran=` | **list** |
| GET | `/api/student/tugas` | `{ tugas: [] }` |
| GET | `/api/student/tugas/:id/submission` | objek atau `null` |
| POST | `/api/student/tugas/:id/submit` | multipart: `file`, `catatan` |

Check-in memvalidasi jarak ke titik koordinat sekolah bila `latitude`, `longitude`
dan `radius_maksimal` sekolah terisi. Jam masuk lewat `sekolah.jam_masuk`
otomatis tercatat sebagai `terlambat`.

### Guru
| Method | Path | Bentuk `data` |
|---|---|---|
| GET | `/api/teacher/profile` | objek |
| GET | `/api/teacher/jadwal` | `{ jadwal: [] }` |
| GET | `/api/teacher/kelas` | list |
| GET | `/api/teacher/kelas/:kelasId/siswa` | `{ siswa: [] }` |
| POST | `/api/teacher/nilai` | objek nilai |
| GET | `/api/teacher/nilai/:siswaId/mapel/:mapelId` | objek atau `null` |
| GET | `/api/teacher/absensi/kelas/:kelasId` | `{ absensi: [{ id, nama, nis, absensi: [] }] }` |
| POST | `/api/teacher/absensi/kelas/:kelasId` | input absensi manual |
| GET | `/api/teacher/absensi/today` · `/history` | objek / list |
| POST | `/api/teacher/absensi/checkin` · `/checkout` | objek |
| GET | `/api/teacher/tugas/:tugasId/submissions` | `{ submissions, belum_submit, total_siswa, total_submitted }` |
| POST | `/api/teacher/submission/:id/nilai` | objek |

Nilai akhir dihitung otomatis: `30% tugas + 30% UTS + 40% UAS`, beserta predikat A–E.

### Orang Tua
| Method | Path | Bentuk `data` |
|---|---|---|
| GET | `/api/parent/profile` · `/profile/detail` | objek |
| PUT | `/api/parent/profile` | objek |
| GET | `/api/parent/anak` | `{ anak: [] }` |
| GET | `/api/parent/dashboard` | `{ jumlah_anak, dashboard: [] }` |
| GET | `/api/parent/anak/:id/jadwal` | `{ jadwal: [] }` |
| GET | `/api/parent/anak/:id/absensi?bulan=&tahun=` | `{ absensi, rekap }` |
| GET | `/api/parent/anak/:id/nilai?page=&limit=` | `{ nilai, pagination }` |
| GET | `/api/parent/anak/:id/spp?tahun=` | `{ tagihan, ringkasan }` |
| GET | `/api/parent/pengumuman` | `{ pengumuman, stats }` |
| POST | `/api/parent/pengumuman/:id/read` | objek |
| GET | `/api/parent/approval/pending` | **list** + field `count` |
| POST | `/api/parent/approval/:absensiId` | `{ action: approve\|reject, note }` |

`/api/parent/pengumuman` dan `/api/parent/anak/:id/spp` juga boleh diakses oleh
siswa **untuk dirinya sendiri**, karena dashboard siswa memanggil kedua route itu.
Permintaan ke data siswa lain ditolak 403.

Menolak permohonan izin akan mencatat absensi hari tersebut sebagai `alpha`.

### Tugas
| Method | Path |
|---|---|
| GET/POST | `/api/tugas/guru/tugas` |
| GET/PUT/DELETE | `/api/tugas/guru/tugas/:id` |
| POST | `/api/tugas/guru/tugas/submission/:id/grade` |
| GET | `/api/tugas/siswa/tugas` · `/api/tugas/siswa/tugas/:id/submission` |
| POST | `/api/tugas/siswa/tugas/:id/submit` |
| GET | `/api/tugas/orang-tua/anak/:anakId/tugas` |

### SPP / Keuangan
| Method | Path |
|---|---|
| GET | `/api/spp/parent/tagihan` → `{ anak, tagihan, stats_per_anak }` |
| GET/POST | `/api/spp/parent/pembayaran` |
| POST | `/api/spp/upload-bukti` → `{ url }` *(multipart, field `bukti`)* |
| GET/POST/PUT | `/api/spp/admin/jenis-pembayaran` |
| POST | `/api/spp/admin/tagihan/generate-massal` |
| POST | `/api/spp/admin/tagihan/generate-all` |
| GET | `/api/spp/admin/tagihan` |
| GET | `/api/spp/admin/pembayaran/pending` → list + `count` |
| POST | `/api/spp/admin/pembayaran/:id/verify` |
| GET | `/api/spp/admin/laporan?bulan=&tahun=` |

Alur pembayaran: orang tua mengunggah bukti → status tagihan menjadi
`menunggu_verifikasi` → admin menyetujui → tagihan `lunas` bila akumulasi
pembayaran yang disetujui sudah menutup `nominal_akhir`. Penolakan mengembalikan
tagihan ke `belum_bayar`. Generate tagihan memakai `INSERT IGNORE`, jadi aman
dijalankan berulang (tagihan yang sudah ada dilewati, bukan diduplikasi).

### Admin
| Method | Path |
|---|---|
| GET/POST/PUT/DELETE | `/api/admin/guru` |
| GET/POST/PUT/DELETE | `/api/admin/mapel` |
| GET/POST/DELETE | `/api/admin/guru-mapel` |
| GET/POST/PUT/DELETE | `/api/admin/kelas` |
| GET/POST/PUT/DELETE | `/api/admin/siswa` (filter `kelas_id`, `tingkat`, `status`, `search`) |
| GET | `/api/admin/siswa/:id` |
| GET/PUT | `/api/admin/schedule/config` |
| POST | `/api/admin/schedule/generate` |
| GET | `/api/admin/schedule/kelas/:kelasId?hari=` |
| PUT | `/api/admin/schedule/:id` |
| DELETE | `/api/admin/schedule/manual/:id` · `/api/admin/schedule/kelas/:kelasId` |
| GET/POST/DELETE | `/api/admin/holidays` |
| GET/POST/DELETE | `/api/admin/pengumuman` |
| GET/POST | `/api/admin/orang-tua` (+ `/:id/anak` untuk penautan) |
| GET | `/api/admin/dashboard` |

Membuat guru/siswa/orang tua sekaligus membuat akun login di tabel `users`
dalam satu transaksi. Menghapusnya juga menghapus akunnya.

## 7. Generator jadwal

`POST /api/admin/schedule/generate` membangun slot waktu per kelas dari konfigurasi:

```json
{
  "startTime": "07:00",
  "lessonDuration": 30,
  "breaks": [{ "start": "09:30", "end": "09:45" }, { "start": "11:45", "end": "12:30" }],
  "endTimeLower": "13:30",
  "endTimeUpper": "14:30",
  "upacaraDay": "Senin",
  "upacaraDuration": 60
}
```

- `endTimeLower` dipakai untuk tingkat 1–3, `endTimeUpper` untuk tingkat 4 ke atas.
- Jam istirahat dilewati, hari upacara mendapat satu slot khusus di awal.
- Mapel dibagikan proporsional terhadap `mapel.jam_per_pekan`.
- Guru dipilih dari `guru_mapel` dan **tidak akan dijadwalkan bentrok** dengan
  kelas lain pada hari dan jam yang sama.
- Slot yang pernah diubah lewat `PUT /api/admin/schedule/:id` ditandai
  `is_manual = 1` dan **tidak ditimpa** saat generate ulang.
- Slot yang tidak mendapat guru tetap dibuat dengan keterangan `Belum terisi`
  agar bisa diisi manual dari aplikasi.

## 8. File unggahan

Disimpan di `uploads/{tugas,bukti,logo}` dan dilayani di `/uploads/...`.
Batas 10 MB per file. Ekstensi lampiran tugas: pdf, doc(x), xls(x), ppt(x),
jpg, jpeg, png, zip, rar, txt. Bukti bayar: jpg, jpeg, png, pdf, webp, heic.

Response upload mengembalikan URL absolut berbasis `BASE_URL`, jadi `BASE_URL`
harus ikut diubah bila alamat server berubah.

## 9. Mengubah alamat server di aplikasi

Semua base URL di aplikasi Flutter berasal dari satu file:
`lib/config/api_config.dart`. Ubah `kApiHost` di sana, lalu build ulang.

## 10. Catatan operasional

- Zona waktu service diset `Asia/Jakarta`; absensi memakai tanggal/jam server.
- Kolom `DATE`/`DATETIME` dikembalikan sebagai string (`dateStrings`) agar
  `DateTime.parse()` di aplikasi tidak bergeser zona waktu.
- Password disimpan sebagai hash bcrypt (10 rounds).
- MySQL di server memakai kebijakan password MEDIUM; password user database
  harus memuat huruf besar, huruf kecil, angka, dan simbol.
