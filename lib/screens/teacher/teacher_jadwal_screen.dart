import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class TeacherJadwalScreen extends StatefulWidget {
  const TeacherJadwalScreen({super.key});

  @override
  State<TeacherJadwalScreen> createState() => _TeacherJadwalScreenState();
}

class _TeacherJadwalScreenState extends State<TeacherJadwalScreen> {
  List<dynamic> _jadwalList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJadwal();
  }

  Future<void> _loadJadwal() async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.getJadwalGuru();
      
      print('📥 API Response: $result');
      
      if (result['success'] == true) {
        final jadwalData = result['data'];
        
        if (jadwalData is List) {
          setState(() {
            _jadwalList = jadwalData;
            _isLoading = false;
          });
        } else if (jadwalData is Map<String, dynamic>) {
          final jadwalList = jadwalData['jadwal'] ?? [];
          setState(() {
            _jadwalList = jadwalList is List ? jadwalList : [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _jadwalList = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Jadwal Mengajar'),
        backgroundColor: const Color(0xFF2196F3),
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2196F3)))
          : _jadwalList.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Belum ada jadwal mengajar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Group by hari
    final Map<String, List> groupedJadwal = {};
    for (var item in _jadwalList) {
      final hari = item['hari'] ?? 'Unknown';
      if (!groupedJadwal.containsKey(hari)) {
        groupedJadwal[hari] = [];
      }
      groupedJadwal[hari]!.add(item);
    }

    final hariOrder = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final sortedHari = groupedJadwal.keys.toList()
      ..sort((a, b) {
        final indexA = hariOrder.indexOf(a);
        final indexB = hariOrder.indexOf(b);
        return indexA.compareTo(indexB);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedHari.length,
      itemBuilder: (context, index) {
        final hari = sortedHari[index];
        final items = groupedJadwal[hari]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: const Color(0xFF2196F3)),
                    const SizedBox(width: 8),
                    Text(
                      hari,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length} jadwal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ...items.map((item) => _buildJadwalItem(item)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJadwalItem(Map<String, dynamic> item) {
    final jamMulai = item['jam_mulai']?.toString().substring(0, 5) ?? '-';
    final jamSelesai = item['jam_selesai']?.toString().substring(0, 5) ?? '-';
    final kelas = item['nama_kelas'] ?? '-';
    final mapel = item['nama_mapel'] ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7BC8A4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.class_, color: Color(0xFF7BC8A4), size: 24),
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
                const SizedBox(height: 4),
                Text(
                  'Kelas: $kelas',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$jamMulai - $jamSelesai',
              style: const TextStyle(
                color: Color(0xFF2196F3),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}