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
  List<Map<String, dynamic>> timetable = [];
  List<String> handledPapers = [];
  bool isLoading = true;
  bool isHoliday = false;
  String holidayMessage = '';
  String staffid = '';
  String dayOrder = '';
  Map<String, dynamic> userProfile = {};

  static const Color primaryColor = Color(0xFF580000);

  @override
  void initState() {
    super.initState();
    _loadStaffIdAndFetch();
  }

  Future<void> _loadStaffIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final storedStaffId = prefs.getString('staffid');

    if (storedStaffId != null && storedStaffId.isNotEmpty) {
      staffid = storedStaffId;
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
        Uri.parse(
            'https://admission.sjctni.edu/eattn_app/get_timetable.php?staffid=$staffid&date=2025-09-04&time=09:20:00'),
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
          // Convert single object into a list
          final Map<String, dynamic> timetableItem = {
            "hour": decoded['hour'],
            "papername": decoded['papername'],
            "papercode": decoded['papercode'],
            "roll": decoded['roll'],
          };

          setState(() {
            timetable = [timetableItem];
            dayOrder = decoded['day_order'] ?? '';
            // only assign user profile if API sends it
            if (decoded.containsKey('user')) {
              userProfile = decoded['user'] ?? {};
            }
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

  void handlePaperTap(Map<String, dynamic> item) {
    final paperName = item['papername'] ?? 'Subject';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.green.shade700,
        title: const Text("Success", style: TextStyle(color: Colors.white)),
        content: Text("You have opened attendance for $paperName",
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/student-list',
                arguments: {
                  'subject': paperName,
                  'papercode': item['papercode'] ?? '',
                  'roll': item['roll'] ?? '',
                },
              );
            },
            child: const Text("Continue", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
    await prefs.remove('staffid');
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
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
              accountName: Text(userProfile['name'] ?? staffid,
                  style: const TextStyle(fontSize: 18)),
              accountEmail: Text(userProfile['role'] ?? 'Role'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text("Substitute"),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SubstituteScreen()));
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
                  Text(userProfile['name'] ?? 'Staff Name',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(getFormattedDate(),
                      style: const TextStyle(fontSize: 16)),
                  if (dayOrder.isNotEmpty && !isHoliday)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text("Day Order: $dayOrder",
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold)),
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
                    Icon(Icons.beach_access,
                        color: Colors.orange[700], size: 60),
                    const SizedBox(height: 10),
                    Text(holidayMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18,
                            color: Colors.red,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else if (timetable.isNotEmpty)
              ...timetable.map((item) {
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text("Paper Code: ${item['papercode'] ?? 'N/A'}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => handlePaperTap(item),
                          icon: const Icon(Icons.check_circle_outline,
                              color: Colors.white),
                          label: const Text(
                            "Take Attendance",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
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
              }).toList()
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("No classes scheduled for today.",
                    style:
                    TextStyle(fontSize: 16, color: Colors.black54)),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
