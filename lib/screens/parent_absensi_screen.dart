import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ParentAbsensiScreen extends StatefulWidget {
  final String? anakId;    // ✅ Parameter optional
  final String? anakNama;  // ✅ Parameter optional
  
  const ParentAbsensiScreen({
    Key? key,
    this.anakId,
    this.anakNama,
  }) : super(key: key);
  
  @override
  State<ParentAbsensiScreen> createState() => _ParentAbsensiScreenState();
}

class _ParentAbsensiScreenState extends State<ParentAbsensiScreen> {
  static const String baseUrl = kApiBaseUrl;
  
  bool _isLoading = true;
  List _children = [];
  Map<String, dynamic> _absensiData = {}; // Cache absensi per anak
  String? _selectedAnakId;
  String _selectedAnakNama = 'Anak';

  @override
  void initState() {
    super.initState();
    
    // ✅ Jika ada parameter dari dashboard, gunakan itu
    if (widget.anakId != null) {
      _selectedAnakId = widget.anakId;
      _selectedAnakNama = widget.anakNama ?? 'Anak';
    }
    
    _loadChildrenData();
  }

  Future<void> _loadChildrenData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // GET /api/parent/anak
      final response = await http.get(
        Uri.parse('$baseUrl/parent/anak'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        final anakList = data['data']['anak'] as List;
        
        setState(() {
          _children = anakList;
          
          // ✅ Jika tidak ada parameter, pilih anak pertama sebagai default
          if (_selectedAnakId == null && anakList.isNotEmpty) {
            _selectedAnakId = anakList[0]['id'].toString();
            _selectedAnakNama = anakList[0]['nama'] ?? 'Anak';
          }
          
          _isLoading = false;
        });
        
        // ✅ Load absensi untuk semua anak (atau hanya anak yang dipilih)
        if (widget.anakId != null) {
          // Jika ada parameter, hanya load anak tersebut
          await _loadAbsensiForAnak(widget.anakId!);
        } else {
          // Jika tidak, load semua
          for (var anak in anakList) {
            await _loadAbsensiForAnak(anak['id'].toString());
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error load children: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAbsensiForAnak(String anakId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/parent/anak/$anakId/absensi'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        setState(() {
          _absensiData[anakId] = data['data'];
        });
      }
    } catch (e) {
      debugPrint('Error load absensi for $anakId: $e');
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return '-';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'hadir': return const Color(0xFF7BC8A4);
      case 'izin': return const Color(0xFF2196F3);
      case 'sakit': return const Color(0xFFFF9800);
      case 'alpha': return const Color(0xFFE53935);
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'hadir': return Icons.check_circle;
      case 'izin': return Icons.description;
      case 'sakit': return Icons.local_hospital;
      case 'alpha': return Icons.cancel;
      default: return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Title AppBar dinamis berdasarkan anak yang dipilih
    final appBarTitle = widget.anakId != null 
        ? 'Absensi ${widget.anakNama ?? "Anak"}'
        : 'Absensi Anak';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF7BC8A4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChildrenData,
          ),
        ],
        // ✅ Dropdown untuk pilih anak jika ada >1 anak dan tidak ada parameter
        bottom: (widget.anakId == null && _children.length > 1) 
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedAnakId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7BC8A4)),
                      items: _children.map((anak) {
                        return DropdownMenuItem(
                          value: anak['id'].toString(),
                          child: Text(
                            '${anak['nama']} (${anak['nama_kelas'] ?? '-'})',
                            style: const TextStyle(color: Color(0xFF1A2B1C)),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedAnakId = value;
                            final selected = _children.firstWhere(
                              (a) => a['id'].toString() == value,
                            );
                            _selectedAnakNama = selected['nama'] ?? 'Anak';
                          });
                        }
                      },
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7BC8A4)))
          : RefreshIndicator(
              onRefresh: _loadChildrenData,
              child: _children.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Belum ada data anak',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    // ✅ Jika ada parameter anakId, tampilkan hanya anak tersebut
    if (widget.anakId != null) {
      final anak = _children.firstWhere(
        (a) => a['id'].toString() == widget.anakId,
        orElse: () => {},
      );
      if (anak.isEmpty) {
        return const Center(child: Text('Data anak tidak ditemukan'));
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_buildChildCard(anak)],
      );
    }
    
    // ✅ Jika tidak ada parameter, tampilkan semua anak
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _children.length,
      itemBuilder: (context, index) {
        final child = _children[index];
        return _buildChildCard(child);
      },
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final anakId = child['id'].toString();
    final absensiInfo = _absensiData[anakId];
    final rekap = absensiInfo?['rekap'] ?? {};
    final absensiList = absensiInfo?['absensi'] as List? ?? [];
    
    final hadir = rekap['hadir'] ?? 0;
    final izin = rekap['izin'] ?? 0;
    final sakit = rekap['sakit'] ?? 0;
    final alpha = rekap['alpha'] ?? 0;
    final total = rekap['total'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Nama & Kelas
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7BC8A4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF7BC8A4), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child['nama'] ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'NIS: ${child['nis'] ?? '-'} | Kelas: ${child['nama_kelas'] ?? '-'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Rekap Absensi
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📊 Rekap Bulan Ini',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStat('Hadir', hadir, const Color(0xFF7BC8A4)),
                      _buildMiniStat('Izin', izin, const Color(0xFF2196F3)),
                      _buildMiniStat('Sakit', sakit, const Color(0xFFFF9800)),
                      _buildMiniStat('Alpha', alpha, const Color(0xFFE53935)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // List Absensi Terbaru (max 5)
            if (absensiList.isNotEmpty) ...[
              const Text(
                '📅 Absensi Terbaru',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...absensiList.take(5).map((absen) => _buildAbsensiItem(absen)),
              if (absensiList.length > 5)
                TextButton(
                  onPressed: () => _showAllAbsensi(absensiList, child['nama'] ?? 'Anak'),
                  //child: const Text('Lihat Semua (${absensiList.length})'),
                  child: Text('Lihat Semua (${absensiList.length})'),
                ),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Belum ada data absensi',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildAbsensiItem(Map<String, dynamic> absen) {
    final status = absen['status'] ?? '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(absen['tanggal']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${absen['jam_masuk'] ?? '-'} - ${absen['jam_pulang'] ?? '-'}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllAbsensi(List absensiList, String namaAnak) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Semua Absensi $namaAnak'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: absensiList.length,
            itemBuilder: (context, index) {
              final absen = absensiList[index];
              return _buildAbsensiItem(absen);
            },
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