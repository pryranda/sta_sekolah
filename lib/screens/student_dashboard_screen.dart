// lib/screens/student_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/school_provider.dart';
import '../providers/student_provider.dart';
import '../services/api_service.dart';
import 'absensi_screen.dart';
import 'jadwal_screen.dart';
import 'nilai_screen.dart';
import 'tugas_screen.dart';
import 'login_screen.dart';
import '../widgets/responsive_layout.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _absensiHariIni;

  List _jadwalHariIni = [];
  List _pengumuman = [];
  List _nilaiTerbaru = [];
  Map<String, dynamic> _sppInfo = {};

  static const Color primaryGreen = Color(0xFF7BC8A4);
  static const Color lightGreen = Color(0xFFB8F0D8);
  static const Color darkGreen = Color(0xFF4A9E7A);
  static const Color accentBlack = Color(0xFF1A2B1C);
  static const Color softWhite = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SchoolProvider>().loadSchoolProfile(forceReload: true);
    });
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (mounted) {
        await context.read<SchoolProvider>().loadSchoolProfile(forceReload: true);
      }

      if (mounted) {
        await context.read<StudentProvider>().loadProfile();
      }

      await Future.wait([
        _loadAbsensiHariIni(token),
        _loadJadwalHariIni(token),
        _loadPengumuman(token),
        _loadNilaiTerbaru(token),
        _loadSPPInfo(token),
      ]);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error load dashboard: $e');
    }
  }

  String _getHariIni() {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    return days[DateTime.now().weekday % 7];
  }

  // ✅ PERBAIKAN FINAL: Bandingkan tanggal lokal (konversi UTC ke local)
  Future<void> _loadAbsensiHariIni(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/student/absensi'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] && mounted) {
        final absensiList = data['data']['absensi'] as List;

        // Format tanggal hari ini (lokal)
        final now = DateTime.now();
        final todayStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        Map<String, dynamic>? todayData;
        for (var item in absensiList) {
          final dateStr = item['tanggal']?.toString() ?? '';
          if (dateStr.isEmpty) continue;

          try {
            // Parse UTC dan konversi ke local, lalu ambil YYYY-MM-DD
            final parsed = DateTime.parse(dateStr).toLocal();
            final itemDateStr =
                '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
            if (itemDateStr == todayStr) {
              todayData = item;
              break;
            }
          } catch (e) {
            // Fallback: potong string sebelum T
            final dateOnly = dateStr.contains('T') ? dateStr.substring(0, 10) : dateStr;
            if (dateOnly == todayStr) {
              todayData = item;
              break;
            }
          }
        }

        setState(() {
          _absensiHariIni = todayData;
        });
      }
    } catch (e) {
      debugPrint('Error load absensi hari ini: $e');
    }
  }

  Future<void> _loadJadwalHariIni(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/student/jadwal'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success']) {
        final allJadwal = data['data']['jadwal'] as List;
        final hariSekarang = _getHariIni().toLowerCase();
        if (mounted) {
          setState(() {
            _jadwalHariIni = allJadwal.where((j) =>
                j['hari'].toString().toLowerCase() == hariSekarang
            ).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error load jadwal: $e');
    }
  }

  Future<void> _loadPengumuman(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/parent/pengumuman'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] && mounted) {
        setState(() {
          _pengumuman = (data['data']['pengumuman'] as List).take(3).toList();
        });
      }
    } catch (e) {
      debugPrint('Error load pengumuman: $e');
    }
  }

  Future<void> _loadNilaiTerbaru(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/student/nilai'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] && mounted) {
        setState(() {
          _nilaiTerbaru = (data['data'] as List).take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('Error load nilai: $e');
    }
  }

  Future<void> _loadSPPInfo(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      final user = jsonDecode(userJson ?? '{}');
      final siswaId = user['id'] ?? '';
      if (siswaId.isEmpty) return;
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/parent/anak/${Uri.encodeComponent(siswaId)}/spp?tahun=2026'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] && mounted) {
        setState(() => _sppInfo = data['data']['ringkasan'] ?? {});
      }
    } catch (e) {
      debugPrint('Error load SPP: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  String _formatRupiah(dynamic amount) {
    if (amount == null) return 'Rp 0';
    final num value = num.tryParse(amount.toString()) ?? 0;
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softWhite,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryGreen))
            : CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 260,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: ResponsiveCenter(
                maxWidth: 1080,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAbsensiStatusCard(),
                    const SizedBox(height: 22),
                    const Row(
                      children: [
                        Icon(Icons.apps, color: primaryGreen, size: 20),
                        SizedBox(width: 8),
                        Text('Menu Utama', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentBlack)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ResponsiveMenuGrid(
                      mobileColumns: 2,
                      tabletColumns: 4,
                      desktopColumns: 4,
                      mobileAspectRatio: 1.25,
                      tabletAspectRatio: 1.25,
                      desktopAspectRatio: 1.45,
                      children: [
                        _buildModernActionCard(
                          'Absensi',
                          Icons.check_circle_outline,
                          const Color(0xFF4CAF50),
                          () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AbsensiScreen()),
                            );
                            _loadDashboardData();
                          },
                        ),
                        _buildModernActionCard('Jadwal', Icons.calendar_today_outlined, const Color(0xFF2196F3), () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const JadwalScreen()));
                        }),
                        _buildModernActionCard('Nilai', Icons.star_outline, const Color(0xFFFF9800), () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const NilaiScreen()));
                        }),
                        _buildModernActionCard('Tugas', Icons.assignment_outlined, const Color(0xFF9C27B0), () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TugasScreen()));
                        }),
                      ],
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final jadwalSection = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildModernSectionHeader('📚 Jadwal Hari Ini'),
                            if (_jadwalHariIni.isEmpty)
                              _buildEmptyStateCard('Tidak ada jadwal hari ini', Icons.event_busy)
                            else
                              ..._jadwalHariIni.map((jadwal) => _buildModernJadwalCard(jadwal)),
                          ],
                        );
                        final pengumumanSection = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildModernSectionHeader('📢 Pengumuman Terbaru'),
                            if (_pengumuman.isEmpty)
                              _buildEmptyStateCard('Tidak ada pengumuman', Icons.campaign_outlined)
                            else
                              ..._pengumuman.map((peng) => _buildModernPengumumanCard(peng)),
                          ],
                        );
                        final nilaiSection = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildModernSectionHeader('📊 Nilai Terbaru'),
                            if (_nilaiTerbaru.isEmpty)
                              _buildEmptyStateCard('Belum ada nilai', Icons.analytics_outlined)
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: primaryGreen.withOpacity(0.2)),
                                  boxShadow: [BoxShadow(color: primaryGreen.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 4))],
                                ),
                                child: Column(children: _nilaiTerbaru.map((nilai) => _buildModernNilaiRow(nilai)).toList()),
                              ),
                          ],
                        );
                        final sppSection = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildModernSectionHeader('💰 Informasi SPP'),
                            _buildModernSPPCard(),
                          ],
                        );

                        if (constraints.maxWidth >= 820) {
                          return Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: jadwalSection),
                                  const SizedBox(width: 16),
                                  Expanded(child: pengumumanSection),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: nilaiSection),
                                  const SizedBox(width: 16),
                                  Expanded(child: sppSection),
                                ],
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            jadwalSection,
                            const SizedBox(height: 24),
                            pengumumanSection,
                            const SizedBox(height: 24),
                            nilaiSection,
                            const SizedBox(height: 24),
                            sppSection,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== WIDGETS ====================

  Widget _buildAbsensiStatusCard() {
    if (_absensiHariIni == null) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange)),
                child: const Icon(Icons.access_time, color: Colors.orange, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status Absensi Hari Ini', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const Text('⚠️ Belum Absen', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16)),
                    Text('Silakan lakukan absen sekarang', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AbsensiScreen()));
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Absen'),
                style: TextButton.styleFrom(foregroundColor: primaryGreen),
              ),
            ],
          ),
        ),
      );
    }
    final status = _absensiHariIni!['status'] ?? 'Belum Absen';
    final jamMasuk = _absensiHariIni!['jam_masuk'] ?? '-';
    final jamKeluar = _absensiHariIni!['jam_pulang'] ?? '-';
    final isMasuk = status == 'hadir' || status == 'Hadir' || status == 'Masuk';
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMasuk ? primaryGreen.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isMasuk ? primaryGreen : Colors.orange),
              ),
              child: Icon(
                isMasuk ? Icons.check_circle_outline : Icons.access_time,
                color: isMasuk ? primaryGreen : Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Status Absensi Hari Ini', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(
                    isMasuk ? '✅ Sudah Absen' : '⚠️ Belum Absen',
                    style: TextStyle(fontWeight: FontWeight.bold, color: isMasuk ? primaryGreen : Colors.orange, fontSize: 16),
                  ),
                  if (isMasuk) ...[
                    Text('Masuk: $jamMasuk', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    if (jamKeluar != '-' && jamKeluar != null) Text('Pulang: $jamKeluar', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ] else ...[
                    Text('Silakan lakukan absen sekarang', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AbsensiScreen()));
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: isMasuk ? const Text('Detail') : const Text('Absen'),
              style: TextButton.styleFrom(foregroundColor: primaryGreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer2<SchoolProvider, StudentProvider>(
      builder: (context, schoolProvider, studentProvider, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE8F8F0), Color(0xFFB8F0D8), Color(0xFF7BC8A4)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: ResponsiveCenter(
              maxWidth: 1080,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (schoolProvider.logoUrl.isNotEmpty)
                            ClipOval(
                              child: Image.network(
                                schoolProvider.logoUrl,
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, color: Colors.white, size: 20),
                              ),
                            )
                          else
                            const Icon(Icons.school, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: accentBlack, borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              schoolProvider.namaSekolah.isNotEmpty ? schoolProvider.namaSekolah : 'Sekolah',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: accentBlack, size: 20),
                        onPressed: _logout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryGreen, width: 3)),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: accentBlack.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: studentProvider.fotoUrl.isNotEmpty
                              ? ClipOval(
                                child: Image.network(
                                  studentProvider.fotoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 38, color: primaryGreen),
                                ),
                              )
                              : const Icon(Icons.person, size: 38, color: primaryGreen),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studentProvider.nama.isEmpty ? 'Loading...' : studentProvider.nama,
                              style: const TextStyle(color: accentBlack, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text('NIS: ${studentProvider.nis}', style: TextStyle(color: accentBlack.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(studentProvider.email, style: TextStyle(color: accentBlack.withOpacity(0.6), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: primaryGreen.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_outline, color: primaryGreen, size: 12),
                                      const SizedBox(width: 4),
                                      Text('Wali Kelas', style: TextStyle(color: accentBlack.withOpacity(0.6), fontSize: 9)),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    studentProvider.waliKelas.isNotEmpty && studentProvider.waliKelas != '-' ? studentProvider.waliKelas : '-',
                                    style: const TextStyle(color: accentBlack, fontSize: 11, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.today, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(_getHariIni(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildInfoCard(icon: Icons.school_outlined, label: 'Kelas', value: studentProvider.kelas)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInfoCard(icon: Icons.calendar_month, label: 'Tahun', value: studentProvider.tahunAjaran)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInfoCard(icon: Icons.bookmark_outline, label: 'Semester', value: studentProvider.semester)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: accentBlack.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: primaryGreen, size: 20),
          const SizedBox(height: 6),
          Text(value.isEmpty ? '-' : value, style: const TextStyle(color: accentBlack, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildModernActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
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
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: accentBlack)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentBlack)),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(String message, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(icon, size: 40, color: primaryGreen.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: accentBlack.withOpacity(0.6), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildModernJadwalCard(Map<String, dynamic> jadwal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryGreen.withOpacity(0.3)),
              ),
              child: const Icon(Icons.book, color: primaryGreen, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jadwal['nama_mapel'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: accentBlack)),
                  const SizedBox(height: 4),
                  Text('${jadwal['jam_mulai'] ?? '-'} - ${jadwal['jam_selesai'] ?? '-'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(jadwal['ruangan'] ?? '-', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryGreen.withOpacity(0.3)),
                ),
                child: Text(
                  jadwal['guru_nama'] ?? '-',
                  style: TextStyle(color: accentBlack.withOpacity(0.7), fontSize: 11),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernPengumumanCard(Map<String, dynamic> peng) {
    final isHighPriority = peng['prioritas'] == 'tinggi';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighPriority ? primaryGreen.withOpacity(0.15) : darkGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isHighPriority ? primaryGreen : darkGreen),
                  ),
                  child: Text(
                    (peng['kategori'] ?? 'Umum').toUpperCase(),
                    style: TextStyle(color: isHighPriority ? primaryGreen : darkGreen, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(_formatDate(peng['created_at']), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            Text(peng['judul'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: accentBlack)),
            const SizedBox(height: 6),
            Text(peng['isi'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700], fontSize: 12, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildModernNilaiRow(Map<String, dynamic> nilai) {
    final nilaiAkhir = num.tryParse(nilai['nilai_akhir']?.toString() ?? '0') ?? 0;
    Color gradeColor;
    if (nilaiAkhir >= 85) gradeColor = primaryGreen;
    else if (nilaiAkhir >= 70) gradeColor = darkGreen;
    else if (nilaiAkhir >= 60) gradeColor = const Color(0xFFFF9800);
    else gradeColor = const Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nilai['nama_mapel'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: accentBlack)),
                const SizedBox(height: 3),
                Text('Tugas: ${nilai['nilai_tugas'] ?? 0} | UTS: ${nilai['nilai_uts'] ?? 0} | UAS: ${nilai['nilai_uas'] ?? 0}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: gradeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: gradeColor.withOpacity(0.3)),
            ),
            child: Text(
              nilaiAkhir.toStringAsFixed(0),
              style: TextStyle(color: gradeColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSPPCard() {
    final totalTagihan = num.tryParse(_sppInfo['total_tagihan']?.toString() ?? '0') ?? 0;
    final totalBayar = num.tryParse(_sppInfo['total_bayar']?.toString() ?? '0') ?? 0;
    final tunggakan = totalTagihan - totalBayar;
    final isLunas = tunggakan <= 0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLunas ? primaryGreen.withOpacity(0.12) : const Color(0xFFE53935).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isLunas ? primaryGreen : const Color(0xFFE53935)),
                  ),
                  child: Icon(
                    isLunas ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                    color: isLunas ? primaryGreen : const Color(0xFFE53935),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status SPP', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text(
                        isLunas ? 'Lunas' : 'Ada Tunggakan',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isLunas ? primaryGreen : const Color(0xFFE53935), fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Tagihan', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(_formatRupiah(totalTagihan), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Sudah Dibayar', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(_formatRupiah(totalBayar), style: const TextStyle(fontWeight: FontWeight.bold, color: primaryGreen, fontSize: 14)),
                  ],
                ),
              ],
            ),
            if (!isLunas) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE53935).withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tunggakan', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
                    Text(_formatRupiah(tunggakan), style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return '-';
    }
  }
}