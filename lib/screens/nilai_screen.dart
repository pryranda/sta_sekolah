import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../config/api_config.dart';

class NilaiScreen extends StatefulWidget {
  const NilaiScreen({Key? key}) : super(key: key);
  @override
  State<NilaiScreen> createState() => _NilaiScreenState();
}

class _NilaiScreenState extends State<NilaiScreen> {
  static const String baseUrl = kApiBaseUrl;
  
  bool _isLoading = true;
  List _nilaiList = [];
  String _selectedSemester = '1';
  String _selectedTahunAjaran = '2026/2027';
  
  Map<String, dynamic> _statistik = {};

  @override
  void initState() {
    super.initState();
    _loadNilai();
  }

  Future<void> _loadNilai() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse(
          '$baseUrl/student/nilai?semester=$_selectedSemester&tahun_ajaran=$_selectedTahunAjaran'
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        setState(() {
          _nilaiList = data['data'] as List;
          _calculateStatistik();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error load nilai: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateStatistik() {
    if (_nilaiList.isEmpty) {
      _statistik = {};
      return;
    }
    
    double totalNilai = 0;
    int count = 0;
    int tertinggi = 0;
    int terendah = 100;
    
    for (var nilai in _nilaiList) {
      final nilaiAkhir = double.tryParse(nilai['nilai_akhir']?.toString() ?? '0') ?? 0;
      totalNilai += nilaiAkhir;
      count++;
      
      if (nilaiAkhir > tertinggi) tertinggi = nilaiAkhir.toInt();
      if (nilaiAkhir < terendah) terendah = nilaiAkhir.toInt();
    }
    
    _statistik = {
      'rata_rata': count > 0 ? (totalNilai / count).toStringAsFixed(2) : '0',
      'tertinggi': tertinggi,
      'terendah': terendah,
      'total_mapel': count,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Nilai Akademik',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7BC8A4)))
          : Column(
              children: [
                // Filter Section
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              'Semester',
                              _selectedSemester,
                              ['1', '2'],
                              (value) {
                                setState(() => _selectedSemester = value!);
                                _loadNilai();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              'Tahun Ajaran',
                              _selectedTahunAjaran,
                              ['2026/2027', '2025/2026', '2024/2025'],
                              (value) {
                                setState(() => _selectedTahunAjaran = value!);
                                _loadNilai();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Statistik Cards
                if (_statistik.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Rata-rata',
                            _statistik['rata_rata'] ?? '0',
                            Colors.purple,
                            Icons.analytics,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Tertinggi',
                            _statistik['tertinggi']?.toString() ?? '0',
                            Colors.green,
                            Icons.trending_up,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Terendah',
                            _statistik['terendah']?.toString() ?? '0',
                            Colors.red,
                            Icons.trending_down,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Grafik (Simple Bar Chart)
                if (_nilaiList.isNotEmpty) ...[
                  Container(
                    height: 200,
                    padding: const EdgeInsets.all(16),
                    child: _buildSimpleChart(),
                  ),
                ],
                
                // Nilai List
                Expanded(
                  child: _nilaiList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada nilai untuk semester ini',
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
                          itemCount: _nilaiList.length,
                          itemBuilder: (context, index) {
                            final nilai = _nilaiList[index];
                            return _buildNilaiCard(nilai, index + 1);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, 
      ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
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
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleChart() {
    final maxHeight = 120.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Grafik Nilai per Mapel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _nilaiList.take(5).map((nilai) {
              final nilaiAkhir = double.tryParse(nilai['nilai_akhir']?.toString() ?? '0') ?? 0;
              final height = (nilaiAkhir / 100) * maxHeight;
              
              Color barColor;
              if (nilaiAkhir >= 85) barColor = Colors.green;
              else if (nilaiAkhir >= 70) barColor = Colors.blue;
              else if (nilaiAkhir >= 60) barColor = Colors.orange;
              else barColor = Colors.red;
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    nilaiAkhir.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
                  ),
                  Container(
                    width: 30,
                    height: height,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 40,
                    child: Text(
                      (nilai['nama_mapel'] ?? '-').substring(0, math.min(3, (nilai['nama_mapel'] ?? '-').length)),
                      style: const TextStyle(fontSize: 9),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNilaiCard(Map<String, dynamic> nilai, int nomor) {
    final nilaiAkhir = double.tryParse(nilai['nilai_akhir']?.toString() ?? '0') ?? 0;
    final nilaiTugas = double.tryParse(nilai['nilai_tugas']?.toString() ?? '0') ?? 0;
    final nilaiUTS = double.tryParse(nilai['nilai_uts']?.toString() ?? '0') ?? 0;
    final nilaiUAS = double.tryParse(nilai['nilai_uas']?.toString() ?? '0') ?? 0;
    
    Color gradeColor;
    String grade;
    
    if (nilaiAkhir >= 85) {
      gradeColor = Colors.green;
      grade = 'A';
    } else if (nilaiAkhir >= 70) {
      gradeColor = Colors.blue;
      grade = 'B';
    } else if (nilaiAkhir >= 60) {
      gradeColor = Colors.orange;
      grade = 'C';
    } else if (nilaiAkhir >= 50) {
      gradeColor = Colors.red.shade300;
      grade = 'D';
    } else {
      gradeColor = Colors.red;
      grade = 'E';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      nomor.toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: gradeColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nilai['nama_mapel'] ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        nilai['kode_mapel'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: gradeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      grade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNilaiItem('Tugas', nilaiTugas),
                _buildNilaiItem('UTS', nilaiUTS),
                _buildNilaiItem('UAS', nilaiUAS),
                _buildNilaiItem('Akhir', nilaiAkhir, isAkhir: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNilaiItem(String label, double nilai, {bool isAkhir = false}) {
    Color color;
    if (nilai >= 85) color = Colors.green;
    else if (nilai >= 70) color = Colors.blue;
    else if (nilai >= 60) color = Colors.orange;
    else color = Colors.red;
    
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          nilai.toStringAsFixed(0),
          style: TextStyle(
            fontSize: isAkhir ? 20 : 16,
            fontWeight: isAkhir ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}