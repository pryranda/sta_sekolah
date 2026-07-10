import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class AdminSiswaScreen extends StatefulWidget {
  const AdminSiswaScreen({super.key});

  @override
  State<AdminSiswaScreen> createState() => _AdminSiswaScreenState();
}

class _AdminSiswaScreenState extends State<AdminSiswaScreen> {
  List<dynamic> _siswaList = [];
  List<dynamic> _kelasList = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _filterKelasId;
  int _totalSiswa = 0;
  int _totalLaki = 0;
  int _totalPerempuan = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getAdminSiswa(
          kelasId: _filterKelasId,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        ),
        ApiService.getKelas(),
      ]);

      if (mounted) {
        final siswaData = results[0]['success'] == true ? results[0]['data'] : [];
        setState(() {
          _siswaList = siswaData;
          _kelasList = results[1]['success'] == true ? results[1]['data'] : [];
          _totalSiswa = siswaData.length;
          _totalLaki = siswaData.where((s) => s['jenis_kelamin'] == 'L').length;
          _totalPerempuan = siswaData.where((s) => s['jenis_kelamin'] == 'P').length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? siswa}) {
    final isEdit = siswa != null;
    final namaCtrl = TextEditingController(text: siswa?['nama'] ?? '');
    final nisCtrl = TextEditingController(text: siswa?['nis'] ?? '');
    final nisnCtrl = TextEditingController(text: siswa?['nisn'] ?? '');
    final tempatLahirCtrl = TextEditingController(text: siswa?['tempat_lahir'] ?? '');
    final agamaCtrl = TextEditingController(text: siswa?['agama'] ?? '');
    final alamatCtrl = TextEditingController(text: siswa?['alamat'] ?? '');
    final noHpCtrl = TextEditingController(text: siswa?['no_hp'] ?? '');
    final emailCtrl = TextEditingController(text: siswa?['email'] ?? '');
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: isEdit ? '' : 'siswa123');
    
    DateTime? tanggalLahir = siswa?['tanggal_lahir'] != null 
        ? DateTime.tryParse(siswa!['tanggal_lahir']) 
        : null;
    String jk = siswa?['jenis_kelamin'] ?? 'L';
    String? kelasId = siswa?['kelas_id'];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(isEdit ? 'Edit Siswa' : 'Tambah Siswa Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: namaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nisCtrl,
                        decoration: const InputDecoration(
                          labelText: 'NIS',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: nisnCtrl,
                        decoration: const InputDecoration(
                          labelText: 'NISN',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tempatLahirCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tempat Lahir',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tanggalLahir ?? DateTime(2018, 1, 1),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setStateDialog(() => tanggalLahir = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tanggal Lahir',
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            tanggalLahir != null 
                                ? DateFormat('dd/MM/yyyy').format(tanggalLahir!) 
                                : 'Pilih',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: jk,
                        decoration: const InputDecoration(
                          labelText: 'Jenis Kelamin *',
                          prefixIcon: Icon(Icons.wc),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
                          DropdownMenuItem(value: 'P', child: Text('Perempuan')),
                        ],
                        onChanged: (v) => setStateDialog(() => jk = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: agamaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Agama',
                          prefixIcon: Icon(Icons.mosque),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: kelasId,
                  decoration: const InputDecoration(
                    labelText: 'Kelas',
                    prefixIcon: Icon(Icons.class_),
                    border: OutlineInputBorder(),
                  ),
                  items: _kelasList.map<DropdownMenuItem<String>>((k) {
                    return DropdownMenuItem<String>(
                      value: k['id'],
                      child: Text('${k['nama_kelas']} (Tingkat ${k['tingkat']})'),
                    );
                  }).toList(),
                  onChanged: (v) => setStateDialog(() => kelasId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: alamatCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Alamat',
                    prefixIcon: Icon(Icons.home),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: noHpCtrl,
                        decoration: const InputDecoration(
                          labelText: 'No. HP',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Buat Akun Login (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.account_circle),
                            border: OutlineInputBorder(),
                            helperText: 'Kosongkan jika tidak perlu',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                            helperText: 'Default: siswa123',
                          ),
                          obscureText: true,
                        ),
                      ),
                    ],
                  ),
                ],
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
                      if (namaCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nama wajib diisi'), backgroundColor: Colors.orange),
                        );
                        return;
                      }
                      setStateDialog(() => isLoading = true);
                      
                      final data = {
                        'nama': namaCtrl.text,
                        'nis': nisCtrl.text,
                        'nisn': nisnCtrl.text,
                        'tempat_lahir': tempatLahirCtrl.text,
                        'tanggal_lahir': tanggalLahir != null 
                            ? DateFormat('yyyy-MM-dd').format(tanggalLahir!) 
                            : null,
                        'jenis_kelamin': jk,
                        'agama': agamaCtrl.text,
                        'alamat': alamatCtrl.text,
                        'no_hp': noHpCtrl.text,
                        'email': emailCtrl.text,
                        'kelas_id': kelasId,
                      };
                      
                      if (!isEdit && usernameCtrl.text.isNotEmpty) {
                        data['username'] = usernameCtrl.text;
                        data['password'] = passwordCtrl.text;
                      }

                      final result = isEdit
                          ? await ApiService.updateSiswa(siswa!['id'], data)
                          : await ApiService.createAdminSiswa(data);

                      setStateDialog(() => isLoading = false);
                      
                      if (mounted) {
                        if (result['success'] == true) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Siswa berhasil ${isEdit ? 'diupdate' : 'ditambahkan'}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal: ${result['message']}'),
                              backgroundColor: Colors.red,
                            ),
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

  void _confirmDelete(Map<String, dynamic> siswa) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Siswa'),
        content: Text('Yakin ingin menghapus ${siswa['nama']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final result = await ApiService.deleteSiswa(siswa['id']);
              if (mounted) {
                if (result['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Siswa dihapus'), backgroundColor: Colors.green),
                  );
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal: ${result['message']}'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Kelola Siswa'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFF1976D2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah Siswa', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Stats Card
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                _buildStatItem('Total', _totalSiswa.toString(), Icons.people, Colors.blue),
                const SizedBox(width: 12),
                _buildStatItem('Laki-laki', _totalLaki.toString(), Icons.male, Colors.indigo),
                const SizedBox(width: 12),
                _buildStatItem('Perempuan', _totalPerempuan.toString(), Icons.female, Colors.pink),
              ],
            ),
          ),
          
          // Search & Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari nama, NIS, atau NISN...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              _loadData();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    _loadData();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _filterKelasId,
                  decoration: InputDecoration(
                    hintText: 'Semua Kelas',
                    prefixIcon: const Icon(Icons.class_),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Semua Kelas'),
                    ),
                    ..._kelasList.map<DropdownMenuItem<String>>((k) {
                      return DropdownMenuItem<String>(
                        value: k['id'],
                        child: Text('${k['nama_kelas']} (Tingkat ${k['tingkat']})'),
                      );
                    }),
                  ],
                  onChanged: (v) {
                    setState(() => _filterKelasId = v);
                    _loadData();
                  },
                ),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _siswaList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text('Belum ada data siswa'),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _siswaList.length,
                          itemBuilder: (context, index) {
                            final s = _siswaList[index];
                            return _buildSiswaCard(s);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiswaCard(Map<String, dynamic> s) {
    final nama = s['nama'] ?? '-';
    final nis = s['nis'] ?? '-';
    final nisn = s['nisn'] ?? '-';
    final kelas = s['nama_kelas'] ?? 'Belum ada kelas';
    final jk = s['jenis_kelamin'];
    final noHp = s['no_hp'];
    final namaIbu = s['nama_ibu'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: jk == 'P' ? Colors.pink.shade100 : Colors.blue.shade100,
              child: Text(
                nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: jk == 'P' ? Colors.pink.shade700 : Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'NIS: $nis | NISN: $nisn',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.class_, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        kelas,
                        style: TextStyle(
                          fontSize: 12,
                          color: kelas == 'Belum ada kelas' ? Colors.orange : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (namaIbu != null && namaIbu.toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.woman, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Ibu: $namaIbu',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (noHp != null && noHp.toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          noHp,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  onPressed: () => _showAddEditDialog(siswa: s),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(s),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}