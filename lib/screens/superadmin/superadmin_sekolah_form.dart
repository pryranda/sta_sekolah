// lib/screens/superadmin/superadmin_sekolah_form.dart
//
// Form pendaftaran / perubahan sekolah untuk Admin Aplikasi.
// Saat mendaftarkan sekolah baru, akun Admin Sekolah pertamanya dibuat
// sekaligus — tanpa itu sekolah baru tidak bisa dipakai siapa pun.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/school_logo_picker.dart';

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
  late final TextEditingController _logoUrl;
  late final TextEditingController _jamMasuk;
  late final TextEditingController _jamPulang;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _radius;

  Uint8List? _pickedLogoBytes;
  String? _pickedLogoName;

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
    _logoUrl = TextEditingController(text: s?['logo_url']?.toString() ?? '');
    _jamMasuk = TextEditingController(text: _normalizeTime(s?['jam_masuk'], '07:00:00'));
    _jamPulang = TextEditingController(text: _normalizeTime(s?['jam_pulang'], '13:30:00'));
    _latitude = TextEditingController(text: s?['latitude']?.toString() ?? '');
    _longitude = TextEditingController(text: s?['longitude']?.toString() ?? '');
    _radius = TextEditingController(text: s?['radius_maksimal']?.toString() ?? '150');
  }

  String _normalizeTime(dynamic value, String fallback) {
    final v = value?.toString().trim() ?? '';
    if (v.isEmpty) return fallback;
    if (v.length == 5) return '$v:00';
    return v;
  }

  String _displayTime(String value) => value.length >= 5 ? value.substring(0, 5) : value;

  Future<void> _pickTime(TextEditingController controller, String label) async {
    final parts = controller.text.split(':');
    final initialHour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 7;
    final initialMinute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

    final picked = await showTimePicker(
      context: context,
      helpText: label,
      initialTime: TimeOfDay(
        hour: initialHour.clamp(0, 23),
        minute: initialMinute.clamp(0, 59),
      ),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nama, _alamat, _telepon, _email, _website, _logoUrl,
      _jamMasuk, _jamPulang, _latitude, _longitude, _radius,
      _adminUsername, _adminPassword, _adminNama,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    String logoUrl = _logoUrl.text.trim();
    if (_pickedLogoBytes != null) {
      final uploadResult = await ApiService.uploadLogoSekolah(
        _pickedLogoBytes!,
        _pickedLogoName ?? 'logo.png',
      );
      if (uploadResult['success'] == true && uploadResult['data'] != null) {
        logoUrl = (uploadResult['data']['url'] ?? '').toString();
        _logoUrl.text = logoUrl;
        _pickedLogoBytes = null;
        _pickedLogoName = null;
      } else {
        if (!mounted) return;
        setState(() => _isSaving = false);
        final statusCode = uploadResult['statusCode'];
        final msg = statusCode == 404
            ? 'Endpoint upload logo belum aktif di server API. Hapus file terpilih dan isi URL Logo secara manual, atau deploy ulang backend.'
            : (uploadResult['message']?.toString() ?? 'Gagal mengunggah logo');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
        return;
      }
    }

    final data = <String, dynamic>{
      'nama': _nama.text.trim(),
      'alamat': _alamat.text.trim(),
      'telepon': _telepon.text.trim(),
      'email': _email.text.trim(),
      'website': _website.text.trim(),
      'logo_url': logoUrl,
      'jam_masuk': _normalizeTime(_jamMasuk.text, '07:00:00'),
      'jam_pulang': _normalizeTime(_jamPulang.text, '13:30:00'),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ResponsiveCenter(
            maxWidth: 860,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _seksi('Logo Sekolah'),
                SchoolLogoPicker(
                  logoUrlController: _logoUrl,
                  pickedBytes: _pickedLogoBytes,
                  pickedFileName: _pickedLogoName,
                  accentColor: primary,
                  onPicked: (bytes, name) => setState(() {
                    _pickedLogoBytes = bytes;
                    _pickedLogoName = name;
                  }),
                  onClear: () => setState(() {
                    _pickedLogoBytes = null;
                    _pickedLogoName = null;
                    _logoUrl.clear();
                  }),
                  onUrlChanged: () => setState(() {}),
                ),

                const SizedBox(height: 18),
                _seksi('Identitas Sekolah'),
                _field(_nama, 'Nama sekolah *', Icons.apartment, wajib: true),
                _field(_alamat, 'Alamat', Icons.place, baris: 2),
                _field(_telepon, 'Telepon', Icons.phone, tipe: TextInputType.phone),
                _field(_email, 'Email', Icons.mail, tipe: TextInputType.emailAddress),
                _field(_website, 'Website', Icons.language),

                const SizedBox(height: 18),
                _seksi('Jam Operasional'),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _pickTime(_jamMasuk, 'Jam Masuk'),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Jam Masuk',
                            prefixIcon: Icon(Icons.login),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          child: Text(
                            _displayTime(_jamMasuk.text),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _pickTime(_jamPulang, 'Jam Pulang'),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Jam Pulang',
                            prefixIcon: Icon(Icons.logout),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          child: Text(
                            _displayTime(_jamPulang.text),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

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
