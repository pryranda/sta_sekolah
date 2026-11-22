import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({Key? key}) : super(key: key);
  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  static const String baseUrl = kApiBaseUrl;
  
  bool _isLoading = true;
  String _selectedHari = 'Senin';
  List _jadwalList = [];
  
  final List<String> _hariList = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'
  ];

  @override
  void initState() {
    super.initState();
    _loadJadwal();
  }

  Future<void> _loadJadwal() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/student/jadwal'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        setState(() {
          _jadwalList = data['data']['jadwal'] as List;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error load jadwal: $e');
      setState(() => _isLoading = false);
    }
  }

  List _getJadwalForHari(String hari) {
    return _jadwalList.where((j) {
      final jadwalHari = (j['hari'] ?? '').toString().toLowerCase();
      return jadwalHari == hari.toLowerCase();
    }).toList()
      ..sort((a, b) {
        final jamA = (a['jam_mulai'] ?? '00:00').toString();
        final jamB = (b['jam_mulai'] ?? '00:00').toString();
        return jamA.compareTo(jamB);
      });
  }

  @override
  Widget build(BuildContext context) {
    final jadwalHariIni = _getJadwalForHari(_selectedHari);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Jadwal Pelajaran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF7BC8A4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJadwal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7BC8A4)))
          : Column(
              children: [
                // Hari Selector
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _hariList.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final hari = _hariList[index];
                      final isSelected = hari == _selectedHari;
                      
                      return GestureDetector(
                        onTap: () => setState(() => _selectedHari = hari),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? const Color(0xFF7BC8A4) 
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? const Color(0xFF7BC8A4) 
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            hari,
                            style: TextStyle(
                              color: isSelected 
                                  ? Colors.white 
                                  : Colors.grey.shade700,
                              fontWeight: isSelected 
                                  ? FontWeight.bold 
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Jadwal List
                Expanded(
                  child: jadwalHariIni.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tidak ada jadwal untuk $_selectedHari',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: jadwalHariIni.length,
                          itemBuilder: (context, index) {
                            final jadwal = jadwalHariIni[index];
                            return _buildJadwalCard(jadwal, index + 1);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ============= UBAHAN UTAMA ADA DI SINI =============
  // Sekarang 1 jadwal = 1 Row (horizontal) dengan layout compact
  Widget _buildJadwalCard(Map<String, dynamic> jadwal, int nomor) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            // 1. Nomor Urut
            SizedBox(
              width: 28,
              child: Text(
                '$nomor',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF7BC8A4),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // 2. Nama Mapel + Kode
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jadwal['nama_mapel'] ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    jadwal['kode_mapel'] ?? '',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 3. Waktu Mulai - Selesai
            Expanded(
              flex: 2,
              child: Text(
                '${jadwal['jam_mulai'] ?? '-'} - ${jadwal['jam_selesai'] ?? '-'}',
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 8),

            // 4. Ruangan
            Expanded(
              flex: 1,
              child: Text(
                jadwal['ruangan'] ?? '-',
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 8),

            // 5. Nama Guru
            Expanded(
              flex: 2,
              child: Text(
                jadwal['guru_nama'] ?? '-',
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}