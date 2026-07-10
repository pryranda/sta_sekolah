import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class AdminMappingScreen extends StatefulWidget {
  const AdminMappingScreen({super.key});

  @override
  State<AdminMappingScreen> createState() => _AdminMappingScreenState();
}

class _AdminMappingScreenState extends State<AdminMappingScreen> {
  List<dynamic> _mappingList = [];
  List<dynamic> _guruList = [];
  List<dynamic> _mapelList = [];
  bool _isLoading = true;

  // ✅ Data yang sudah di-group by guru
  Map<String, Map<String, dynamic>> _groupedData = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔵 Loading admin mapping data...');
      
      final results = await Future.wait([
        ApiService.getAdminGuruMapel(),
        ApiService.getAdminGuru(),
        ApiService.getAdminMapel(),
      ]);

      print('📥 Guru-Mapel response: ${jsonEncode(results[0])}');
      print('📥 Guru response: ${jsonEncode(results[1])}');
      print('📥 Mapel response: ${jsonEncode(results[2])}');

      if (mounted) {
        setState(() {
          // ✅ Handle berbagai format response
          _mappingList = [];
          if (results[0]['success'] == true) {
            final data = results[0]['data'];
            if (data is List) {
              _mappingList = data;
            } else if (data is Map && data.containsKey('data')) {
              _mappingList = data['data'] as List;
            }
          }

          _guruList = [];
          if (results[1]['success'] == true) {
            final data = results[1]['data'];
            if (data is List) {
              _guruList = data;
            } else if (data is Map && data.containsKey('data')) {
              _guruList = data['data'] as List;
            }
          }

          _mapelList = [];
          if (results[2]['success'] == true) {
            final data = results[2]['data'];
            if (data is List) {
              _mapelList = data;
            } else if (data is Map && data.containsKey('data')) {
              _mapelList = data['data'] as List;
            }
          }

          print('✅ Loaded: ${_mappingList.length} mappings, ${_guruList.length} guru, ${_mapelList.length} mapel');
          
          _isLoading = false;
          _groupData();
        });
      }
    } catch (e) {
      print('❌ Error loading mapping: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ Group mapping by guru (gunakan nama guru sebagai key karena API tidak return guru_id)
  void _groupData() {
    print('🔵 Grouping data...');
    print('📊 Total mapping: ${_mappingList.length}');
    
    final grouped = <String, Map<String, dynamic>>{};

    for (var m in _mappingList) {
      print('📝 Processing mapping: $m');
      
      // ✅ Gunakan nama guru sebagai key (karena API tidak return guru_id)
      final guruNama = (
        m['guru_nama'] ?? 
        m['guruNama'] ?? 
        m['nama_guru'] ?? 
        m['nama'] ?? 
        'Unknown'
      ).toString();
      
      // ✅ Gunakan nama guru sebagai unique key
      final guruKey = guruNama;
      
      final mapelNama = (
        m['nama_mapel'] ?? 
        m['namaMapel'] ?? 
        m['mapel_nama'] ?? 
        m['mapel'] ?? 
        'Unknown'
      ).toString();
      
      final mapelKode = (
        m['kode_mapel'] ?? 
        m['kodeMapel'] ?? 
        m['mapel_kode'] ?? 
        m['kode'] ?? 
        '-'
      ).toString();
      
      final mappingId = (m['id']?.toString() ?? '').toString();

      print('✅ Mapped: $guruKey | $guruNama → $mapelNama ($mapelKode)');

      if (!grouped.containsKey(guruKey)) {
        grouped[guruKey] = {
          'guru_nama': guruNama,
          'mapel_list': <Map<String, String>>[],
        };
      }

      (grouped[guruKey]!['mapel_list'] as List).add({
        'nama': mapelNama,
        'kode': mapelKode,
        'mapping_id': mappingId,
      });
    }

    _groupedData = grouped;
    print('✅ Grouped: ${_groupedData.length} guru');
    print('📋 Grouped data: $_groupedData');
  }

  void _showAddMappingDialog() {
    String? selectedGuruId;
    String? selectedMapelId;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Assign Mapel ke Guru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedGuruId,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Guru *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  items: _guruList.map<DropdownMenuItem<String>>((g) {
                    return DropdownMenuItem<String>(
                      value: g['id'].toString(),
                      child: Text(g['nama'] ?? '-'),
                    );
                  }).toList(),
                  onChanged: (v) => setStateDialog(() => selectedGuruId = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedMapelId,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Mata Pelajaran *',
                    prefixIcon: Icon(Icons.book),
                    border: OutlineInputBorder(),
                  ),
                  items: _mapelList.map<DropdownMenuItem<String>>((m) {
                    return DropdownMenuItem<String>(
                      value: m['id'].toString(),
                      child: Text('${m['nama_mapel']} (${m['kode_mapel']})'),
                    );
                  }).toList(),
                  onChanged: (v) => setStateDialog(() => selectedMapelId = v),
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
              onPressed: isLoading
                  ? null
                  : () async {
                      if (selectedGuruId == null || selectedMapelId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pilih guru dan mapel')),
                        );
                        return;
                      }
                      setStateDialog(() => isLoading = true);
                      final result = await ApiService.assignGuruMapel(
                        selectedGuruId!,
                        selectedMapelId!,
                      );
                      setStateDialog(() => isLoading = false);
                      if (result['success'] == true) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Mapping berhasil ditambahkan'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadAll();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Gagal'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(String mappingId, String guruNama, String mapelNama) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Mapping'),
        content: Text('Yakin ingin menghapus mapping $guruNama → $mapelNama?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final result = await ApiService.removeGuruMapel(mappingId);
              if (result['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Mapping berhasil dihapus'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadAll();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Gagal'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ✅ Export data ke CSV
  void _exportToCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Guru,Mata Pelajaran,Kode Mapel');

    for (var entry in _groupedData.entries) {
      final guruNama = entry.value['guru_nama'] ?? '-';
      final mapelList = entry.value['mapel_list'] as List;

      for (var m in mapelList) {
        buffer.writeln('$guruNama,${m['nama']},${m['kode']}');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Data berhasil disalin ke clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mapping Guru-Mapel'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ✅ Tombol Export/Download
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export ke CSV',
            onPressed: _exportToCSV,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMappingDialog,
        backgroundColor: const Color(0xFF1976D2),
        icon: const Icon(Icons.add_link),
        label: const Text('Tambah Mapping'),
      ),
      body: Column(
        children: [
          // Stats Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.link, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Total: ${_groupedData.length} guru • ${_mappingList.length} mapping aktif',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Tree List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.link_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('Belum ada mapping'),
                            const SizedBox(height: 8),
                            Text(
                              'Klik tombol + untuk menambah mapping',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groupedData.length,
                        itemBuilder: (context, index) {
                          final entry = _groupedData.entries.elementAt(index);
                          final guruId = entry.key;
                          final guruNama = entry.value['guru_nama'] ?? '-';
                          final mapelList = entry.value['mapel_list'] as List;

                          return _buildGuruCard(
                            guruId: guruId,
                            guruNama: guruNama,
                            mapelList: mapelList,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ✅ Card per Guru dengan ExpansionTile
  Widget _buildGuruCard({
    required String guruId,
    required String guruNama,
    required List mapelList,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: Icon(Icons.person, color: Colors.blue.shade700),
          ),
          title: Text(
            guruNama,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${mapelList.length} mata pelajaran',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down,
            color: Colors.grey.shade600,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  ...mapelList.map<Widget>((m) {
                    return _buildMapelTile(
                      mappingId: m['mapping_id'].toString(),
                      mapelNama: m['nama'] ?? '-',
                      mapelKode: m['kode'] ?? '-',
                      guruNama: guruNama,
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Tile per Mata Pelajaran
  Widget _buildMapelTile({
    required String mappingId,
    required String mapelNama,
    required String mapelKode,
    required String guruNama,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.book, size: 16, color: Colors.green.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mapelNama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  mapelKode,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
            onPressed: () => _confirmRemove(mappingId, guruNama, mapelNama),
          ),
        ],
      ),
    );
  }
}