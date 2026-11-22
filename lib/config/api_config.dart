/// Konfigurasi alamat backend.
///
/// Semua service dan screen mengambil base URL dari sini, jadi untuk
/// memindahkan server cukup ubah satu baris di bawah ini.
///
/// Contoh nilai lain:
///   - Emulator Android ke server lokal : http://10.0.2.2:5001/api
///   - iOS Simulator / desktop          : http://localhost:5001/api
library;

/// Host + port backend, tanpa `/api` dan tanpa garis miring di akhir.
const String kApiHost = 'http://192.168.25.61:5001';

/// Base URL seluruh endpoint REST.
const String kApiBaseUrl = '$kApiHost/api';

/// Base URL file yang diunggah (bukti pembayaran, lampiran tugas, logo).
const String kApiUploadsUrl = '$kApiHost/uploads';
