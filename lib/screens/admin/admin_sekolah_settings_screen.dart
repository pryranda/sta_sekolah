import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/school_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/school_logo_picker.dart';

/// Form Pengaturan Sekolah untuk Admin Sekolah:
/// identitas sekolah, logo, jam masuk/pulang, dan lokasi/radius absensi.
class AdminSekolahSettingsScreen extends StatefulWidget {
  const AdminSekolahSettingsScreen({super.key});

  @override
  State<AdminSekolahSettingsScreen> createState() => _AdminSekolahSettingsScreenState();
}

class _AdminSekolahSettingsScreenState extends State<AdminSekolahSettingsScreen> {
  static const Color primaryBlue = Color(0xFF1976D2);

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGettingLocation = false;
  String? _loadError;
  String _sekolahId = '';

  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _teleponController = TextEditingController();
  final _emailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _jamMasukController = TextEditingController(text: '07:00:00');
  final _jamPulangController = TextEditingController(text: '13:30:00');
  final _latitudeController = TextEditingController(text: '0');
  final _longitudeController = TextEditingController(text: '0');
  final _radiusController = TextEditingController(text: '150');

  Uint8List? _pickedLogoBytes;
  String? _pickedLogoName;

  @override
  void initState() {
    super.initState();
    _loadSekolah();
  }

  @override
  void dispose() {
    for (final c in [
      _namaController,
      _alamatController,
      _teleponController,
      _emailController,
      _websiteController,
      _logoUrlController,
      _jamMasukController,
      _jamPulangController,
      _latitudeController,
      _longitudeController,
      _radiusController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSekolah() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson != null) {
        final user = jsonDecode(userJson) as Map<String, dynamic>;
        _sekolahId = (user['sekolah_id'] ?? '').toString();
      }

      final result = await ApiService.getSekolahInfo(sekolahId: _sekolahId);
      if (!mounted) return;

      if (result['success'] == true && result['data'] is Map<String, dynamic>) {
        final data = result['data'] as Map<String, dynamic>;
        _sekolahId = (data['id'] ?? _sekolahId).toString();
        _namaController.text = (data['nama'] ?? '').toString();
        _alamatController.text = (data['alamat'] ?? '').toString();
        _teleponController.text = (data['telepon'] ?? '').toString();
        _emailController.text = (data['email'] ?? '').toString();
        _websiteController.text = (data['website'] ?? '').toString();
        _logoUrlController.text = (data['logo_url'] ?? '').toString();
        _jamMasukController.text = _normalizeTime(data['jam_masuk'], '07:00:00');
        _jamPulangController.text = _normalizeTime(data['jam_pulang'], '13:30:00');
        _latitudeController.text = (data['latitude'] ?? '0').toString();
        _longitudeController.text = (data['longitude'] ?? '0').toString();
        _radiusController.text = (data['radius_maksimal'] ?? '150').toString();

        setState(() => _isLoading = false);
      } else {
        setState(() {
          _loadError = result['message']?.toString() ?? 'Gagal memuat data sekolah';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Gagal memuat data sekolah: $e';
        _isLoading = false;
      });
    }
  }

  String _normalizeTime(dynamic value, String fallback) {
    final s = value?.toString().trim() ?? '';
    if (s.isEmpty) return fallback;
    if (s.length == 5) return '$s:00';
    return s;
  }

  String _displayTime(String value) {
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

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
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() {
        controller.text = '$hh:$mm:00';
      });
    }
  }

  Future<void> _ambilLokasiSaatIni() async {
    setState(() => _isGettingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Layanan lokasi tidak aktif di perangkat/browser.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak.');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _latitudeController.text = pos.latitude.toStringAsFixed(7);
        _longitudeController.text = pos.longitude.toStringAsFixed(7);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koordinat lokasi saat ini berhasil diambil'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak bisa mengambil lokasi: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String logoUrl = _logoUrlController.text.trim();

      if (_pickedLogoBytes != null) {
        final uploadResult = await ApiService.uploadLogoSekolah(
          _pickedLogoBytes!,
          _pickedLogoName ?? 'logo.png',
        );
        if (uploadResult['success'] == true && uploadResult['data'] != null) {
          logoUrl = (uploadResult['data']['url'] ?? '').toString();
          _logoUrlController.text = logoUrl;
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

      final infoPayload = <String, dynamic>{
        'nama': _namaController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'telepon': _teleponController.text.trim(),
        'email': _emailController.text.trim(),
        'website': _websiteController.text.trim(),
        'logo_url': logoUrl,
        'jam_masuk': _normalizeTime(_jamMasukController.text, '07:00:00'),
        'jam_pulang': _normalizeTime(_jamPulangController.text, '13:30:00'),
      };
      if (_sekolahId.isNotEmpty) {
        infoPayload['sekolah_id'] = _sekolahId;
      }

      final infoResult = await ApiService.updateSekolahInfo(infoPayload);
      if (infoResult['success'] != true) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(infoResult['message']?.toString() ?? 'Gagal menyimpan info sekolah'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final lokasiPayload = <String, dynamic>{
        'latitude': double.tryParse(_latitudeController.text.trim()) ?? 0,
        'longitude': double.tryParse(_longitudeController.text.trim()) ?? 0,
        'radius_maksimal': int.tryParse(_radiusController.text.trim()) ?? 150,
      };
      if (_sekolahId.isNotEmpty) {
        lokasiPayload['sekolah_id'] = _sekolahId;
      }

      final lokasiResult = await ApiService.updateLokasiSekolah(lokasiPayload);
      if (!mounted) return;

      if (lokasiResult['success'] != true) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Info sekolah tersimpan, namun lokasi gagal diperbarui: ${lokasiResult['message'] ?? ''}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await context.read<SchoolProvider>().loadSchoolProfile(forceReload: true);

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan sekolah berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengaturan Sekolah',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: _isSaving ? null : _loadSekolah,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _buildErrorState()
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ResponsiveCenter(
                      maxWidth: 920,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _sectionTitle('Logo Sekolah', Icons.image_outlined),
                          const SizedBox(height: 10),
                          SchoolLogoPicker(
                            logoUrlController: _logoUrlController,
                            pickedBytes: _pickedLogoBytes,
                            pickedFileName: _pickedLogoName,
                            accentColor: primaryBlue,
                            onPicked: (bytes, name) => setState(() {
                              _pickedLogoBytes = bytes;
                              _pickedLogoName = name;
                            }),
                            onClear: () => setState(() {
                              _pickedLogoBytes = null;
                              _pickedLogoName = null;
                              _logoUrlController.clear();
                            }),
                            onUrlChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: 22),

                          _sectionTitle('Identitas Sekolah', Icons.apartment),
                          const SizedBox(height: 10),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _namaController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nama Sekolah *',
                                      prefixIcon: Icon(Icons.school_outlined),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Nama sekolah wajib diisi'
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _alamatController,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                      labelText: 'Alamat Lengkap',
                                      prefixIcon: Icon(Icons.location_on_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final telField = TextFormField(
                                        controller: _teleponController,
                                        keyboardType: TextInputType.phone,
                                        decoration: const InputDecoration(
                                          labelText: 'Telepon',
                                          prefixIcon: Icon(Icons.phone_outlined),
                                        ),
                                      );
                                      final emailField = TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: const InputDecoration(
                                          labelText: 'Email',
                                          prefixIcon: Icon(Icons.mail_outline),
                                        ),
                                        validator: (v) {
                                          final val = v?.trim() ?? '';
                                          if (val.isNotEmpty && !val.contains('@')) {
                                            return 'Format email tidak valid';
                                          }
                                          return null;
                                        },
                                      );

                                      if (constraints.maxWidth >= 600) {
                                        return Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: telField),
                                            const SizedBox(width: 12),
                                            Expanded(child: emailField),
                                          ],
                                        );
                                      }
                                      return Column(
                                        children: [
                                          telField,
                                          const SizedBox(height: 14),
                                          emailField,
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _websiteController,
                                    keyboardType: TextInputType.url,
                                    decoration: const InputDecoration(
                                      labelText: 'Website',
                                      hintText: 'https://sekolah.sch.id',
                                      prefixIcon: Icon(Icons.language),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          _sectionTitle('Jam Operasional', Icons.access_time),
                          const SizedBox(height: 10),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildTimeField(
                                      label: 'Jam Masuk',
                                      controller: _jamMasukController,
                                      icon: Icons.login,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTimeField(
                                      label: 'Jam Pulang',
                                      controller: _jamPulangController,
                                      icon: Icons.logout,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          _sectionTitle('Lokasi & Radius Absensi', Icons.my_location),
                          const SizedBox(height: 10),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Digunakan untuk memvalidasi jarak saat siswa melakukan absensi. '
                                    'Isi radius dengan 0 jika tidak ingin membatasi jarak.',
                                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 14),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final latField = TextFormField(
                                        controller: _latitudeController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Latitude',
                                          prefixIcon: Icon(Icons.explore_outlined),
                                        ),
                                      );
                                      final lngField = TextFormField(
                                        controller: _longitudeController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Longitude',
                                          prefixIcon: Icon(Icons.explore_outlined),
                                        ),
                                      );
                                      final radField = TextFormField(
                                        controller: _radiusController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Radius (meter)',
                                          prefixIcon: Icon(Icons.radar),
                                        ),
                                      );

                                      if (constraints.maxWidth >= 680) {
                                        return Row(
                                          children: [
                                            Expanded(child: latField),
                                            const SizedBox(width: 12),
                                            Expanded(child: lngField),
                                            const SizedBox(width: 12),
                                            Expanded(child: radField),
                                          ],
                                        );
                                      }
                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: latField),
                                              const SizedBox(width: 12),
                                              Expanded(child: lngField),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          radField,
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: _isGettingLocation ? null : _ambilLokasiSaatIni,
                                    icon: _isGettingLocation
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.gps_fixed, size: 18),
                                    label: Text(
                                      _isGettingLocation
                                          ? 'Mengambil lokasi...'
                                          : 'Ambil Lokasi GPS Saat Ini',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryBlue,
                                      side: BorderSide(color: primaryBlue.withOpacity(0.4)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _simpan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                _isSaving ? 'Menyimpan Pengaturan...' : 'Simpan Pengaturan Sekolah',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pickTime(controller, label),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.schedule, size: 18),
        ),
        child: Text(
          _displayTime(controller.text),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: primaryBlue),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      );

  Widget _buildErrorState() => Center(
        child: ResponsiveCenter(
          maxWidth: 460,
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 52, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadSekolah,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
