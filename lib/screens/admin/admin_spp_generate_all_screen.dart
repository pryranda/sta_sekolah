import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSppGenerateAllScreen extends StatefulWidget {
  const AdminSppGenerateAllScreen({Key? key}) : super(key: key);

  @override
  State<AdminSppGenerateAllScreen> createState() => _AdminSppGenerateAllScreenState();
}

class _AdminSppGenerateAllScreenState extends State<AdminSppGenerateAllScreen> {
  static const String baseUrl = 'http://103.182.209.20:3000/api';
  
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _token;
  
  int _tahun = DateTime.now().year;
  int _bulanMulai = 1;
  int _bulanSelesai = 12;
  List _jenisPembayaran = [];
  Map<String, int> _nominalOverrides = {};
  
  final List<String> _bulanNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _loadJenisPembayaran();
  }

  String _formatRupiah(dynamic nominal) {
    if (nominal == null) return 'Rp 0';
    final value = nominal is int ? nominal : int.tryParse(nominal.toString()) ?? 0;
    if (value == 0) return 'Rp 0 (Gratis)';
    return 'Rp ${value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  // ✅ Helper function untuk parse int yang aman
  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<void> _loadJenisPembayaran() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/spp/admin/jenis-pembayaran'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        setState(() {
          _jenisPembayaran = data['data'] ?? [];
          // Inisialisasi nominal overrides dengan default
          for (var jp in _jenisPembayaran) {
            _nominalOverrides[jp['id'].toString()] = _safeParseInt(jp['nominal_default']);
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error load jenis pembayaran: $e');
      setState(() => _isLoading = false);
    }
  }

  int _getTotalPerBulan() {
    return _jenisPembayaran.fold<int>(
      0,
      (sum, jp) => sum + _safeParseInt(_nominalOverrides[jp['id'].toString()]),
    );
  }

  Future<void> _generateAll() async {
    if (!_formKey.currentState!.validate()) return;
    
    final totalPerBulan = _getTotalPerBulan();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Generate Semua Tagihan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📅 Tahun: $_tahun'),
              Text('📆 Periode: ${_bulanNames[_bulanMulai - 1]} - ${_bulanNames[_bulanSelesai - 1]}'),
              const SizedBox(height: 16),
              const Text('Jenis Pembayaran yang akan digenerate:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._jenisPembayaran.map((jp) {
                final nominal = _safeParseInt(_nominalOverrides[jp['id'].toString()]);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${jp['nama']}: ${_formatRupiah(nominal)}'),
                );
              }).toList(),
              const Divider(),
              Text(
                '💰 Total per siswa per bulan: ${_formatRupiah(totalPerBulan)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7BC8A4)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tagihan akan dibuat untuk SEMUA siswa aktif dan SEMUA jenis pembayaran.\nLanjutkan?',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7BC8A4)),
            child: const Text('Ya, Generate Semua'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/spp/admin/tagihan/generate-all'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'tahun': _tahun,
          'bulan_mulai': _bulanMulai,
          'bulan_selesai': _bulanSelesai,
          'nominal_overrides': _nominalOverrides,
        }),
      );
      
      final data = jsonDecode(response.body);
      
      if (mounted) {
        if (data['success']) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF7BC8A4), size: 28),
                  SizedBox(width: 8),
                  Text('Berhasil'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Semua tagihan berhasil dibuat!'),
                    const SizedBox(height: 16),
                    _buildInfoRow('Total Tagihan', '${data['data']['total_tagihan_dibuat']} tagihan'),
                    _buildInfoRow('Total Siswa', '${data['data']['total_siswa']} siswa'),
                    _buildInfoRow('Periode', '${_bulanNames[_bulanMulai - 1]} - ${_bulanNames[_bulanSelesai - 1]} $_tahun'),
                    const Divider(),
                    const Text('Detail per Jenis:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...(data['data']['summary'] as List).map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${item['jenis_pembayaran']}: ${item['tagihan_dibuat']} tagihan (@${_formatRupiah(item['nominal_per_tagihan'])})'),
                    )).toList(),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7BC8A4)),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Gagal generate tagihan'),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Generate Semua Tagihan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF7BC8A4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading && _jenisPembayaran.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7BC8A4)))
          : Form(
              key: _formKey,
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
                          const Text(
                            'Parameter Generate',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          
                          DropdownButtonFormField<int>(
                            value: _tahun,
                            decoration: const InputDecoration(
                              labelText: 'Tahun',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            items: List.generate(5, (index) => DateTime.now().year - 1 + index)
                                .map((year) => DropdownMenuItem<int>(value: year, child: Text(year.toString())))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _tahun = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          DropdownButtonFormField<int>(
                            value: _bulanMulai,
                            decoration: const InputDecoration(
                              labelText: 'Bulan Mulai',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.arrow_forward),
                            ),
                            items: List.generate(12, (index) => index + 1)
                                .map((month) => DropdownMenuItem<int>(value: month, child: Text(_bulanNames[month - 1])))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _bulanMulai = value;
                                  if (_bulanMulai > _bulanSelesai) _bulanSelesai = _bulanMulai;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          DropdownButtonFormField<int>(
                            value: _bulanSelesai,
                            decoration: const InputDecoration(
                              labelText: 'Bulan Selesai',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.arrow_back),
                            ),
                            items: List.generate(12, (index) => index + 1)
                                .where((month) => month >= _bulanMulai)
                                .map((month) => DropdownMenuItem<int>(value: month, child: Text(_bulanNames[month - 1])))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _bulanSelesai = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Jenis Pembayaran & Nominal',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ..._jenisPembayaran.map((jp) {
                            final jpId = jp['id'].toString();
                            final currentNominal = _nominalOverrides[jpId] ?? _safeParseInt(jp['nominal_default']);
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(jp['nama'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text(
                                          'Default: ${_formatRupiah(jp['nominal_default'])}',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 140,
                                    child: TextFormField(
                                      initialValue: currentNominal > 0 ? currentNominal.toString() : '',
                                      decoration: const InputDecoration(
                                        labelText: 'Nominal',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.money, size: 20),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      onChanged: (value) {
                                        setState(() {
                                          _nominalOverrides[jpId] = int.tryParse(value) ?? 0;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text('Ringkasan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('• Setiap siswa akan mendapat ${_jenisPembayaran.length} tagihan berbeda', style: TextStyle(color: Colors.blue.shade800, fontSize: 13)),
                        Text('• Total per siswa per bulan: ${_formatRupiah(_getTotalPerBulan())}', style: TextStyle(color: Colors.blue.shade800, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('• Jatuh tempo: Tanggal 10 setiap bulan', style: TextStyle(color: Colors.blue.shade800, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _generateAll,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Icon(Icons.auto_awesome, size: 20),
                    label: Text(_isLoading ? 'Memproses...' : 'Generate Semua Tagihan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7BC8A4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}