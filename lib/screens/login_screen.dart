import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'student_dashboard_screen.dart';
import 'parent_dashboard_screen.dart';
import 'teacher/teacher_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'superadmin/superadmin_dashboard_screen.dart';
import 'package:provider/provider.dart';
import '../providers/school_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  bool _rememberMe = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color primaryGreen = Color(0xFF7BC8A4);
  static const Color darkGreen = Color(0xFF2D5A4A);
  static const Color darkerGreen = Color(0xFF1A3D32);
  static const Color softWhite = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _loadSavedCredentials();
    // TIDAK ADA panggil loadSchoolProfile di sini
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('remembered_username');
    if (savedUsername != null) {
      setState(() {
        _usernameController.text = savedUsername;
        _rememberMe = true;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (result['success'] == true) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('token', result['data']['token']);
        await prefs.setString('user', jsonEncode(result['data']['user']));

        if (_rememberMe) {
          await prefs.setString('remembered_username', _usernameController.text.trim());
        } else {
          await prefs.remove('remembered_username');
        }

        // Hapus cache sekolah agar data baru diambil
        await prefs.remove('school_info');

        final user = result['data']['user'];
        final userRole = (user['role'] ?? user['role_name'] ?? '').toString().toLowerCase();

        // Superadmin tidak terikat satu sekolah, jadi tidak ada profil sekolah
        // yang perlu dimuat untuknya.
        if (userRole != 'superadmin') {
          await context.read<SchoolProvider>().loadSchoolProfile(forceReload: true);
        }

        Widget targetScreen;
        switch (userRole) {
          case 'siswa':
            targetScreen = const StudentDashboardScreen();
            break;
          case 'orang_tua':
            targetScreen = const ParentDashboardScreen();
            break;
          case 'guru':
            targetScreen = const TeacherDashboardScreen();
            break;
          case 'admin':
          case 'administrator':
            targetScreen = const AdminDashboardScreen();
            break;
          case 'superadmin':
            targetScreen = const SuperadminDashboardScreen();
            break;
          default:
            targetScreen = const HomeScreen();
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => targetScreen),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Login gagal'),
              backgroundColor: darkerGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: darkerGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F8F0),
              Color(0xFFB8F0D8),
              Color(0xFF7BC8A4),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Dekorasi lingkaran
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
              Positioned(
                bottom: 30,
                left: -70,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
              Positioned(
                top: 200,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: darkerGreen.withOpacity(0.06),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ==========================================
                          // LOGO & NAMA SEKOLAH (HANYA PLACEHOLDER)
                          // ==========================================
                          Consumer<SchoolProvider>(
                            builder: (context, schoolProvider, child) {
                              final isLoading = schoolProvider.isLoading;
                              final logo = schoolProvider.logoUrl;
                              final nama = schoolProvider.namaSekolah;

                              return Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: primaryGreen, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: darkerGreen.withOpacity(0.12),
                                          blurRadius: 15,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 50,
                                            height: 50,
                                            child: CircularProgressIndicator(
                                              color: primaryGreen,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : (logo.isNotEmpty
                                            ? ClipOval(
                                                child: Image.network(
                                                  logo,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return const SizedBox(
                                                      width: 50,
                                                      height: 50,
                                                      child: Center(
                                                        child: CircularProgressIndicator(
                                                          color: primaryGreen,
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      const Icon(
                                                    Icons.school_rounded,
                                                    size: 50,
                                                    color: primaryGreen,
                                                  ),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.school_rounded,
                                                size: 50,
                                                color: primaryGreen,
                                              )),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    nama.isNotEmpty ? nama : 'Sekolah', // placeholder
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: darkerGreen,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: darkGreen,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Text(
                                      'Sistem Informasi Sekolah',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 28),

                          // Login Card (sama seperti sebelumnya, tidak diubah)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: primaryGreen.withOpacity(0.2), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: darkerGreen.withOpacity(0.08),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: primaryGreen,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Selamat Datang',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: darkerGreen,
                                            ),
                                          ),
                                          Text(
                                            'Silakan login untuk melanjutkan',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _usernameController,
                                    decoration: InputDecoration(
                                      labelText: 'Username',
                                      labelStyle: const TextStyle(fontSize: 13),
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.all(6),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: primaryGreen.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.person_outline,
                                          color: primaryGreen,
                                          size: 18,
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      filled: true,
                                      fillColor: softWhite,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Username tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscureText,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      labelStyle: const TextStyle(fontSize: 13),
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.all(6),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: primaryGreen.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.lock_outline,
                                          color: primaryGreen,
                                          size: 18,
                                        ),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          color: Colors.grey[600],
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() => _obscureText = !_obscureText);
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      filled: true,
                                      fillColor: softWhite,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Password tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() => _rememberMe = value ?? false);
                                          },
                                          activeColor: primaryGreen,
                                          checkColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          side: BorderSide(color: Colors.grey[400]!),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Ingat saya',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () {},
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Lupa password?',
                                          style: TextStyle(
                                            color: darkGreen,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _isLoading
                                      ? const SizedBox(
                                          height: 44,
                                          child: Center(child: CircularProgressIndicator(color: primaryGreen)),
                                        )
                                      : Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [darkGreen, darkerGreen],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: darkGreen.withOpacity(0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _login,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Text(
                                                  'Masuk',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: primaryGreen,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.arrow_forward,
                                                    color: Colors.white,
                                                    size: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey[300], thickness: 0.8)),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(
                                          'atau',
                                          style: TextStyle(color: Colors.grey, fontSize: 11),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.grey[300], thickness: 0.8)),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: primaryGreen.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: primaryGreen.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 14,
                                          color: darkGreen,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Hubungi admin untuk bantuan',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: darkerGreen.withOpacity(0.7),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Text(
                            '© 2026 STA • v1.0.0',
                            style: TextStyle(
                              fontSize: 10,
                              color: darkerGreen.withOpacity(0.5),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}