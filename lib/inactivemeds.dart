import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database.dart';
import 'homepage.dart';
import 'settings.dart';
import 'history.dart';
import 'notification.dart';

class InactiveMedsPage extends StatefulWidget {
  @override
  _InactiveMedsPageState createState() => _InactiveMedsPageState();
}

class _InactiveMedsPageState extends State<InactiveMedsPage> {
  final String todayDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
  List<Map<String, dynamic>> _medications = [];

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    final db = await DatabaseHelper().database;
    final data =
        await db.query('medications', where: 'is_active = ?', whereArgs: [0]);
    setState(() {
      _medications = data;
    });
  }

  Future<void> _reactivateMedication(Map<String, dynamic> med) async {
    final TextEditingController durationController =
        TextEditingController(text: med['duration'].toString());
    String? selectedFrequency = med['frequency'];
    String? selectedInterval = med['hourly_interval'];
    List<String> selectedChips = (med['timings'] ?? '')
        .toString()
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final id = med['id'];

    // _firstDoseTime
    TimeOfDay? _firstDoseTime = med['first_dose'] != null
        ? TimeOfDay(
            hour: int.parse(med['first_dose'].split(":")[0]),
            minute: int.parse(med['first_dose'].split(":")[1]),
          )
        : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final List<String> frequencies = ['Once', 'Twice', 'Thrice', 'Hourly'];
        final List<String> timingOptions = [
          'Before Breakfast',
          'After Breakfast',
          'Before Lunch',
          'After Lunch',
          'Before Dinner',
          'After Dinner',
        ];
        final Map<String, String> hourlyOptions = {
          'Every 2 Hours': 'Every 2 Hours',
          'Every 3 Hours': 'Every 3 Hours',
          'Every 4 Hours': 'Every 4 Hours',
          'Every 6 Hours': 'Every 6 Hours',
          'Every 8 Hours': 'Every 8 Hours',
          'Every 12 Hours': 'Every 12 Hours',
          'Every 24 Hours': 'Once Daily',
        };

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> _pickFirstDoseTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _firstDoseTime ?? TimeOfDay.now(),
                initialEntryMode: TimePickerEntryMode.inputOnly,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      timePickerTheme: TimePickerThemeData(
                        backgroundColor: Colors.white,
                        hourMinuteTextColor: Colors.black,
                        hourMinuteShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.green),
                        ),
                        dialHandColor: Colors.black,
                        dialTextColor: Colors.black,
                        entryModeIconColor: Colors.green,
                        helpTextStyle: TextStyle(color: Colors.green),
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.green),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setModalState(() {
                  _firstDoseTime = picked;
                });
              }
            }

            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Reactivate Medication',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Duration (days)'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedFrequency,
                        hint: Text('Select Frequency'),
                        items: frequencies
                            .map((f) =>
                                DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            selectedFrequency = value!;
                            selectedChips.clear();
                            selectedInterval = null;
                            _firstDoseTime =
                                null; // reset first dose when frequency changes
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      if (selectedFrequency == 'Hourly') ...[
                        ElevatedButton(
                          onPressed: () async {
                            await _pickFirstDoseTime();
                          },
                          child: Text(_firstDoseTime != null
                              ? 'First Dose: ${_firstDoseTime!.format(context)}'
                              : 'Select First Dose Time'),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedInterval,
                          hint: Text('Select Hourly Interval'),
                          items: hourlyOptions.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              selectedInterval = val;
                            });
                          },
                        ),
                      ],
                      if (selectedFrequency != 'Hourly')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select Meal Timings:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Wrap(
                              spacing: 8.0,
                              children: timingOptions.map((timing) {
                                final selected = selectedChips.contains(timing);
                                return FilterChip(
                                  label: Text(timing),
                                  selected: selected,
                                  onSelected: (val) {
                                    setModalState(() {
                                      if (val) {
                                        if ((selectedFrequency == 'Once' &&
                                                selectedChips.length < 1) ||
                                            (selectedFrequency == 'Twice' &&
                                                selectedChips.length < 2) ||
                                            (selectedFrequency == 'Thrice' &&
                                                selectedChips.length < 3)) {
                                          selectedChips.add(timing);
                                        }
                                      } else {
                                        selectedChips.remove(timing);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Confirm Delete'),
                                  content: Text(
                                      'Are you sure you want to delete this medication?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text('Delete',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                Navigator.pop(context);
                                await _deleteMedication(id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Medication deleted')),
                                );
                              }
                            },
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final duration =
                                  int.tryParse(durationController.text.trim());
                              if (duration == null ||
                                  selectedFrequency == null) {
                                Navigator.pop(context);
                                return;
                              }

                              final updatedData = {
                                'id': id,
                                'name': med['name'],
                                'strength': med['strength'],
                                'duration': duration,
                                'frequency': selectedFrequency,
                                'timings': selectedChips.join(','),
                                'hourly_interval': selectedInterval,
                                'first_dose': _firstDoseTime != null
                                    ? '${_firstDoseTime!.hour.toString().padLeft(2, '0')}:${_firstDoseTime!.minute.toString().padLeft(2, '0')}'
                                    : med['first_dose'],
                                'is_active': 1,
                                'start_date': DateFormat('yyyy-MM-dd')
                                    .format(DateTime.now()),
                              };

                              final db = await DatabaseHelper().database;
                              await db.update(
                                'medications',
                                updatedData,
                                where: 'id = ?',
                                whereArgs: [id],
                              );

                              await NotificationService
                                  .scheduleMedicationReminderFor(
                                      medData: updatedData);

                              Navigator.pop(context);
                              await _loadMedications();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Medication reactivated successfully!')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                            child: Text('Save'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMedication(int id) async {
    await DatabaseHelper().deleteMedication(id);
    await _loadMedications();
  }

  String _buildDetails(Map<String, dynamic> med) {
    final f = med['frequency'];
    final t = med['timings'];
    final h = med['hourly_interval'];
    final d = med['duration'];
    if (f == 'Hourly') {
      return 'Hourly (${h ?? 'N/A'}) - originally $d days';
    } else if (t != null && t.isNotEmpty) {
      return '$f daily (${t.replaceAll(",", ", ")}) - originally $d days';
    } else {
      return '$f daily - originally $d days';
    }
  }

  String _buildInfo(Map<String, dynamic> med) {
    final f = med['frequency'];
    final t = med['timings'];
    final h = med['hourly_interval'];
    final fd = med['first_dose'];
    final d = med['duration'];
    if (f == 'Hourly') {
      return 'Was taken every ${h ?? '...'} from ${fd ?? '...'} for $d days.';
    } else {
      return 'Was taken at ${t?.replaceAll(",", " and ") ?? '...'} for $d days.';
    }
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
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inactive Medications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _medications.isEmpty
                  ? Center(child: Text('No inactive medications.'))
                  : ListView.builder(
                      itemCount: _medications.length,
                      itemBuilder: (context, index) {
                        final med = _medications[index];
                        final name = med['strength'] != null &&
                                med['strength'].toString().isNotEmpty
                            ? '${med['name']} ${med['strength']}mg'
                            : med['name'];
                        return ExpansionTile(
                          title: Text(name),
                          subtitle: Text(_buildDetails(med)),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _reactivateMedication(med),
                                  icon: Icon(Icons.replay, color: Colors.green),
                                  label: Text('Reactivate',
                                      style: TextStyle(color: Colors.green)),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('Confirm Delete'),
                                        content: Text(
                                            'Are you sure you want to delete this medication?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _deleteMedication(med['id']);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Medication deleted')),
                                      );
                                    }
                                  },
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  label: Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: Text(_buildInfo(med)),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
