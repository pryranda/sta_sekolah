import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'admin_schedule_editor_screen.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  List<dynamic> _kelasList = [];
  List<dynamic> _scheduleList = [];
  Map<String, dynamic>? _scheduleConfig;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _selectedKelasId;
  String? _selectedKelasNama;
  String? _selectedHari;

  final List<String> _hariList = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        ApiService.getKelas(),
        ApiService.getScheduleConfig(),
      ]);

      if (mounted) {
        setState(() {
          _kelasList = results[0]['success'] == true ? results[0]['data'] : [];
          _scheduleConfig = results[1]['success'] == true ? results[1]['data'] : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadSchedule() async {
    if (_selectedKelasId == null || _selectedHari == null) {
      setState(() => _scheduleList = []);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final result = await ApiService.getScheduleByClass(
        _selectedKelasId!,
        hari: _selectedHari,
      );

      if (mounted) {
        setState(() {
          _scheduleList = result['success'] == true ? result['data'] : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat jadwal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showGenerateDialog() async {
    final List<String> selectedKelasIds = [];
    final List<String> selectedHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'];
    String tahunAjaran = '2026/2027';
    int semester = 1;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Generate Jadwal Otomatis'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Kelas:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kelasList.map((k) {
                    final isSelected = selectedKelasIds.contains(k['id']);
                    return FilterChip(
                      label: Text(k['nama_kelas'] ?? ''),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedKelasIds.add(k['id']);
                          } else {
                            selectedKelasIds.remove(k['id']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Hari Aktif:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _hariList.map((hari) {
                    final isSelected = selectedHari.contains(hari);
                    return FilterChip(
                      label: Text(hari),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedHari.add(hari);
                          } else {
                            selectedHari.remove(hari);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Tahun Ajaran',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => tahunAjaran = v,
                  controller: TextEditingController(text: tahunAjaran),
                ),
                const SizedBox(height: 16),
                const Text(
                  '⚠️ Jadwal lama akan dihapus dan digantikan dengan jadwal baru.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
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
              onPressed: selectedKelasIds.isEmpty || selectedHari.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _generateSchedule(selectedKelasIds, selectedHari, tahunAjaran, semester);
                    },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateSchedule(
    List<String> kelasIds,
    List<String> hariList,
    String tahunAjaran,
    int semester,
  ) async {
    setState(() => _isGenerating = true);
    
    try {
      final result = await ApiService.generateSchedule(
        kelasIds: kelasIds,
        hariList: hariList,
        tahunAjaran: tahunAjaran,
        semester: semester,
      );

      if (mounted) {
        setState(() => _isGenerating = false);
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Jadwal berhasil di-generate! Total: ${result['data']['total_schedules']} slot'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          _loadSchedule();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Kelola Jadwal'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _showGenerateDialog,
        backgroundColor: const Color(0xFF1976D2),
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(_isGenerating ? 'Generating...' : 'Generate Jadwal'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Section
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedKelasId,
                          decoration: const InputDecoration(
                            labelText: 'Pilih Kelas',
                            prefixIcon: Icon(Icons.class_),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          isDense: true,
                          items: _kelasList.map<DropdownMenuItem<String>>((k) {
                            return DropdownMenuItem<String>(
                              value: k['id'],
                              child: Text(k['nama_kelas'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedKelasId = v;
                              final kelas = _kelasList.firstWhere((k) => k['id'] == v);
                              _selectedKelasNama = kelas['nama_kelas'];
                              _loadSchedule();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedHari,
                          decoration: const InputDecoration(
                            labelText: 'Pilih Hari',
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          isDense: true,
                          items: _hariList
                              .map((hari) => DropdownMenuItem<String>(
                                    value: hari,
                                    child: Text(hari),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedHari = v;
                              _loadSchedule();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Schedule List
                Expanded(
                  child: _selectedKelasId == null || _selectedHari == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_note, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text('Pilih kelas dan hari untuk melihat jadwal'),
                            ],
                          ),
                        )
                      : _scheduleList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  const Text('Belum ada jadwal'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Klik tombol "Generate Jadwal" untuk membuat jadwal otomatis',
                                    style: TextStyle(color: Colors.grey.shade600),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadSchedule,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _scheduleList.length,
                                itemBuilder: (context, index) {
                                  final schedule = _scheduleList[index];
                                  return _buildScheduleCard(schedule);
                                },
                              ),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final jamMulai = schedule['jam_mulai']?.toString().substring(0, 5) ?? '-';
    final jamSelesai = schedule['jam_selesai']?.toString().substring(0, 5) ?? '-';
    final mapelNama = schedule['nama_mapel'] ?? 'Upacara/Lainnya';
    final kodeMapel = schedule['kode_mapel'] ?? '';
    final guruNama = schedule['guru_nama'] ?? '-';

    // Warna berdasarkan jenis mapel
    Color cardColor;
    IconData icon;
    if (schedule['mapel_id'] == null) {
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
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey.shade800),
        ),
        title: Text(
          '$jamMulai - $jamSelesai',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              mapelNama,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              guruNama,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: const Icon(Icons.edit, color: Colors.blue, size: 20),
        onTap: () {
          if (_selectedKelasId != null && _selectedKelasNama != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminScheduleEditorScreen(
                  kelasId: _selectedKelasId!,
                  kelasNama: _selectedKelasNama!,
                  initialHari: _selectedHari,
                  initialSchedule: schedule,
                ),
              ),
            ).then((_) => _loadSchedule()); // Refresh setelah kembali
          }
        },
      ),
    );
  }
}