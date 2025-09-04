import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';

class AbsentSummaryScreen extends StatefulWidget {
  final int timetableId;
  final String subject;

  const AbsentSummaryScreen({
    Key? key,
    required this.timetableId,
    required this.subject,
  }) : super(key: key);

  @override
  State<AbsentSummaryScreen> createState() => _AbsentSummaryScreenState();
}

class _AbsentSummaryScreenState extends State<AbsentSummaryScreen> {
  List<Map<String, dynamic>> absentStudents = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchAbsentStudents();
  }

  Future<void> fetchAbsentStudents() async {
    final url = Uri.parse(
        'https://apps.jeevanlarosh.me/sxc/get_absentees.php?timetable_id=${widget.timetableId}');
    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.statusCode}");
      }

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        setState(() {
          absentStudents =
          List<Map<String, dynamic>>.from(data['students']);
          isLoading = false;
        });
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch data');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void goToHomePage() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Absent Summary - ${widget.subject}"),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: absentStudents.isEmpty
                ? const Center(
              child: Text(
                "No students are absent!",
                style: TextStyle(fontSize: 18),
              ),
            )
                : ListView.builder(
              itemCount: absentStudents.length,
              itemBuilder: (context, index) {
                final student = absentStudents[index];
                return ListTile(
                  leading: const Icon(
                    Icons.person_off,
                    color: Colors.red,
                  ),
                  title: Text(
                    "Roll No: ${student['rollno']}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Year: ${student['year']}",
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          if (errorMessage != null)
            Container(
              color: Colors.red[100],
              padding: const EdgeInsets.all(10),
              child: Text(
                "Error: $errorMessage",
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: goToHomePage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Go to Home Page",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
