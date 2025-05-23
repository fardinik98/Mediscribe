import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database.dart';
import 'addmanual.dart';
import 'activemeds.dart';
import 'inactivemeds.dart';
import 'history.dart';
import 'settings.dart';
import 'alternate.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final String todayDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
  List<Map<String, dynamic>> medications = [];
  String nextReminder = 'Next Reminder will appear here...';

  @override
  void initState() {
    super.initState();
    _loadMedications();
    _loadNextReminder();
  }

  Future<void> _loadMedications() async {
    final data = await DatabaseHelper().getMedications();
    setState(() {
      medications = data.where((med) => med['is_active'] == 1).toList();
    });
  }

  Future<void> _loadNextReminder() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> meds = await db.query(
      'medications',
      where: 'is_active = 1',
    );

    final now = DateTime.now();
    final List<Map<String, dynamic>> upcoming = [];

    // Step 1: Get notifyBefore in minutes
    final notifyStr = await DatabaseHelper().getNotifyBefore();
    final notifyBeforeMinutes =
        int.tryParse((notifyStr ?? '15').split(' ')[0]) ?? 15;

    for (var med in meds) {
      final frequency = med['frequency'];
      final timings = med['timings'];
      final interval = med['hourly_interval'];
      final firstDoseStr = med['first_dose'];

      if (frequency == 'Hourly' && interval != null && firstDoseStr != null) {
        final startTime = TimeOfDay(
          hour: int.parse(firstDoseStr.split(":")[0]),
          minute: int.parse(firstDoseStr.split(":")[1]),
        );
        final intervalHours =
            int.tryParse(RegExp(r'\d+').firstMatch(interval)?.group(0) ?? '');

        if (intervalHours != null) {
          DateTime doseTime = DateTime(
              now.year, now.month, now.day, startTime.hour, startTime.minute);
          while (doseTime.isBefore(now)) {
            doseTime = doseTime.add(Duration(hours: intervalHours));
          }
          upcoming.add({
            'time': doseTime,
            'title': med['name'],
          });
        }
      } else if (timings != null) {
        for (var timing in timings.split(',')) {
          timing = timing.trim();
          TimeOfDay? timingTime = await _getTimingFromDatabase(timing);

          if (timingTime != null) {
            DateTime scheduledTime = DateTime(
              now.year,
              now.month,
              now.day,
              timingTime.hour,
              timingTime.minute,
            );

            // Step 2: Adjust for notifyBefore
            if (timing.startsWith('Before')) {
              scheduledTime = scheduledTime
                  .subtract(Duration(minutes: notifyBeforeMinutes));
            } else if (timing.startsWith('After')) {
              scheduledTime =
                  scheduledTime.add(Duration(minutes: notifyBeforeMinutes));
            }

            if (scheduledTime.isAfter(now)) {
              upcoming.add({
                'time': scheduledTime,
                'title': med['name'],
              });
            }
          }
        }
      }
    }

    if (upcoming.isNotEmpty) {
      upcoming.sort((a, b) => (a['time'] as DateTime)
          .compareTo(b['time'] as DateTime)); // sort by time
      final next = upcoming.first;
      final formattedTime = DateFormat.jm().format(next['time']);
      setState(() {
        nextReminder = '${next['title']} at $formattedTime';
      });
    }
  }

  Future<TimeOfDay?> _getTimingFromDatabase(String timing) async {
    final timingMap = {
      'Before Breakfast': 'Before Breakfast',
      'After Breakfast': 'After Breakfast',
      'Before Lunch': 'Before Lunch',
      'After Lunch': 'After Lunch',
      'Before Dinner': 'Before Dinner',
      'After Dinner': 'After Dinner',
    };

    if (timingMap.containsKey(timing)) {
      final timingData = await DatabaseHelper().getMealTime(timingMap[timing]!);
      if (timingData != null) {
        return TimeOfDay(
            hour: timingData['hour']!, minute: timingData['minute']!);
      }
    }
    return null;
  }

  String _formatDuration(int days) {
    if (days == 1) return "1 day left";
    return "$days days left";
  }

  String _buildSubtitle(
      String frequency, String? timings, String? hourlyInterval, int duration) {
    String base = '';
    if (frequency == 'Hourly') {
      base = 'Hourly (${hourlyInterval ?? 'unknown interval'})';
    } else if (frequency == 'Once' ||
        frequency == 'Twice' ||
        frequency == 'Thrice') {
      if (timings != null && timings.isNotEmpty) {
        base = '$frequency daily (${timings.replaceAll(",", ", ")})';
      } else {
        base = '$frequency daily';
      }
    } else {
      base = '$frequency';
    }

    return '$base - ${_formatDuration(duration)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          }
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SettingsPage()),
            );
          }
          if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HistoryPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Top Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mediscribe',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  Text(
                    todayDate,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              /// Upcoming Reminder
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        nextReminder,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// Quick Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AddManualPage()),
                        ).then((_) => _loadMedications());
                      },
                      icon: Icon(Icons.add),
                      label: Text('Add Manually'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {},
                      icon: Icon(Icons.camera_alt),
                      label: Text('Take Picture'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// Active Medications
              Text(
                'Active Medications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: medications.isEmpty
                    ? Center(child: Text('No active medications yet.'))
                    : ListView(
                        children: [
                          ...medications.take(2).map((med) {
                            final name = med['name'];
                            return ListTile(
                              title: Text(name),
                              subtitle: Text(
                                _buildSubtitle(
                                  med['frequency'],
                                  med['timings'],
                                  med['hourly_interval'],
                                  med['duration'],
                                ),
                              ),
                            );
                          }).toList(),
                          if (medications.isNotEmpty)
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => ActiveMedsPage()),
                                  );
                                },
                                child: Text('View All',
                                    style: TextStyle(color: Colors.green)),
                              ),
                            ),
                        ],
                      ),
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AlternatePage()),
                    );
                  },
                  icon: Icon(Icons.compare_arrows, color: Colors.green),
                  label: Text(
                    'Find Alternatives',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ),

              /// View Inactive
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => InactiveMedsPage()),
                    );
                  },
                  icon: Icon(Icons.folder_open, color: Colors.green),
                  label: Text(
                    'View Inactive Medications',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
