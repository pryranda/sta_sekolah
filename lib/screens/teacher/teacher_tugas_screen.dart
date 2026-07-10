import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';
import 'teacher_submission_screen.dart';

class TeacherTugasScreen extends StatefulWidget {
  const TeacherTugasScreen({super.key});

  @override
  State<TeacherTugasScreen> createState() => _TeacherTugasScreenState();
}

class _TeacherTugasScreenState extends State<TeacherTugasScreen> {
  List<dynamic> _tugasList = [];
  List<dynamic> _kelasList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTugas();
    _loadKelas();
  }

  Future<void> _loadTugas() async {
    setState(() => _isLoading = true);

    try {
      final headers = await ApiService.getHeaders();
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/tugas/guru/tugas'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('📥 Tugas response: ${response.body}');
      final result = jsonDecode(response.body);

      if (result['success'] == true) {
        final data = result['data'];
        List<dynamic> tugasList = [];

        if (data is List) {
          tugasList = data;
        } else if (data is Map) {
          tugasList = data['tugas'] ?? data['data'] ?? [];
        }

        setState(() {
          _tugasList = tugasList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading tugas: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadKelas() async {
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
              uniqueClasses[kelasId.toString()] = namaKelas;
            }
          }
        }

        setState(() {
          _kelasList = uniqueClasses.entries.map((e) => {
            'id': e.key,
            'nama': e.value,
          }).toList();
        });
      }
    } catch (e) {
      print('❌ Error loading kelas: $e');
    }
  }

  void _navigateToCreateTugas() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTugasScreen(kelasList: _kelasList),
      ),
    ).then((_) => _loadTugas());
  }

  void _viewTugasDetail(dynamic tugas) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TeacherSubmissionScreen(tugas: tugas),
    ),
  ).then((_) {
    // Refresh tugas list setelah kembali dari submission screen
    _loadTugas();
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Tugas'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTugas,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateTugas,
        icon: const Icon(Icons.add),
        label: const Text('Buat Tugas'),
        backgroundColor: const Color(0xFF9C27B0),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0)))
          : _tugasList.isEmpty
              ? _buildEmptyState()
              : _buildTugasList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Belum ada tugas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Klik tombol + untuk membuat tugas baru',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToCreateTugas,
            icon: const Icon(Icons.add),
            label: const Text('Buat Tugas Pertama'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C27B0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTugasList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tugasList.length,
      itemBuilder: (context, index) {
        final tugas = _tugasList[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTugasCard(tugas),
        );
      },
    );
  }

  Widget _buildTugasCard(Map<String, dynamic> tugas) {
    return FutureBuilder<int>(
      future: _getSubmissionCount(tugas['id']),
      builder: (context, snapshot) {
        final submissionCount = snapshot.data ?? 0;
        return _buildTugasCardUI(tugas, submissionCount);
      },
    );
  }

  Future<int> _getSubmissionCount(String tugasId) async {
  try {
    final headers = await ApiService.getHeaders();
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/teacher/tugas/$tugasId/submissions'),  // ✅ Path yang benar
      headers: headers,
    ).timeout(const Duration(seconds: 10));

    print('📥 Submission count response: ${response.body}');
    final result = jsonDecode(response.body);
    if (result['success'] == true) {
      return result['data']['total_submitted'] ?? 0;
    }
  } catch (e) {
    print('❌ Error getting submission count: $e');
  }
  return 0;
}

  Widget _buildTugasCardUI(Map<String, dynamic> tugas, int submissionCount) {
    final judul = tugas['judul'] ?? 'Tanpa Judul';
    final deskripsi = tugas['deskripsi'] ?? '';
    final deadline = tugas['deadline'] ?? '-';
    final status = tugas['status'] ?? 'aktif';
    final kelasNama = tugas['nama_kelas'] ?? '-';

    final isExpired = DateTime.tryParse(deadline)?.isBefore(DateTime.now()) ?? false;
    final currentStatus = isExpired ? 'expired' : status;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _viewTugasDetail(tugas),
        borderRadius: BorderRadius.circular(16),
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
                      color: const Color(0xFF9C27B0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment, color: Color(0xFF9C27B0)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          judul,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.class_, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              kelasNama,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentStatus == 'aktif'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentStatus == 'aktif' ? 'AKTIF' : 'EXPIRED',
                      style: TextStyle(
                        color: currentStatus == 'aktif' ? Colors.green : Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (deskripsi.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  deskripsi,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Deadline: $deadline',
                    style: TextStyle(
                      fontSize: 12,
                      color: isExpired ? Colors.red : Colors.grey.shade600,
                      fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: submissionCount > 0 
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people, 
                          size: 14, 
                          color: submissionCount > 0 ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$submissionCount submission',
                          style: TextStyle(
                            fontSize: 12,
                            color: submissionCount > 0 ? Colors.blue : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// CREATE TUGAS SCREEN
// ============================================

class CreateTugasScreen extends StatefulWidget {
  final List<dynamic> kelasList;

  const CreateTugasScreen({super.key, required this.kelasList});

  @override
  State<CreateTugasScreen> createState() => _CreateTugasScreenState();
}

class _CreateTugasScreenState extends State<CreateTugasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  DateTime? _deadlineDate;
  TimeOfDay? _deadlineTime;
  String? _selectedKelasId;
  String? _selectedMapelId;
  List<dynamic> _mapelList = [];
  List<dynamic> _allJadwal = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllJadwal();
  }

  Future<void> _loadAllJadwal() async {
    try {
      print('🔵 [TUGAS] Loading all jadwal...');
      final result = await ApiService.getJadwalGuru();
      print('📥 [TUGAS] Jadwal response success: ${result['success']}');

      if (result['success'] == true) {
        final data = result['data'];
        print('📊 [TUGAS] Data type: ${data.runtimeType}');
        
        List<dynamic> jadwalList = [];

        if (data is List) {
          jadwalList = data;
        } else if (data is Map) {
          jadwalList = data['jadwal'] ?? data['data'] ?? [];
        }

        print('✅ [TUGAS] Total jadwal loaded: ${jadwalList.length}');
        
        if (jadwalList.isNotEmpty) {
          final firstItem = jadwalList[0];
          print('📋 [TUGAS] First item: $firstItem');
          print('📋 [TUGAS] First item kelas_id: ${firstItem['kelas_id']}');
          print('📋 [TUGAS] First item mapel_id: ${firstItem['mapel_id']}');
        }
        
        final uniqueKelas = <String>{};
        for (var item in jadwalList) {
          if (item is Map && item['kelas_id'] != null) {
            uniqueKelas.add(item['kelas_id'].toString());
          }
        }
        print('📚 [TUGAS] Unique kelas IDs: $uniqueKelas');

        setState(() {
          _allJadwal = jadwalList;
        });
        
        if (_selectedKelasId != null) {
          _updateMapelList();
        }
      } else {
        print('❌ [TUGAS] API returned success: false');
        print('❌ [TUGAS] Message: ${result['message']}');
      }
    } catch (e, stackTrace) {
      print('❌ [TUGAS] Error loading jadwal: $e');
      print('❌ [TUGAS] Stack: $stackTrace');
    }
  }

  void _updateMapelList() {
    print('🔵 [TUGAS] Update mapel list untuk kelas: $_selectedKelasId');
    print('🔵 [TUGAS] Total jadwal di _allJadwal: ${_allJadwal.length}');
    
    if (_selectedKelasId == null) {
      print('⚠️ [TUGAS] Kelas ID null');
      setState(() {
        _mapelList = [];
      });
      return;
    }

    final selectedKelasIdStr = _selectedKelasId!.toString();
    print('🔵 [TUGAS] Selected kelas ID (string): $selectedKelasIdStr');

    final jadwalKelasIni = _allJadwal.where((item) {
      if (item is Map) {
        final kelasId = item['kelas_id']?.toString();
        final mapelId = item['mapel_id']?.toString();
        final mapelNama = item['nama_mapel'];
        
        final match = kelasId == selectedKelasIdStr 
            && mapelId != null 
            && mapelId.isNotEmpty
            && mapelNama != null;
            
        if (match) {
          print('✅ [TUGAS] Match: kelas=$kelasId, mapel=$mapelNama');
        }
        
        return match;
      }
      return false;
    }).toList();

    print('🔍 [TUGAS] Jadwal untuk kelas $selectedKelasIdStr: ${jadwalKelasIni.length}');

    final uniqueMapel = <String, Map<String, dynamic>>{};
    for (var item in jadwalKelasIni) {
      if (item is Map) {
        final mapelId = item['mapel_id']?.toString();
        final mapelNama = item['nama_mapel'];
        final mapelKode = item['kode_mapel'];

        if (mapelId != null && mapelId.isNotEmpty && mapelNama != null) {
          uniqueMapel[mapelId] = {
            'id': mapelId,
            'nama_mapel': mapelNama,
            'kode_mapel': mapelKode ?? '',
          };
        }
      }
    }

    print('✅ [TUGAS] Mapel unik: ${uniqueMapel.length}');
    print('📚 [TUGAS] Mapel list: ${uniqueMapel.values.toList()}');

    setState(() {
      _mapelList = uniqueMapel.values.toList();
      _selectedMapelId = null;
    });
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _deadlineDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _deadlineTime = picked);
    }
  }

  Future<void> _submitTugas() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedKelasId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kelas terlebih dahulu')),
      );
      return;
    }
    if (_selectedMapelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih mata pelajaran')),
      );
      return;
    }
    if (_deadlineDate == null || _deadlineTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih deadline tugas')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final deadlineDateTime = DateTime(
        _deadlineDate!.year,
        _deadlineDate!.month,
        _deadlineDate!.day,
        _deadlineTime!.hour,
        _deadlineTime!.minute,
      );

      final headers = await ApiService.getHeaders();
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/tugas/guru/tugas'),
        headers: headers,
        body: jsonEncode({
          'kelas_id': _selectedKelasId,
          'mapel_id': _selectedMapelId,
          'judul': _judulController.text,
          'deskripsi': _deskripsiController.text,
          'deadline': deadlineDateTime.toIso8601String(),
        }),
      );

      print('📥 Create tugas response: ${response.body}');
      final result = jsonDecode(response.body);

      setState(() => _isLoading = false);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Tugas berhasil dibuat'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal membuat tugas'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error creating tugas: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Buat Tugas Baru'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Kelas',
                        prefixIcon: const Icon(Icons.class_),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      value: _selectedKelasId,
                      items: widget.kelasList.map<DropdownMenuItem<String>>((kelas) {
                        return DropdownMenuItem<String>(
                          value: kelas['id'].toString(),
                          child: Text(kelas['nama'] ?? '-'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedKelasId = value;
                        });
                        _updateMapelList();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Pilih kelas';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    if (_mapelList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedKelasId == null
                                    ? 'Pilih kelas terlebih dahulu untuk melihat mata pelajaran.'
                                    : 'Tidak ada mata pelajaran untuk kelas ini.',
                                style: TextStyle(color: Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Mata Pelajaran',
                          prefixIcon: const Icon(Icons.book),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        value: _selectedMapelId,
                        items: _mapelList.map<DropdownMenuItem<String>>((mapel) {
                          final namaMapel = mapel['nama_mapel'] ?? '-';
                          final kodeMapel = mapel['kode_mapel'] ?? '';
                          return DropdownMenuItem<String>(
                            value: mapel['id'].toString(),
                            child: Text('$namaMapel ($kodeMapel)'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedMapelId = value);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pilih mata pelajaran';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _judulController,
                      decoration: InputDecoration(
                        labelText: 'Judul Tugas',
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Judul wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _deskripsiController,
                      decoration: InputDecoration(
                        labelText: 'Deskripsi',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Deskripsi wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDeadline,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _deadlineDate != null
                                        ? '${_deadlineDate!.day}/${_deadlineDate!.month}/${_deadlineDate!.year}'
                                        : 'Pilih Tanggal',
                                    style: TextStyle(
                                      color: _deadlineDate != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _selectTime,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _deadlineTime != null
                                        ? '${_deadlineTime!.hour.toString().padLeft(2, '0')}:${_deadlineTime!.minute.toString().padLeft(2, '0')}'
                                        : 'Pilih Waktu',
                                    style: TextStyle(
                                      color: _deadlineTime != null
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitTugas,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Buat Tugas',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}