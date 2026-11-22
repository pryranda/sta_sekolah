// lib/screens/superadmin/superadmin_sekolah_form.dart
//
// Form pendaftaran / perubahan sekolah untuk Admin Aplikasi.
// Saat mendaftarkan sekolah baru, akun Admin Sekolah pertamanya dibuat
// sekaligus — tanpa itu sekolah baru tidak bisa dipakai siapa pun.

import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class SuperadminSekolahForm extends StatefulWidget {
  /// null = tambah sekolah baru, selain itu = ubah sekolah.
  final Map<String, dynamic>? sekolah;

  const SuperadminSekolahForm({Key? key, this.sekolah}) : super(key: key);

  @override
  State<SuperadminSekolahForm> createState() => _SuperadminSekolahFormState();
}

class _SuperadminSekolahFormState extends State<SuperadminSekolahForm> {
  static const Color primary = Color(0xFF3F51B5);

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late final TextEditingController _nama;
  late final TextEditingController _alamat;
  late final TextEditingController _telepon;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _radius;

  final _adminUsername = TextEditingController();
  final _adminPassword = TextEditingController();
  final _adminNama = TextEditingController();
  bool _sembunyiSandi = true;

  bool get _isEdit => widget.sekolah != null;

  @override
  void initState() {
    super.initState();
    final s = widget.sekolah;
    _nama = TextEditingController(text: s?['nama']?.toString() ?? '');
    _alamat = TextEditingController(text: s?['alamat']?.toString() ?? '');
    _telepon = TextEditingController(text: s?['telepon']?.toString() ?? '');
    _email = TextEditingController(text: s?['email']?.toString() ?? '');
    _website = TextEditingController(text: s?['website']?.toString() ?? '');
    _latitude = TextEditingController(text: s?['latitude']?.toString() ?? '');
    _longitude = TextEditingController(text: s?['longitude']?.toString() ?? '');
    _radius = TextEditingController(text: s?['radius_maksimal']?.toString() ?? '150');
  }

  @override
  void dispose() {
    for (final c in [
      _nama, _alamat, _telepon, _email, _website, _latitude, _longitude, _radius,
      _adminUsername, _adminPassword, _adminNama,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = <String, dynamic>{
      'nama': _nama.text.trim(),
      'alamat': _alamat.text.trim(),
      'telepon': _telepon.text.trim(),
      'email': _email.text.trim(),
      'website': _website.text.trim(),
      'latitude': double.tryParse(_latitude.text.trim()) ?? 0,
      'longitude': double.tryParse(_longitude.text.trim()) ?? 0,
      'radius_maksimal': int.tryParse(_radius.text.trim()) ?? 150,
    };

    Map<String, dynamic> result;
    if (_isEdit) {
      result = await ApiService.updateSekolah(widget.sekolah!['id'].toString(), data);
    } else {
      data['admin_username'] = _adminUsername.text.trim();
      data['admin_password'] = _adminPassword.text;
      data['admin_nama'] = _adminNama.text.trim();
      result = await ApiService.createSekolah(data);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    final berhasil = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? (berhasil ? 'Tersimpan' : 'Gagal')),
        backgroundColor: berhasil ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );

    if (berhasil) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah Sekolah' : 'Tambah Sekolah',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _seksi('Identitas Sekolah'),
            _field(_nama, 'Nama sekolah *', Icons.apartment, wajib: true),
            _field(_alamat, 'Alamat', Icons.place, baris: 2),
            _field(_telepon, 'Telepon', Icons.phone, tipe: TextInputType.phone),
            _field(_email, 'Email', Icons.mail, tipe: TextInputType.emailAddress),
            _field(_website, 'Website', Icons.language),

            const SizedBox(height: 18),
            _seksi('Lokasi Absensi'),
            Text(
              'Dipakai untuk memvalidasi jarak saat siswa melakukan check-in. '
              'Kosongkan radius dengan 0 bila tidak ingin dibatasi.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _field(_latitude, 'Latitude', Icons.my_location,
                    tipe: const TextInputType.numberWithOptions(decimal: true, signed: true))),
                const SizedBox(width: 10),
                Expanded(child: _field(_longitude, 'Longitude', Icons.my_location,
                    tipe: const TextInputType.numberWithOptions(decimal: true, signed: true))),
              ],
            ),
            _field(_radius, 'Radius maksimal (meter)', Icons.adjust,
                tipe: TextInputType.number),

            if (!_isEdit) ...[
              const SizedBox(height: 18),
              _seksi('Akun Admin Sekolah'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Akun ini yang nanti mengelola guru, siswa, dan kelas di '
                        'sekolah tersebut. Tanpa akun ini sekolah belum bisa dipakai.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _field(_adminNama, 'Nama admin', Icons.person),
              _field(_adminUsername, 'Username admin *', Icons.account_circle, wajib: true),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _adminPassword,
                  obscureText: _sembunyiSandi,
                  decoration: InputDecoration(
                    labelText: 'Password admin *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_sembunyiSandi
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _sembunyiSandi = !_sembunyiSandi),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password wajib diisi';
                    if (v.length < 6) return 'Minimal 6 karakter';
                    return null;
                  },
                ),
              ),
            ],

            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _simpan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(_isSaving
                    ? 'Menyimpan...'
                    : (_isEdit ? 'Simpan Perubahan' : 'Daftarkan Sekolah')),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _seksi(String judul) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(width: 3, height: 18,
                decoration: BoxDecoration(
                    color: primary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(judul,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      );

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool wajib = false,
    int baris = 1,
    TextInputType? tipe,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          maxLines: baris,
          keyboardType: tipe,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          validator: wajib
              ? (v) => (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null
              : null,
        ),
      );
}
