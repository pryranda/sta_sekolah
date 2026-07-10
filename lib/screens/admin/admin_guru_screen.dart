import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminGuruScreen extends StatefulWidget {
  const AdminGuruScreen({super.key});

  @override
  State<AdminGuruScreen> createState() => _AdminGuruScreenState();
}

class _AdminGuruScreenState extends State<AdminGuruScreen> {
  List<dynamic> _guruList = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGuru();
  }

  Future<void> _loadGuru() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getAdminGuru();
    
    if (result['success'] == true) {
      setState(() {
        _guruList = result['data'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      _showError(result['message'] ?? 'Gagal memuat data guru');
    }
  }

  List<dynamic> get _filteredGuru {
    if (_searchQuery.isEmpty) return _guruList;
    return _guruList.where((g) {
      final nama = (g['nama'] ?? '').toString().toLowerCase();
      final email = (g['email'] ?? '').toString().toLowerCase();
      return nama.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showAddGuruDialog() {
    final namaCtrl = TextEditingController();
    final nipCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final hpCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: 'guru123');
    String jk = 'L';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Tambah Guru Baru'),
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
                TextField(
                  controller: nipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'NIP',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'No. HP',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password Default',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: jk,
                  decoration: const InputDecoration(
                    labelText: 'Jenis Kelamin',
                    prefixIcon: Icon(Icons.wc),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
                    DropdownMenuItem(value: 'P', child: Text('Perempuan')),
                  ],
                  onChanged: (v) => setStateDialog(() => jk = v!),
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
                      if (namaCtrl.text.isEmpty || emailCtrl.text.isEmpty) {
                        _showError('Nama dan Email wajib diisi');
                        return;
                      }
                      setStateDialog(() => isLoading = true);
                      final result = await ApiService.createAdminGuru({
                        'nama': namaCtrl.text,
                        'nip': nipCtrl.text,
                        'email': emailCtrl.text,
                        'no_hp': hpCtrl.text,
                        'jenis_kelamin': jk,
                        'password': passwordCtrl.text,
                      });
                      setStateDialog(() => isLoading = false);
                      if (result['success'] == true) {
                        Navigator.pop(context);
                        _showSuccess('Guru berhasil ditambahkan');
                        _loadGuru();
                      } else {
                        _showError(result['message'] ?? 'Gagal menambah guru');
                      }
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> guru) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Guru'),
        content: Text('Yakin ingin menghapus ${guru['nama']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final result = await ApiService.deleteAdminGuru(guru['id']);
              if (result['success'] == true) {
                _showSuccess('Guru berhasil dihapus');
                _loadGuru();
              } else {
                _showError(result['message'] ?? 'Gagal menghapus');
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Kelola Guru'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGuruDialog,
        backgroundColor: const Color(0xFF1976D2),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Guru'),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari nama atau email guru...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Stats
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.people, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Total: ${_guruList.length} guru',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredGuru.isEmpty
                    ? const Center(child: Text('Tidak ada data'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredGuru.length,
                        itemBuilder: (context, index) {
                          final g = _filteredGuru[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (g['jenis_kelamin'] == 'P')
                                    ? Colors.pink.shade100
                                    : Colors.blue.shade100,
                                child: Text(
                                  (g['nama']?.toString().isNotEmpty == true)
                                      ? g['nama'].toString()[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: (g['jenis_kelamin'] == 'P')
                                        ? Colors.pink.shade700
                                        : Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                g['nama'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g['email'] ?? '-'),
                                  if (g['no_hp'] != null && g['no_hp'].toString().isNotEmpty)
                                    Text('HP: ${g['no_hp']}'),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDelete(g),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
