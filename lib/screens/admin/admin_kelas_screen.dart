import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminKelasScreen extends StatefulWidget {
  const AdminKelasScreen({super.key});

  @override
  State<AdminKelasScreen> createState() => _AdminKelasScreenState();
}

class _AdminKelasScreenState extends State<AdminKelasScreen> {
  List<dynamic> _kelasList = [];
  List<dynamic> _guruList = [];
  bool _isLoading = true;

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
        ApiService.getAdminGuru(),
      ]);

      if (mounted) {
        setState(() {
          _kelasList = results[0]['success'] == true ? results[0]['data'] : [];
          _guruList = results[1]['success'] == true ? results[1]['data'] : [];
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

  void _showAddEditDialog({Map<String, dynamic>? kelas}) {
    final isEdit = kelas != null;
    final namaController = TextEditingController(text: kelas?['nama_kelas'] ?? '');
    final kapasitasController = TextEditingController(text: kelas?['kapasitas']?.toString() ?? '28');
    final tahunAjaranController = TextEditingController(text: kelas?['tahun_ajaran'] ?? '2026/2027');
    int tingkat = kelas?['tingkat'] ?? 1;
    String? waliKelasId = kelas?['wali_kelas_id'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? 'Edit Kelas' : 'Tambah Kelas'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kelas',
                    hintText: 'Contoh: 1A, 2B, 3A',
                    prefixIcon: Icon(Icons.class_),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: tingkat,
                  decoration: const InputDecoration(
                    labelText: 'Tingkat',
                    prefixIcon: Icon(Icons.layers),
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(6, (i) => i + 1)
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text('Kelas $t'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => tingkat = v ?? 1),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: kapasitasController,
                  decoration: const InputDecoration(
                    labelText: 'Kapasitas',
                    prefixIcon: Icon(Icons.people),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tahunAjaranController,
                  decoration: const InputDecoration(
                    labelText: 'Tahun Ajaran',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: waliKelasId,
                  decoration: const InputDecoration(
                    labelText: 'Wali Kelas',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  items: _guruList.map<DropdownMenuItem<String>>((g) {
                    return DropdownMenuItem<String>(
                      value: g['id'],
                      child: Text(g['nama'] ?? '-'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => waliKelasId = v),
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
              onPressed: () async {
                if (namaController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama kelas wajib diisi'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                Navigator.pop(context);

                try {
                  final data = {
                    'nama_kelas': namaController.text,
                    'tingkat': tingkat,
                    'kapasitas': int.tryParse(kapasitasController.text) ?? 28,
                    'tahun_ajaran': tahunAjaranController.text,
                    'wali_kelas_id': waliKelasId,
                  };

                  Map<String, dynamic> result;
                  if (isEdit) {
                    result = await ApiService.updateKelas(kelas!['id'], data);
                  } else {
                    result = await ApiService.createKelas(data);
                  }

                  if (mounted) {
                    if (result['success'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Kelas berhasil ${isEdit ? 'diupdate' : 'ditambahkan'}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadData();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal: ${result['message']}'), backgroundColor: Colors.red),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Update' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteKelas(String id, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kelas'),
        content: Text('Yakin ingin menghapus kelas $nama?'),
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
      try {
        final result = await ApiService.deleteKelas(id);
        if (mounted) {
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Kelas dihapus'), backgroundColor: Colors.green),
            );
            _loadData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal: ${result['message']}'), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Kelola Kelas'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFF1976D2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Kelas', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _kelasList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.class_, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada data kelas',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Klik tombol + untuk menambahkan kelas',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _kelasList.length,
                    itemBuilder: (context, index) {
                      final kelas = _kelasList[index];
                      return _buildKelasCard(kelas);
                    },
                  ),
                ),
    );
  }

  Widget _buildKelasCard(Map<String, dynamic> kelas) {
    final namaKelas = kelas['nama_kelas'] ?? '-';
    final tingkat = kelas['tingkat'] ?? '-';
    final kapasitas = kelas['kapasitas'] ?? '-';
    final tahunAjaran = kelas['tahun_ajaran'] ?? '-';
    final waliKelas = kelas['wali_kelas'] ?? 'Belum ada wali kelas';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.class_, color: Colors.purple.shade700, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kelas $namaKelas',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tingkat $tingkat • Kapasitas $kapasitas siswa',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showAddEditDialog(kelas: kelas);
                    } else if (value == 'delete') {
                      _deleteKelas(kelas['id'], namaKelas);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Wali Kelas: $waliKelas',
                    style: TextStyle(
                      fontSize: 13,
                      color: waliKelas == 'Belum ada wali kelas' ? Colors.grey.shade500 : Colors.black87,
                      fontWeight: waliKelas == 'Belum ada wali kelas' ? FontWeight.normal : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Tahun Ajaran: $tahunAjaran',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
