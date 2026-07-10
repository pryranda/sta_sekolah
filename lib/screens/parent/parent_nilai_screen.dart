import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ParentNilaiScreen extends StatefulWidget {
  final String anakId;
  final String anakNama;
  
  const ParentNilaiScreen({
    super.key,
    required this.anakId,
    required this.anakNama,
  });

  @override
  State<ParentNilaiScreen> createState() => _ParentNilaiScreenState();
}

class _ParentNilaiScreenState extends State<ParentNilaiScreen> {
  List<dynamic> _nilaiList = [];
  Map<String, dynamic>? _pagination;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNilai();
  }

  // ✅ Helper untuk konversi ke double yang aman
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadNilai() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _nilaiList = [];
      _pagination = null;
    });

    try {
      print('🔍 Loading nilai for anak: ${widget.anakId}');
      
      final result = await ApiService.getNilaiAnak(widget.anakId);
      
      print('📥 Response: ${result['success']}');
      
      if (result['success'] == true) {
        final data = result['data'];
        
        if (data != null && data is Map<String, dynamic>) {
          final nilai = data['nilai'];
          final pagination = data['pagination'];
          
          if (nilai is List) {
            print('✅ Found ${nilai.length} nilai records');
            setState(() {
              _nilaiList = nilai;
              _pagination = pagination;
              _isLoading = false;
            });
          } else {
            setState(() {
              _nilaiList = [];
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _nilaiList = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal memuat data nilai';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Nilai ${widget.anakNama}'),
        backgroundColor: const Color(0xFF7BC8A4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNilai,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF7BC8A4)),
                  SizedBox(height: 16),
                  Text(
                    'Memuat data nilai...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadNilai,
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

  Widget _buildContent() {
    if (_nilaiList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grade_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada data nilai',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nilai akan muncul setelah guru menginput',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // Calculate overall average
    double totalAverage = 0;
    int count = 0;
    for (var item in _nilaiList) {
      final nilaiAkhir = _toDouble(item['nilai_akhir']);
      if (nilaiAkhir > 0) {
        totalAverage += nilaiAkhir;
        count++;
      }
    }
    final overallAverage = count > 0 ? totalAverage / count : 0.0;

    return Column(
      children: [
        // Overall Average Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getNilaiColor(overallAverage),
                _getNilaiColor(overallAverage).withOpacity(0.7),
              ],
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 8),
              const Text(
                'Rata-rata Keseluruhan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                overallAverage.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'dari ${_nilaiList.length} mata pelajaran',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Nilai List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _nilaiList.length,
            itemBuilder: (context, index) {
              final item = _nilaiList[index];
              return _buildNilaiCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNilaiCard(Map<String, dynamic> item) {
    final mapel = item['nama_mapel'] ?? 'Mata Pelajaran';
    final nilaiAkhir = _toDouble(item['nilai_akhir']);
    final guru = item['guru_nama'] ?? '-';
    final semester = item['semester'] ?? '-';
    final tahunAjaran = item['tahun_ajaran'] ?? '-';
    final predikat = item['predikat'] ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getNilaiColor(nilaiAkhir),
                  child: Text(
                    mapel.isNotEmpty ? mapel[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mapel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Guru: $guru',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getNilaiColor(nilaiAkhir),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        nilaiAkhir.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        predikat,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Detail Nilai
            Row(
              children: [
                _buildNilaiDetail('Tugas', _toDouble(item['nilai_tugas'])),
                const SizedBox(width: 8),
                _buildNilaiDetail('UTS', _toDouble(item['nilai_uts'])),
                const SizedBox(width: 8),
                _buildNilaiDetail('UAS', _toDouble(item['nilai_uas'])),
              ],
            ),
            const SizedBox(height: 8),
            
            // Info
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Semester $semester - $tahunAjaran',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNilaiDetail(String label, double nilai) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nilai > 0 ? nilai.toStringAsFixed(0) : '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getNilaiColor(double nilai) {
    if (nilai >= 85) return const Color(0xFF7BC8A4); // Hijau mint
    if (nilai >= 70) return Colors.blue;
    if (nilai >= 60) return Colors.orange;
    return Colors.red;
  }
}