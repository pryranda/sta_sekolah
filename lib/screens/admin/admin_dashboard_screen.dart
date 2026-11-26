import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'admin_guru_screen.dart';
import 'admin_mapel_screen.dart';
import 'admin_mapping_screen.dart';
import 'admin_schedule_screen.dart';
import 'admin_holiday_screen.dart';
import 'admin_kelas_screen.dart';
import 'admin_siswa_screen.dart';
import 'admin_spp_verification_screen.dart';
import 'admin_spp_generate_all_screen.dart';
import 'admin_laporan_keuangan_screen.dart';
import 'admin_sekolah_settings_screen.dart';
import '../../config/api_config.dart';
import '../../providers/school_provider.dart';
import '../../widgets/responsive_layout.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const String baseUrl = kApiBaseUrl;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  
  // ✅ State untuk notifikasi verifikasi
  bool _isKeuangan = false;
  int _pendingVerificationCount = 0;
  bool _isLoadingCount = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SchoolProvider>().loadSchoolProfile(forceReload: true);
    });
    _loadUserData();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // ✅ Cancel timer saat dispose
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson != null) {
        final user = jsonDecode(userJson);
        setState(() {
          _userData = user;
          _isKeuangan = user['jabatan'] == 'keuangan';
          _isLoading = false;
        });
        
        // ✅ Load pending count setelah user data dimuat
        _loadPendingCount();
        
        // ✅ Auto-refresh setiap 30 detik (hanya untuk admin keuangan)
        if (_isKeuangan) {
          _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
            if (mounted) {
              _loadPendingCount();
            }
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ Fungsi untuk load count pembayaran pending
  Future<void> _loadPendingCount() async {
    if (!_isKeuangan) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/spp/admin/pembayaran/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && mounted) {
          setState(() {
            _pendingVerificationCount = data['count'] ?? 0;
            _isLoadingCount = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error load pending count: $e');
      if (mounted) {
        setState(() => _isLoadingCount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Admin Panel',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ✅ Tombol refresh untuk admin keuangan
          if (_isKeuangan)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh notifikasi',
              onPressed: () {
                _loadPendingCount();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifikasi diperbarui'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadPendingCount();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: ResponsiveCenter(
                  maxWidth: 1080,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Card
                      _buildWelcomeCard(),
                      const SizedBox(height: 24),

                      // ✅ Notifikasi Banner untuk Admin Keuangan
                      if (_isKeuangan && !_isLoadingCount && _pendingVerificationCount > 0) ...[
                        _buildNotificationBanner(),
                        const SizedBox(height: 20),
                      ],

                      // Section Title - Data Master
                      const Text(
                        'Data Master',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kelola data utama sekolah',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),

                      // Menu Grid - Data Master
                      ResponsiveMenuGrid(
                        mobileColumns: 2,
                        tabletColumns: 3,
                        desktopColumns: 4,
                        mobileAspectRatio: 1.05,
                        tabletAspectRatio: 1.2,
                        desktopAspectRatio: 1.35,
                        children: [
                          _buildMenuCard(
                            icon: Icons.people,
                            title: 'Kelola Guru',
                            subtitle: 'Tambah & kelola data guru',
                            color: Colors.blue,
                            onTap: () => _navigateTo(const AdminGuruScreen()),
                          ),
                          _buildMenuCard(
                            icon: Icons.book,
                            title: 'Mata Pelajaran',
                            subtitle: 'Kelola data mapel',
                            color: Colors.green,
                            onTap: () => _navigateTo(const AdminMapelScreen()),
                          ),
                          _buildMenuCard(
                            icon: Icons.link,
                            title: 'Mapping Guru',
                            subtitle: 'Assign mapel ke guru',
                            color: Colors.orange,
                            onTap: () => _navigateTo(const AdminMappingScreen()),
                          ),
                          _buildMenuCard(
                            icon: Icons.class_,
                            title: 'Kelas',
                            subtitle: 'Kelola data kelas',
                            color: Colors.purple,
                            onTap: () => _navigateTo(const AdminKelasScreen()),
                          ),
                          // ✅ Menu Verifikasi SPP dengan Badge
                          _buildMenuCardWithBadge(
                            icon: Icons.verified_user,
                            title: 'Verifikasi SPP',
                            subtitle: 'Verifikasi pembayaran SPP',
                            color: const Color(0xFF7BC8A4),
                            badgeCount: _isKeuangan ? _pendingVerificationCount : 0,
                            isLoadingBadge: _isLoadingCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminSppVerificationScreen()),
                              ).then((_) {
                                _loadPendingCount();
                              });
                            },
                          ),
                          _buildMenuCard(
                            icon: Icons.school,
                            title: 'Siswa',
                            subtitle: 'Kelola data siswa',
                            color: Colors.teal,
                            onTap: () => _navigateTo(const AdminSiswaScreen()),
                          ),
                          _buildMenuCard(
                            icon: Icons.receipt_long,
                            title: 'Generate SPP',
                            subtitle: 'Semua jenis sekaligus',
                            color: Colors.purple,
                            onTap: () => _navigateTo(const AdminSppGenerateAllScreen()),
                          ),
                          _buildMenuCard(
                            icon: Icons.bar_chart,
                            title: 'Laporan Keuangan',
                            subtitle: 'Dashboard laporan bulanan',
                            color: Colors.indigo,
                            onTap: () => _navigateTo(const AdminLaporanKeuanganScreen()),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Section Title - Akademik
                      const Text(
                        'Akademik & Kalender',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Atur jadwal dan kalender akademik',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),

                      // Menu Grid - Akademik
                      ResponsiveMenuGrid(
                        mobileColumns: 2,
                        tabletColumns: 3,
                        desktopColumns: 4,
                        mobileAspectRatio: 1.05,
                        tabletAspectRatio: 1.2,
                        desktopAspectRatio: 1.35,
                        children: [
                          _buildMenuCard(
                            icon: Icons.calendar_today,
                            title: 'Jadwal Pelajaran',
                            subtitle: 'Generate & kelola jadwal',
                            color: Colors.red,
                            onTap: () => _navigateTo(const AdminScheduleScreen()),
                          ),
                          _buildMenuCard(
                            icon: Icons.event,
                            title: 'Libur Nasional',
                            subtitle: 'Kalender hari libur',
                            color: Colors.pink,
                            onTap: () => _navigateTo(const AdminHolidayScreen()),
                          ),
                          _buildMenuCard(
                            icon: Icons.assignment,
                            title: 'Absensi',
                            subtitle: 'Kelola absensi siswa',
                            color: Colors.indigo,
                            onTap: () => _showComingSoon('Absensi'),
                          ),
                          _buildMenuCard(
                            icon: Icons.grade,
                            title: 'Nilai',
                            subtitle: 'Kelola nilai siswa',
                            color: Colors.amber.shade800,
                            onTap: () => _showComingSoon('Nilai'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Section Title - Lainnya
                      const Text(
                        'Lainnya',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Menu Lainnya (2 kolom di layar lebar, bertumpuk di HP)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final card1 = _buildWideMenuCard(
                            icon: Icons.announcement,
                            title: 'Pengumuman',
                            subtitle: 'Buat dan kelola pengumuman sekolah',
                            color: Colors.cyan,
                            onTap: () => _showComingSoon('Pengumuman'),
                          );
                          final card2 = _buildWideMenuCard(
                            icon: Icons.settings,
                            title: 'Pengaturan Sekolah',
                            subtitle: 'Identitas, logo, jam operasional & lokasi sekolah',
                            color: Colors.grey.shade700,
                            onTap: () => _navigateTo(const AdminSekolahSettingsScreen()),
                          );

                          if (constraints.maxWidth >= 680) {
                            return Row(
                              children: [
                                Expanded(child: card1),
                                const SizedBox(width: 12),
                                Expanded(child: card2),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              card1,
                              const SizedBox(height: 12),
                              card2,
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ✅ Widget Banner Notifikasi
  Widget _buildNotificationBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminSppVerificationScreen()),
        ).then((_) => _loadPendingCount());
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 28,
                  ),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _pendingVerificationCount > 99 
                            ? '99+' 
                            : _pendingVerificationCount.toString(),
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Ada Pembayaran Menunggu Verifikasi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_pendingVerificationCount tagihan perlu diverifikasi',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap untuk verifikasi sekarang →',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final nama = _userData?['nama'] ?? _userData?['username'] ?? 'Admin';
    final role = _userData?['role_name'] ?? 'Admin Sekolah';

    return Consumer<SchoolProvider>(
      builder: (context, schoolProvider, _) {
        final namaSekolah = schoolProvider.namaSekolah;
        final logoUrl = schoolProvider.logoUrl;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: logoUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              logoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          )
                        : const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          namaSekolah.isNotEmpty ? namaSekolah : 'Selamat Datang,',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          nama,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  if (_isKeuangan)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payments, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Keuangan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ Widget Menu Card dengan Badge
  Widget _buildMenuCardWithBadge({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required int badgeCount,
    required bool isLoadingBadge,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const Spacer(),
                  // ✅ Badge Counter
                  if (!isLoadingBadge && badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fitur $feature akan segera hadir'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}