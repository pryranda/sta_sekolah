import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

class AdminLaporanKeuanganScreen extends StatefulWidget {
  const AdminLaporanKeuanganScreen({Key? key}) : super(key: key);

  @override
  State<AdminLaporanKeuanganScreen> createState() => _AdminLaporanKeuanganScreenState();
}

class _AdminLaporanKeuanganScreenState extends State<AdminLaporanKeuanganScreen> {
  static const String baseUrl = kApiBaseUrl;
  
  bool _isLoading = true;
  String? _token;
  Map<String, dynamic>? _laporanData;
  
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  
  final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

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
        Uri.parse('$baseUrl/spp/admin/laporan?bulan=$_selectedMonth&tahun=$_selectedYear'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        setState(() {
          _laporanData = data['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Gagal memuat laporan')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error load laporan: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatRupiah(dynamic nominal) {
    if (nominal == null) return 'Rp 0';
    final value = nominal is int ? nominal : int.tryParse(nominal.toString()) ?? 0;
    return 'Rp ${value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Laporan Keuangan',
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
    return Column(
      children: [
        // Filter Period
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Bulan',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: List.generate(12, (index) => index + 1)
                      .map((month) => DropdownMenuItem(
                            value: month,
                            child: Text(_monthNames[month - 1]),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedMonth = value!);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Tahun',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: List.generate(5, (index) => DateTime.now().year - 2 + index)
                      .map((year) => DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedYear = value!);
                    _loadData();
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCards(),
                const SizedBox(height: 16),
                _buildPembayaranBulanIni(),
                const SizedBox(height: 16),
                _buildDetailPerJenis(),
                const SizedBox(height: 16),
                _buildPerKelas(),
                const SizedBox(height: 16),
                _buildTopTunggakan(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final ringkasan = _laporanData?['ringkasan'] ?? {};
    final totalTagihan = ringkasan['total_tagihan'] ?? 0;
    final lunas = ringkasan['lunas'] ?? 0;
    final belumBayar = ringkasan['belum_bayar'] ?? 0;
    final menunggu = ringkasan['menunggu_verifikasi'] ?? 0;
    final totalTerbayar = ringkasan['total_terbayar'] ?? 0;
    final persentase = ringkasan['persentase_pembayaran'] ?? 0;
    final totalNominal = ringkasan['total_nominal'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Tagihan', totalTagihan.toString(), Colors.blue, Icons.receipt)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Lunas', lunas.toString(), Colors.green, Icons.check_circle)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildStatCard('Belum Bayar', belumBayar.toString(), Colors.red, Icons.cancel)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Menunggu', menunggu.toString(), Colors.orange, Icons.hourglass_empty)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7BC8A4), Color(0xFF5FA88A)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Terbayar',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                _formatRupiah(totalTerbayar),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: persentase > 0 ? persentase / 100 : 0,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '$persentase% dari ${_formatRupiah(totalNominal)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
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
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPembayaranBulanIni() {
    final pembayaran = _laporanData?['pembayaran_bulan_ini'] ?? {};
    final totalPembayaran = pembayaran['total_pembayaran'] ?? 0;
    final totalTerima = pembayaran['total_terima'] ?? 0;
    final hariIni = pembayaran['pembayaran_hari_ini'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'Pembayaran Bulan Ini',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Pembayaran', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(totalPembayaran.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Terima', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_formatRupiah(totalTerima), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7BC8A4))),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hari Ini', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(hariIni.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPerJenis() {
    final detailPerJenis = _laporanData?['detail_per_jenis'] ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Per Jenis Pembayaran',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...detailPerJenis.map((jenis) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jenis['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildMiniStat('Total', jenis['total_tagihan'] ?? 0)),
                      Expanded(child: _buildMiniStat('Lunas', jenis['lunas'] ?? 0, color: Colors.green)),
                      Expanded(child: _buildMiniStat('Belum', jenis['belum_bayar'] ?? 0, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total: ${_formatRupiah(jenis['total_nominal'] ?? 0)}', 
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      Text('Terbayar: ${_formatRupiah(jenis['total_terbayar'] ?? 0)}', 
                        style: const TextStyle(fontSize: 12, color: Color(0xFF7BC8A4), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int value, {Color? color}) {
    return Text(
      '$label: $value',
      style: TextStyle(fontSize: 11, color: color ?? Colors.grey.shade700),
    );
  }

  Widget _buildPerKelas() {
    final perKelas = _laporanData?['per_kelas'] ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Per Kelas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...perKelas.map((kelas) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(kelas['nama_kelas'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    Text('${kelas['lunas']}/${kelas['total_tagihan']}', 
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(width: 8),
                    Text(_formatRupiah(kelas['total_terbayar'] ?? 0), 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7BC8A4))),
                  ],
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildTopTunggakan() {
    final topTunggakan = _laporanData?['top_tunggakan'] ?? [];

    if (topTunggakan.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text(
                'Top 10 Tunggakan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...topTunggakan.map((siswa) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(siswa['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${siswa['nis']} - ${siswa['nama_kelas']}', 
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatRupiah(siswa['total_tunggakan'] ?? 0), 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      Text('${siswa['jumlah_tagihan']} tagihan', 
                        style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
                    ],
                  ),
                ],
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }
}