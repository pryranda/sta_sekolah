import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/school_provider.dart';

class AbsensiScreen extends StatefulWidget {
  const AbsensiScreen({Key? key}) : super(key: key);
  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> {
  static const String baseUrl = 'http://103.182.209.20:3000/api';
  
  bool _isLoading = false;
  bool _isCheckingIn = false;
  bool _isCheckingOut = false;
  bool _isRequesting = false;
  
  Position? _currentPosition;
  String _locationMessage = '';
  double _distanceToSchool = 0.0;
  
  Map<String, dynamic>? _todayAttendance;
  List _attendanceHistory = [];
  Map<String, dynamic> _rekap = {};

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
    _getCurrentLocation();
  }

  Future<void> _loadAttendanceData() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      final response = await http.get(
        Uri.parse('$baseUrl/student/absensi'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        final absensiList = data['data']['absensi'] as List;
        final rekap = data['data']['rekap'];
        
        final today = DateTime.now();
        final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        
        final todayData = absensiList.firstWhere(
          (a) => a['tanggal'].toString().startsWith(todayStr),
          orElse: () => null,
        );
        
        setState(() {
          _todayAttendance = todayData;
          _attendanceHistory = absensiList.take(10).toList();
          _rekap = rekap ?? {};
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error load attendance: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _locationMessage = '📍 Mendapatkan lokasi...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationMessage = '⚠️ Layanan lokasi tidak aktif');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationMessage = '❌ Izin lokasi ditolak');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationMessage = '❌ Izin lokasi ditolak permanen');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final schoolProvider = context.read<SchoolProvider>();
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        schoolProvider.latitude,
        schoolProvider.longitude,
      ) / 1000; // Convert to km

      setState(() {
        _currentPosition = position;
        _distanceToSchool = distance;
        _locationMessage = '📍 ${(distance * 1000).toStringAsFixed(0)}m dari sekolah';
      });
    } catch (e) {
      setState(() => _locationMessage = '❌ Error: $e');
    }
  }

  Future<void> _checkIn() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dapatkan lokasi terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_distanceToSchool > 0.6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Anda berada ${(_distanceToSchool * 1000).toStringAsFixed(0)}m dari sekolah. Maksimal 600m.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isCheckingIn = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/student/absensi/checkin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': 'hadir',
          'keterangan': 'Absen via Flutter App',
          'latitude': _currentPosition!.latitude.toString(),
          'longitude': _currentPosition!.longitude.toString(),
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '✅ Check-in berhasil'),
            backgroundColor: const Color(0xFF7BC8A4),
          ),
        );
        await _loadAttendanceData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '❌ Check-in gagal'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCheckingIn = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() => _isCheckingOut = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/student/absensi/checkout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body);

      if (data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '✅ Check-out berhasil'),
            backgroundColor: const Color(0xFF7BC8A4),
          ),
        );
        await _loadAttendanceData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '❌ Check-out gagal'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCheckingOut = false);
    }
  }

  Future<void> _requestPermission(String status) async {
    final keteranganController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    
    // Show date picker
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7BC8A4),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;
    
    selectedDate = pickedDate;

    // Show dialog untuk input keterangan
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Request ${status.toUpperCase()}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Request ini akan dikirim ke orang tua untuk di-approve.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF7BC8A4)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tanggal',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        Text(
                          _formatDateFull(selectedDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final newDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 7)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Color(0xFF7BC8A4),
                                onPrimary: Colors.white,
                                surface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (newDate != null) {
                        setDialogState(() => selectedDate = newDate);
                      }
                    },
                    child: const Text('Ubah'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: keteranganController,
                decoration: const InputDecoration(
                  labelText: 'Keterangan (wajib)',
                  hintText: 'Contoh: Sakit demam, Izin keluarga, dll',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7BC8A4),
              ),
              child: const Text('Kirim Request'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    if (keteranganController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keterangan wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isRequesting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final tanggalStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

      final response = await http.post(
        Uri.parse('$baseUrl/student/absensi/request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': status,
          'keterangan': keteranganController.text,
          'tanggal': tanggalStr,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? '✅ Request berhasil dikirim. Menunggu approval orang tua.',
            ),
            backgroundColor: const Color(0xFF2196F3),
            duration: const Duration(seconds: 4),
          ),
        );
        await _loadAttendanceData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? '❌ Request gagal'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Absensi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF7BC8A4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7BC8A4)))
          : RefreshIndicator(
              onRefresh: _loadAttendanceData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTodayStatusCard(),
                    const SizedBox(height: 16),
                    _buildCheckInCard(),
                    const SizedBox(height: 16),
                    _buildRekapCard(),
                    const SizedBox(height: 16),
                    _buildHistoryCard(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTodayStatusCard() {
    final bool hasCheckedIn = _todayAttendance != null;
    final bool hasCheckedOut = hasCheckedIn && _todayAttendance!['jam_pulang'] != null;
    final String approvalStatus = _todayAttendance?['approval_status'] ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasCheckedIn 
                        ? const Color(0xFF7BC8A4).withOpacity(0.15)
                        : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasCheckedIn ? Icons.check_circle : Icons.schedule,
                    color: hasCheckedIn ? const Color(0xFF7BC8A4) : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Hari Ini',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        hasCheckedIn 
                            ? (_todayAttendance!['status'] ?? 'Hadir').toString().toUpperCase()
                            : 'Belum Absen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: hasCheckedIn 
                              ? const Color(0xFF7BC8A4)
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (approvalStatus == 'pending')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⏳ Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
            if (hasCheckedIn) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jam Masuk', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        _formatTime(_todayAttendance!['jam_masuk']),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Jam Pulang', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        hasCheckedOut 
                            ? _formatTime(_todayAttendance!['jam_pulang'])
                            : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: hasCheckedOut ? const Color(0xFF7BC8A4) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInCard() {
    final bool hasCheckedIn = _todayAttendance != null;
    final bool hasCheckedOut = hasCheckedIn && _todayAttendance!['jam_pulang'] != null;
    final String approvalStatus = _todayAttendance?['approval_status'] ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Absensi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (hasCheckedIn && approvalStatus == 'pending')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_empty, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Menunggu Approval Orang Tua',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: ${_todayAttendance!['status']}',
                            style: const TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                          if (_todayAttendance!['keterangan'] != null)
                            Text(
                              'Keterangan: ${_todayAttendance!['keterangan']}',
                              style: const TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7BC8A4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7BC8A4).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF7BC8A4)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationMessage.isEmpty ? 'Lokasi belum didapatkan' : _locationMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: _locationMessage.isEmpty ? Colors.grey : const Color(0xFF1A2B1C),
                      ),
                    ),
                  ),
                  if (_locationMessage.isEmpty)
                    TextButton(
                      onPressed: _getCurrentLocation,
                      child: const Text('Dapatkan'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            if (!hasCheckedIn)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isCheckingIn ? null : _checkIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7BC8A4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isCheckingIn
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('✅ Check In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              )
            else if (!hasCheckedOut && approvalStatus != 'pending')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isCheckingOut ? null : _checkOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isCheckingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: Colors.white),
                            SizedBox(width: 8),
                            Text('🚪 Check Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              )
            else if (approvalStatus == 'pending')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Menunggu Approval',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7BC8A4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF7BC8A4)),
                    SizedBox(width: 8),
                    Text(
                      'Absensi Hari Ini Selesai',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7BC8A4),
                      ),
                    ),
                  ],
                ),
              ),
            
            if (!hasCheckedIn) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Atau Request Izin/Sakit:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isRequesting ? null : () => _requestPermission('izin'),
                      icon: const Icon(Icons.description, size: 18),
                      label: const Text('📝 Izin'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2196F3),
                        side: const BorderSide(color: Color(0xFF2196F3)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isRequesting ? null : () => _requestPermission('sakit'),
                      icon: const Icon(Icons.local_hospital, size: 18),
                      label: const Text('🤒 Sakit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF9800),
                        side: const BorderSide(color: Color(0xFFFF9800)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRekapCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rekap Bulan Ini',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildRekapItem('Hadir', _rekap['hadir'] ?? 0, const Color(0xFF7BC8A4)),
                _buildRekapItem('Izin', _rekap['izin'] ?? 0, const Color(0xFF2196F3)),
                _buildRekapItem('Sakit', _rekap['sakit'] ?? 0, const Color(0xFFFF9800)),
                _buildRekapItem('Alpha', _rekap['alpha'] ?? 0, const Color(0xFFE53935)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRekapItem(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Riwayat Absensi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_attendanceHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Belum ada riwayat absensi'),
                ),
              )
            else
              ..._attendanceHistory.map((absen) => _buildHistoryItem(absen)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> absen) {
    final status = absen['status'] ?? 'hadir';
    final approvalStatus = absen['approval_status'] ?? '';
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'hadir':
        statusColor = const Color(0xFF7BC8A4);
        statusIcon = Icons.check_circle;
        break;
      case 'izin':
        statusColor = const Color(0xFF2196F3);
        statusIcon = Icons.description;
        break;
      case 'sakit':
        statusColor = const Color(0xFFFF9800);
        statusIcon = Icons.local_hospital;
        break;
      default:
        statusColor = const Color(0xFFE53935);
        statusIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(absen['tanggal']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${_formatTime(absen['jam_masuk'])} - ${absen['jam_pulang'] != null ? _formatTime(absen['jam_pulang']) : "belum pulang"}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (approvalStatus == 'pending')
                  const Text(
                    '⏳ Menunggu approval',
                    style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateFull(DateTime date) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(dynamic time) {
    if (time == null) return '-';
    try {
      final timeStr = time.toString();
      if (timeStr.contains('T')) {
        final dt = DateTime.parse(timeStr);
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return timeStr.substring(0, 5);
    } catch (e) {
      return '-';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dateStr = date.toString();
      final dt = DateTime.parse(dateStr.contains('T') ? dateStr : '${dateStr}T00:00:00');
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return '-';
    }
  }
}