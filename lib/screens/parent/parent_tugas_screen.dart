import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ParentTugasScreen extends StatefulWidget {
  final String anakId;
  final String anakNama;
  
  const ParentTugasScreen({
    super.key,
    required this.anakId,
    required this.anakNama,
  });

  @override
  State<ParentTugasScreen> createState() => _ParentTugasScreenState();
}

class _ParentTugasScreenState extends State<ParentTugasScreen> {
  List<dynamic> _tugasList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTugas();
  }

  Future<void> _loadTugas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔍 Loading tugas for anak: ${widget.anakId}');
      
      final result = await ApiService.getTugasAnak(widget.anakId);
      
      print('📥 Response: $result');
      
      if (result['success'] == true) {
        final data = result['data'];
        
        // Handle response structure
        if (data is Map<String, dynamic>) {
          final tugas = data['tugas'];
          if (tugas is List) {
            setState(() {
              _tugasList = tugas;
              _isLoading = false;
            });
          } else if (tugas is Map) {
            setState(() {
              _tugasList = [tugas];
              _isLoading = false;
            });
          } else {
            setState(() {
              _tugasList = [];
              _isLoading = false;
            });
          }
        } else if (data is List) {
          setState(() {
            _tugasList = data;
            _isLoading = false;
          });
        } else {
          setState(() {
            _tugasList = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal memuat data';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _errorMessage = 'Gagal memuat data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Tugas ${widget.anakNama}'),
        backgroundColor: const Color(0xFF00BCD4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTugas,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00BCD4)),
                  SizedBox(height: 16),
                  Text(
                    'Memuat data tugas...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTugas,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_tugasList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada tugas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A2B1C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tugas akan muncul setelah guru memberikan',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tugasList.length,
      itemBuilder: (context, index) {
        final item = _tugasList[index];
        return _buildTugasCard(item);
      },
    );
  }

  Widget _buildTugasCard(Map<String, dynamic> item) {
    final judul = item['judul'] ?? 'Tugas';
    final deskripsi = item['deskripsi'] ?? '';
    final deadline = item['deadline'] ?? '';
    final guru = item['guru_nama'] ?? '-';
    final mapel = item['nama_mapel'] ?? '-';
    final status = item['status'] ?? 'belum_dikerjakan';
    final isSelesai = status == 'selesai';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isSelesai 
                      ? const Color(0xFF7BC8A4) 
                      : const Color(0xFFFF9800),
                  child: Icon(
                    isSelesai ? Icons.check : Icons.pending,
                    color: Colors.white,
                    size: 20,
                  ),
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
                      ),
                      Text(
                        mapel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelesai 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isSelesai ? 'Selesai' : 'Belum',
                    style: TextStyle(
                      color: isSelesai ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (deskripsi.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                deskripsi,
                maxLines: 3,
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
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Deadline: $deadline',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  guru,
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
    );
  }
}