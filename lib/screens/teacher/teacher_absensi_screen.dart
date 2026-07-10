import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';

class TeacherAbsensiScreen extends StatefulWidget {
  const TeacherAbsensiScreen({super.key});

  @override
  State<TeacherAbsensiScreen> createState() => _TeacherAbsensiScreenState();
}

class _TeacherAbsensiScreenState extends State<TeacherAbsensiScreen> {
  List<dynamic> _kelasList = [];
  List<dynamic> _siswaList = [];
  Map<String, Map<String, int>> _siswaRekap = {};
  bool _isLoading = true;
  String? _selectedKelasId;
  String? _selectedKelasNama;

  @override
  void initState() {
    super.initState();
    _loadKelas();
  }

  Future<void> _loadKelas() async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.getJadwalGuru();
      
      if (result['success'] == true) {
        final data = result['data'];
        List<dynamic> jadwalList = [];
        
        if (data is List) {
          jadwalList = data;
        } else if (data is Map) {
          jadwalList = data['jadwal'] ?? data['data'] ?? [];
        }
        
        final uniqueClasses = <String, String>{};
        for (var item in jadwalList) {
          if (item is Map) {
            final kelasId = item['kelas_id'];
            final namaKelas = item['nama_kelas'];
            
            if (kelasId != null && namaKelas != null) {
              uniqueClasses[kelasId] = namaKelas;
            }
          }
        }

        setState(() {
          _kelasList = uniqueClasses.entries.map((e) => {
            'id': e.key,
            'nama': e.value,
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSiswa(String kelasId) async {
    setState(() => _isLoading = true);

    try {
      final headers = await ApiService.getHeaders();
      final url = '${ApiService.baseUrl}/teacher/kelas/$kelasId/siswa';
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      
      final result = jsonDecode(response.body);
      
      if (result['success'] == true) {
        final data = result['data'];
        List<dynamic> siswaList = [];
        
        if (data is List) {
          siswaList = data;
        } else if (data is Map) {
          siswaList = data['siswa'] ?? data['data'] ?? [];
        }
        
        await _loadAbsensiKelas(kelasId, siswaList);
        
        setState(() {
          _siswaList = siswaList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAbsensiKelas(String kelasId, List<dynamic> siswaList) async {
    try {
      final headers = await ApiService.getHeaders();
      final url = '${ApiService.baseUrl}/teacher/absensi/kelas/$kelasId';
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      
      final result = jsonDecode(response.body);
      
      if (result['success'] == true) {
        final data = result['data'];
        List<dynamic> absensiList = [];
        
        if (data is List) {
          absensiList = data;
        } else if (data is Map) {
          absensiList = data['absensi'] ?? data['data'] ?? [];
        }
        
        Map<String, Map<String, int>> rekapPerSiswa = {};
        
        for (var siswa in siswaList) {
          final siswaId = siswa['id']?.toString();
          if (siswaId != null) {
            rekapPerSiswa[siswaId] = {
              'hadir': 0,
              'izin': 0,
              'sakit': 0,
              'alpha': 0,
            };
          }
        }
        
        for (var item in absensiList) {
          if (item is Map) {
            final siswaId = item['id']?.toString();
            final absensiList = item['absensi'];
            
            if (siswaId != null && absensiList is List && rekapPerSiswa.containsKey(siswaId)) {
              for (var abs in absensiList) {
                if (abs is Map) {
                  final status = abs['status']?.toString().toLowerCase();
                  if (status == 'hadir') {
                    rekapPerSiswa[siswaId]!['hadir'] = rekapPerSiswa[siswaId]!['hadir']! + 1;
                  } else if (status == 'izin') {
                    rekapPerSiswa[siswaId]!['izin'] = rekapPerSiswa[siswaId]!['izin']! + 1;
                  } else if (status == 'sakit') {
                    rekapPerSiswa[siswaId]!['sakit'] = rekapPerSiswa[siswaId]!['sakit']! + 1;
                  } else if (status == 'alpha') {
                    rekapPerSiswa[siswaId]!['alpha'] = rekapPerSiswa[siswaId]!['alpha']! + 1;
                  }
                }
              }
            }
          }
        }
        
        setState(() {
          _siswaRekap = rekapPerSiswa;
        });
      }
    } catch (e) {
      print('❌ Error loading absensi: $e');
    }
  }

  // ✅ Hitung summary
  Map<String, dynamic> _getSummary() {
    if (_siswaList.isEmpty) return {};
    
    String? rajinHadir;
    int maxHadir = 0;
    
    String? palingIzin;
    int maxIzin = 0;
    
    String? palingSakit;
    int maxSakit = 0;
    
    String? palingAlpha;
    int maxAlpha = 0;
    
    for (var siswa in _siswaList) {
      final siswaId = siswa['id']?.toString();
      if (siswaId == null) continue;
      
      final rekap = _siswaRekap[siswaId] ?? {'hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0};
      final nama = siswa['nama'] ?? 'Unknown';
      
      if (rekap['hadir']! > maxHadir) {
        maxHadir = rekap['hadir']!;
        rajinHadir = nama;
      }
      
      if (rekap['izin']! > maxIzin) {
        maxIzin = rekap['izin']!;
        palingIzin = nama;
      }
      
      if (rekap['sakit']! > maxSakit) {
        maxSakit = rekap['sakit']!;
        palingSakit = nama;
      }
      
      if (rekap['alpha']! > maxAlpha) {
        maxAlpha = rekap['alpha']!;
        palingAlpha = nama;
      }
    }
    
    return {
      'rajinHadir': rajinHadir,
      'maxHadir': maxHadir,
      'palingIzin': palingIzin,
      'maxIzin': maxIzin,
      'palingSakit': palingSakit,
      'maxSakit': maxSakit,
      'palingAlpha': palingAlpha,
      'maxAlpha': maxAlpha,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Absensi Kelas'),
        backgroundColor: const Color(0xFF7BC8A4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7BC8A4)))
          : _selectedKelasId == null
              ? _buildKelasList()
              : _buildSiswaList(),
    );
  }

  Widget _buildKelasList() {
    if (_kelasList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'Belum ada kelas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _kelasList.length,
      itemBuilder: (context, index) {
        final kelas = _kelasList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.class_, color: Color(0xFF7BC8A4)),
            title: Text(kelas['nama'] ?? '-'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectedKelasId = kelas['id'];
                _selectedKelasNama = kelas['nama'];
              });
              _loadSiswa(kelas['id']);
            },
          ),
        );
      },
    );
  }

  Widget _buildSiswaList() {
    final summary = _getSummary();
    
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF7BC8A4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _selectedKelasId = null;
                    _selectedKelasNama = null;
                    _siswaList = [];
                    _siswaRekap = {};
                  });
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kelas $_selectedKelasNama',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_siswaList.length} siswa',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ✅ Summary Section
              if (summary.isNotEmpty) ...[
                _buildSummaryCard(summary),
                const SizedBox(height: 16),
              ],
              
              // ✅ List Siswa dengan Riwayat HISA
              ..._siswaList.map((siswa) {
                final siswaId = siswa['id']?.toString() ?? '';
                final rekap = _siswaRekap[siswaId] ?? {
                  'hadir': 0, 'izin': 0, 'sakit': 0, 'alpha': 0
                };
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSiswaCard(siswa, rekap),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
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
                Icon(Icons.emoji_events, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Summary Kelas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2B1C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    '🏆 Rajin Hadir',
                    summary['rajinHadir'] ?? '-',
                    '${summary['maxHadir']}x',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryItem(
                    '📝 Paling Izin',
                    summary['palingIzin'] ?? '-',
                    '${summary['maxIzin']}x',
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    '🤒 Paling Sakit',
                    summary['palingSakit'] ?? '-',
                    '${summary['maxSakit']}x',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryItem(
                    '❌ Paling Alpha',
                    summary['palingAlpha'] ?? '-',
                    '${summary['maxAlpha']}x',
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String nama, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nama,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A2B1C),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiswaCard(Map<String, dynamic> siswa, Map<String, int> rekap) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF7BC8A4).withOpacity(0.1),
              child: Text(
                (siswa['nama'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF7BC8A4),
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
                    siswa['nama'] ?? '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'NIS: ${siswa['nis'] ?? '-'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Rekap HISA
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMiniStat(rekap['hadir']!, Colors.green),
                const SizedBox(width: 4),
                _buildMiniStat(rekap['izin']!, Colors.blue),
                const SizedBox(width: 4),
                _buildMiniStat(rekap['sakit']!, Colors.orange),
                const SizedBox(width: 4),
                _buildMiniStat(rekap['alpha']!, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(int count, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}