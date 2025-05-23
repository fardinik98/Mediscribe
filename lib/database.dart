import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
// import 'dart:typed_data';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static Database? _medicinesDb;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mediscribe.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE medications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            strength TEXT,
            duration INTEGER,
            frequency TEXT,
            timings TEXT,
            hourly_interval TEXT,
            first_dose TEXT,
            start_date TEXT,
            is_active INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE meal_timings (
            meal TEXT PRIMARY KEY,
            hour INTEGER,
            minute INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE notify_settings (
            id INTEGER PRIMARY KEY,
            notify_before TEXT
          )
        ''');

        await db.insert('meal_timings',
            {'meal': 'Before Breakfast', 'hour': 8, 'minute': 0});
        await db.insert('meal_timings',
            {'meal': 'After Breakfast', 'hour': 8, 'minute': 0});
        await db.insert(
            'meal_timings', {'meal': 'Before Lunch', 'hour': 13, 'minute': 0});
        await db.insert(
            'meal_timings', {'meal': 'After Lunch', 'hour': 13, 'minute': 0});
        await db.insert(
            'meal_timings', {'meal': 'Before Dinner', 'hour': 20, 'minute': 0});
        await db.insert(
            'meal_timings', {'meal': 'After Dinner', 'hour': 20, 'minute': 0});

        await db.insert(
            'notify_settings', {'id': 1, 'notify_before': '15 minutes'});
      },
    );
  }

  Future<void> insertMedication(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('medications', data);
  }

  Future<List<Map<String, dynamic>>> getMedications() async {
    final db = await database;
    return await db.query('medications');
  }

  Future<void> deleteMedication(int id) async {
    final db = await database;
    await db.delete(
      'medications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>?> getMealTime(String meal) async {
    final db = await database;
    final result = await db.query(
      'meal_timings',
      where: 'meal = ?',
      whereArgs: [meal],
    );
    if (result.isNotEmpty) {
      return {
        'hour': result.first['hour'] as int,
        'minute': result.first['minute'] as int,
      };
    }
    return null;
  }

  Future<void> updateMealTime(String meal, int hour, int minute) async {
    final db = await database;
    await db.update(
      'meal_timings',
      {'hour': hour, 'minute': minute},
      where: 'meal = ?',
      whereArgs: [meal],
    );
  }

  Future<String?> getNotifyBefore() async {
    final db = await database;
    final result = await db.query('notify_settings', where: 'id = 1');
    if (result.isNotEmpty) {
      return result.first['notify_before'] as String?;
    }
    return null;
  }

  Future<void> updateNotifyBefore(String notifyBefore) async {
    final db = await database;
    await db.update(
      'notify_settings',
      {'notify_before': notifyBefore},
      where: 'id = 1',
    );
  }

  /// Copy medicines.db from assets (only once)
  static Future<void> copyMedicinesDbIfNeeded() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final path = join(documentsDir.path, 'medicines.db');

    if (!await File(path).exists()) {
      final data = await rootBundle.load('assets/medicines.db');
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);
    }
  }

  /// Open the read-only medicines.db
  static Future<Database> getMedicinesDatabase() async {
    if (_medicinesDb != null) return _medicinesDb!;
    final documentsDir = await getApplicationDocumentsDirectory();
    final path = join(documentsDir.path, 'medicines.db');
    _medicinesDb = await openDatabase(path, readOnly: true);
    return _medicinesDb!;
  }

  /// Fetch brand suggestions by prefix
  Future<List<String>> getBrandSuggestions(String prefix) async {
    final db = await getMedicinesDatabase();
    final results = await db.query(
      'medicines',
      where: '`brand name` LIKE ?', // backticks required due to space
      whereArgs: ['$prefix%'],
      limit: 10,
    );
    return results.map((row) => row['brand name'].toString()).toList();
  }

  Future<String?> getStrengthForBrand(String brand) async {
    final db = await getMedicinesDatabase();
    final results = await db.query(
      'medicines',
      columns: ['strength'],
      where: '`brand name` = ?',
      whereArgs: [brand],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first['strength']?.toString();
    }
    return null;
  }

  Future<Map<String, List<Map<String, dynamic>>>> getAlternatives(
      String brandName) async {
    final db = await getMedicinesDatabase();

    // Step 1: Get the generic name for the input brand (case-insensitive)
    final source = await db.query(
      'medicines',
      columns: ['generic'],
      where: 'LOWER(`brand name`) = ?',
      whereArgs: [brandName.toLowerCase()],
      limit: 1,
    );

    if (source.isEmpty) return {};

    final generic = source.first['generic'];

    // Step 2: Query all entries that match the generic
    final results = await db.query(
      'medicines',
      where: 'generic = ?',
      whereArgs: [generic],
    );

    // Step 3: Group by brand name
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var row in results) {
      final brand = (row['brand name'] ?? 'Unknown').toString();
      grouped.putIfAbsent(brand, () => []).add(row);
    }

    return grouped;
  }
}
