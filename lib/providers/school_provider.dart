import 'package:flutter/foundation.dart';
import '../services/school_service.dart';

class SchoolProvider with ChangeNotifier {
  // Semua default kosong (tidak ada hardcode)
  String _idSekolah = '';
  String _namaSekolah = '';
  String _alamatSekolah = '';
  String _teleponSekolah = '';
  String _emailSekolah = '';
  String _websiteSekolah = '';
  String _logoUrl = '';
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _radiusMaksimal = 0.0;

  bool _isLoading = false;
  bool _isLoaded = false;

  // Getters
  String get idSekolah => _idSekolah;
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

  Future<void> loadSchoolProfile({bool forceReload = false}) async {
    if (forceReload) {
      _isLoaded = false;
      await SchoolService.clearCache();
    }
    await loadSchoolData();
  }

  Future<void> loadSchoolData() async {
    if (_isLoaded) return;

    _isLoading = true;
    notifyListeners();

    try {
      final schoolData = await SchoolService.getSchoolInfo();
      if (schoolData != null) {
        _updateFromData(schoolData);
        await SchoolService.cacheSchoolInfo(schoolData);
      } else {
        final cachedData = await SchoolService.getCachedSchoolInfo();
        if (cachedData != null) {
          _updateFromData(cachedData);
        }
      }
    } catch (e) {
      print('Error loading school data: $e');
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
    _idSekolah = data['id'] ?? '';
    _namaSekolah = data['nama'] ?? '';
    _alamatSekolah = data['alamat'] ?? '';
    _teleponSekolah = data['telepon'] ?? '';
    _emailSekolah = data['email'] ?? '';
    _websiteSekolah = data['website'] ?? '';
    _logoUrl = data['logo_url'] ?? '';
    _latitude = double.tryParse(data['latitude']?.toString() ?? '') ?? 0.0;
    _longitude = double.tryParse(data['longitude']?.toString() ?? '') ?? 0.0;
    _radiusMaksimal = double.tryParse(data['radius_maksimal']?.toString() ?? '') ?? 0.0;
  }
}