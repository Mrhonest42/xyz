import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'home_screen.dart';

class ConfirmAttendanceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final String subject;
  final int timetableId;

  const ConfirmAttendanceScreen({
    Key? key,
    required this.students,
    required this.subject,
    required this.timetableId,
  }) : super(key: key);

  @override
  State<ConfirmAttendanceScreen> createState() => _ConfirmAttendanceScreenState();
}

class _ConfirmAttendanceScreenState extends State<ConfirmAttendanceScreen> {
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (var student in widget.students) {
      student['status'] ??= 'P';
      student['wasAbsent'] = student['status'] == 'A';
    }
  }

  void toggleStatus(String rollNumber) {
    setState(() {
      for (var student in widget.students) {
        if (student['roll_number'].toString() == rollNumber) {
          student['status'] = (student['status'] == 'A') ? 'P' : 'A';
        }
      }
    });
  }

  Future<void> submitFinalAttendance() async {
    setState(() => isSubmitting = true);

    try {
      final url = Uri.parse('https://apps.jeevanlarosh.me/sxc/submit_attendance.php');

      final payload = {
        'hour_id': widget.timetableId,
        'attendance': widget.students.map((student) => {
          'rollno': student['roll_number'] ?? '',
          'status': student['status'] ?? 'P',
        }).toList(),
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          if (!mounted) return;

          // Show success dialog
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Success"),
              content: const Text("Attendance submitted successfully!"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (route) => false,
                    );
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        } else {
          throw Exception(result['message'] ?? 'Unknown server error');
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error"),
          content: Text("Submission failed: $e"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> visibleStudents = widget.students
        .where((s) => s['wasAbsent'] == true || s['status'] == 'A')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Confirm Absent - ${widget.subject}"),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Expanded(
            child: visibleStudents.isEmpty
                ? const Center(
              child: Text(
                "No absent students to confirm.",
                style: TextStyle(fontSize: 18),
              ),
            )
                : ListView.builder(
              itemCount: visibleStudents.length,
              itemBuilder: (context, index) {
                final student = visibleStudents[index];
                final rollNo = student['roll_number'] ?? 'Unknown';
                final status = student['status'] ?? 'P';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Icon(
                      status == 'A' ? Icons.person_off : Icons.person,
                      color: status == 'A' ? Colors.red : Colors.green,
                    ),
                    title: Text(rollNo,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Tap buttons to toggle status'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => toggleStatus(rollNo),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            status == 'P' ? Colors.green : Colors.grey,
                          ),
                          child: const Text('P'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => toggleStatus(rollNo),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            status == 'A' ? Colors.red : Colors.grey,
                          ),
                          child: const Text('A'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : submitFinalAttendance,
              icon: const Icon(Icons.send),
              label: Text(isSubmitting ? "Submitting..." : "Final Submit"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
