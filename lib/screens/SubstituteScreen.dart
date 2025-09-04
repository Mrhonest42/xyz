import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './student_list_screen.dart';

class SubstituteScreen extends StatefulWidget {
  const SubstituteScreen({super.key});

  @override
  State<SubstituteScreen> createState() => _SubstituteScreenState();
}

class _SubstituteScreenState extends State<SubstituteScreen> {
  List<dynamic> subjects = [];
  bool isLoading = true;
  String staffid = '';
  static const Color primaryColor = Color(0xFF580000);

  @override
  void initState() {
    super.initState();
    _loadStaffIdAndFetchSubjects();
  }

  Future<void> _loadStaffIdAndFetchSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final storedStaffId = prefs.getString('staffid');

    if (storedStaffId != null && storedStaffId.isNotEmpty) {
      staffid = storedStaffId;
      await fetchSubjects(staffid);
    } else {
      _showPopup("Session Expired", "Staff ID not found. Please login again.", Colors.red);
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> fetchSubjects(String staffid) async {
    setState(() => isLoading = true);
    try {
      final url = 'https://apps.jeevanlarosh.me/sxc/get_subjects_by_staff.php?staffid=$staffid';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['status'] == 'success' && decoded['data'] is List) {
          setState(() => subjects = decoded['data']);
        } else {
          _showPopup("Access Denied", decoded['message'] ?? "Unexpected error.", Colors.red);
        }
      } else {
        _showPopup("Server Error", 'Status code: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      _showPopup("Connection Error", 'Failed to connect: $e', Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<bool> checkIfAttendanceSubmitted(int timetableId) async {
    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await http.get(
        Uri.parse('https://apps.jeevanlarosh.me/sxc/check_attendance.php?timetable_id=$timetableId&date=$date'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['submitted'] == true;
      }
    } catch (_) {}
    return false;
  }

  void handlePaperTap(Map<String, dynamic> subjectData) async {
    final timetableId = int.tryParse(subjectData['timetable_id'].toString()) ?? 0;
    final paperName = subjectData['subject'] ?? 'Subject';
    final startStr = subjectData['start_time'] ?? '';

    if (startStr.isEmpty) {
      _showPopup("Missing Time", "Start time is not available for this class.", Colors.red);
      return;
    }

    final now = DateTime.now();
    final isSubmitted = await checkIfAttendanceSubmitted(timetableId);

    DateTime openTime;
    try {
      final parsedTime = DateFormat("HH:mm:ss").parseLoose(startStr);
      openTime = DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
    } catch (_) {
      _showPopup("Time Error", "Invalid start time format.", Colors.red);
      return;
    }

    final closeTime = openTime.add(const Duration(minutes: 15));

    if (isSubmitted) {
      _showPopup("Already Submitted", "Attendance already submitted for this subject.", Colors.green);
    } else if (now.isBefore(openTime)) {
      _showPopup("Too Early", "Attendance opens at ${DateFormat('hh:mm a').format(openTime)}", Colors.orange);
    } else if (now.isAfter(closeTime)) {
      _showPopup("Too Late", "Attendance window closed at ${DateFormat('hh:mm a').format(closeTime)}.", Colors.grey);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const StudentListScreen(),
          settings: RouteSettings(
            arguments: {
              'timetable_id': timetableId,
              'subject': paperName,
            },
          ),
        ),
      );
    }
  }

  void _showPopup(String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: color.withOpacity(0.95),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  String getFormattedDate() {
    return DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text(
          "Substitute Subjects",
          style: TextStyle(color: Colors.white), // ✅ Title text color set to white
        ),
        iconTheme: const IconThemeData(color: Colors.white), // ✅ Icon color (e.g., back arrow)
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () => fetchSubjects(staffid),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Text(
                getFormattedDate(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(),
            if (subjects.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No subjects found for today.",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ),
              )
            else
              ...subjects.map((subjectData) {
                final paperName = subjectData['subject'] ?? 'Unknown Subject';
                final time = subjectData['start_time'] ?? '';
                final paperCode = subjectData['papercode'] ?? 'N/A';
                final hour = subjectData['hour'] ?? 'N/A';

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Subject: $paperName",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text("Paper Code: $paperCode", style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text("Hour: $hour", style: const TextStyle(fontSize: 14)),
                        if (time.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              "Start Time: $time",
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => handlePaperTap(subjectData),
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          label: const Text("Select Substitute"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            minimumSize: const Size.fromHeight(40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
