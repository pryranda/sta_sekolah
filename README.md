# STA Sekolah (`sta_sekolah`)

Aplikasi manajemen sekolah multi-tenant berbasis **Flutter** (Android, iOS, Web) dengan backend **Node.js + Express + MySQL 8** di folder [`backend/`](backend/).

Server API aktif: **`http://10.0.0.39:5001/api`**

---

## Peran & Fitur Utama

| Peran | Akses & Fitur Utama |
|---|---|
| **Siswa** (`siswa`) | Dashboard siswa, jadwal pelajaran, absensi GPS (check-in/check-out/izin), tugas & pengumpulan lampiran, nilai, pengumuman, dan tagihan SPP |
| **Guru** (`guru`) | Dashboard guru, jadwal mengajar, absensi guru, absensi siswa per kelas, pembuatan tugas & penilaian submission, serta input nilai |
| **Orang Tua** (`orang_tua`) | Dashboard pemantauan anak, persetujuan izin absensi (`approval`), jadwal, absensi, nilai, tugas, pengumuman, profil, dan pembayaran/upload bukti SPP |
| **Admin Sekolah** (`admin`) | Manajemen guru, mapel, pemetaan guru-mapel, kelas, siswa (termasuk **upload massal CSV/Excel** di panel web admin), generator & editor jadwal pelajaran otomatis, hari libur, pengumuman, pengaturan sekolah (identitas, logo, jam masuk/pulang, koordinat & radius GPS), serta verifikasi & laporan keuangan SPP |
| **Admin Aplikasi** (`superadmin`) | Manajemen multi-sekolah (buat sekolah baru beserta admin pertamanya, ubah, dan hapus sekolah) |

---

## Struktur Repositori

```text
sta_sekolah/
├── lib/
│   ├── config/
│   │   └── api_config.dart        # Konfigurasi terpusat host & base URL API
│   ├── providers/                 # State management (SchoolProvider, StudentProvider)
│   ├── services/                  # Klien REST API (ApiService, SchoolService, StudentService)
│   ├── widgets/                   # Komponen bersama (responsive layout, logo picker, dialog pembayaran)
│   ├── screens/                   # Layar per peran (admin, superadmin, teacher, student, parent)
│   └── main.dart                  # Entry point, tema Material 3, locale id_ID, dan routing
├── backend/
│   ├── public/admin/              # Panel Web Admin (HTML/CSS/JS tanpa Flutter)
│   └── ...                        # Backend Node.js + Express + MySQL (lihat backend/README.md)
├── web/                           # Aset dan konfigurasi Flutter Web
├── android/                       # Konfigurasi proyek Android
├── ios/                           # Konfigurasi proyek iOS
└── pubspec.yaml                   # Dependensi Flutter (Dart SDK ^3.12.2)
```

---

## Konfigurasi Server API

Semua endpoint REST dan URL file unggahan pada aplikasi Flutter diatur terpusat di [`lib/config/api_config.dart`](lib/config/api_config.dart):

```dart
const String kApiHost = 'http://10.0.0.39:5001';
const String kApiBaseUrl = '$kApiHost/api';
const String kApiUploadsUrl = '$kApiHost/uploads';
```

Jika alamat server backend berubah:
1. Perbarui `kApiHost` di [`lib/config/api_config.dart`](lib/config/api_config.dart).
2. Perbarui juga `BASE_URL` di [`backend/src/config.js`](backend/src/config.js) dan [`backend/deploy/sta-api.service`](backend/deploy/sta-api.service) agar URL hasil unggahan dari backend ikut sesuai.
3. Build ulang aplikasi Flutter.

---

## Menjalankan Aplikasi

### 1. Instal dependensi

```bash
flutter pub get
```

### 2. Menjalankan di Web (Development / Build Release)

Menjalankan mode debug langsung di Chrome:

```bash
flutter run -d chrome
```

Atau build versi release dan sajikan folder hasil build (`build/web`):

```bash
flutter build web --release
cd build/web && python3 -m http.server 8080
```

Lalu buka `http://localhost:8080` di browser (tekan **Cmd + Shift + R** / hard refresh jika browser masih menyimpan service worker lama).

### 3. Menjalankan di Android / iOS

```bash
flutter run
```

Catatan HTTP cleartext (`http://10.0.0.39:5001`):
- **Android**: `android:usesCleartextTraffic="true"` sudah diaktifkan di [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml).
- **iOS**: [`ios/Runner/Info.plist`](ios/Runner/Info.plist) belum menyertakan pengecualian `NSAppTransportSecurity` (`NSAllowsArbitraryLoads`). Untuk build iOS dengan endpoint HTTP non-HTTPS, tambahkan konfigurasi ATS atau gunakan HTTPS.

---

## Panel Web Admin (Tanpa Flutter)

Untuk kebutuhan admin sekolah (upload massal siswa/guru/mapel/orang tua via CSV atau copy-paste Excel, kelola kelas, jadwal, pengumuman, verifikasi SPP, dan pengaturan sekolah), tersedia **Panel Web Admin** ringan (HTML/CSS/JS) di [`backend/public/admin/`](backend/public/admin/).

- Saat backend Express berjalan, buka langsung: **`http://10.0.0.39:5001/admin/`**
- Atau sajikan secara terpisah untuk testing lokal:

```bash
python3 -m http.server 8082 --directory backend/public/admin
```

Lalu buka `http://localhost:8082` (default mengarah ke `http://10.0.0.39:5001/api`, dapat diubah di form login pada bagian **Pengaturan Server API**).

---

## Backend REST API

Dokumentasi lengkap struktur backend, skema database MySQL, multi-tenant, deployment `systemd`, dan daftar seluruh endpoint tersedia di [`backend/README.md`](backend/README.md).
