import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSppVerificationScreen extends StatefulWidget {
  const AdminSppVerificationScreen({Key? key}) : super(key: key);

  @override
  State<AdminSppVerificationScreen> createState() => _AdminSppVerificationScreenState();
}

class _AdminSppVerificationScreenState extends State<AdminSppVerificationScreen> {
  static const String baseUrl = 'http://103.182.209.20:3000/api';
  
  bool _isLoading = true;
  List _pembayaranPending = [];
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/spp/admin/pembayaran/pending'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        setState(() {
          _pembayaranPending = data['data'] ?? [];
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

  String _formatTanggal(String? tanggal) {
    if (tanggal == null) return '-';
    try {
      final date = DateTime.parse(tanggal);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '-';
    }
  }

  Future<void> _verifikasiPembayaran(String pembayaranId, String action) async {
    // Konfirmasi dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action == 'approved' ? 'Konfirmasi Verifikasi' : 'Konfirmasi Penolakan'),
        content: Text(
          action == 'approved'
            ? 'Apakah Anda yakin ingin menyetujui pembayaran ini?'
            : 'Apakah Anda yakin ingin menolak pembayaran ini? Tagihan akan kembali ke status Belum Bayar.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approved' ? const Color(0xFF7BC8A4) : Colors.red,
            ),
            child: Text(action == 'approved' ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/spp/admin/pembayaran/$pembayaranId/verify'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': action,
          'note': action == 'approved' ? 'Disetujui oleh admin' : 'Ditolak oleh admin',
        }),
      );

      final data = jsonDecode(response.body);

      if (mounted) {
        if (data['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Verifikasi berhasil'),
              backgroundColor: action == 'approved' ? Colors.green : Colors.red,
            ),
          );
          await _loadData(); // Refresh list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Gagal memverifikasi'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showBuktiTransfer(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Bukti Transfer'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Gagal memuat gambar'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Verifikasi Pembayaran SPP',
          style: TextStyle(fontWeight: FontWeight.bold),
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7BC8A4)))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_pembayaranPending.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Color(0xFF7BC8A4)),
            SizedBox(height: 16),
            Text(
              'Tidak ada pembayaran menunggu verifikasi',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pembayaranPending.length,
        itemBuilder: (context, index) {
          final pembayaran = _pembayaranPending[index];
          return _buildPembayaranCard(pembayaran);
        },
      ),
    );
  }

  Widget _buildPembayaranCard(Map<String, dynamic> pembayaran) {
    final namaSiswa = pembayaran['nama_siswa'] ?? '-';
    final nis = pembayaran['nis'] ?? '-';
    final namaKelas = pembayaran['nama_kelas'] ?? '-';
    final namaOrtu = pembayaran['nama_orang_tua'] ?? '-';
    final jenisPembayaran = pembayaran['jenis_pembayaran'] ?? 'SPP';
    final periodeBulan = pembayaran['periode_bulan'];
    final periodeTahun = pembayaran['periode_tahun'];
    final nominal = pembayaran['jumlah_bayar'] ?? pembayaran['nominal_akhir'] ?? 0;
    final metodeBayar = pembayaran['metode_bayar'] ?? '-';
    final tanggalBayar = pembayaran['tanggal_bayar'];
    final nomorReferensi = pembayaran['nomor_referensi'];
    final catatan = pembayaran['catatan'];
    final buktiUrl = pembayaran['bukti_transfer_url'];
    final pembayaranId = pembayaran['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Info Siswa
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7BC8A4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF7BC8A4)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        namaSiswa,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'NIS: $nis | Kelas: $namaKelas',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Orang Tua: $namaOrtu',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Detail Pembayaran
            _buildInfoRow(Icons.receipt_long, 'Jenis Pembayaran', jenisPembayaran),
            _buildInfoRow(
              Icons.calendar_today,
              'Periode',
              '${_formatBulan(periodeBulan ?? 1)} $periodeTahun',
            ),
            _buildInfoRow(Icons.attach_money, 'Nominal', _formatRupiah(nominal)),
            _buildInfoRow(Icons.payment, 'Metode Bayar', metodeBayar.toUpperCase()),
            _buildInfoRow(Icons.access_time, 'Tanggal Bayar', _formatTanggal(tanggalBayar)),
            
            if (nomorReferensi != null && nomorReferensi.toString().isNotEmpty)
              _buildInfoRow(Icons.numbers, 'No. Referensi', nomorReferensi),
            
            if (catatan != null && catatan.toString().isNotEmpty)
              _buildInfoRow(Icons.note, 'Catatan', catatan),

            const SizedBox(height: 16),

            // Bukti Transfer
            if (buktiUrl != null && buktiUrl.toString().isNotEmpty) ...[
              const Text(
                'Bukti Transfer:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showBuktiTransfer(buktiUrl),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      buktiUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Gagal memuat gambar', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap untuk memperbesar',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _verifikasiPembayaran(pembayaranId, 'rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Tolak'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _verifikasiPembayaran(pembayaranId, 'approved'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Setujui'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7BC8A4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A2B1C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
