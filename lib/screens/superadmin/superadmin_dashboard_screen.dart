// lib/screens/superadmin/superadmin_dashboard_screen.dart
//
// Admin Aplikasi (superadmin): mendaftarkan dan mengelola sekolah yang
// memakai aplikasi ini. Peran ini bekerja lintas sekolah, berbeda dengan
// Admin Sekolah yang hanya mengelola satu sekolah.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../login_screen.dart';
import 'superadmin_sekolah_form.dart';

class SuperadminDashboardScreen extends StatefulWidget {
  const SuperadminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SuperadminDashboardScreen> createState() => _SuperadminDashboardScreenState();
}

class _SuperadminDashboardScreenState extends State<SuperadminDashboardScreen> {
  static const Color primary = Color(0xFF3F51B5);
  static const Color primaryDark = Color(0xFF283593);
  static const Color softBg = Color(0xFFF5F6FA);

  bool _isLoading = true;
  String? _error;
  List _sekolah = [];
  String _namaUser = 'Admin Aplikasi';
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadSekolah();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null && mounted) {
      final user = jsonDecode(userJson);
      setState(() => _namaUser = user['nama'] ?? user['username'] ?? 'Admin Aplikasi');
    }
  }

  Future<void> _loadSekolah() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getSekolahList();

    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _sekolah = (result['data'] as List?) ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'Gagal memuat daftar sekolah';
        _isLoading = false;
      });
    }
  }

  List get _sekolahTersaring {
    if (_cari.trim().isEmpty) return _sekolah;
    final q = _cari.toLowerCase();
    return _sekolah.where((s) {
      final nama = (s['nama'] ?? '').toString().toLowerCase();
      final alamat = (s['alamat'] ?? '').toString().toLowerCase();
      return nama.contains(q) || alamat.contains(q);
    }).toList();
  }

  int _totalDari(String key) =>
      _sekolah.fold<int>(0, (sum, s) => sum + ((s[key] ?? 0) as num).toInt());

  Future<void> _bukaForm({Map<String, dynamic>? sekolah}) async {
    final berubah = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SuperadminSekolahForm(sekolah: sekolah)),
    );
    if (berubah == true) _loadSekolah();
  }

  Future<void> _hapusSekolah(Map<String, dynamic> sekolah) async {
    final nama = (sekolah['nama'] ?? '').toString();
    final pengetikan = TextEditingController();

    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Sekolah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Tindakan ini menghapus SELURUH data sekolah ini: '
                '${sekolah['jumlah_siswa'] ?? 0} siswa, '
                '${sekolah['jumlah_guru'] ?? 0} guru, kelas, nilai, absensi, '
                'tagihan, dan semua akunnya. Tidak dapat dibatalkan.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
            Text('Ketik nama sekolah untuk melanjutkan:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            SelectableText(nama,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: pengetikan,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'Nama sekolah',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );

    if (yakin != true) return;

    if (pengetikan.text.trim() != nama) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama sekolah tidak cocok, penghapusan dibatalkan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await ApiService.deleteSekolah(sekolah['id'].toString(), nama);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Selesai'),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );
    if (result['success'] == true) _loadSekolah();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('school_info');
    if (!mounted) return;
    Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: const Text('Admin Aplikasi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSekolah),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        onPressed: () => _bukaForm(),
        icon: const Icon(Icons.add_business),
        label: const Text('Tambah Sekolah'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSekolah,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primary))
            : _error != null
                ? _buildError()
                : Column(
                    children: [
                      _buildRingkasan(),
                      _buildPencarian(),
                      Expanded(child: _buildDaftar()),
                    ],
                  ),
      ),
    );
  }

  Widget _buildError() => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadSekolah,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(backgroundColor: primary),
            ),
          ),
        ],
      );

  Widget _buildRingkasan() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selamat datang,',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
          Text(_namaUser,
              style: const TextStyle(
                  color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              _kartuStat('Sekolah', _sekolah.length.toString(), Icons.apartment),
              const SizedBox(width: 10),
              _kartuStat('Siswa', _totalDari('jumlah_siswa').toString(), Icons.groups),
              const SizedBox(width: 10),
              _kartuStat('Guru', _totalDari('jumlah_guru').toString(), Icons.badge),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kartuStat(String label, String nilai, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 6),
              Text(nilai,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85), fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _buildPencarian() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _cari = v),
          decoration: InputDecoration(
            hintText: 'Cari nama atau alamat sekolah...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      );

  Widget _buildDaftar() {
    final data = _sekolahTersaring;
    if (data.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.apartment_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            _sekolah.isEmpty
                ? 'Belum ada sekolah terdaftar.\nTekan "Tambah Sekolah" untuk mulai.'
                : 'Tidak ada sekolah yang cocok dengan pencarian.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _kartuSekolah(data[i] as Map<String, dynamic>),
    );
  }

  Widget _kartuSekolah(Map<String, dynamic> s) {
    final nama = (s['nama'] ?? '-').toString();
    final alamat = (s['alamat'] ?? '').toString();
    final inisial = nama.isNotEmpty ? nama.trim()[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: primary.withOpacity(0.12),
                  child: Text(inisial,
                      style: const TextStyle(
                          color: primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nama,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (alamat.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(alamat,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _bukaForm(sekolah: s);
                    if (v == 'hapus') _hapusSekolah(s);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Ubah')),
                    PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(Icons.groups, '${s['jumlah_siswa'] ?? 0} siswa', Colors.blue),
                _chip(Icons.badge, '${s['jumlah_guru'] ?? 0} guru', Colors.teal),
                _chip(Icons.meeting_room, '${s['jumlah_kelas'] ?? 0} kelas', Colors.orange),
                _chip(Icons.shield, '${s['jumlah_admin'] ?? 0} admin', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String teks, Color warna) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: warna.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: warna),
            const SizedBox(width: 5),
            Text(teks,
                style: TextStyle(
                    fontSize: 11, color: warna, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
