import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';

class TeacherSubmissionScreen extends StatefulWidget {
  final Map<String, dynamic> tugas;

  const TeacherSubmissionScreen({super.key, required this.tugas});

  @override
  State<TeacherSubmissionScreen> createState() => _TeacherSubmissionScreenState();
}

class _TeacherSubmissionScreenState extends State<TeacherSubmissionScreen> {
  bool _isLoading = true;
  List _submissions = [];
  List _belumSubmit = [];
  int _totalSiswa = 0;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);

    try {
      final headers = await ApiService.getHeaders();
      final tugasId = widget.tugas['id'];
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/teacher/tugas/$tugasId/submissions'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('📥 Submissions response: ${response.body}');
      final result = jsonDecode(response.body);

      if (result['success'] == true) {
        setState(() {
          _submissions = result['data']['submissions'] ?? [];
          _belumSubmit = result['data']['belum_submit'] ?? [];
          _totalSiswa = result['data']['total_siswa'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading submissions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateNilai(String submissionId, String siswaNama, double nilai, String feedback) async {
    try {
      print('📝 Updating nilai: submission=$submissionId, nilai=$nilai, feedback=$feedback');
      
      final headers = await ApiService.getHeaders();
      headers['Content-Type'] = 'application/json';
      
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/teacher/submission/$submissionId/nilai'),
        headers: headers,
        body: jsonEncode({
          'nilai': nilai,
          'feedback': feedback,
        }),
      );

      print('📥 Update nilai response status: ${response.statusCode}');
      print('📥 Update nilai response body: ${response.body}');
      
      final result = jsonDecode(response.body);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Nilai berhasil disimpan'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Refresh list
          await _loadSubmissions();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${result['message'] ?? 'Gagal menyimpan nilai'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error updating nilai: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal menyimpan nilai: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showNilaiDialog(String submissionId, String siswaNama) {
    final nilaiController = TextEditingController();
    final feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Berikan Nilai'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Siswa: $siswaNama'),
              const SizedBox(height: 16),
              TextField(
                controller: nilaiController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nilai (0-100)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Feedback (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
              final nilai = double.tryParse(nilaiController.text);
              if (nilai == null || nilai < 0 || nilai > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nilai harus antara 0-100'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              _updateNilai(submissionId, siswaNama, nilai, feedbackController.text);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final judul = widget.tugas['judul'] ?? 'Tanpa Judul';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Submission Tugas'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSubmissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0)))
          : Column(
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      _buildSummaryItem('Total Siswa', _totalSiswa.toString(), Colors.blue),
                      const SizedBox(width: 16),
                      _buildSummaryItem('Sudah Submit', _submissions.length.toString(), Colors.green),
                      const SizedBox(width: 16),
                      _buildSummaryItem('Belum Submit', _belumSubmit.length.toString(), Colors.orange),
                    ],
                  ),
                ),
                
                // Tabs
                DefaultTabController(
                  length: 2,
                  child: Expanded(
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: 'Sudah Submit'),
                            Tab(text: 'Belum Submit'),
                          ],
                          labelColor: Color(0xFF9C27B0),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildSubmittedList(),
                              _buildBelumSubmitList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittedList() {
    if (_submissions.isEmpty) {
      return const Center(
        child: Text('Belum ada yang submit'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _submissions.length,
      itemBuilder: (context, index) {
        final sub = _submissions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: sub['nilai'] != null ? Colors.green : Colors.orange,
              child: Icon(
                sub['nilai'] != null ? Icons.check : Icons.pending,
                color: Colors.white,
              ),
            ),
            title: Text(sub['siswa_nama'] ?? '-'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${sub['file_nama'] ?? '-'}'),
                Text('Submit: ${_formatDateTime(sub['submitted_at'])}'),
                if (sub['catatan'] != null && sub['catatan'].isNotEmpty)
                  Text('Catatan: ${sub['catatan']}'),
              ],
            ),
            trailing: sub['nilai'] != null
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sub['nilai'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => _showNilaiDialog(sub['id'], sub['siswa_nama']),
                    child: const Text('Nilai'),
                  ),
            onTap: () {
              // Download file atau lihat detail
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File: ${sub['file_nama']}'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBelumSubmitList() {
    if (_belumSubmit.isEmpty) {
      return const Center(
        child: Text('Semua siswa sudah submit!'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _belumSubmit.length,
      itemBuilder: (context, index) {
        final siswa = _belumSubmit[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(siswa['nama'] ?? '-'),
            subtitle: Text('NIS: ${siswa['nis'] ?? '-'}'),
            trailing: const Chip(
              label: Text('Belum'),
              backgroundColor: Colors.orange,
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '-';
    try {
      final date = DateTime.parse(dateTimeStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '-';
    }
  }
}