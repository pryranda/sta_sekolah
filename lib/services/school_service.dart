import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SchoolService {
  static const String baseUrl = 'http://103.182.209.20:3000/api';
  
  // Fetch data sekolah dari API
  static Future<Map<String, dynamic>?> getSchoolInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sekolah/info'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['data'] != null) {
          return data['data'];
        }
      }
    } catch (e) {
      print('Error fetching school info: $e');
    }
    return null;
  }
  
  // Simpan data sekolah ke cache (SharedPreferences)
  static Future<void> cacheSchoolInfo(Map<String, dynamic> schoolData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('school_info', jsonEncode(schoolData));
  }
  
  // Ambil data sekolah dari cache
  static Future<Map<String, dynamic>?> getCachedSchoolInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final schoolInfo = prefs.getString('school_info');
    if (schoolInfo != null) {
      return jsonDecode(schoolInfo);
    }
    return null;
  }
}