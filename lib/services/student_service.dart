import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StudentService {
  static const String baseUrl = 'http://103.182.209.20:3000/api';
  
  // Fetch profile siswa dari API
  static Future<Map<String, dynamic>?> getProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/student/profile'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['data'] != null) {
          print('✅ Student profile loaded: ${data['data']}');
          return data['data'];
        }
      }
    } catch (e) {
      print('Error fetching student profile: $e');
    }
    return null;
  }
  
  // Cache profile siswa
  static Future<void> cacheProfile(Map<String, dynamic> profileData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_profile', jsonEncode(profileData));
  }
  
  // Ambil dari cache
  static Future<Map<String, dynamic>?> getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = prefs.getString('student_profile');
    if (profile != null) {
      print('✅ Loaded from cache: $profile');
      return jsonDecode(profile);
    }
    return null;
  }
}