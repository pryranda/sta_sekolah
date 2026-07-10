import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ParentJadwalScreen extends StatefulWidget {
  final String anakId;
  final String anakNama;
  
  const ParentJadwalScreen({
    super.key,
    required this.anakId,
    required this.anakNama,
  });

  @override
  State<ParentJadwalScreen> createState() => _ParentJadwalScreenState();
}

class _ParentJadwalScreenState extends State<ParentJadwalScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJadwal();
  }

  Future<void> _loadJadwal() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await ApiService.getJadwalAnak(widget.anakId)
          .timeout(const Duration(seconds: 10));
      
      setState(() {
        _data = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _data = {'success': false, 'message': 'Error: $e'};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jadwal ${widget.anakNama}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJadwal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null || !_data!['success']
              ? Center(child: Text(_data?['message'] ?? 'Gagal memuat data'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final jadwal = _data!['data']['jadwal'] as List? ?? [];
    
    if (jadwal.isEmpty) {
      return const Center(child: Text('Belum ada jadwal'));
    }

    // Filter jadwal yang punya nama_mapel (tidak null)
    final filteredJadwal = jadwal.where((j) => j['nama_mapel'] != null).toList();

    // Group by hari
    final Map<String, List> groupedJadwal = {};
    for (var item in filteredJadwal) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      hari,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length} pelajaran',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ...items.map((item) {
                final jamMulai = item['jam_mulai']?.toString().substring(0, 5) ?? '-';
                final jamSelesai = item['jam_selesai']?.toString().substring(0, 5) ?? '-';
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      (item['nama_mapel'] ?? '?')[0].toUpperCase(),
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                  title: Text(
                    item['nama_mapel'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '$jamMulai - $jamSelesai\nGuru: ${item['guru_nama'] ?? '-'}',
                  ),
                  trailing: item['ruangan'] != null
                      ? Text(
                          item['ruangan'],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}