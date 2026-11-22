import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'student/student_submit_tugas_screen.dart';
import '../config/api_config.dart';

class TugasScreen extends StatefulWidget {
  const TugasScreen({Key? key}) : super(key: key);
  @override
  State<TugasScreen> createState() => _TugasScreenState();
}

class _TugasScreenState extends State<TugasScreen> {
  static const String baseUrl = kApiBaseUrl;
  
  bool _isLoading = true;
  List _tugasList = [];
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadTugas();
  }

  Future<void> _loadTugas() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/student/tugas'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          // API membungkus daftar tugas di dalam objek { tugas: [...] };
          // tetap dukung bentuk list langsung agar aman terhadap perubahan.
          final payload = data['data'];
          final List list = payload is List
              ? payload
              : (payload is Map
                  ? (payload['tugas'] ?? payload['data'] ?? []) as List
                  : []);
          setState(() {
            _tugasList = list;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error load tugas: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ Cek submission status untuk setiap tugas
  Future<Map<String, dynamic>?> _checkSubmissionStatus(String tugasId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/student/tugas/$tugasId/submission'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      final result = jsonDecode(response.body);
      if (result['success'] == true && result['data'] != null) {
        return result['data'];
      }
    } catch (e) {
      debugPrint('Error checking submission: $e');
    }
    return null;
  }

  List _getFilteredTugas() {
    if (_filterStatus == 'all') return _tugasList;
    return _tugasList;
  }

  void _navigateToSubmit(Map<String, dynamic> tugas) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSubmitTugasScreen(tugas: tugas),
      ),
    ).then((_) {
      // ✅ Refresh setelah kembali dari submit screen
      _loadTugas();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredTugas = _getFilteredTugas();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Daftar Tugas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF7BC8A4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTugas,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('Semua', 'all'),
                _buildFilterChip('Belum', 'belum'),
                _buildFilterChip('Submitted', 'submitted'),
                _buildFilterChip('Dinilai', 'dinilai'),
              ],
            ),
          ),
          
          // Tugas List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF7BC8A4)))
                : filteredTugas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada tugas',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredTugas.length,
                        itemBuilder: (context, index) {
                          final tugas = filteredTugas[index];
                          return _buildTugasCard(tugas);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = value);
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: const Color(0xFF7BC8A4).withOpacity(0.3),
      checkmarkColor: const Color(0xFF7BC8A4),
    );
  }

  Widget _buildTugasCard(Map<String, dynamic> tugas) {
    // ✅ Gunakan FutureBuilder untuk cek submission status real-time
    return FutureBuilder<Map<String, dynamic>?>(
      future: _checkSubmissionStatus(tugas['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final submission = snapshot.data;
        final isSubmitted = submission != null;
        final isGraded = submission?['nilai'] != null;
        final nilai = submission?['nilai'];
        final feedback = submission?['feedback'];

        return _buildTugasCardUI(tugas, isSubmitted, isGraded, nilai, feedback);
      },
    );
  }

  Widget _buildTugasCardUI(
    Map<String, dynamic> tugas,
    bool isSubmitted,
    bool isGraded,
    dynamic nilai,
    String? feedback,
  ) {
    final deadline = tugas['deadline'] != null 
        ? DateTime.tryParse(tugas['deadline'].toString())
        : null;
    
    final isOverdue = deadline != null && deadline.isBefore(DateTime.now());
    final daysLeft = deadline != null 
        ? deadline.difference(DateTime.now()).inDays
        : 0;
    
    // ✅ Tentukan status berdasarkan submission, bukan field 'status' dari API
    String currentFilterStatus;
    if (isGraded) {
      currentFilterStatus = 'dinilai';
    } else if (isSubmitted) {
      currentFilterStatus = 'submitted';
    } else {
      currentFilterStatus = 'belum';
    }

    // Filter logic
    if (_filterStatus != 'all' && _filterStatus != currentFilterStatus) {
      return const SizedBox.shrink(); // Sembunyikan card yang tidak sesuai filter
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (isGraded) {
      statusColor = Colors.green;
      statusText = 'Dinilai: $nilai';
      statusIcon = Icons.check_circle;
    } else if (isSubmitted) {
      statusColor = Colors.blue;
      statusText = 'Sudah Submit';
      statusIcon = Icons.send;
    } else if (isOverdue) {
      statusColor = Colors.red;
      statusText = 'Terlambat';
      statusIcon = Icons.error;
    } else {
      statusColor = Colors.orange;
      statusText = 'Belum Dikerjakan';
      statusIcon = Icons.pending;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tugas['judul'] ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        tugas['nama_mapel'] ?? '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            if (tugas['deskripsi'] != null && tugas['deskripsi'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                tugas['deskripsi'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: isOverdue ? Colors.red : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  deadline != null 
                      ? 'Deadline: ${_formatDate(deadline)}'
                      : 'Tidak ada deadline',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverdue ? Colors.red : Colors.grey.shade600,
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (!isOverdue && deadline != null && daysLeft <= 3 && daysLeft >= 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$daysLeft hari lagi',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            
            // ✅ Tampilkan feedback dari guru jika ada
            if (feedback != null && feedback.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment, color: Colors.amber.shade700, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Feedback Guru:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feedback,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const Divider(height: 24),
            
            Row(
              children: [
                if (!isSubmitted)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToSubmit(tugas),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Submit Tugas'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7BC8A4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  )
                else if (isGraded)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Nilai: $nilai',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Menunggu Penilaian',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}