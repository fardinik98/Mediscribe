import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database.dart';
import 'homepage.dart';
import 'notification.dart';

class AddManualPage extends StatefulWidget {
  @override
  _AddManualPageState createState() => _AddManualPageState();
}

class _AddManualPageState extends State<AddManualPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _strengthController = TextEditingController();

  String _frequency = 'Once';
  String? _hourlyInterval;
  List<String> _selectedTimings = [];
  TimeOfDay? _firstDoseTime;

  final List<String> _timingOptions = [
    'Before Breakfast',
    'After Breakfast',
    'Before Lunch',
    'After Lunch',
    'Before Dinner',
    'After Dinner',
  ];

  final List<String> _frequencyOptions = ['Once', 'Twice', 'Thrice', 'Hourly'];
  final Map<String, String> _hourlyOptions = {
    'Every 2 Hours': 'Every 2 Hours',
    'Every 3 Hours': 'Every 3 Hours',
    'Every 4 Hours': 'Every 4 Hours',
    'Every 6 Hours': 'Every 6 Hours',
    'Every 8 Hours': 'Every 8 Hours',
    'Every 12 Hours': 'Every 12 Hours',
    'Every 24 Hours': 'Once Daily',
  };

  void _toggleTiming(String timing) {
    setState(() {
      bool isSameMeal(String t1, String t2) {
        final meals = ['Breakfast', 'Lunch', 'Dinner'];
        for (var meal in meals) {
          if (t1.contains(meal) && t2.contains(meal)) return true;
        }
        return false;
      }

      if (_selectedTimings.contains(timing)) {
        _selectedTimings.remove(timing);
      } else {
        if (_frequency == 'Once') {
          _selectedTimings = [timing];
        } else if (_frequency == 'Twice' || _frequency == 'Thrice') {
          _selectedTimings.removeWhere((t) => isSameMeal(t, timing));
          if (_selectedTimings.length < (_frequency == 'Twice' ? 2 : 3)) {
            _selectedTimings.add(timing);
          }
        }
      }
    });
  }

  bool _isValidSelection() {
    if (_frequency == 'Once') return _selectedTimings.length == 1;
    if (_frequency == 'Twice') {
      final lunch = _selectedTimings.where((t) => t.contains('Lunch')).length;
      final dinner = _selectedTimings.where((t) => t.contains('Dinner')).length;
      final breakfast =
          _selectedTimings.where((t) => t.contains('Breakfast')).length;
      return _selectedTimings.length == 2 &&
          breakfast <= 1 &&
          lunch <= 1 &&
          dinner <= 1;
    }
    if (_frequency == 'Thrice') {
      final breakfast =
          _selectedTimings.where((t) => t.contains('Breakfast')).length;
      final lunch = _selectedTimings.where((t) => t.contains('Lunch')).length;
      final dinner = _selectedTimings.where((t) => t.contains('Dinner')).length;
      return _selectedTimings.length == 3 &&
          breakfast <= 1 &&
          lunch <= 1 &&
          dinner <= 1;
    }
    if (_frequency == 'Hourly')
      return _hourlyInterval != null && _firstDoseTime != null;
    return false;
  }

  void _submitMedicine() async {
    final name = _nameController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());
    final strength = _strengthController.text.trim();

    if (name.isEmpty || duration == null || !_isValidSelection()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and select valid timings.')),
      );
      return;
    }

    final medication = {
      'name': name,
      'strength': strength.isEmpty ? null : strength,
      'frequency': _frequency,
      'duration': duration,
      'timings':
          _selectedTimings.isNotEmpty ? _selectedTimings.join(',') : null,
      'hourly_interval': _hourlyInterval,
      'first_dose': _firstDoseTime != null
          ? '${_firstDoseTime!.hour.toString().padLeft(2, '0')}:${_firstDoseTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'start_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'is_active': 1,
    };

    final db = await DatabaseHelper().database;
    final newId = await db.insert('medications', medication); //Get ID

    medication['id'] = newId;

    //Now schedule notification properly
    await NotificationService.scheduleMedicationReminderFor(
        medData: medication);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Medication saved successfully!')),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage()),
    );
  }

  Future<void> _pickFirstDoseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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
              style: TextButton.styleFrom(foregroundColor: Colors.green),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _firstDoseTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Medicine Manually'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  final results = await DatabaseHelper()
                      .getBrandSuggestions(textEditingValue.text);
                  print(
                      "Suggestions for '${textEditingValue.text}': $results"); // optional debug
                  return results;
                },
                onSelected: (String selection) async {
                  _nameController.text = selection;

                  // fetch and clean strength
                  final rawStrength =
                      await DatabaseHelper().getStrengthForBrand(selection);
                  if (rawStrength != null) {
                    // Extract only numeric part (e.g., "500" from "500mg" or "500 mg")
                    final numeric = RegExp(r'\d+').stringMatch(rawStrength);
                    if (numeric != null) {
                      setState(() {
                        _strengthController.text = numeric;
                      });
                    }
                  }
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onEditingComplete) {
                  controller.text = _nameController.text;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (value) => _nameController.text = value,
                    decoration: InputDecoration(labelText: 'Medicine Name'),
                  );
                },
              ),
              TextField(
                controller: _strengthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Strength (mg)'),
              ),
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Duration (in days)'),
              ),
              const SizedBox(height: 20),
              Text(
                'Dose Frequency:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _frequency,
                onChanged: (value) {
                  setState(() {
                    _frequency = value!;
                    _selectedTimings.clear();
                    _hourlyInterval = null;
                    _firstDoseTime = null;
                  });
                },
                items: _frequencyOptions
                    .map((freq) => DropdownMenuItem(
                          value: freq,
                          child: Text(freq),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              if (_frequency == 'Once' ||
                  _frequency == 'Twice' ||
                  _frequency == 'Thrice')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Meal Timings:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ..._timingOptions.map((timing) {
                      return CheckboxListTile(
                        title: Text(timing),
                        value: _selectedTimings.contains(timing),
                        onChanged: (bool? checked) {
                          _toggleTiming(timing);
                        },
                        activeColor: Colors.green,
                      );
                    }).toList(),
                  ],
                ),
              if (_frequency == 'Hourly')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Hourly Interval:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      value: _hourlyInterval,
                      hint: Text('Choose interval'),
                      onChanged: (value) {
                        setState(
                            () => _hourlyInterval = value!); // value is the key
                      },
                      items: _hourlyOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key, // backend value
                          child: Text(entry.value), // visible text
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Select First Dose Time:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(_firstDoseTime == null
                            ? 'No time selected'
                            : _firstDoseTime!.format(context)),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _pickFirstDoseTime,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          child: Text('Select Time'),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: _submitMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text('Save'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
