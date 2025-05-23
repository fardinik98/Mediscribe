import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'homepage.dart';
import 'notification.dart';
import 'history.dart';
import 'database.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _selectedIndex = 1;
  final String todayDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
  TimeOfDay? breakfastTime;
  TimeOfDay? lunchTime;
  TimeOfDay? dinnerTime;
  bool notificationsEnabled = true;
  String notifyBefore = '15 minutes';
  final List<String> notifyOptions = ['5 minutes', '10 minutes', '15 minutes'];

  final bool _showTestButton = false;

  @override
  void initState() {
    super.initState();
    NotificationService.initializeNotifications();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final breakfast = await DatabaseHelper().getMealTime('Before Breakfast');
    final lunch = await DatabaseHelper().getMealTime('Before Lunch');
    final dinner = await DatabaseHelper().getMealTime('Before Dinner');

    setState(() {
      breakfastTime = breakfast != null
          ? TimeOfDay(hour: breakfast['hour']!, minute: breakfast['minute']!)
          : TimeOfDay(hour: 7, minute: 45);
      lunchTime = lunch != null
          ? TimeOfDay(hour: lunch['hour']!, minute: lunch['minute']!)
          : TimeOfDay(hour: 11, minute: 45);
      dinnerTime = dinner != null
          ? TimeOfDay(hour: dinner['hour']!, minute: dinner['minute']!)
          : TimeOfDay(hour: 18, minute: 45);
    });

    // Load notifyBefore
    final notifySetting = await DatabaseHelper().getNotifyBefore();
    setState(() {
      notifyBefore = notifySetting ?? '15 minutes';
    });

    // await NotificationService.scheduleMealBasedReminders();
  }

  Future<void> _saveTimeToDatabase(String meal, TimeOfDay time) async {
    final mealType =
        meal.split(' ').last; // Extract 'Breakfast', 'Lunch', or 'Dinner'

    await DatabaseHelper()
        .updateMealTime('Before $mealType', time.hour, time.minute);
    await DatabaseHelper()
        .updateMealTime('After $mealType', time.hour, time.minute);

    // Cancel all old meal-based alarms
    await NotificationService.cancelMealBasedReminders();

    // Reschedule only remaining days for all active meds
    final db = await DatabaseHelper().database;
    final now = DateTime.now();
    final meds = await db.query('medications', where: 'is_active = 1');

    for (final med in meds) {
      final startDateStr = med['start_date']?.toString();
      final duration = int.tryParse(med['duration'].toString()) ?? 0;

      if (startDateStr == null || duration == 0) continue;

      final startDate = DateTime.tryParse(startDateStr);
      if (startDate == null) continue;

      final daysPassed = now
          .difference(DateTime(startDate.year, startDate.month, startDate.day))
          .inDays;
      final remainingDays = duration - daysPassed;

      if (remainingDays > 0) {
        final updatedMed = Map<String, dynamic>.from(med);
        updatedMed['duration'] = remainingDays;
        await NotificationService.scheduleMedicationReminderFor(
            medData: updatedMed);
      }
    }
  }

  Future<void> _updateNotifyPreference(String value) async {
    await DatabaseHelper().updateNotifyBefore(value);
    setState(() => notifyBefore = value);
    await NotificationService.cancelMealBasedReminders();

    final db = await DatabaseHelper().database;
    final now = DateTime.now();
    final meds = await db.query('medications', where: 'is_active = 1');

    for (final med in meds) {
      final startDateStr = med['start_date']?.toString();
      final duration = int.tryParse(med['duration'].toString()) ?? 0;

      if (startDateStr == null || duration == 0) continue;

      final startDate = DateTime.tryParse(startDateStr);
      if (startDate == null) continue;

      final daysPassed = now
          .difference(DateTime(startDate.year, startDate.month, startDate.day))
          .inDays;
      final remainingDays = duration - daysPassed;

      if (remainingDays > 0) {
        final updatedMed = Map<String, dynamic>.from(med);
        updatedMed['duration'] = remainingDays;
        await NotificationService.scheduleMedicationReminderFor(
            medData: updatedMed);
      }
    }
  }

  // Future<void> _resetToDefault() async {
  //   await DatabaseHelper().updateMealTime('Before Breakfast', 8, 00);
  //   await DatabaseHelper().updateMealTime('After Breakfast', 8, 00);
  //   await DatabaseHelper().updateMealTime('Before Lunch', 13, 00);
  //   await DatabaseHelper().updateMealTime('After Lunch', 13, 00);
  //   await DatabaseHelper().updateMealTime('Before Dinner', 20, 00);
  //   await DatabaseHelper().updateMealTime('After Dinner', 20, 00);
  //   await DatabaseHelper().updateNotifyBefore('15 minutes');

  //   await NotificationService.cancelMealBasedReminders();

  //   final db = await DatabaseHelper().database;
  //   final now = DateTime.now();
  //   final meds = await db.query('medications', where: 'is_active = 1');

  //   for (final med in meds) {
  //     final startDateStr = med['start_date']?.toString();
  //     final duration = int.tryParse(med['duration'].toString()) ?? 0;
  //     if (startDateStr == null || duration == 0) continue;

  //     final startDate = DateTime.tryParse(startDateStr);
  //     if (startDate == null) continue;

  //     final daysPassed = now
  //         .difference(DateTime(startDate.year, startDate.month, startDate.day))
  //         .inDays;
  //     final remainingDays = duration - daysPassed;

  //     if (remainingDays > 0) {
  //       final updatedMed = Map<String, dynamic>.from(med);
  //       updatedMed['duration'] = remainingDays;
  //       await NotificationService.scheduleMedicationReminderFor(
  //           medData: updatedMed);
  //     }
  //   }

  //   await _loadSettings();
  // }

  Future<void> _pickTimeWithConfirm(
      String label, TimeOfDay? current, String mealKey) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.inputOnly,
    );

    if (picked != null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Confirm Change'),
          content: Text('Change $label time to ${picked.format(context)}?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true), child: Text('Yes')),
          ],
        ),
      );

      if (confirm == true) {
        setState(() {
          if (label == 'Breakfast') breakfastTime = picked;
          if (label == 'Lunch') lunchTime = picked;
          if (label == 'Dinner') dinnerTime = picked;
        });
        await _saveTimeToDatabase(mealKey, picked);
      }
    }
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mediscribe',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800])),
            Text(todayDate,
                style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0)
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (context) => HomePage()));
          if (index == 1)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => SettingsPage()));
          if (index == 2)
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => HistoryPage()));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          Text('Meal Timings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildTimeTile(
              'Breakfast',
              breakfastTime,
              () => _pickTimeWithConfirm(
                  'Breakfast', breakfastTime, 'Before Breakfast')),
          _buildTimeTile('Lunch', lunchTime,
              () => _pickTimeWithConfirm('Lunch', lunchTime, 'Before Lunch')),
          _buildTimeTile(
              'Dinner',
              dinnerTime,
              () =>
                  _pickTimeWithConfirm('Dinner', dinnerTime, 'Before Dinner')),
          // const SizedBox(height: 10),
          // ElevatedButton.icon(
          //   icon: Icon(Icons.refresh),
          //   label: Text('Reset to Default'),
          //   style: ElevatedButton.styleFrom(
          //       backgroundColor: Colors.green, foregroundColor: Colors.white),
          //   onPressed: _resetToDefault,
          // ),
          Divider(height: 30, thickness: 1),
          Text('Notification Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ListTile(
            title: Text('Notify Before Meals'),
            trailing: DropdownButton<String>(
              value: notifyBefore,
              items: notifyOptions
                  .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                  .toList(),
              onChanged: (val) {
                if (val != null) _updateNotifyPreference(val);
              },
            ),
          ),
          if (_showTestButton)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: ElevatedButton.icon(
                icon: Icon(Icons.notifications_active),
                label: Text('Send Test Notification'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white),
                onPressed: () async {
                  try {
                    final now = DateTime.now();
                    final scheduledTime = now.add(Duration(minutes: 1));
                    const platform = MethodChannel('alarm_channel');
                    await platform.invokeMethod('scheduleAlarm', {
                      'id': 101,
                      'title': 'Native Alarm Test',
                      'body': 'This fired even when the app was killed!',
                      'hour': scheduledTime.hour,
                      'minute': scheduledTime.minute,
                    });
                    if (context.mounted) {
                      final formattedTime = TimeOfDay(
                              hour: scheduledTime.hour,
                              minute: scheduledTime.minute)
                          .format(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text('🔔 Alarm scheduled for $formattedTime')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('❌ Failed to schedule alarm: $e')));
                    }
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeTile(String label, TimeOfDay? time, VoidCallback onTap) {
    return ListTile(
      title: Text(label),
      subtitle: Text(time != null ? _formatTime(time) : 'Not set'),
      trailing: Icon(Icons.edit, color: Colors.green),
      onTap: onTap,
    );
  }
}
