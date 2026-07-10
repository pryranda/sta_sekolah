import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminScheduleEditorScreen extends StatefulWidget {
  final String kelasId;
  final String kelasNama;
  final String? initialHari;
  final Map<String, dynamic>? initialSchedule;

  const AdminScheduleEditorScreen({
    super.key,
    required this.kelasId,
    required this.kelasNama,
    this.initialHari,
    this.initialSchedule,
  });

  @override
  State<AdminScheduleEditorScreen> createState() => _AdminScheduleEditorScreenState();
}

class _AdminScheduleEditorScreenState extends State<AdminScheduleEditorScreen> {
  List<dynamic> _schedule = [];
  List<dynamic> _mapelList = [];
  List<dynamic> _guruList = [];
  bool _isLoading = true;
  String? _selectedHari;

  final List<String> _hariList = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  @override
  void initState() {
    super.initState();
    _selectedHari = widget.initialHari ?? 'Senin';
    _loadData().then((_) {
      if (widget.initialSchedule != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showEditDialog(widget.initialSchedule!);
        });
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getScheduleByClass(widget.kelasId, hari: _selectedHari),
        ApiService.getAdminMapel(),
        ApiService.getAdminGuru(),
      ]);

      if (mounted) {
        setState(() {
          _schedule = results[0]['success'] == true ? results[0]['data'] : [];
          _mapelList = results[1]['success'] == true ? results[1]['data'] : [];
          _guruList = results[2]['success'] == true ? results[2]['data'] : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> item) {
    String? selectedMapel = item['mapel_id'] as String?;
    String? selectedGuru = item['guru_id'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit Jadwal',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${item['jam_mulai']?.toString().substring(0, 5)} - ${item['jam_selesai']?.toString().substring(0, 5)}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedMapel,
                  decoration: const InputDecoration(
                    labelText: 'Mata Pelajaran',
                    prefixIcon: Icon(Icons.book),
                    border: OutlineInputBorder(),
                  ),
                  items: _mapelList.map<DropdownMenuItem<String>>((m) => DropdownMenuItem<String>(
                    value: m['id'] as String,
                    child: Text(m['nama_mapel'] ?? '-'),
                  )).toList(),
                  onChanged: (v) => setModalState(() => selectedMapel = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGuru,
                  decoration: const InputDecoration(
                    labelText: 'Guru Pengampu',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  items: _guruList.map<DropdownMenuItem<String>>((g) => DropdownMenuItem<String>(
                    value: g['id'] as String,
                    child: Text(g['nama'] ?? '-'),
                  )).toList(),
                  onChanged: (v) => setModalState(() => selectedGuru = v),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Jadwal'),
                              content: const Text('Yakin ingin menghapus jadwal ini?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final result = await ApiService.deleteScheduleManual(item['id']);
                            if (mounted) {
                              if (result['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ Jadwal dihapus'), backgroundColor: Colors.green),
                                );
                                _loadData();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal: ${result['message']}'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Simpan'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          if (selectedMapel != null && selectedGuru != null) {
                            Navigator.pop(context);
                            final result = await ApiService.updateSchedule(
                              item['id'],
                              mapelId: selectedMapel!,
                              guruId: selectedGuru!,
                              jamMulai: item['jam_mulai'].toString().substring(0, 5),
                              jamSelesai: item['jam_selesai'].toString().substring(0, 5),
                            );
                            if (mounted) {
                              if (result['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ Jadwal diupdate'), backgroundColor: Colors.green),
                                );
                                _loadData();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal: ${result['message']}'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Pilih mapel dan guru terlebih dahulu'), backgroundColor: Colors.orange),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jadwal ${widget.kelasNama}'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _hariList.map((hari) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(hari),
                    selected: _selectedHari == hari,
                    selectedColor: Colors.blue.shade100,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedHari = hari;
                        });
                        _loadData();
                      }
                    },
                  ),
                )).toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _schedule.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height / 3),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    const Text('Belum ada jadwal untuk hari ini'),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _schedule.length,
                            itemBuilder: (context, index) {
                              final item = _schedule[index];
                              return _buildScheduleItem(item);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> item) {
    final jamMulai = item['jam_mulai']?.toString().substring(0, 5) ?? '-';
    final jamSelesai = item['jam_selesai']?.toString().substring(0, 5) ?? '-';
    final mapelNama = item['nama_mapel'] ?? 'Kosong';
    final guruNama = item['guru_nama'] ?? '-';
    final kodeMapel = item['kode_mapel'] ?? '';

    Color cardColor;
    IconData icon;
    if (item['mapel_id'] == null) {
      cardColor = Colors.grey.shade100;
      icon = Icons.flag;
    } else if (kodeMapel == 'PJOK') {
      cardColor = Colors.orange.shade100;
      icon = Icons.sports_soccer;
    } else if (['BIND', 'BING', 'BSND', 'ARAB'].contains(kodeMapel)) {
      cardColor = Colors.purple.shade100;
      icon = Icons.menu_book;
    } else if (['MTK', 'IPAS'].contains(kodeMapel)) {
      cardColor = Colors.green.shade100;
      icon = Icons.calculate;
    } else if (['PAI', 'ALIS', 'BTQ', 'TFZ'].contains(kodeMapel)) {
      cardColor = Colors.teal.shade100;
      icon = Icons.mosque;
    } else {
      cardColor = Colors.blue.shade100;
      icon = Icons.book;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.grey.shade800, size: 20),
              const SizedBox(height: 4),
              Text(
                jamMulai,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        title: Text(
          mapelNama,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          guruNama,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            jamSelesai,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () => _showEditDialog(item),
      ),
    );
  }
}