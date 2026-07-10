import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'student_dashboard_screen.dart';
import 'parent_dashboard_screen.dart';
import 'teacher/teacher_dashboard_screen.dart';
import 'admin/admin_dashboard_screen.dart';
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

  // ✅ Color Palette - Hijau Profesional
  static const Color primaryGreen = Color(0xFF7BC8A4);
  static const Color lightGreen = Color(0xFFB8F0D8);
  static const Color darkGreen = Color(0xFF2D5A4A);        // ✅ Hijau Tua Profesional
  static const Color darkerGreen = Color(0xFF1A3D32);      // ✅ Hijau Sangat Gelap
  static const Color accentGreen = Color(0xFF4A9E7A);
  static const Color softWhite = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();
    _loadSavedCredentials();
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

        final user = result['data']['user'];
        final userRole = (user['role'] ?? user['role_name'] ?? '').toString().toLowerCase();
        
        final roleId = user['role_id'];
        final roleIdInt = roleId is int ? roleId : int.tryParse(roleId.toString()) ?? 0;
        
        debugPrint('👤 Login berhasil: ${user['username']}');
        debugPrint('🔑 Role: $userRole (ID: $roleIdInt)');
        debugPrint('🏫 Sekolah ID: ${user['sekolah_id']}');
        
        Widget targetScreen;
        
        switch (userRole) {
          case 'siswa':
            debugPrint('➡️ Navigate ke StudentDashboardScreen');
            targetScreen = const StudentDashboardScreen();
            break;
          case 'orang_tua':
            debugPrint('➡️ Navigate ke ParentDashboardScreen');
            targetScreen = const ParentDashboardScreen();
            break;
          case 'guru':
            debugPrint('➡️ Navigate ke TeacherDashboardScreen');
            targetScreen = const TeacherDashboardScreen();
            break;
          case 'admin':
          case 'administrator':
            debugPrint('➡️ Navigate ke AdminDashboardScreen');
            targetScreen = const AdminDashboardScreen();
            break;
          default:
            debugPrint('⚠️ Role tidak dikenali: $userRole, redirect ke HomeScreen');
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              // Decorative Circles
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
              Positioned(
                bottom: 50,
                left: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
              Positioned(
                top: 250,
                right: -50,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: darkerGreen.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                top: 100,
                left: -60,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryGreen.withOpacity(0.3),
                  ),
                ),
              ),
              
              // Decorative Leaf Pattern
              Positioned(
                top: 0,
                left: 0,
                child: Opacity(
                  opacity: 0.15,
                  child: Icon(
                    Icons.eco,
                    size: 120,
                    color: darkerGreen,
                  ),
                ),
              ),
              
              // Main Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo & Branding
                          Consumer<SchoolProvider>(
                            builder: (context, schoolProvider, child) {
                              return Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: primaryGreen, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: darkerGreen.withOpacity(0.15),
                                      blurRadius: 20,
                                      spreadRadius: 3,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: primaryGreen.withOpacity(0.3),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: schoolProvider.logoUrl.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          schoolProvider.logoUrl,
                                          width: 75,
                                          height: 75,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const SizedBox(
                                              width: 75,
                                              height: 75,
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  color: primaryGreen,
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.school_rounded,
                                              size: 75,
                                              color: primaryGreen,
                                            );
                                          },
                                        ),
                                      )
                                    : const Icon(
                                        Icons.school_rounded,
                                        size: 75,
                                        color: primaryGreen,
                                      ),
                              );
                            },
                          ),
                          const SizedBox(height: 25),
                          
                          // School Name
                          Consumer<SchoolProvider>(
                            builder: (context, schoolProvider, child) {
                              return Column(
                                children: [
                                  Text(
                                    schoolProvider.namaSekolah,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: darkerGreen,  // ✅ Hijau Tua
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: darkGreen,  // ✅ Hijau Tua
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Sistem Informasi Sekolah',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 40),
                          
                          // Login Card
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: primaryGreen.withOpacity(0.3), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: darkerGreen.withOpacity(0.1),
                                  blurRadius: 25,
                                  spreadRadius: 3,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: primaryGreen.withOpacity(0.15),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Header Card
                                  Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: primaryGreen,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Selamat Datang',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: darkerGreen,  // ✅ Hijau Tua
                                            ),
                                          ),
                                          Text(
                                            'Silakan login untuk melanjutkan',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 28),
                                  
                                  // Username Field
                                  TextFormField(
                                    controller: _usernameController,
                                    decoration: InputDecoration(
                                      labelText: 'Username',
                                      labelStyle: TextStyle(color: Colors.grey[600]),
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.all(8),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryGreen.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.person_outline,
                                          color: primaryGreen,
                                          size: 20,
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: primaryGreen, width: 2),
                                      ),
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
                                  const SizedBox(height: 18),
                                  
                                  // Password Field
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscureText,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      labelStyle: TextStyle(color: Colors.grey[600]),
                                      prefixIcon: Container(
                                        margin: const EdgeInsets.all(8),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primaryGreen.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.lock_outline,
                                          color: primaryGreen,
                                          size: 20,
                                        ),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          color: Colors.grey[600],
                                        ),
                                        onPressed: () {
                                          setState(() => _obscureText = !_obscureText);
                                        },
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: primaryGreen, width: 2),
                                      ),
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
                                  const SizedBox(height: 14),
                                  
                                  // Remember Me
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() => _rememberMe = value ?? false);
                                          },
                                          activeColor: primaryGreen,
                                          checkColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          side: BorderSide(color: Colors.grey[400]!),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Ingat saya',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () {},
                                        child: const Text(
                                          'Lupa password?',
                                          style: TextStyle(
                                            color: darkGreen,  // ✅ Hijau Tua
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  
                                  // Login Button - ✅ HIJAU TUA
                                  _isLoading
                                      ? const SizedBox(
                                          height: 54,
                                          child: Center(child: CircularProgressIndicator(color: primaryGreen)),
                                        )
                                      : Container(
                                          height: 54,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(  // ✅ Gradient Hijau
                                              colors: [darkGreen, darkerGreen],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: darkGreen.withOpacity(0.4),  // ✅ Hijau
                                                blurRadius: 15,
                                                offset: const Offset(0, 5),
                                              ),
                                              BoxShadow(
                                                color: primaryGreen.withOpacity(0.2),
                                                blurRadius: 20,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _login,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Text(
                                                  'Masuk',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: primaryGreen,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.arrow_forward,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                  const SizedBox(height: 20),
                                  
                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.grey[300])),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'atau',
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.grey[300])),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Footer
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: primaryGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: primaryGreen.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 16,
                                          color: darkGreen,  // ✅ Hijau Tua
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Hubungi admin untuk bantuan',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: darkerGreen.withOpacity(0.8),  // ✅ Hijau Gelap
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
                          
                          const SizedBox(height: 25),
                          
                          // Version Info
                          Text(
                            '© 2026 STA • v1.0.0',
                            style: TextStyle(
                              fontSize: 11,
                              color: darkerGreen.withOpacity(0.6),  // ✅ Hijau Gelap
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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