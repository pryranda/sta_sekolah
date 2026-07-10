import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class TeacherSelfAbsensiScreen extends StatefulWidget {
  const TeacherSelfAbsensiScreen({super.key});

  @override
  State<TeacherSelfAbsensiScreen> createState() => _TeacherSelfAbsensiScreenState();
}

class _TeacherSelfAbsensiScreenState extends State<TeacherSelfAbsensiScreen> {
  Map<String, dynamic>? _todayStatus;
  List<dynamic> _history = [];
  bool _isLoading = true;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getTeacherAbsensiToday(),
        ApiService.getTeacherAbsensiHistory(),
      ]);

      if (mounted) {
        setState(() {
          _todayStatus = results[0]['success'] == true ? results[0]['data'] : null;
          _history = results[1]['success'] == true ? results[1]['data'] : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _doCheckIn() async {
    setState(() => _isChecking = true);
    try {
      final result = await ApiService.teacherCheckIn();
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Check-in berhasil!'), backgroundColor: Colors.green),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: ${result['message']}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _doCheckOut() async {
    setState(() => _isChecking = true);
    try {
      final result = await ApiService.teacherCheckOut();
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Check-out berhasil!'), backgroundColor: Colors.green),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: ${result['message']}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  String _formatTime(dynamic time) {
    if (time == null) return '-';
    return time.toString().substring(0, 5);
  }

  String _getStatusText() {
    if (_todayStatus == null) return 'Belum Absen Hari Ini';
    if (_todayStatus!['jam_masuk'] != null && _todayStatus!['jam_keluar'] == null) {
      return 'Sudah Check-in (${_formatTime(_todayStatus!['jam_masuk'])})';
    }
    if (_todayStatus!['jam_keluar'] != null) {
      return 'Sudah Check-out (${_formatTime(_todayStatus!['jam_keluar'])})';
    }
    return 'Status Tidak Diketahui';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeString = DateFormat('HH:mm:ss').format(now);
    final dateString = DateFormat('EEEE, dd MMMM yyyy').format(now);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Absensi Saya'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Clock Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
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
                      children: [
                        Text(
                          dateString,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          timeString,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getStatusText(),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.login,
                          label: 'Check In',
                          color: Colors.green,
                          isEnabled: _todayStatus == null || _todayStatus!['jam_masuk'] == null,
                          onTap: _doCheckIn,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.logout,
                          label: 'Check Out',
                          color: Colors.red,
                          isEnabled: _todayStatus != null && 
                              _todayStatus!['jam_masuk'] != null && 
                              _todayStatus!['jam_keluar'] == null,
                          onTap: _doCheckOut,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Today's Info
                  if (_todayStatus != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Status Hari Ini',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Masuk', style: TextStyle(color: Colors.grey)),
                                    Text(
                                      _formatTime(_todayStatus!['jam_masuk']),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Keluar', style: TextStyle(color: Colors.grey)),
                                    Text(
                                      _formatTime(_todayStatus!['jam_keluar']),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _todayStatus!['jam_keluar'] != null 
                                            ? Colors.red 
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // History
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Riwayat Absensi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _history.isEmpty
                      ? const Center(child: Text('Belum ada riwayat absensi'))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _history.length > 7 ? 7 : _history.length,
                          itemBuilder: (context, index) {
                            final item = _history[index];
                            final tanggal = DateTime.parse(item['tanggal']);
                            final dateStr = DateFormat('EEEE, dd MMM yyyy').format(tanggal);
                            final masuk = _formatTime(item['jam_masuk']);
                            final keluar = _formatTime(item['jam_keluar']);
                            
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: item['jam_keluar'] != null 
                                      ? Colors.green.shade100 
                                      : Colors.orange.shade100,
                                  child: Icon(
                                    item['jam_keluar'] != null 
                                        ? Icons.check_circle 
                                        : Icons.access_time,
                                    color: item['jam_keluar'] != null 
                                        ? Colors.green 
                                        : Colors.orange,
                                  ),
                                ),
                                title: Text(
                                  dateStr,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('Masuk: $masuk | Keluar: $keluar'),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: isEnabled && !_isChecking ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? color : Colors.grey.shade300,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}