import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import 'student_submit_tugas_screen.dart';

class StudentTugasScreen extends StatefulWidget {
  const StudentTugasScreen({super.key});

  @override
  State<StudentTugasScreen> createState() => _StudentTugasScreenState();
}

class _StudentTugasScreenState extends State<StudentTugasScreen> {
  List<dynamic> _tugasList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTugas();
  }

  Future<void> _loadTugas() async {
    setState(() => _isLoading = true);

    try {
      final headers = await ApiService.getHeaders();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/student/tugas'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('📥 Tugas response: ${response.body}');
      final result = jsonDecode(response.body);

      if (result['success'] == true) {
        final data = result['data'];
        List<dynamic> tugasList = [];

        if (data is List) {
          tugasList = data;
        } else if (data is Map) {
          tugasList = data['tugas'] ?? data['data'] ?? [];
        }

        setState(() {
          _tugasList = tugasList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading tugas: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _checkSubmissionStatus(String tugasId) async {
    try {
      final headers = await ApiService.getHeaders();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/student/tugas/$tugasId/submission'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      final result = jsonDecode(response.body);
      if (result['success'] == true && result['data'] != null) {
        return result['data'];
      }
    } catch (e) {
      print('❌ Error checking submission: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Tugas Saya'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTugas,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0)))
          : _tugasList.isEmpty
              ? _buildEmptyState()
              : _buildTugasList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Belum ada tugas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tugas dari guru akan muncul di sini',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTugasList() {
    return RefreshIndicator(
      onRefresh: _loadTugas,
      color: const Color(0xFF9C27B0),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tugasList.length,
        itemBuilder: (context, index) {
          final tugas = _tugasList[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTugasCard(tugas),
          );
        },
      ),
    );
  }

  Widget _buildTugasCard(Map<String, dynamic> tugas) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _checkSubmissionStatus(tugas['id']),
      builder: (context, snapshot) {
        final submission = snapshot.data;
        final isSubmitted = submission != null;
        final isGraded = submission?['nilai'] != null;
        final nilai = submission?['nilai'];
        
        return _buildTugasCardUI(tugas, isSubmitted, isGraded, nilai);
      },
    );
  }

  Widget _buildTugasCardUI(
    Map<String, dynamic> tugas,
    bool isSubmitted,
    bool isGraded,
    dynamic nilai,
  ) {
    final judul = tugas['judul'] ?? 'Tanpa Judul';
    final deskripsi = tugas['deskripsi'] ?? '';
    final deadline = tugas['deadline'] ?? '-';
    final namaMapel = tugas['nama_mapel'] ?? '-';
    final kodeMapel = tugas['kode_mapel'] ?? '';
    final guruNama = tugas['guru_nama'] ?? '-';

    final deadlineDate = DateTime.tryParse(deadline);
    final isExpired = deadlineDate != null && deadlineDate.isBefore(DateTime.now());
    final daysLeft = deadlineDate != null 
        ? deadlineDate.difference(DateTime.now()).inDays 
        : 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentSubmitTugasScreen(tugas: tugas),
            ),
          ).then((_) => _loadTugas()); // Refresh setelah kembali
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment, color: Color(0xFF9C27B0)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          judul,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.book, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '$namaMapel ($kodeMapel)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  _buildStatusBadge(isSubmitted, isGraded, isExpired, daysLeft),
                ],
              ),
              if (deskripsi.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  deskripsi,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Deadline: ${_formatDeadline(deadlineDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isExpired ? Colors.red : Colors.grey.shade600,
                        fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Guru: $guruNama',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              // Tampilkan nilai jika sudah dinilai
              if (isGraded && nilai != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Nilai: $nilai',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isSubmitted, bool isGraded, bool isExpired, int daysLeft) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    if (isGraded) {
      bgColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green;
      text = 'DINILAI';
      icon = Icons.check_circle;
    } else if (isSubmitted) {
      bgColor = Colors.blue.withOpacity(0.1);
      textColor = Colors.blue;
      text = 'SUBMITTED';
      icon = Icons.send;
    } else if (isExpired) {
      bgColor = Colors.red.withOpacity(0.1);
      textColor = Colors.red;
      text = 'EXPIRED';
      icon = Icons.error;
    } else {
      bgColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange;
      text = daysLeft <= 3 ? '$daysLeft hari' : 'BELUM';
      icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeadline(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}