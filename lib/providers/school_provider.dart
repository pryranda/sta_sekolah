import 'package:flutter/foundation.dart';
import '../services/school_service.dart';

class SchoolProvider with ChangeNotifier {
  // Default values (fallback jika API gagal)
  String _namaSekolah = 'Daarul Jannah';
  String _alamatSekolah = '';
  String _teleponSekolah = '';
  String _emailSekolah = '';
  String _websiteSekolah = '';
  String _logoUrl = '';
  double _latitude = -6.50159536;
  double _longitude = 106.83357635;
  double _radiusMaksimal = 600;
  
  bool _isLoading = false;
  bool _isLoaded = false;

  // Getters
  String get namaSekolah => _namaSekolah;
  String get alamatSekolah => _alamatSekolah;
  String get teleponSekolah => _teleponSekolah;
  String get emailSekolah => _emailSekolah;
  String get websiteSekolah => _websiteSekolah;
  String get logoUrl => _logoUrl;
  double get latitude => _latitude;
  double get longitude => _longitude;
  double get radiusMaksimal => _radiusMaksimal;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  // Load school data dari API atau Cache
  Future<void> loadSchoolData() async {
    if (_isLoaded) return; // Jangan load ulang kalau sudah pernah load
    
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Coba fetch dari API
      final schoolData = await SchoolService.getSchoolInfo();
      
      if (schoolData != null) {
        _updateFromData(schoolData);
        await SchoolService.cacheSchoolInfo(schoolData); // Simpan ke cache
      } else {
        // 2. Jika API gagal, pakai cache
        final cachedData = await SchoolService.getCachedSchoolInfo();
        if (cachedData != null) {
          _updateFromData(cachedData);
        }
      }
    } catch (e) {
      print('Error loading school data: $e');
      // 3. Jika error, pakai cache
      final cachedData = await SchoolService.getCachedSchoolInfo();
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
    _namaSekolah = data['nama'] ?? _namaSekolah;
    _alamatSekolah = data['alamat'] ?? _alamatSekolah;
    _teleponSekolah = data['telepon'] ?? _teleponSekolah;
    _emailSekolah = data['email'] ?? _emailSekolah;
    _websiteSekolah = data['website'] ?? _websiteSekolah;
    _logoUrl = data['logo_url'] ?? _logoUrl;
    _latitude = double.tryParse(data['latitude']?.toString() ?? '') ?? _latitude;
    _longitude = double.tryParse(data['longitude']?.toString() ?? '') ?? _longitude;
    _radiusMaksimal = double.tryParse(data['radius_maksimal']?.toString() ?? '') ?? _radiusMaksimal;
  }
}