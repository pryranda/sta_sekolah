import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../../widgets/payment_dialog.dart';
import '../../config/api_config.dart';

class ParentSppScreen extends StatefulWidget {
  final String? anakId;
  final String? anakNama;

  const ParentSppScreen({
    Key? key,
    this.anakId,
    this.anakNama,
  }) : super(key: key);

  @override
  State<ParentSppScreen> createState() => _ParentSppScreenState();
}

class _ParentSppScreenState extends State<ParentSppScreen> {
  static const String baseUrl = kApiBaseUrl;
  
  bool _isLoading = true;
  List _anak = [];
  List _tagihan = [];
  Map<String, dynamic> _statsPerAnak = {};
  String? _selectedAnakId;
  String _selectedAnakNama = 'Anak';

  @override
  void initState() {
    super.initState();
    if (widget.anakId != null) {
      _selectedAnakId = widget.anakId;
      _selectedAnakNama = widget.anakNama ?? 'Anak';
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/spp/parent/tagihan'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        setState(() {
          _anak = data['data']['anak'] ?? [];
          _tagihan = data['data']['tagihan'] ?? [];
          _statsPerAnak = data['data']['stats_per_anak'] ?? {};
          
          if (_selectedAnakId == null && _anak.isNotEmpty) {
            _selectedAnakId = _anak[0]['id'].toString();
            _selectedAnakNama = _anak[0]['nama'] ?? 'Anak';
          }
          
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error load data: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatBulan(int bulan) {
    final namaBulan = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return namaBulan[bulan - 1];
  }

  String _formatRupiah(int nominal) {
    return 'Rp ${nominal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'lunas':
        return const Color(0xFF7BC8A4);
      case 'menunggu_verifikasi':
        return const Color(0xFFFF9800);
      case 'belum_bayar':
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'lunas':
        return 'LUNAS';
      case 'menunggu_verifikasi':
        return 'MENUNGGU VERIFIKASI';
      case 'belum_bayar':
        return 'BELUM BAYAR';
      default:
        return status.toUpperCase();
    }
  }

  void _showBayarDialog(Map<String, dynamic> tagihan) {
    final nominal = tagihan['nominal_akhir'];
    final namaSiswa = tagihan['nama_siswa'];
    final bulan = _formatBulan(tagihan['periode_bulan']);
    final tahun = tagihan['periode_tahun'];
    final tagihanId = tagihan['id'];
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PaymentDialog(
        namaSiswa: namaSiswa,
        periode: '$bulan $tahun',
        nominal: _formatRupiah(nominal),
        onSubmit: (String rekening, String nomorReferensi, String catatan, Uint8List? bytes, File? file) async {
          String? buktiUrl;
          
          // Upload file
          if (bytes != null) {
            // Upload dari bytes (web)
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('token') ?? '';
            
            final uri = Uri.parse('$baseUrl/spp/upload-bukti');
            final request = http.MultipartRequest('POST', uri);
            request.headers['Authorization'] = 'Bearer $token';
            
            final fileUpload = http.MultipartFile.fromBytes(
              'bukti',
              bytes,
              filename: 'bukti_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            request.files.add(fileUpload);
            
            final response = await request.send();
            final responseData = await response.stream.bytesToString();
            final data = jsonDecode(responseData);
            
            if (response.statusCode == 200 && data['success']) {
              buktiUrl = data['data']['url'];
            } else {
              throw Exception(data['message'] ?? 'Upload gagal');
            }
          } else if (file != null) {
            // Upload dari file (mobile)
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('token') ?? '';
            
            final uri = Uri.parse('$baseUrl/spp/upload-bukti');
            final request = http.MultipartRequest('POST', uri);
            request.headers['Authorization'] = 'Bearer $token';
            
            final fileUpload = await http.MultipartFile.fromPath(
              'bukti',
              file.path,
              filename: path.basename(file.path),
            );
            request.files.add(fileUpload);
            
            final response = await request.send();
            final responseData = await response.stream.bytesToString();
            final data = jsonDecode(responseData);
            
            if (response.statusCode == 200 && data['success']) {
              buktiUrl = data['data']['url'];
            } else {
              throw Exception(data['message'] ?? 'Upload gagal');
            }
          }
          
          // Submit pembayaran
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token') ?? '';
          
          final response = await http.post(
            Uri.parse('$baseUrl/spp/parent/pembayaran'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'tagihan_id': tagihanId,
              'jumlah_bayar': nominal,
              'metode_bayar': 'transfer_bank',
              'nomor_referensi': nomorReferensi,
              'catatan': catatan,
              'bukti_transfer_url': buktiUrl,
            }),
          );
          
          final data = jsonDecode(response.body);
          
          if (!data['success']) {
            throw Exception(data['message'] ?? 'Gagal mengirim pembayaran');
          }
          
          // Refresh data
          await _loadData();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Bukti pembayaran berhasil dikirim! Menunggu verifikasi admin.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.anakId != null 
            ? 'SPP ${widget.anakNama}'
            : 'SPP Anak',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF7BC8A4),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: (widget.anakId == null && _anak.length > 1)
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
                      items: _anak.map((a) {
                        return DropdownMenuItem(
                          value: a['id'].toString(),
                          child: Text('${a['nama']} (${a['nis']})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedAnakId = value;
                            final selected = _anak.firstWhere(
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
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final tagihanAnak = _tagihan.where((t) {
      if (widget.anakId != null) {
        return t['siswa_id'] == widget.anakId;
      }
      return t['siswa_id'] == _selectedAnakId;
    }).toList();

    final stats = _statsPerAnak[_selectedAnakId] ?? {};
    final totalNominal = stats['total_nominal'] ?? 0;
    final totalTerbayar = stats['total_terbayar'] ?? 0;
    final tunggakan = totalNominal - totalTerbayar;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          color: const Color(0xFF7BC8A4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet, color: Color(0xFF7BC8A4)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ringkasan SPP',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _selectedAnakNama,
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Total Tagihan',
                          _formatRupiah(totalNominal),
                          const Color(0xFF2196F3),
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Terbayar',
                          _formatRupiah(totalTerbayar),
                          const Color(0xFF7BC8A4),
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          'Tunggakan',
                          _formatRupiah(tunggakan),
                          const Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (tagihanAnak.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Belum ada tagihan',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ...tagihanAnak.map((tagihan) => _buildTagihanCard(tagihan)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

Widget _buildTagihanCard(Map<String, dynamic> tagihan) {
  final status = tagihan['status'] ?? 'belum_bayar';
  final statusColor = _getStatusColor(status);
  final statusText = _getStatusText(status);
  final nominal = tagihan['nominal_akhir'];
  final bulan = _formatBulan(tagihan['periode_bulan']);
  final tahun = tagihan['periode_tahun'];
  final jatuhTempo = tagihan['tanggal_jatuh_tempo'];
  final items = tagihan['items'] as List<dynamic>? ?? [];
  
  String jatuhTempoFormatted = '-';
  if (jatuhTempo != null) {
    try {
      final date = DateTime.parse(jatuhTempo);
      jatuhTempoFormatted = '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      jatuhTempoFormatted = '-';
    }
  }

  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status & Periode
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$bulan $tahun',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Jatuh Tempo
          Row(
            children: [
              Icon(Icons.event_busy, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Jatuh Tempo: $jatuhTempoFormatted',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Divider
          const Divider(),
          const SizedBox(height: 12),
          
          // Detail Items
          if (items.isNotEmpty) ...[
            const Text(
              'Detail Tagihan:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['nama'] ?? '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    _formatRupiah(item['nominal'] ?? 0),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )).toList(),
            const SizedBox(height: 12),
            const Divider(),
          ],
          
          // Total & Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRupiah(nominal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2B1C),
                    ),
                  ),
                ],
              ),
              if (status == 'belum_bayar')
                ElevatedButton.icon(
                  onPressed: () => _showBayarDialog(tagihan),
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Bayar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7BC8A4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              else if (status == 'menunggu_verifikasi')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_empty, size: 18, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Menunggu',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7BC8A4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF7BC8A4).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 18, color: Color(0xFF7BC8A4)),
                      const SizedBox(width: 8),
                      const Text(
                        'Lunas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7BC8A4),
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
  );
}

}