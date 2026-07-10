import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSppGenerateScreen extends StatefulWidget {
  const AdminSppGenerateScreen({Key? key}) : super(key: key);

  @override
  State<AdminSppGenerateScreen> createState() => _AdminSppGenerateScreenState();
}

class _AdminSppGenerateScreenState extends State<AdminSppGenerateScreen> {
  static const String baseUrl = 'http://103.182.209.20:3000/api';
  
  final _formKey = GlobalKey<FormState>();
  final _nominalController = TextEditingController();
  
  bool _isLoading = false;
  String? _token;
  
  // ✅ Gunakan ValueNotifier untuk setiap field
  final ValueNotifier<int> _tahunNotifier = ValueNotifier(DateTime.now().year);
  final ValueNotifier<int> _bulanMulaiNotifier = ValueNotifier(1);
  final ValueNotifier<int> _bulanSelesaiNotifier = ValueNotifier(12);
  final ValueNotifier<String?> _jenisPembayaranNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _useCustomNominalNotifier = ValueNotifier(false);
  
  List _jenisPembayaran = [];
  int? _customNominal;
  
  final List<String> _bulanNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _loadJenisPembayaran();
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _tahunNotifier.dispose();
    _bulanMulaiNotifier.dispose();
    _bulanSelesaiNotifier.dispose();
    _jenisPembayaranNotifier.dispose();
    _useCustomNominalNotifier.dispose();
    super.dispose();
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

  String _formatRupiahPlain(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  int _getNominalToUse() {
    if (_useCustomNominalNotifier.value && _customNominal != null) {
      return _customNominal!;
    }
    final selected = _jenisPembayaran.firstWhere(
      (jp) => jp['id'].toString() == _jenisPembayaranNotifier.value,
      orElse: () => null,
    );
    return selected?['nominal_default'] ?? 0;
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
          if (_jenisPembayaran.isNotEmpty) {
            _jenisPembayaranNotifier.value = _jenisPembayaran[0]['id'].toString();
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

  Future<void> _generateTagihan() async {
    if (!_formKey.currentState!.validate()) return;
    
    final nominal = _getNominalToUse();
    if (nominal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal tidak boleh negatif'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Generate Tagihan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅 Tahun: ${_tahunNotifier.value}'),
            Text('📆 Periode: ${_bulanNames[_bulanMulaiNotifier.value - 1]} - ${_bulanNames[_bulanSelesaiNotifier.value - 1]}'),
            const SizedBox(height: 8),
            Text('💰 Jenis: ${_getSelectedJenisName()}'),
            Text('💵 Nominal: ${_formatRupiah(nominal)}'),
            if (_useCustomNominalNotifier.value)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Menggunakan nominal custom',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Tagihan akan dibuat untuk SEMUA siswa aktif.\nLanjutkan?',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7BC8A4)),
            child: const Text('Ya, Generate'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/spp/admin/tagihan/generate-massal'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'tahun': _tahunNotifier.value,
          'bulan_mulai': _bulanMulaiNotifier.value,
          'bulan_selesai': _bulanSelesaiNotifier.value,
          'jenis_pembayaran_id': _jenisPembayaranNotifier.value,
          'nominal_override': _useCustomNominalNotifier.value ? _customNominal : null,
        }),
      );
      
      final data = jsonDecode(response.body);
      
      if (mounted) {
        if (data['success']) {
          final tagihanDibuat = data['data']['tagihan_dibuat'] ?? 0;
          final totalNominal = data['data']['total_nominal'] ?? 0;
          final nominalPerTagihan = data['data']['nominal_per_tagihan'] ?? 0;
          
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tagihan berhasil dibuat!'),
                  const SizedBox(height: 16),
                  _buildInfoRow('Total Tagihan', '$tagihanDibuat tagihan'),
                  _buildInfoRow('Nominal/Tagihan', _formatRupiah(nominalPerTagihan)),
                  _buildInfoRow('Total Nominal', _formatRupiah(totalNominal)),
                  _buildInfoRow('Periode', '${_bulanNames[_bulanMulaiNotifier.value - 1]} - ${_bulanNames[_bulanSelesaiNotifier.value - 1]} ${_tahunNotifier.value}'),
                ],
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

  String _getSelectedJenisName() {
    final selected = _jenisPembayaran.firstWhere(
      (jp) => jp['id'].toString() == _jenisPembayaranNotifier.value,
      orElse: () => null,
    );
    return selected?['nama'] ?? '-';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          'Generate Tagihan Massal',
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Tahun - Pakai ValueListenableBuilder
                          ValueListenableBuilder<int>(
                            valueListenable: _tahunNotifier,
                            builder: (context, value, child) {
                              return DropdownButtonFormField<int>(
                                value: value,
                                decoration: const InputDecoration(
                                  labelText: 'Tahun',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                items: List.generate(5, (index) => DateTime.now().year - 1 + index)
                                    .map((year) => DropdownMenuItem<int>(
                                          value: year,
                                          child: Text(year.toString()),
                                        ))
                                    .toList(),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    _tahunNotifier.value = newValue;
                                  }
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Bulan Mulai
                          ValueListenableBuilder<int>(
                            valueListenable: _bulanMulaiNotifier,
                            builder: (context, value, child) {
                              return DropdownButtonFormField<int>(
                                value: value,
                                decoration: const InputDecoration(
                                  labelText: 'Bulan Mulai',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.arrow_forward),
                                ),
                                items: List.generate(12, (index) => index + 1)
                                    .map((month) => DropdownMenuItem<int>(
                                          value: month,
                                          child: Text(_bulanNames[month - 1]),
                                        ))
                                    .toList(),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    _bulanMulaiNotifier.value = newValue;
                                    if (newValue > _bulanSelesaiNotifier.value) {
                                      _bulanSelesaiNotifier.value = newValue;
                                    }
                                  }
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Bulan Selesai
                          ValueListenableBuilder<int>(
                            valueListenable: _bulanSelesaiNotifier,
                            builder: (context, value, child) {
                              return DropdownButtonFormField<int>(
                                value: value,
                                decoration: const InputDecoration(
                                  labelText: 'Bulan Selesai',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.arrow_back),
                                ),
                                items: List.generate(12, (index) => index + 1)
                                    .where((month) => month >= _bulanMulaiNotifier.value)
                                    .map((month) => DropdownMenuItem<int>(
                                          value: month,
                                          child: Text(_bulanNames[month - 1]),
                                        ))
                                    .toList(),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    _bulanSelesaiNotifier.value = newValue;
                                  }
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Jenis Pembayaran
                          ValueListenableBuilder<String?>(
                            valueListenable: _jenisPembayaranNotifier,
                            builder: (context, value, child) {
                              return DropdownButtonFormField<String>(
                                value: value,
                                decoration: const InputDecoration(
                                  labelText: 'Jenis Pembayaran',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.payment),
                                ),
                                items: _jenisPembayaran
                                    .map<DropdownMenuItem<String>>((jp) => DropdownMenuItem<String>(
                                          value: jp['id'].toString(),
                                          child: Text(
                                            '${jp['nama']} (${_formatRupiah(jp['nominal_default'])})',
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (newValue) {
                                  if (newValue != null) {
                                    _jenisPembayaranNotifier.value = newValue;
                                  }
                                },
                                validator: (value) {
                                  if (value == null) return 'Pilih jenis pembayaran';
                                  return null;
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Toggle Nominal Custom
                          ValueListenableBuilder<bool>(
                            valueListenable: _useCustomNominalNotifier,
                            builder: (context, value, child) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: value 
                                      ? Colors.orange.shade50 
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: value 
                                        ? Colors.orange.shade300 
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'Gunakan Nominal Custom',
                                        style: TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(
                                        value 
                                            ? 'Aktif - nominal akan di-override'
                                            : 'Non-aktif - pakai nominal default',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      value: value,
                                      onChanged: (newValue) {
                                        _useCustomNominalNotifier.value = newValue!;
                                        if (!newValue) {
                                          _customNominal = null;
                                          _nominalController.clear();
                                        }
                                      },
                                      activeColor: const Color(0xFF7BC8A4),
                                    ),
                                    
                                    if (value) ...[
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _nominalController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nominal Custom',
                                          hintText: 'Contoh: 200000',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.money),
                                          helperText: 'Kosongkan atau 0 untuk tagihan gratis',
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        onChanged: (inputValue) {
                                          final cleanValue = inputValue.replaceAll('.', '');
                                          _customNominal = int.tryParse(cleanValue) ?? 0;
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Nominal default: ${_formatRupiah(_jenisPembayaran.firstWhere(
                                                (jp) => jp['id'].toString() == _jenisPembayaranNotifier.value,
                                                orElse: () => null,
                                              )?['nominal_default'] ?? 0)}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Info Card
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
                            Text(
                              'Informasi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Tagihan akan dibuat untuk SEMUA siswa aktif',
                          style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                        ),
                        Text(
                          '• Jatuh tempo: Tanggal 10 setiap bulan',
                          style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                        ),
                        Text(
                          '• Tagihan yang sudah ada akan dilewati (tidak duplikat)',
                          style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                        ),
                        Text(
                          '• Nominal Rp 0 = tagihan gratis (untuk tracking)',
                          style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Generate Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _generateTagihan,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 20),
                    label: Text(_isLoading ? 'Memproses...' : 'Generate Tagihan'),
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