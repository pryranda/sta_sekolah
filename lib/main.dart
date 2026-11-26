import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'providers/school_provider.dart';
import 'providers/student_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/student_dashboard_screen.dart';
import 'screens/parent_dashboard_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_schedule_screen.dart';
import 'screens/admin/admin_holiday_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SchoolProvider()..loadSchoolData(),
        ),
        ChangeNotifierProvider(
          create: (_) => StudentProvider(),
        ),
      ],
      child: Consumer<SchoolProvider>(
        builder: (context, schoolProvider, child) {
          return MaterialApp(
            title: schoolProvider.namaSekolah,
            debugShowCheckedModeBanner: false,
            
            // ✅ Konfigurasi Locale Bahasa Indonesia
            locale: const Locale('id', 'ID'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('id', 'ID'),
              Locale('en', 'US'),
            ],
            
            // Theme
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF7BC8A4),
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF6F8FA),
              visualDensity: VisualDensity.adaptivePlatformDensity,
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 0,
                scrolledUnderElevation: 0.5,
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7BC8A4), width: 1.5),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            // Routes
            routes: {
              '/': (context) => const LoginScreen(),
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/student-dashboard': (context) => const StudentDashboardScreen(),
              '/parent-dashboard': (context) => const ParentDashboardScreen(),
              '/teacher-dashboard': (context) => const TeacherDashboardScreen(),
              '/admin-dashboard': (context) => const AdminDashboardScreen(),
              '/admin/schedule': (context) => const AdminScheduleScreen(),
              '/admin/holidays': (context) => const AdminHolidayScreen(),
            },
          );
        },
      ),
    );
  }
}