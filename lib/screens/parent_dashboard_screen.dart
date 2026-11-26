import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/school_provider.dart';
import 'login_screen.dart';
import 'approval_screen.dart';
import 'parent_absensi_screen.dart';
import 'parent/parent_spp_screen.dart';
import 'parent/parent_pengumuman_screen.dart';
import 'parent/parent_jadwal_screen.dart';
import 'parent/parent_nilai_screen.dart';
import 'parent/parent_tugas_screen.dart';
import 'parent/parent_edit_profile_screen.dart';
import '../config/api_config.dart';
import '../widgets/responsive_layout.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({Key? key}) : super(key: key);
  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  static const String baseUrl = kApiBaseUrl;
  
  bool _isLoading = true;
  Map<String, dynamic>? _parentData;
  Map<String, dynamic>? _dashboardData;
  List _children = [];
  int _pendingApprovalCount = 0;
  int _unreadPengumumanCount = 0;

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  double _toDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // 1. Load Profile Orang Tua
      final profileResponse = await http.get(
        Uri.parse('$baseUrl/parent/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        if (profileData['success']) {
          setState(() {
            _parentData = profileData['data'];
          });
        }
      }
      
      // 2. Load Dashboard Overview
      final dashboardResponse = await http.get(
        Uri.parse('$baseUrl/parent/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (dashboardResponse.statusCode == 200) {
        final dashboardData = jsonDecode(dashboardResponse.body);
        if (dashboardData['success']) {
          setState(() {
            _dashboardData = dashboardData['data'];
            final dashboardList = dashboardData['data']['dashboard'];
            if (dashboardList is List) {
              _children = dashboardList;
            } else {
              _children = [];
            }
          });
        }
      }
      
      // 3. Load Pending Approval Count
      final approvalResponse = await http.get(
        Uri.parse('$baseUrl/parent/approval/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (approvalResponse.statusCode == 200) {
        final approvalData = jsonDecode(approvalResponse.body);
        if (approvalData['success']) {
          setState(() {
            _pendingApprovalCount = _toInt(approvalData['count']);
          });
        }
      }
      
      // 4. Load Pengumuman
      final pengumumanResponse = await http.get(
        Uri.parse('$baseUrl/parent/pengumuman'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (pengumumanResponse.statusCode == 200) {
        final pengumumanData = jsonDecode(pengumumanResponse.body);
        if (pengumumanData['success']) {
          setState(() {
            final stats = pengumumanData['data']?['stats'];
            if (stats != null) {
              _unreadPengumumanCount = _toInt(stats['belum_dibaca']);
            }
          });
        }
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error load dashboard: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  void _showSelectChildDialog(Function(Map<String, dynamic>) onSelected) {
    if (_children.length == 1) {
      onSelected(_children[0]['anak']);
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pilih Anak'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _children.map((childData) {
              final anak = childData['anak'];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(anak['nama'] ?? '-'),
                subtitle: Text('Kelas: ${anak['kelas'] ?? '-'}'),
                onTap: () {
                  Navigator.pop(context);
                  onSelected(anak);
                },
              );
            }).toList(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7BC8A4)))
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverAppBar(
                    expandedHeight: 320,
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A2B1C),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.school, color: Colors.white, size: 14),
                                          const SizedBox(width: 6),
                                          Consumer<SchoolProvider>(
                                            builder: (context, schoolProvider, child) {
                                              return Text(
                                                schoolProvider.namaSekolah,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Color(0xFF1A2B1C), size: 20),
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const ParentEditProfileScreen()),
                                            );
                                            if (result == true) {
                                              _loadDashboardData();
                                            }
                                          },
                                          tooltip: 'Edit Profile',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.logout, color: Color(0xFF1A2B1C), size: 20),
                                          tooltip: 'Logout',
                                          onPressed: _logout,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF7BC8A4), width: 3),
                                      ),
                                      child: Container(
                                        width: 66,
                                        height: 66,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF1A2B1C).withOpacity(0.15),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.person, size: 36, color: Color(0xFF7BC8A4)),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _parentData?['nama_ibu'] ?? 'Orang Tua',
                                            style: const TextStyle(
                                              color: Color(0xFF1A2B1C),
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _parentData?['email'] ?? '',
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
                                const SizedBox(height: 14),
                                // Informasi Orang Tua (2 Kolom: Ibu & Ayah)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.82),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '👩 Informasi Ibu',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF4A9E7A),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (_parentData?['hp_ibu'] != null && _parentData!['hp_ibu'].isNotEmpty)
                                                _buildInfoRow(
                                                  icon: Icons.phone,
                                                  label: 'No HP',
                                                  value: _parentData!['hp_ibu'],
                                                ),
                                              if (_parentData?['alamat'] != null && _parentData!['alamat'].isNotEmpty)
                                                _buildInfoRow(
                                                  icon: Icons.location_on_outlined,
                                                  label: 'Alamat',
                                                  value: _parentData!['alamat'],
                                                  isMultiline: true,
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        VerticalDivider(width: 1, thickness: 1, color: Colors.grey.shade300),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '👨 Informasi Ayah',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF2196F3),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (_parentData?['nama_ayah'] != null && _parentData!['nama_ayah'].isNotEmpty)
                                                _buildInfoRow(
                                                  icon: Icons.person_outline,
                                                  label: 'Nama',
                                                  value: _parentData!['nama_ayah'],
                                                ),
                                              if (_parentData?['hp_ayah'] != null && _parentData!['hp_ayah'].isNotEmpty)
                                                _buildInfoRow(
                                                  icon: Icons.phone,
                                                  label: 'No HP',
                                                  value: _parentData!['hp_ayah'],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                    child: ResponsiveCenter(
                      maxWidth: 1080,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dashboard Summary
                          if (_dashboardData != null) ...[
                            _buildDashboardSummary(),
                            const SizedBox(height: 24),
                          ],
                          
                          // Data Anak dengan Menu Aksi
                          if (_children.isNotEmpty) ...[
                            const Text(
                              'Data Anak',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2B1C),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._children.map((childData) => _buildChildCard(childData)),
                            const SizedBox(height: 24),
                          ],
                          
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
                          ResponsiveMenuGrid(
                            mobileColumns: 2,
                            tabletColumns: 4,
                            desktopColumns: 4,
                            mobileAspectRatio: 1.2,
                            tabletAspectRatio: 1.2,
                            desktopAspectRatio: 1.35,
                            children: [
                              _buildMenuCard(
                                'Approval',
                                Icons.approval,
                                const Color(0xFF9C27B0),
                                _pendingApprovalCount,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ApprovalScreen()),
                                  );
                                },
                              ),
                              _buildMenuCard(
                                'Absensi',
                                Icons.check_circle_outline,
                                const Color(0xFF7BC8A4),
                                0,
                                () {
                                  _showSelectChildDialog((anak) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ParentAbsensiScreen(
                                          anakId: anak['id'].toString(),
                                          anakNama: anak['nama'] ?? 'Anak',
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                              _buildMenuCard(
                                'SPP',
                                Icons.payment,
                                const Color(0xFF2196F3),
                                0,
                                () {
                                  _showSelectChildDialog((anak) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ParentSppScreen(
                                          anakId: anak['id'].toString(),
                                          anakNama: anak['nama'] ?? 'Anak',
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                              _buildMenuCard(
                                'Pengumuman',
                                Icons.campaign,
                                const Color(0xFFFF9800),
                                _unreadPengumumanCount,
                                () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ParentPengumumanScreen()),
                                  );
                                },
                              ),
                            ],
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

  Widget _buildDashboardSummary() {
    final jumlahAnak = _toInt(_dashboardData?['jumlah_anak']);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  child: const Icon(Icons.family_restroom, color: Color(0xFF7BC8A4), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Anak',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '$jumlahAnak Anak',
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
    );
  }

  Widget _buildChildCard(Map<String, dynamic> childData) {
    final anak = childData['anak'] ?? {};
    final absensi = childData['absensi'] ?? {};
    final nilai = childData['nilai'] ?? {};
    
    final totalHadir = _toInt(absensi['hadir']);
    final totalIzin = _toInt(absensi['izin']);
    final totalSakit = _toInt(absensi['sakit']);
    final totalAlpha = _toInt(absensi['alpha']);
    final rataRataNilai = _toDouble(nilai['rata_rata']);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  child: const Icon(Icons.person, color: Color(0xFF7BC8A4), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anak['nama'] ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Kelas: ${anak['kelas'] ?? '-'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              '📊 Absensi Bulan Ini',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('✅ Hadir', totalHadir, const Color(0xFF7BC8A4)),
                _buildMiniStat('📝 Izin', totalIzin, const Color(0xFF2196F3)),
                _buildMiniStat('🤒 Sakit', totalSakit, const Color(0xFFFF9800)),
                _buildMiniStat('❌ Alpha', totalAlpha, const Color(0xFFE53935)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics, color: Color(0xFF9C27B0), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Rata-rata Nilai: ',
                    style: TextStyle(fontSize: 13),
                  ),
                  Text(
                    rataRataNilai.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9C27B0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aksi Cepat',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.calendar_today,
                    label: 'Jadwal',
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ParentJadwalScreen(
                            anakId: anak['id'].toString(),
                            anakNama: anak['nama'] ?? 'Anak',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.grade,
                    label: 'Nilai',
                    color: const Color(0xFFE91E63),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ParentNilaiScreen(
                            anakId: anak['id'].toString(),
                            anakNama: anak['nama'] ?? 'Anak',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.assignment,
                    label: 'Tugas',
                    color: const Color(0xFF00BCD4),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ParentTugasScreen(
                            anakId: anak['id'].toString(),
                            anakNama: anak['nama'] ?? 'Anak',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A2B1C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
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