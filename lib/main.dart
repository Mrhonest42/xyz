import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/student_list_screen.dart';
import 'screens/confirm_attendance_screen.dart'; // <-- Import this

void main() {
  runApp(const SchoolApp());
}

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  static const Color _primaryColor = Color(0xFF580000);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SJCE Attendance App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: Colors.grey[100],
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/student-list': (context) => const StudentListScreen(),
      },
      // ➕ Add this to support ConfirmAttendanceScreen with arguments
      onGenerateRoute: (settings) {
        if (settings.name == '/confirm-attendance') {
          final args = settings.arguments as Map<String, dynamic>;

          return MaterialPageRoute(
            builder: (_) => ConfirmAttendanceScreen(
              timetableId: args['timetableId'],
              subject: args['subject'],
              students: args['students'],
            ),
          );
        }
        return null; // fallback for undefined routes
      },
    );
  }
}
