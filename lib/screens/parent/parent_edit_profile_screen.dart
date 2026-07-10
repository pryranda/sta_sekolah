import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ParentEditProfileScreen extends StatefulWidget {
  const ParentEditProfileScreen({Key? key}) : super(key: key);

  @override
  State<ParentEditProfileScreen> createState() => _ParentEditProfileScreenState();
}

class _ParentEditProfileScreenState extends State<ParentEditProfileScreen> {
  static const String baseUrl = 'http://103.182.209.20:3000/api';
  
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Controllers untuk Ibu
  final _namaIbuController = TextEditingController();
  final _pekerjaanIbuController = TextEditingController();
  final _hpIbuController = TextEditingController();
  final _tahunLahirIbuController = TextEditingController();
  final _pendidikanIbuController = TextEditingController();
  final _penghasilanIbuController = TextEditingController();
  final _nikIbuController = TextEditingController();
  
  // Controllers untuk Ayah
  final _namaAyahController = TextEditingController();
  final _pekerjaanAyahController = TextEditingController();
  final _hpAyahController = TextEditingController();
  final _tahunLahirAyahController = TextEditingController();
  final _pendidikanAyahController = TextEditingController();
  final _penghasilanAyahController = TextEditingController();
  final _nikAyahController = TextEditingController();
  
  // Controllers untuk Wali (opsional)
  final _namaWaliController = TextEditingController();
  final _pekerjaanWaliController = TextEditingController();
  final _tahunLahirWaliController = TextEditingController();
  final _pendidikanWaliController = TextEditingController();
  final _penghasilanWaliController = TextEditingController();
  
  // Controllers umum
  final _alamatController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Dropdown values
  String? _selectedPendidikanIbu;
  String? _selectedPendidikanAyah;
  String? _selectedPendidikanWali;
  String? _selectedPenghasilanIbu;
  String? _selectedPenghasilanAyah;
  String? _selectedPenghasilanWali;
  
  final List<String> _pendidikanOptions = [
    'SD', 'SMP', 'SMA', 'D3', 'S1', 'S2', 'S3', 'Lainnya'
  ];
  
  final List<String> _penghasilanOptions = [
    'Tidak Berpenghasilan',
    'Rp. 500,000 - Rp. 999,999',
    'Rp. 1,000,000 - Rp. 1,999,999',
    'Rp. 2,000,000 - Rp. 4,999,999',
    'Rp. 5,000,000 - Rp. 9,999,999',
    'Rp. 10,000,000 - Rp. 19,999,999',
    'Rp. 20,000,000 - Rp. 49,999,999',
    'Rp. 50,000,000 - Rp. 99,999,999',
    'Rp. 100,000,000 atau lebih'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/parent/profile/detail'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        final profile = data['data'];
        setState(() {
          // Ibu
          _namaIbuController.text = profile['nama_ibu'] ?? '';
          _pekerjaanIbuController.text = profile['pekerjaan_ibu'] ?? '';
          _hpIbuController.text = profile['hp_ibu'] ?? '';
          _tahunLahirIbuController.text = profile['tahun_lahir_ibu']?.toString() ?? '';
          _selectedPendidikanIbu = profile['jenjang_pendidikan_ibu'];
          _selectedPenghasilanIbu = profile['penghasilan_ibu'];
          _nikIbuController.text = profile['nik_ibu'] ?? '';
          
          // Ayah
          _namaAyahController.text = profile['nama_ayah'] ?? '';
          _pekerjaanAyahController.text = profile['pekerjaan_ayah'] ?? '';
          _hpAyahController.text = profile['hp_ayah'] ?? '';
          _tahunLahirAyahController.text = profile['tahun_lahir_ayah']?.toString() ?? '';
          _selectedPendidikanAyah = profile['jenjang_pendidikan_ayah'];
          _selectedPenghasilanAyah = profile['penghasilan_ayah'];
          _nikAyahController.text = profile['nik_ayah'] ?? '';
          
          // Wali
          _namaWaliController.text = profile['nama_wali'] ?? '';
          _pekerjaanWaliController.text = profile['pekerjaan_wali'] ?? '';
          _tahunLahirWaliController.text = profile['tahun_lahir_wali']?.toString() ?? '';
          _selectedPendidikanWali = profile['jenjang_pendidikan_wali'];
          _selectedPenghasilanWali = profile['penghasilan_wali'];
          
          // Umum
          _alamatController.text = profile['alamat'] ?? '';
          _emailController.text = profile['email'] ?? '';
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error load profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.put(
        Uri.parse('$baseUrl/parent/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          // Ibu
          'nama_ibu': _namaIbuController.text.trim(),
          'pekerjaan_ibu': _pekerjaanIbuController.text.trim(),
          'hp_ibu': _hpIbuController.text.trim(),
          'tahun_lahir_ibu': _tahunLahirIbuController.text.isNotEmpty 
            ? int.tryParse(_tahunLahirIbuController.text) 
            : null,
          'jenjang_pendidikan_ibu': _selectedPendidikanIbu,
          'penghasilan_ibu': _selectedPenghasilanIbu,
          'nik_ibu': _nikIbuController.text.trim(),
          
          // Ayah
          'nama_ayah': _namaAyahController.text.trim(),
          'pekerjaan_ayah': _pekerjaanAyahController.text.trim(),
          'hp_ayah': _hpAyahController.text.trim(),
          'tahun_lahir_ayah': _tahunLahirAyahController.text.isNotEmpty 
            ? int.tryParse(_tahunLahirAyahController.text) 
            : null,
          'jenjang_pendidikan_ayah': _selectedPendidikanAyah,
          'penghasilan_ayah': _selectedPenghasilanAyah,
          'nik_ayah': _nikAyahController.text.trim(),
          
          // Wali
          'nama_wali': _namaWaliController.text.trim(),
          'pekerjaan_wali': _pekerjaanWaliController.text.trim(),
          'tahun_lahir_wali': _tahunLahirWaliController.text.isNotEmpty 
            ? int.tryParse(_tahunLahirWaliController.text) 
            : null,
          'jenjang_pendidikan_wali': _selectedPendidikanWali,
          'penghasilan_wali': _selectedPenghasilanWali,
          
          // Umum
          'alamat': _alamatController.text.trim(),
          'email': _emailController.text.trim(),
        }),
      );
      
      final data = jsonDecode(response.body);
      
      if (mounted) {
        if (data['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile berhasil diperbarui'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Gagal menyimpan profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error save profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan. Silakan coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF7BC8A4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save, size: 24),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7BC8A4)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Informasi Ibu
                  _buildSectionTitle('👩 Informasi Ibu'),
                  _buildTextField(_namaIbuController, 'Nama Ibu', Icons.person, required: true),
                  _buildTextField(_hpIbuController, 'No HP Ibu', Icons.phone, keyboardType: TextInputType.phone),
                  _buildTextField(_nikIbuController, 'NIK Ibu', Icons.credit_card, keyboardType: TextInputType.number),
                  _buildTextField(_pekerjaanIbuController, 'Pekerjaan Ibu', Icons.work),
                  _buildDropdownField(
                    'Pendidikan Ibu',
                    _selectedPendidikanIbu,
                    _pendidikanOptions,
                    (value) => setState(() => _selectedPendidikanIbu = value),
                    Icons.school,
                  ),
                  _buildDropdownField(
                    'Penghasilan Ibu',
                    _selectedPenghasilanIbu,
                    _penghasilanOptions,
                    (value) => setState(() => _selectedPenghasilanIbu = value),
                    Icons.attach_money,
                  ),
                  _buildTextField(_tahunLahirIbuController, 'Tahun Lahir Ibu', Icons.cake, keyboardType: TextInputType.number),
                  
                  const SizedBox(height: 24),
                  
                  // Informasi Ayah
                  _buildSectionTitle('👨 Informasi Ayah'),
                  _buildTextField(_namaAyahController, 'Nama Ayah', Icons.person, required: true),
                  _buildTextField(_hpAyahController, 'No HP Ayah', Icons.phone, keyboardType: TextInputType.phone),
                  _buildTextField(_nikAyahController, 'NIK Ayah', Icons.credit_card, keyboardType: TextInputType.number),
                  _buildTextField(_pekerjaanAyahController, 'Pekerjaan Ayah', Icons.work),
                  _buildDropdownField(
                    'Pendidikan Ayah',
                    _selectedPendidikanAyah,
                    _pendidikanOptions,
                    (value) => setState(() => _selectedPendidikanAyah = value),
                    Icons.school,
                  ),
                  _buildDropdownField(
                    'Penghasilan Ayah',
                    _selectedPenghasilanAyah,
                    _penghasilanOptions,
                    (value) => setState(() => _selectedPenghasilanAyah = value),
                    Icons.attach_money,
                  ),
                  _buildTextField(_tahunLahirAyahController, 'Tahun Lahir Ayah', Icons.cake, keyboardType: TextInputType.number),
                  
                  const SizedBox(height: 24),
                  
                  // Informasi Wali (Opsional)
                  _buildSectionTitle('👤 Informasi Wali (Opsional)'),
                  _buildTextField(_namaWaliController, 'Nama Wali', Icons.person),
                  _buildTextField(_pekerjaanWaliController, 'Pekerjaan Wali', Icons.work),
                  _buildDropdownField(
                    'Pendidikan Wali',
                    _selectedPendidikanWali,
                    _pendidikanOptions,
                    (value) => setState(() => _selectedPendidikanWali = value),
                    Icons.school,
                  ),
                  _buildDropdownField(
                    'Penghasilan Wali',
                    _selectedPenghasilanWali,
                    _penghasilanOptions,
                    (value) => setState(() => _selectedPenghasilanWali = value),
                    Icons.attach_money,
                  ),
                  _buildTextField(_tahunLahirWaliController, 'Tahun Lahir Wali', Icons.cake, keyboardType: TextInputType.number),
                  
                  const SizedBox(height: 24),
                  
                  // Informasi Umum
                  _buildSectionTitle('📧 Informasi Umum'),
                  _buildTextField(_alamatController, 'Alamat', Icons.location_on, maxLines: 3),
                  _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                  
                  const SizedBox(height: 32),
                  
                  // Tombol Simpan
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : const Icon(Icons.save, size: 20),
                    label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Perubahan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7BC8A4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A2B1C),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label + (required ? ' *' : ''),
          prefixIcon: Icon(icon, color: const Color(0xFF7BC8A4)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7BC8A4), width: 2),
          ),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: required && controller.text.trim().isEmpty
            ? (value) => '$label harus diisi'
            : null,
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF7BC8A4)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF7BC8A4), width: 2),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value != null && items.contains(value) ? value : null,
            isExpanded: true,
            hint: Text('Pilih $label'),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _namaIbuController.dispose();
    _pekerjaanIbuController.dispose();
    _hpIbuController.dispose();
    _tahunLahirIbuController.dispose();
    _pendidikanIbuController.dispose();
    _penghasilanIbuController.dispose();
    _nikIbuController.dispose();
    
    _namaAyahController.dispose();
    _pekerjaanAyahController.dispose();
    _hpAyahController.dispose();
    _tahunLahirAyahController.dispose();
    _pendidikanAyahController.dispose();
    _penghasilanAyahController.dispose();
    _nikAyahController.dispose();
    
    _namaWaliController.dispose();
    _pekerjaanWaliController.dispose();
    _tahunLahirWaliController.dispose();
    _pendidikanWaliController.dispose();
    _penghasilanWaliController.dispose();
    
    _alamatController.dispose();
    _emailController.dispose();
    
    super.dispose();
  }
}
