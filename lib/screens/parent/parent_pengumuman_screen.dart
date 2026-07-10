import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ParentPengumumanScreen extends StatefulWidget {
  const ParentPengumumanScreen({super.key});

  @override
  State<ParentPengumumanScreen> createState() => _ParentPengumumanScreenState();
}

class _ParentPengumumanScreenState extends State<ParentPengumumanScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _filterKategori;
  String? _filterPrioritas;

  @override
  void initState() {
    super.initState();
    _loadPengumuman();
  }

  Future<void> _loadPengumuman() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getPengumuman(
      kategori: _filterKategori,
      prioritas: _filterPrioritas,
    );
    setState(() {
      _data = result;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(String pengumumanId) async {
    await ApiService.markPengumumanRead(pengumumanId);
    _loadPengumuman();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPengumuman,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                if (value == 'kategori') {
                  _filterKategori = _filterKategori == null ? 'umum' : null;
                } else if (value == 'prioritas') {
                  _filterPrioritas = _filterPrioritas == null ? 'urgent' : null;
                }
              });
              _loadPengumuman();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'kategori',
                child: Text('Filter: Kategori Umum'),
              ),
              const PopupMenuItem(
                value: 'prioritas',
                child: Text('Filter: Prioritas Urgent'),
              ),
            ],
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
    final pengumuman = _data!['data']['pengumuman'] as List? ?? [];
    final stats = _data!['data']['stats'] as Map<String, dynamic>? ?? {};
    final belumDibaca = stats['belum_dibaca'] ?? 0;

    return Column(
      children: [
        // Stats Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengumuman',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$belumDibaca belum dibaca dari ${pengumuman.length} total',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List Pengumuman
        Expanded(
          child: pengumuman.isEmpty
              ? const Center(child: Text('Tidak ada pengumuman'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pengumuman.length,
                  itemBuilder: (context, index) {
                    final item = pengumuman[index];
                    final isRead = item['is_read'] ?? false;
                    final prioritas = item['prioritas'] ?? 'normal';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isRead ? 1 : 3,
                      child: InkWell(
                        onTap: () {
                          if (!isRead) {
                            _markAsRead(item['id'].toString());
                          }
                          _showDetailDialog(item);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['judul'] ?? '-',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isRead ? Colors.grey : Colors.black,
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item['isi'] ?? '',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildBadge(
                                    _getPrioritasLabel(prioritas),
                                    _getPrioritasColor(prioritas),
                                  ),
                                  const SizedBox(width: 8),
                                  if (item['kategori'] != null)
                                    _buildBadge(
                                      item['kategori'],
                                      Colors.grey.shade600,
                                    ),
                                  const Spacer(),
                                  Text(
                                    item['created_at'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getPrioritasLabel(String prioritas) {
    switch (prioritas) {
      case 'urgent':
        return 'Urgent';
      case 'tinggi':
        return 'Tinggi';
      case 'normal':
        return 'Normal';
      case 'rendah':
        return 'Rendah';
      default:
        return prioritas;
    }
  }

  Color _getPrioritasColor(String prioritas) {
    switch (prioritas) {
      case 'urgent':
        return Colors.red;
      case 'tinggi':
        return Colors.orange;
      case 'normal':
        return Colors.blue;
      case 'rendah':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showDetailDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['judul'] ?? ''),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildBadge(
                    _getPrioritasLabel(item['prioritas'] ?? 'normal'),
                    _getPrioritasColor(item['prioritas'] ?? 'normal'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item['created_at'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(item['isi'] ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}