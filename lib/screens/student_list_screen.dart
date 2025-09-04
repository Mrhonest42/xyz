import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'confirm_attendance_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  List<Map<String, dynamic>> students = [];
  bool isLoading = true;
  String subject = '';
  int timetableId = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> &&
        args.containsKey('timetable_id') &&
        args.containsKey('subject')) {
      timetableId = int.tryParse(args['timetable_id'].toString()) ?? 0;
      subject = args['subject'].toString();
      fetchStudentsByTimetableId(timetableId);
    } else {
      showError("Missing timetable or subject data.");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchStudentsByTimetableId(int id) async {
    try {
      final uri = Uri.parse(
        'http://localhost/attendance/get_students_by_timetable.php?timetable_id=$id',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body.trim());

        if (jsonResponse['status'] == 'success') {
          final List<dynamic> data = jsonResponse['data'];
          setState(() {
            students = data.map<Map<String, dynamic>>((s) => {
              'roll_number': s['roll_number'],
              'status': s['status'],
            }).toList();
            isLoading = false;
          });
        } else if (jsonResponse['status'] == 'closed') {
          showError(jsonResponse['message'] ?? 'Attendance window closed.');
          if (mounted) Navigator.pop(context);
        } else {
          showError(jsonResponse['message'] ?? 'Failed to load students.');
          setState(() => isLoading = false);
        }
      } else {
        showError('Server error: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      showError('Error loading students: $e');
      setState(() => isLoading = false);
    }
  }

  void setStatus(int index, String status) {
    setState(() {
      students[index]['status'] = status;
    });
  }

  void goToConfirmation() {
    if (students.isEmpty) {
      showError("No students available.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmAttendanceScreen(
          students: students,
          subject: subject,
          timetableId: timetableId,
        ),
      ),
    );
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget buildStudentItem(int index) {
    final student = students[index];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        title: Text(student['roll_number'] ?? 'No Roll Number'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                student['status'] == 'P' ? Colors.green : Colors.grey,
              ),
              onPressed: () => setStatus(index, 'P'),
              child: const Text("P"),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                student['status'] == 'A' ? Colors.red : Colors.grey,
              ),
              onPressed: () => setStatus(index, 'A'),
              child: const Text("A"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Attendance - $subject"),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: students.isEmpty
                ? const Center(
              child: Text("No students found."),
            )
                : ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) =>
                  buildStudentItem(index),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: goToConfirmation,
              icon: const Icon(Icons.check),
              label: const Text("Review & Submit"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
