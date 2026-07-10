import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_service.dart';

class TeacherInputNilaiScreen extends StatefulWidget {
  const TeacherInputNilaiScreen({super.key});

  @override
  State<TeacherInputNilaiScreen> createState() => _TeacherInputNilaiScreenState();
}

class _TeacherInputNilaiScreenState extends State<TeacherInputNilaiScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tugasController = TextEditingController();
  final _utsController = TextEditingController();
  final _uasController = TextEditingController();
  
  List<dynamic> _siswaList = [];
  List<dynamic> _kelasList = [];
  List<dynamic> _mapelList = [];
  List<dynamic> _allJadwal = [];
  bool _isLoading = false;
  bool _isLoadingNilai = false;
  String? _selectedKelasId;
  String? _selectedMapelId;
  String? _selectedSiswaId;
  bool _hasExistingNilai = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _tugasController.dispose();
    _utsController.dispose();
    _uasController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
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
            final kelasId = item['kelas_id']?.toString();
            final namaKelas = item['nama_kelas'];
            if (kelasId != null && namaKelas != null) {
              uniqueClasses[kelasId] = namaKelas;
            }
          }
        }

        setState(() {
          _allJadwal = jadwalList;
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

  void _updateMapelList() {
    if (_selectedKelasId == null) {
      setState(() {
        _mapelList = [];
        _selectedMapelId = null;
        _siswaList = [];
        _selectedSiswaId = null;
        _hasExistingNilai = false;
      });
      _clearForm();
      return;
    }

    final selectedKelasIdStr = _selectedKelasId!.toString();

    final uniqueMapel = <String, Map<String, dynamic>>{};
    for (var item in _allJadwal) {
      if (item is Map) {
        final kelasId = item['kelas_id']?.toString();
        final mapelId = item['mapel_id']?.toString();
        final mapelNama = item['nama_mapel'];
        final mapelKode = item['kode_mapel'];

        if (kelasId == selectedKelasIdStr 
            && mapelId != null 
            && mapelId.isNotEmpty
            && mapelNama != null) {
          uniqueMapel[mapelId] = {
            'id': mapelId,
            'nama_mapel': mapelNama,
            'kode_mapel': mapelKode ?? '',
          };
        }
      }
    }

    setState(() {
      _mapelList = uniqueMapel.values.toList();
      _selectedMapelId = null;
      _siswaList = [];
      _selectedSiswaId = null;
      _hasExistingNilai = false;
    });
    _clearForm();
  }

  void _clearForm() {
    _tugasController.clear();
    _utsController.clear();
    _uasController.clear();
  }

  Future<void> _loadSiswa() async {
    if (_selectedKelasId == null) return;

    setState(() => _isLoading = true);

    try {
      final headers = await ApiService.getHeaders();
      final url = '${ApiService.baseUrl}/teacher/kelas/$_selectedKelasId/siswa';
      
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
        
        setState(() {
          _siswaList = siswaList;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading siswa: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ Load nilai existing saat pilih siswa
  Future<void> _loadNilaiExisting() async {
    if (_selectedSiswaId == null || _selectedMapelId == null) return;

    setState(() => _isLoadingNilai = true);

    try {
      final headers = await ApiService.getHeaders();
      final url = '${ApiService.baseUrl}/teacher/nilai/$_selectedSiswaId/mapel/$_selectedMapelId';
      
      print('🔍 Loading nilai existing...');
      print('🔍 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      final result = jsonDecode(response.body);
      
      if (result['success'] == true && result['data'] != null) {
        final nilaiData = result['data'];
        
        // Auto-fill form dengan nilai existing
        setState(() {
          _tugasController.text = nilaiData['nilai_tugas']?.toString() ?? '';
          _utsController.text = nilaiData['nilai_uts']?.toString() ?? '';
          _uasController.text = nilaiData['nilai_uas']?.toString() ?? '';
          _hasExistingNilai = true;
          _isLoadingNilai = false;
        });
        
        print('✅ Nilai existing loaded');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ℹ️ Nilai lama ter-load, silakan edit'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Clear form jika belum ada nilai
        setState(() {
          _clearForm();
          _hasExistingNilai = false;
          _isLoadingNilai = false;
        });
        print('ℹ️ Belum ada nilai untuk siswa ini');
      }
    } catch (e) {
      print('❌ Error loading nilai: $e');
      setState(() {
        _clearForm();
        _hasExistingNilai = false;
        _isLoadingNilai = false;
      });
    }
  }

  Future<void> _submitNilai() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }
    
    if (_selectedSiswaId == null || _selectedSiswaId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Pilih siswa terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_selectedMapelId == null || _selectedMapelId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Pilih mata pelajaran'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final tugasStr = _tugasController.text.trim();
    final utsStr = _utsController.text.trim();
    final uasStr = _uasController.text.trim();
    
    if (tugasStr.isEmpty || utsStr.isEmpty || uasStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Semua nilai wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final tugasVal = double.tryParse(tugasStr);
    final utsVal = double.tryParse(utsStr);
    final uasVal = double.tryParse(uasStr);
    
    if (tugasVal == null || utsVal == null || uasVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Nilai harus berupa angka'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('✅ Validasi passed');
    print('📝 Data yang akan dikirim:');
    print('   - siswa_id: $_selectedSiswaId');
    print('   - mapel_id: $_selectedMapelId');
    print('   - nilai_tugas: $tugasVal');
    print('   - nilai_uts: $utsVal');
    print('   - nilai_uas: $uasVal');

    setState(() => _isLoading = true);

    try {
      final headers = await ApiService.getHeaders();
      final body = {
        'siswa_id': _selectedSiswaId,
        'mapel_id': _selectedMapelId,
        'nilai_tugas': tugasVal,
        'nilai_uts': utsVal,
        'nilai_uas': uasVal,
        'semester': 1,
        'tahun_ajaran': '2026/2027',
      };
      
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/teacher/nilai'),
        headers: headers,
        body: jsonEncode(body),
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      final result = jsonDecode(response.body);
      
      setState(() => _isLoading = false);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_hasExistingNilai 
                  ? '✅ Nilai berhasil diupdate' 
                  : '✅ Nilai berhasil disimpan'),
              backgroundColor: Colors.green,
            ),
          );
          // Load ulang nilai yang baru disimpan
          await _loadNilaiExisting();
        } else {
          final message = result['message'] ?? 'Gagal menyimpan nilai';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Exception: $e');
      print('❌ Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Input Nilai'),
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF9800)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pilih Kelas
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Kelas',
                        prefixIcon: const Icon(Icons.class_),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      value: _selectedKelasId,
                      items: _kelasList.map<DropdownMenuItem<String>>((kelas) {
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

                    // Pilih Mata Pelajaran
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
                                    ? 'Pilih kelas terlebih dahulu.'
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
                          setState(() {
                            _selectedMapelId = value;
                            _selectedSiswaId = null;
                            _siswaList = [];
                            _hasExistingNilai = false;
                          });
                          _clearForm();
                          if (value != null) {
                            _loadSiswa();
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pilih mata pelajaran';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),

                    // Pilih Siswa
                    if (_siswaList.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Siswa',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        value: _selectedSiswaId,
                        items: _siswaList.map<DropdownMenuItem<String>>((siswa) {
                          return DropdownMenuItem<String>(
                            value: siswa['id'].toString(),
                            child: Text('${siswa['nama']} (NIS: ${siswa['nis']})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSiswaId = value;
                            _hasExistingNilai = false;
                          });
                          _clearForm();
                          if (value != null) {
                            _loadNilaiExisting();
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pilih siswa';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 24),

                    // ✅ Info Nilai Existing
                    if (_isLoadingNilai)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Memuat nilai yang sudah ada...',
                              style: TextStyle(color: Colors.blue.shade800),
                            ),
                          ],
                        ),
                      ),

                    if (_hasExistingNilai && !_isLoadingNilai)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nilai lama berhasil dimuat. Edit dan simpan untuk update.',
                                style: TextStyle(color: Colors.green.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!_hasExistingNilai && _selectedSiswaId != null && !_isLoadingNilai)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add_circle_outline, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Belum ada nilai. Input nilai baru untuk siswa ini.',
                                style: TextStyle(color: Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Nilai Tugas
                    TextFormField(
                      controller: _tugasController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nilai Tugas',
                        prefixIcon: const Icon(Icons.assignment),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nilai tugas wajib diisi';
                        }
                        final number = double.tryParse(value);
                        if (number == null || number < 0 || number > 100) {
                          return 'Nilai harus antara 0-100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Nilai UTS
                    TextFormField(
                      controller: _utsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nilai UTS',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nilai UTS wajib diisi';
                        }
                        final number = double.tryParse(value);
                        if (number == null || number < 0 || number > 100) {
                          return 'Nilai harus antara 0-100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Nilai UAS
                    TextFormField(
                      controller: _uasController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nilai UAS',
                        prefixIcon: const Icon(Icons.school),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nilai UAS wajib diisi';
                        }
                        final number = double.tryParse(value);
                        if (number == null || number < 0 || number > 100) {
                          return 'Nilai harus antara 0-100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: (_isLoading || _isLoadingNilai) ? null : _submitNilai,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_hasExistingNilai ? Icons.update : Icons.save),
                                const SizedBox(width: 8),
                                Text(
                                  _hasExistingNilai ? 'Update Nilai' : 'Simpan Nilai',
                                  style: const TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}