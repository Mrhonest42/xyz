import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _staffIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final fid = _staffIdController.text.trim();
    final pass = _passwordController.text.trim();

    final url = Uri.parse('https://admission.sjctni.edu/eattn_app/get_login.php');
    try {
      final response = await http.post(
        url,
        body: {
          'fid': fid,
          'pass': pass,
        },
      );

      print("📡 Response status: ${response.statusCode}");
      print("📡 Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 200) {
          print("✅ Login successful for Staff ID: ${data['data']['fid']}");

          // ✅ Save Staff ID in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('staffId', data['data']['fid']);

          if (!mounted) return;

          // ✅ Navigate to Home screen
          Navigator.pushReplacementNamed(
            context,
            '/home',
            arguments: {'staffId': data['data']['fid']},
          );
        } else {
          _showError("❌ ${data['message']}");
        }
      } else {
        _showError("⚠️ Server Error: ${response.statusCode}");
      }
    } catch (e) {
      _showError("🚨 Network Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _staffIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final darkRed = const Color(0xFF580000);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Card(
            elevation: 16,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo.png', height: 100),
                    const SizedBox(height: 16),
                    Text('SJC e-attendance', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: darkRed)),
                    const SizedBox(height: 16),
                    Text('Login with your Staff ID', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700])),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _staffIdController,
                      decoration: InputDecoration(
                        labelText: 'Staff ID',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Enter your Staff ID' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Enter your password' : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : const Text('Login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
