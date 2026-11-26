import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'student_dashboard_screen.dart';
import 'parent_dashboard_screen.dart';
import 'teacher/teacher_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'superadmin/superadmin_dashboard_screen.dart';
import '../widgets/responsive_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  String _userRole = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      final user = jsonDecode(userJson);
      setState(() {
        _userName = user['username'] ?? user['nama'] ?? '';
        _userRole = user['role'] ?? '';
        _isLoading = false;
      });
      
      // Auto-redirect ke dashboard sesuai role setelah 1 detik
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToDashboard();
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    
    Widget dashboard;
    switch (_userRole.toLowerCase()) {
      case 'siswa':
        dashboard = const StudentDashboardScreen();
        break;
      case 'guru':
        dashboard = const TeacherDashboardScreen();
        break;
      case 'superadmin':
        dashboard = const SuperadminDashboardScreen();
        break;
      case 'admin':
      case 'administrator':
        dashboard = const AdminDashboardScreen();
        break;
      case 'orang_tua':
        dashboard = const ParentDashboardScreen();
        break;
      default:
        return; // Stay di HomeScreen
    }
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => dashboard),
    );
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF7BC8A4)),
              SizedBox(height: 16),
              Text('Memuat data...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: ResponsiveCenter(
        maxWidth: 420,
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF7BC8A4)),
                const SizedBox(height: 24),
                Text(
                  'Selamat Datang, $_userName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7BC8A4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _userRole.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _logout,
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}