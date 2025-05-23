import 'package:flutter/material.dart';
import 'database.dart';
import 'homepage.dart';
import 'notification.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initializeNotifications();
  await AndroidAlarmManager.initialize();
  await DatabaseHelper.copyMedicinesDbIfNeeded();

  runApp(MediscribeApp());
}

class MediscribeApp extends StatelessWidget {
  const MediscribeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mediscribe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}
