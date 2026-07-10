import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminMapelScreen extends StatefulWidget {
  const AdminMapelScreen({super.key});

  @override
  State<AdminMapelScreen> createState() => _AdminMapelScreenState();
}

class _AdminMapelScreenState extends State<AdminMapelScreen> {
  List<dynamic> _mapelList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMapel();
  }

  Future<void> _loadMapel() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getAdminMapel();
    
    if (result['success'] == true) {
      setState(() {
        _mapelList = result['data'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _showAddMapelDialog() {
    final namaCtrl = TextEditingController();
    final kodeCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Tambah Mata Pelajaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Mata Pelajaran *',
                  prefixIcon: Icon(Icons.book),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kode Mapel *',
                  prefixIcon: Icon(Icons.code),
                  border: OutlineInputBorder(),
                  helperText: 'Contoh: MTK-1, IPA-1',
                ),
              ),
            ],
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
                      if (namaCtrl.text.isEmpty || kodeCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Semua field wajib diisi')),
                        );
                        return;
                      }
                      setStateDialog(() => isLoading = true);
                      // TODO: Implement create mapel API
                      await Future.delayed(const Duration(milliseconds: 500));
                      setStateDialog(() => isLoading = false);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur tambah mapel akan segera hadir'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Mata Pelajaran'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMapelDialog,
        backgroundColor: const Color(0xFF1976D2),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Mapel'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.book, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Total: ${_mapelList.length} mata pelajaran',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mapelList.isEmpty
                    ? const Center(child: Text('Belum ada mata pelajaran'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _mapelList.length,
                        itemBuilder: (context, index) {
                          final m = _mapelList[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: Icon(Icons.book, color: Colors.green.shade700),
                              ),
                              title: Text(
                                m['nama_mapel'] ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Kode: ${m['kode_mapel'] ?? '-'}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  m['kode_mapel'] ?? '-',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
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
