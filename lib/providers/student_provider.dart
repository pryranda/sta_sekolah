import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/student_service.dart';

class StudentProvider with ChangeNotifier {
  // Data Profile
  String _nama = '';
  String _nis = '';
  String _email = '';
  String _kelas = '';  // ✅ Ini yang kosong
  String _tahunAjaran = '';
  String _semester = '';
  String _waliKelas = '';
  String _fotoUrl = '';
  
  bool _isLoading = false;
  bool _isLoaded = false;

  // Getters
  String get nama => _nama;
  String get nis => _nis;
  String get email => _email;
  String get kelas => _kelas;  // ✅ Getter untuk kelas
  String get tahunAjaran => _tahunAjaran;
  String get semester => _semester;
  String get waliKelas => _waliKelas;
  String get fotoUrl => _fotoUrl;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  // Load profile siswa
  Future<void> loadProfile() async {
    if (_isLoaded) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // Fetch from API
      final profileData = await StudentService.getProfile(token);
      
      if (profileData != null) {
        _updateFromData(profileData);
        await StudentService.cacheProfile(profileData);
      } else {
        // Fallback to cache
        final cachedData = await StudentService.getCachedProfile();
        if (cachedData != null) {
          _updateFromData(cachedData);
        }
      }
    } catch (e) {
      print('Error loading student profile: $e');
      // Try cache
      final cachedData = await StudentService.getCachedProfile();
      if (cachedData != null) {
        _updateFromData(cachedData);
      }
    } finally {
      _isLoading = false;
      _isLoaded = true;
      notifyListeners();
    }
  }

  void _updateFromData(Map<String, dynamic> data) {
    _nama = data['nama'] ?? _nama;
    _nis = data['nis'] ?? _nis;
    _email = data['email'] ?? _email;
    _kelas = data['nama_kelas'] ?? data['kelas'] ?? _kelas;  // ✅ Handle kedua field
    _tahunAjaran = data['tahun_ajaran'] ?? _tahunAjaran;
    _semester = data['semester']?.toString() ?? _semester;
    _waliKelas = data['wali_kelas'] ?? _waliKelas;
    _fotoUrl = data['foto_url'] ?? _fotoUrl;
  }
}