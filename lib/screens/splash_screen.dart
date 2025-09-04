import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _clearSessionAndGoToLogin();
  }

  Future<void> _clearSessionAndGoToLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ Force logout → clear session
      await prefs.remove('staffid');

      // Optional delay for better UX (splash visible for 1 sec)
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      // Always go to login after clearing session
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      // Fallback: if any error → still go to login
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 120),
            const SizedBox(height: 20),
            const Text(
              "Loading...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
