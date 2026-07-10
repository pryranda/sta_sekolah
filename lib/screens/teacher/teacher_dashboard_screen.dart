import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../login_screen.dart';
import 'teacher_jadwal_screen.dart';
import 'teacher_absensi_screen.dart';
import 'teacher_input_nilai_screen.dart';
import 'teacher_tugas_screen.dart';
import 'teacher_self_absensi_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<dynamic> _jadwalList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ✅ Helper untuk konversi type yang aman
  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Load Profile Guru
      final profileResult = await ApiService.getTeacherProfile();
      print('👤 Profile Response: $profileResult');
      
      if (profileResult['success'] == true) {
        final profileData = profileResult['data'];
        if (profileData != null) {
          setState(() {
            _profileData = profileData is Map<String, dynamic> 
                ? profileData 
                : {};
          });
        }
      } else {
        print('⚠️ Profile failed: ${profileResult['message']}');
      }

      // 2. Load Jadwal Mengajar
      final jadwalResult = await ApiService.getJadwalGuru();
      print('📅 Jadwal Response: $jadwalResult');
      
      if (jadwalResult['success'] == true) {
        final jadwalData = jadwalResult['data'];
        List<dynamic> jadwalList = [];
        
        // ✅ Handle berbagai kemungkinan struktur response
        if (jadwalData is List) {
          jadwalList = jadwalData;
        } else if (jadwalData is Map<String, dynamic>) {
          // Jika data berbentuk Map, coba extract dari field 'jadwal' atau 'data'
          jadwalList = jadwalData['jadwal'] 
              ?? jadwalData['data'] 
              ?? [];
        }
        
        print('✅ Loaded ${jadwalList.length} jadwal');
        setState(() {
          _jadwalList = jadwalList;
          _isLoading = false;
        });
      } else {
        print('⚠️ Jadwal failed: ${jadwalResult['message']}');
        setState(() {
          _jadwalList = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data: $e';
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF7BC8A4)),
                  SizedBox(height: 16),
                  Text(
                    'Memuat data...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    slivers: [
                      // Header
                      SliverAppBar(
                        expandedHeight: 180,
                        floating: false,
                        pinned: true,
                        backgroundColor: const Color(0xFF7BC8A4),
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFE8F8F0),
                                  Color(0xFFB8F0D8),
                                  Color(0xFF7BC8A4),
                                ],
                              ),
                            ),
                            child: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12, 
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1A2B1C),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.school, color: Colors.white, size: 14),
                                              SizedBox(width: 6),
                                              Text(
                                                'Portal Guru',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.logout, color: Color(0xFF1A2B1C), size: 20),
                                          onPressed: _logout,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF7BC8A4), width: 3),
                                          ),
                                          child: Container(
                                            width: 70,
                                            height: 70,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.person, size: 38, color: Color(0xFF7BC8A4)),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _profileData?['nama'] ?? _profileData?['fullName'] ?? 'Guru',
                                                style: const TextStyle(
                                                  color: Color(0xFF1A2B1C),
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _profileData?['email'] ?? '',
                                                style: TextStyle(
                                                  color: const Color(0xFF1A2B1C).withOpacity(0.7),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Content
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stats Card
                              _buildStatsCard(),
                              const SizedBox(height: 24),

                              // Menu Utama
                              const Text(
                                'Menu Utama',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A2B1C),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Grid Menu
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.2,
                                children: [
                                  _buildMenuCard(
                                    'Jadwal Mengajar',
                                    Icons.calendar_today,
                                    const Color(0xFF2196F3),
                                    _jadwalList.length,
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const TeacherJadwalScreen()),
                                      );
                                    },
                                  ),
                                  _buildMenuCard(
                                    'Absensi Kelas',
                                    Icons.check_circle_outline,
                                    const Color(0xFF7BC8A4),
                                    0,
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const TeacherAbsensiScreen()),
                                      );
                                    },
                                  ),
                                  _buildMenuCard(
                                    'Absensi Saya',  // ← MENU BARU 1
                                    Icons.fingerprint,
                                    Colors.red,
                                    0,
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const TeacherSelfAbsensiScreen()),
                                      );
                                    },
                                  ),
                                  _buildMenuCard(
                                    'Input Nilai',
                                    Icons.grade,
                                    const Color(0xFFFF9800),
                                    0,
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const TeacherInputNilaiScreen()),
                                      );
                                    },
                                  ),
                                  _buildMenuCard(
                                    'Tugas',
                                    Icons.assignment,
                                    const Color(0xFF9C27B0),
                                    0,
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const TeacherTugasScreen()),
                                      );
                                    },
                                  ),
                                  // Menu kosong untuk mengisi grid (opsional)
                                  Container(),  // ← Kosongkan agar grid tetap rapi
                                ],
                            ),



                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7BC8A4),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    // ✅ Hitung unique classes dari jadwal
    final uniqueClasses = _jadwalList
        .map((j) => j['nama_kelas'] ?? j['kelas_id'])
        .toSet()
        .length;
    final totalJadwal = _jadwalList.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Total Kelas
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7BC8A4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.class_, color: Color(0xFF7BC8A4), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Kelas',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              '$uniqueClasses Kelas',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2B1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Total Jadwal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.schedule, color: Color(0xFF2196F3), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Jadwal',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              '$totalJadwal Jam',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2B1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(String title, IconData icon, Color color, int badge, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1A2B1C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}