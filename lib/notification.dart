import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database.dart';

@pragma('vm:entry-point')
void scheduleFromAlarmManager() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initializeNotifications();
  await scheduleAllMedicationReminders();
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const MethodChannel _nativeAlarmChannel =
      MethodChannel('alarm_channel');
  static const MethodChannel _platform =
      MethodChannel('flutter_local_notifications_example');

  static Future<void> initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);
    await _flutterLocalNotificationsPlugin.initialize(initSettings);

    try {
      final bool isGranted =
          await _platform.invokeMethod('checkExactAlarmPermission') ?? false;
      if (!isGranted) {
        await _platform.invokeMethod('requestExactAlarmPermission');
      }
    } catch (e) {
      print('⚠️ Exact alarm permission check/request failed: $e');
    }
  }

  static Future<void> cancelRemindersForMedication(int medId) async {
    // Cancel base hourly alarm for this med
    for (int i = 0; i < 50; i++) {
      final hourlyId = 30000 + (medId * 100) + i;
      await _flutterLocalNotificationsPlugin.cancel(hourlyId);
      try {
        await _nativeAlarmChannel.invokeMethod('cancelAlarm', {'id': hourlyId});
      } catch (e) {
        print("⚠️ Failed to cancel hourly alarm ID $hourlyId: $e");
      }
    }

    // Cancel base meal alarm for this med
    for (int i = 0; i < 10; i++) {
      final mealId = 50000 + (medId * 100) + i;
      await _flutterLocalNotificationsPlugin.cancel(mealId);
      try {
        await _nativeAlarmChannel.invokeMethod('cancelAlarm', {'id': mealId});
      } catch (e) {
        print("⚠️ Failed to cancel meal alarm ID $mealId: $e");
      }
    }

    print("🗑️ Cancelled all alarms for medication ID $medId");
  }

  static Future<void> scheduleMedicationReminderFor({
    required Map<String, dynamic> medData,
  }) async {
    final name = medData['name'];
    final frequency = medData['frequency'];
    final duration = medData['duration'] as int;
    final timings = medData['timings'];
    final hourlyInterval = medData['hourly_interval'];
    final firstDose = medData['first_dose'];

    final now = DateTime.now();
    final medId = medData['id'] as int;

    int hourlyIdCounter = 0; // For hourly-based reminders
    int mealIdCounter = 0; // For non-hourly (meal-based) reminders

    if (frequency == 'Hourly' && hourlyInterval != null && firstDose != null) {
      final intervalHours = int.tryParse(
          RegExp(r'\d+').firstMatch(hourlyInterval)?.group(0) ?? '');
      if (intervalHours != null) {
        DateTime doseTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(firstDose.split(":")[0]),
          int.parse(firstDose.split(":")[1]),
        );

        // Shift first dose forward if it's already in the past
        while (doseTime.isBefore(now)) {
          doseTime = doseTime.add(Duration(hours: intervalHours));
        }

        final treatmentEnd = now.add(Duration(days: duration));

        while (doseTime.isBefore(treatmentEnd)) {
          await scheduleNativeAlarmReminder(
            id: 30000 + (medId * 100) + hourlyIdCounter,
            title: '$name Dose',
            body: 'Time to take $name (every $intervalHours hours)',
            time: TimeOfDay(hour: doseTime.hour, minute: doseTime.minute),
            fullDateTime: doseTime,
          );
          hourlyIdCounter++;
          doseTime = doseTime.add(Duration(hours: intervalHours));
        }
      }
    } else if (timings != null && frequency != 'Hourly') {
      final notifyBeforeStr = await DatabaseHelper().getNotifyBefore();
      final notifyBeforeMinutes =
          int.tryParse((notifyBeforeStr ?? '15').split(' ')[0]) ?? 15;

      for (int day = 0; day < duration; day++) {
        final scheduledDate = now.add(Duration(days: day));
        for (var timing in timings.split(',')) {
          timing = timing.trim();
          final timeMap = await DatabaseHelper().getMealTime(timing);
          if (timeMap != null) {
            final timingTime =
                TimeOfDay(hour: timeMap['hour']!, minute: timeMap['minute']!);
            DateTime doseTime = DateTime(
              scheduledDate.year,
              scheduledDate.month,
              scheduledDate.day,
              timingTime.hour,
              timingTime.minute,
            );

            if (timing.startsWith('Before')) {
              doseTime =
                  doseTime.subtract(Duration(minutes: notifyBeforeMinutes));
            } else if (timing.startsWith('After')) {
              doseTime = doseTime.add(Duration(minutes: notifyBeforeMinutes));
            }

            if (doseTime.isAfter(now)) {
              await scheduleNativeAlarmReminder(
                id: 50000 + (medId * 100) + mealIdCounter,
                title: 'Medication Reminder',
                body: '$name at $timing',
                time: TimeOfDay(hour: doseTime.hour, minute: doseTime.minute),
                fullDateTime: doseTime,
              );
              mealIdCounter++;
            }
          }
        }
      }
    }
  }

  static Future<void> cancelMealBasedReminders() async {
    for (int id = 50000; id < 51000; id++) {
      // increment later (time complex)
      try {
        await _nativeAlarmChannel.invokeMethod('cancelAlarm', {'id': id});
      } catch (e) {
        print("⚠️ Failed to cancel native alarm ID $id: $e");
      }
    }
    print("🧹 Cancelled all meal-based reminders.");
  }

  static DateTime getAdjustedTimeObject(TimeOfDay time, int beforeMinutes) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return base.subtract(Duration(minutes: beforeMinutes));
  }

  static Future<void> scheduleMealBasedReminders() async {
    final db = await DatabaseHelper().database;
    final activeMeds = await db.query('medications', where: 'is_active = 1');

    final notifyBeforeStr = await DatabaseHelper().getNotifyBefore();
    final notifyBeforeMinutes =
        int.tryParse((notifyBeforeStr ?? '15').split(' ')[0]) ?? 15;

    for (var med in activeMeds) {
      final frequency = med['frequency'];
      final timings = med['timings']?.toString();
      final name = med['name'];
      final id = (med['id'] as int);

      if (frequency != 'Hourly' && timings != null && timings.isNotEmpty) {
        final timingList = timings.split(',').map((e) => e.trim()).toList();
        for (var timing in timingList) {
          final timeMap = await DatabaseHelper().getMealTime(timing);
          if (timeMap != null) {
            TimeOfDay mealTime =
                TimeOfDay(hour: timeMap['hour']!, minute: timeMap['minute']!);

            DateTime adjustedDateTime;

            if (timing.startsWith('Before')) {
              adjustedDateTime =
                  getAdjustedTimeObject(mealTime, notifyBeforeMinutes);
            } else if (timing.startsWith('After')) {
              final now = DateTime.now();
              final mealDateTime = DateTime(
                  now.year, now.month, now.day, mealTime.hour, mealTime.minute);
              adjustedDateTime =
                  mealDateTime.add(Duration(minutes: notifyBeforeMinutes));
            } else {
              final now = DateTime.now();
              adjustedDateTime = DateTime(
                  now.year, now.month, now.day, mealTime.hour, mealTime.minute);
            }

            await scheduleNativeAlarmReminder(
              id: 50000 + (id * 100) + (timing.hashCode % 100),
              title: 'Medication Reminder',
              body: '$name at $timing',
              time: TimeOfDay(
                  hour: adjustedDateTime.hour, minute: adjustedDateTime.minute),
              fullDateTime: adjustedDateTime,
            );
          }
        }
      }
    }
  }

  static Future<void> scheduleNativeAlarmReminder({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
    DateTime? fullDateTime,
  }) async {
    final now = DateTime.now();
    final scheduledDateTime = fullDateTime ??
        DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );

    if (!scheduledDateTime.isAfter(now)) {
      print("⏭️ Skipping alarm: $title at ${time.hour}:${time.minute} (past)");
      return;
    }

    try {
      await _nativeAlarmChannel.invokeMethod('scheduleAlarm', {
        'id': id,
        'title': title,
        'body': body,
        'year': scheduledDateTime.year,
        'month': scheduledDateTime.month,
        'day': scheduledDateTime.day,
        'hour': scheduledDateTime.hour,
        'minute': scheduledDateTime.minute,
      });
      print(
          "📲 Native alarm scheduled: $title → $body at ${scheduledDateTime.hour}:${scheduledDateTime.minute}");
    } catch (e) {
      print("❌ Failed to schedule native alarm: $e");
    }
  }

  static Future<void> cancelAllReminders() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  static Future<void> cancelReminderById(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }
}

Future<void> scheduleAllMedicationReminders() async {
  final db = await DatabaseHelper().database;
  final meds = await db.query('medications', where: 'is_active = 1');

  final now = DateTime.now();

  // Fetch meal timings from the database
  final Map<String, TimeOfDay> timeMap = {};
  final meals = [
    'Before Breakfast',
    'After Breakfast',
    'Before Lunch',
    'After Lunch',
    'Before Dinner',
    'After Dinner'
  ];

  for (final meal in meals) {
    final timing = await DatabaseHelper().getMealTime(meal);
    if (timing != null) {
      timeMap[meal] =
          TimeOfDay(hour: timing['hour']!, minute: timing['minute']!);
    }
  }

  Map<String, List<String>> timingToMeds = {};
  int notificationId = 10000;

  for (var med in meds) {
    final id = med['id'] as int;
    final name = med['name'].toString();
    final frequency = med['frequency']?.toString();
    final timingsRaw = med['timings']?.toString();
    final interval = med['hourly_interval']?.toString();
    final firstDose = med['first_dose']?.toString();

    if (frequency == 'Hourly' && interval != null && firstDose != null) {
      final intervalHours = _parseIntervalHours(interval);
      final firstTime = _parseTime(firstDose);

      DateTime doseTime = DateTime(
        now.year,
        now.month,
        now.day,
        firstTime.hour,
        firstTime.minute,
      );

      int i = 0;
      while (doseTime.isBefore(now.add(const Duration(days: 1)))) {
        if (doseTime.isAfter(now)) {
          await NotificationService.scheduleNativeAlarmReminder(
            id: 30000 + (id * 100) + i,
            title: '$name Dose',
            body: 'Time to take $name (every $intervalHours hours)',
            time: TimeOfDay.fromDateTime(doseTime),
          );
        }
        doseTime = doseTime.add(Duration(hours: intervalHours));
        i++;
      }
    } else if (timingsRaw != null && timingsRaw.isNotEmpty) {
      final timings = timingsRaw.split(',');
      for (final timing in timings) {
        timingToMeds.putIfAbsent(timing.trim(), () => []).add(name);
      }
    }
  }

  for (final entry in timingToMeds.entries) {
    final timing = entry.key;
    final medNames = entry.value;
    final time = timeMap[timing];

    if (time != null && medNames.isNotEmpty) {
      await NotificationService.scheduleNativeAlarmReminder(
        id: notificationId++,
        title: 'Medication Reminder',
        body: medNames.join(', '),
        time: time,
      );
    }
  }
}

// Helper to parse time from HH:mm format
TimeOfDay _parseTime(String? timeString) {
  if (timeString == null) return const TimeOfDay(hour: 8, minute: 0);
  final parts = timeString.split(':');
  return TimeOfDay(
    hour: int.parse(parts[0]),
    minute: int.parse(parts[1]),
  );
}

// Helper to parse hourly interval like "Every 2 Hours"
int _parseIntervalHours(String interval) {
  final match = RegExp(r'\d+').firstMatch(interval);
  return match != null ? int.parse(match.group(0)!) : 2;
}
