import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './SubstituteScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> timetable = [];
  List<String> handledPapers = [];
  Map<int, bool> attendanceStatusMap = {};
  bool isLoading = true;
  bool isHoliday = false;
  String holidayMessage = '';
  String staffid = '';
  String dayOrder = '';
  String staffname = '';
  int hourno = 0;
  Map<String, dynamic> userProfile = {};

  static const Color primaryColor = Color(0xFF580000);

  @override
  void initState() {
    super.initState();
    _loadStaffIdAndFetch();
  }

  Future<void> _loadStaffIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final storedStaffId = prefs.getString('staffId');

    if (storedStaffId != null && storedStaffId.isNotEmpty) {
      staffid = "21FCS01";
      await fetchTimetable(staffid);
      await fetchHandledPapers(staffid);
    } else {
      _showPopup("Session Expired", "Staff ID not found. Please login again.", Colors.red);
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> fetchTimetable(String staffid) async {
    setState(() {
      isLoading = true;
      isHoliday = false;
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost/attendance/get_timetable.php?staffid=21FMA01&date=2025-09-04&time=02:46:00'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded['status'] == 'holiday') {
          setState(() {
            isHoliday = true;
            holidayMessage = decoded['message'] ?? "Today is a Holiday";
            timetable = [];
            dayOrder = '';
          });
          return;
        }

        if (decoded['status'] == 'success') {
          final fetchedTimetable = decoded['data'] ?? [];

          for (var item in fetchedTimetable) {
            final id = int.tryParse(item['id'].toString()) ?? 0;
            if (id > 0) {
              final isSubmitted = await checkIfAttendanceSubmitted(id);
              attendanceStatusMap[id] = isSubmitted;
            }
          }

          setState(() {
            timetable = fetchedTimetable;
            dayOrder = decoded['day_order'] ?? '';
            userProfile = decoded['user'] ?? {};
            staffname = decoded['staffname'] ?? '';
            hourno = decoded['hour'] ?? '';
          });
        } else {
          _showPopup("Error", decoded['message'] ?? 'Error loading data', Colors.red);
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

  Future<void> fetchHandledPapers(String staffid) async {
    try {
      final response = await http.get(
        Uri.parse('https://admission.sjctni.edu/eattn_app/get_handled_papers.php?staffid=$staffid'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == 'success') {
          final papersList = decoded['papers'] as List<dynamic>;
          setState(() {
            handledPapers = papersList.map((p) => p['papername'].toString()).toList();
          });
        } else {
          _showPopup("Error", decoded['message'] ?? 'Error loading handled papers', Colors.red);
        }
      }
    } catch (e) {
      _showPopup("Connection Error", 'Failed to fetch handled papers: $e', Colors.red);
    }
  }

  Future<bool> checkIfAttendanceSubmitted(int timetableId) async {
    try {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 👇 Debug print
      print("🔍 Checking Attendance -> Timetable ID: $timetableId, Date: $date");

      final response = await http.get(
        Uri.parse(
          'https://admission.sjctni.edu/eattn_app/check_attendance.php?timetable_id=$timetableId&date=$date',
        ),
      );

      // 👇 Print server response too
      print("📡 API Response (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['submitted'] == true;
      }
    } catch (e) {
      print("❌ Error in checkIfAttendanceSubmitted: $e");
    }
    return false;
  }

  void handlePaperTap(Map<String, dynamic> item) {
    final timetableId = int.tryParse(item['id'].toString()) ?? 0;
    print("Time table id $timetableId");
    final paperName = item['papername'] ?? 'Subject';
    final isSubmitted = attendanceStatusMap[timetableId] ?? false;

    final now = DateTime.now();
    final startStr = item['start_time'] ?? '00:00:00';
    DateTime openTime;

    try {
      final startTime = DateFormat("HH:mm:ss").parse(startStr);
      openTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
    } catch (_) {
      _showPopup("Time Error", "Invalid class start time.", Colors.red);
      return;
    }

    final closeTime = openTime.add(const Duration(minutes: 200));

    if (isSubmitted) {
      _showPopup("Already Submitted", "Attendance already submitted for this paper.", Colors.green);
    } else if (now.isBefore(openTime)) {
      _showPopup("Not Yet Open", "Attendance opens at ${DateFormat('hh:mm a').format(openTime)}", Colors.orange);
    } else if (now.isAfter(closeTime)) {
      _showPopup("Closed", "Attendance window closed.", Colors.grey);
    } else {
      Navigator.pushNamed(context, '/student-list', arguments: {
        'timetable_id': timetableId,
        'subject': paperName,
      });
    }
  }

  void _showPopup(String title, String message, Color color) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: color.withOpacity(0.9),
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('staffId');
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  String getFormattedDate() {
    return DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Current Attendance", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF8E0E00), Color(0xFF1F1C18)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundImage: userProfile['photo_name'] != null
                    ? NetworkImage('https://apps.jeevanlarosh.me/sxc/uploads/${userProfile['photo_name']}')
                    : const AssetImage('default_avatar.jpg') as ImageProvider,
              ),
              accountName: Text(userProfile['name'] ?? staffid, style: const TextStyle(fontSize: 18)),
              accountEmail: Text(userProfile['role'] ?? 'Role'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text("Substitute"),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SubstituteScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () async {
          await fetchTimetable(staffid);
          await fetchHandledPapers(staffid);
        },
        child: ListView(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Image.asset('assets/logo1.png', height: 100),
            ),
            const SizedBox(height: 10),
            Center(
              child: Column(
                children: [
                Text(
                  staffname.isNotEmpty ? staffname : 'Staff Name',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Hour: ${hourno > 0 ? hourno : 'N/A'}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(getFormattedDate(), style: const TextStyle(fontSize: 16)),
                  if (dayOrder.isNotEmpty && !isHoliday)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text("Day Order: $dayOrder",
                          style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const Divider(),
            if (isHoliday)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.beach_access, color: Colors.orange[700], size: 60),
                    const SizedBox(height: 10),
                    Text(holidayMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              Builder(
                builder: (_) {
                  final now = DateTime.now();
                  final filteredTimetable = timetable.where((item) {
                    try {
                      final startStr = item['start_time'] ?? '00:00:00';
                      final t = DateFormat("HH:mm:ss").parse(startStr);
                      final openTime = DateTime(now.year, now.month, now.day, t.hour, t.minute);
                      final closeTime = openTime.add(const Duration(minutes: 200));
                      return now.isAfter(openTime) && now.isBefore(closeTime);
                    } catch (_) {
                      return false;
                    }
                  }).toList();

                  if (filteredTimetable.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("No classes currently open for attendance.",
                          style: TextStyle(fontSize: 16, color: Colors.black54)),
                    );
                  }

                  return Column(
                    children: filteredTimetable.map((item) {
                      final id = int.tryParse(item['id'].toString()) ?? 0;
                      final submitted = attendanceStatusMap[id] ?? false;

                      final startStr = item['start_time'] ?? '00:00:00';
                      final t = DateFormat("HH:mm:ss").parse(startStr);
                      final openTime = DateTime(now.year, now.month, now.day, t.hour, t.minute);
                      final closeTime = openTime.add(const Duration(minutes: 200));
                      final withinWindow = now.isAfter(openTime) && now.isBefore(closeTime);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Hour: ${item['hour'] ?? 'N/A'}",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text("Paper Name: ${item['papername'] ?? 'N/A'}",
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("Paper Code: ${item['papercode']}",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: submitted ? null : () => handlePaperTap(item),
                                icon: Icon(
                                  submitted ? Icons.done : Icons.check_circle_outline,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  submitted ? "Already Submitted" : "Take Attendance",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: submitted
                                      ? Colors.blueGrey
                                      : withinWindow
                                      ? Colors.green
                                      : Colors.orange,
                                  minimumSize: const Size.fromHeight(45),
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
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}