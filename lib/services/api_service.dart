import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://103.182.209.20:3000/api';

  // ==========================================
  // AUTHENTICATION
  // ==========================================
  
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (data['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['data']['token']);
        await prefs.setString('user', jsonEncode(data['data']['user']));
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      final headers = await getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  // ==========================================
  // STUDENT PORTAL
  // ==========================================
  
  static Future<Map<String, dynamic>> getStudentProfile() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/student/profile'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getJadwalSiswa() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/student/jadwal'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getAbsensiSiswa() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/student/absensi'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> checkinAbsensi(String status) async {
    try {
      final headers = await getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/student/absensi/checkin'),
        headers: headers,
        body: jsonEncode({
          'status': status,
          'keterangan': 'Check-in via Flutter App',
          'device': 'Flutter Mobile',
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> checkoutAbsensi() async {
    try {
      final headers = await getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/student/absensi/checkout'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getNilaiSiswa() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/student/nilai'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ==========================================
  // TEACHER PORTAL
  // ==========================================
  
  static Future<Map<String, dynamic>> getTeacherProfile() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/profile'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getJadwalGuru() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/jadwal'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getSiswaByKelas(String kelasId) async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/kelas/$kelasId/siswa'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> inputNilai(Map<String, dynamic> nilaiData) async {
    try {
      final headers = await getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/teacher/nilai'),
        headers: headers,
        body: jsonEncode(nilaiData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getAbsensiKelas(String kelasId) async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/absensi/kelas/$kelasId'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ==========================================
  // PARENT PORTAL
  // ==========================================
  
  static Future<Map<String, dynamic>> getParentProfile() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/parent/profile'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getParentDashboard() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/parent/dashboard'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getDataAnak() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/parent/anak'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getSPPAnak(String anakId, {int? tahun}) async {
    try {
      final headers = await getHeaders();
      String url = '$baseUrl/parent/anak/$anakId/spp';
      if (tahun != null) {
        url += '?tahun=$tahun';
      }
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getPengumuman({String? kategori, String? prioritas}) async {
    try {
      final headers = await getHeaders();
      String url = '$baseUrl/parent/pengumuman';
      final params = <String>[];
      if (kategori != null) params.add('kategori=$kategori');
      if (prioritas != null) params.add('prioritas=$prioritas');
      if (params.isNotEmpty) url += '?${params.join('&')}';
      
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> markPengumumanRead(String pengumumanId) async {
    try {
      final headers = await getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/parent/pengumuman/$pengumumanId/read'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getJadwalAnak(String anakId) async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/parent/anak/$anakId/jadwal'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getAbsensiAnak(String anakId, {String? bulan, String? tahun}) async {
    try {
      final headers = await getHeaders();
      String url = '$baseUrl/parent/anak/$anakId/absensi';
      final params = <String>[];
      if (bulan != null) params.add('bulan=$bulan');
      if (tahun != null) params.add('tahun=$tahun');
      if (params.isNotEmpty) url += '?${params.join('&')}';
      
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getNilaiAnak(
    String anakId, {
    String? semester,
    String? tahunAjaran,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final headers = await getHeaders();
      String url = '$baseUrl/parent/anak/$anakId/nilai';
      final params = <String>[];
      params.add('page=$page');
      params.add('limit=$limit');
      
      if (semester != null && semester.isNotEmpty) params.add('semester=$semester');
      if (tahunAjaran != null && tahunAjaran.isNotEmpty) params.add('tahun_ajaran=$tahunAjaran');
      
      url += '?${params.join('&')}';
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getPendingApproval() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/parent/approval/pending'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> approvePermission(
    String absensiId, {
    required String action,
    String? note,
  }) async {
    try {
      final headers = await getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/parent/approval/$absensiId'),
        headers: headers,
        body: jsonEncode({
          'action': action,
          'note': note,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ==========================================
  // TUGAS (ASSIGNMENTS)
  // ==========================================
  
  static Future<Map<String, dynamic>> getTugasGuru() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/tugas/guru/tugas'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTugasGuruById(String tugasId) async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/tugas/guru/tugas/$tugasId'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> createTugas(Map<String, dynamic> tugasData) async {
    try {
      final headers = await getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/tugas/guru/tugas'),
        headers: headers,
        body: jsonEncode(tugasData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> gradeSubmission(String tugasId, Map<String, dynamic> gradeData) async {
    try {
      final headers = await getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/tugas/guru/tugas/submission/$tugasId/grade'),
        headers: headers,
        body: jsonEncode(gradeData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTugasSiswa() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/tugas/siswa/tugas'),
        headers: headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> submitTugasSiswa(String tugasId, Map<String, dynamic> submissionData) async {
    try {
      final headers = await getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/tugas/siswa/tugas/$tugasId/submit'),
        headers: headers,
        body: jsonEncode(submissionData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTugasAnak(String anakId) async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/tugas/orang-tua/anak/$anakId/tugas'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ==========================================
  // ADMIN API - GURU
  // ==========================================

  static Future<Map<String, dynamic>> getAdminGuru() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/guru'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error get admin guru: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createAdminGuru(Map<String, dynamic> data) async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.post(
        Uri.parse('$baseUrl/admin/guru'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error create guru: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteAdminGuru(String id) async {
    try {
      final headers = await getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/guru/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error delete guru: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // ADMIN API - MAPEL
  // ==========================================

  static Future<Map<String, dynamic>> getAdminMapel() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/mapel'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error get admin mapel: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // ADMIN API - GURU-MAPEL MAPPING
  // ==========================================

  static Future<Map<String, dynamic>> getAdminGuruMapel() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/guru-mapel'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error get admin guru mapel: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> assignGuruMapel(String guruId, String mapelId) async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.post(
        Uri.parse('$baseUrl/admin/guru-mapel'),
        headers: headers,
        body: jsonEncode({
          'guru_id': guruId,
          'mapel_id': mapelId,
        }),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error assign guru mapel: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> removeGuruMapel(String id) async {
    try {
      final headers = await getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/guru-mapel/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error remove guru mapel: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // ADMIN API - KELAS (LENGKAP)
  // ==========================================

  static Future<Map<String, dynamic>> getKelas() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/kelas'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error get kelas: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createKelas(Map<String, dynamic> data) async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.post(
        Uri.parse('$baseUrl/admin/kelas'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error create kelas: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateKelas(String id, Map<String, dynamic> data) async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.put(
        Uri.parse('$baseUrl/admin/kelas/$id'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error update kelas: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteKelas(String id) async {
    try {
      final headers = await getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/kelas/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error delete kelas: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // ADMIN API - SCHEDULE
  // ==========================================

  static Future<Map<String, dynamic>> getScheduleConfig() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/schedule/config'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error get schedule config: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> generateSchedule({
    required List<String> kelasIds,
    required List<String> hariList,
    required String tahunAjaran,
    required int semester,
    Map<String, dynamic>? config,
  }) async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.post(
        Uri.parse('$baseUrl/admin/schedule/generate'),
        headers: headers,
        body: jsonEncode({
          'kelas_ids': kelasIds,
          'hari_list': hariList,
          'tahun_ajaran': tahunAjaran,
          'semester': semester,
          'config': config ?? {
            'startTime': '07:00',
            'lessonDuration': 30,
            'breaks': [
              {'start': '09:30', 'end': '09:45'},
              {'start': '11:45', 'end': '12:30'}
            ],
            'endTimeLower': '13:30',
            'endTimeUpper': '14:30',
            'upacaraDay': 'Senin',
            'upacaraDuration': 60
          }
        }),
      ).timeout(const Duration(seconds: 60));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error generate schedule: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getScheduleByClass(String kelasId, {String? hari}) async {
    try {
      final headers = await getHeaders();
      String url = '$baseUrl/admin/schedule/kelas/$kelasId';
      if (hari != null) url += '?hari=$hari';
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error get schedule by class: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateSchedule(String id, {
    required String mapelId,
    required String guruId,
    required String jamMulai,
    required String jamSelesai,
  }) async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.put(
        Uri.parse('$baseUrl/admin/schedule/$id'),
        headers: headers,
        body: jsonEncode({
          'mapel_id': mapelId,
          'guru_id': guruId,
          'jam_mulai': jamMulai,
          'jam_selesai': jamSelesai,
        }),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error update schedule: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteScheduleManual(String id) async {
    try {
      final headers = await getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/schedule/manual/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error delete schedule: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // ADMIN API - HOLIDAYS (LIBUR NASIONAL)
  // ==========================================

  static Future<Map<String, dynamic>> getHolidays() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/holidays'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error get holidays: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createHoliday(String tanggal, String keterangan) async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.post(
        Uri.parse('$baseUrl/admin/holidays'),
        headers: headers,
        body: jsonEncode({
          'tanggal': tanggal,
          'keterangan': keterangan,
        }),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error create holiday: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteHoliday(String id) async {
    try {
      final headers = await getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/holidays/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error delete holiday: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==========================================
  // SEKOLAH
  // ==========================================
  
  static Future<Map<String, dynamic>> getSekolahInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sekolah/info'),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateLokasiSekolah(Map<String, dynamic> lokasiData) async {
    try {
      final headers = await getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/sekolah/lokasi'),
        headers: headers,
        body: jsonEncode(lokasiData),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

    // ==========================================
  // TEACHER ABSENSI (SELF)
  // ==========================================

  static Future<Map<String, dynamic>> getTeacherAbsensiToday() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/absensi/today'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTeacherAbsensiHistory() async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/teacher/absensi/history'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> teacherCheckIn() async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.post(
        Uri.parse('$baseUrl/teacher/absensi/checkin'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> teacherCheckOut() async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.post(
        Uri.parse('$baseUrl/teacher/absensi/checkout'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
    // ==========================================
  // ADMIN API - SISWA
  // ==========================================

  static Future<Map<String, dynamic>> getAdminSiswa({
    String? kelasId,
    String? tingkat,
    String? status,
    String? search,
  }) async {
    try {
      final headers = await getHeaders();
      String url = '$baseUrl/admin/siswa?';
      final params = <String>[];
      
      if (kelasId != null) params.add('kelas_id=$kelasId');
      if (tingkat != null) params.add('tingkat=$tingkat');
      if (status != null) params.add('status=$status');
      if (search != null && search.isNotEmpty) {
        params.add('search=${Uri.encodeComponent(search)}');
      }
      
      url += params.join('&');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error get siswa: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getAdminSiswaById(String id) async {
    try {
      final headers = await getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/admin/siswa/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error get siswa by id: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> createAdminSiswa(Map<String, dynamic> data) async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.post(
        Uri.parse('$baseUrl/admin/siswa'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error create siswa: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateSiswa(String id, Map<String, dynamic> data) async {
    try {
      final headers = await getHeaders();
      headers['Content-Type'] = 'application/json';
      final response = await http.put(
        Uri.parse('$baseUrl/admin/siswa/$id'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error update siswa: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteSiswa(String id) async {
    try {
      final headers = await getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/siswa/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body);
    } catch (e) {
      print('❌ Error delete siswa: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}  // ← Penutup class ApiService
// ❌ JANGAN ADA CODE APAPUN DI BAWAH SINI (di luar class)