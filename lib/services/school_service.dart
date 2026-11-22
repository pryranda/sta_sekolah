import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class SchoolService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, dynamic>?> getSchoolInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final userJson = prefs.getString('user');
      final user = userJson != null ? jsonDecode(userJson) as Map<String, dynamic> : {};
      final sekolahId = user['sekolah_id'] ?? '';

      if (sekolahId.isEmpty) {
        print('sekolah_id tidak ditemukan di SharedPreferences');
        return null;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/sekolah/info?sekolah_id=$sekolahId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['data'] != null) {
          return data['data'];
        }
      } else {
        print('Error response: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching school info: $e');
    }
    return null;
  }

  static Future<void> cacheSchoolInfo(Map<String, dynamic> schoolData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('school_info', jsonEncode(schoolData));
  }

  static Future<Map<String, dynamic>?> getCachedSchoolInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final schoolInfo = prefs.getString('school_info');
    if (schoolInfo != null) {
      try {
        return jsonDecode(schoolInfo) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('school_info');
  }
}