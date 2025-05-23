import 'package:flutter/material.dart';
import 'database.dart';
import 'homepage.dart';
import 'settings.dart';
import 'history.dart';
import 'package:intl/intl.dart';

class AlternatePage extends StatefulWidget {
  @override
  _AlternatePageState createState() => _AlternatePageState();
}

class _AlternatePageState extends State<AlternatePage> {
  final TextEditingController _controller = TextEditingController();
  Map<String, List<Map<String, dynamic>>> _alternatives = {};
  int _selectedIndex = 0;
  String _searchError = '';
  String todayDate = DateFormat('dd MMM yyyy').format(DateTime.now());

  String? _selectedStrength;
  List<String> _availableStrengths = [];

  Future<void> _searchAlternatives() async {
    final brand = _controller.text.trim();
    if (brand.isEmpty) {
      setState(() {
        _searchError = 'Please enter a medicine name';
        _alternatives = {};
        _availableStrengths = [];
        _selectedStrength = null;
      });
      return;
    }

    final results = await DatabaseHelper().getAlternatives(brand);
    final strengths = results.values
        .expand(
            (list) => list.map((e) => e['strength']?.toString() ?? 'Unknown'))
        .toSet()
        .toList()
      ..sort();

    setState(() {
      _alternatives = results;
      _availableStrengths = strengths;
      _selectedStrength = null;
      _searchError = results.isEmpty ? 'No alternatives found' : '';
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupByStrength(
      List<Map<String, dynamic>> meds) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var med in meds) {
      final strength = (med['strength'] ?? 'Unknown').toString();
      grouped.putIfAbsent(strength, () => []).add(med);
    }
    return grouped;
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Enter Brand Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _searchAlternatives,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Search'),
                  )
                ],
              ),
              const SizedBox(height: 10),
              if (_searchError.isNotEmpty)
                Text(_searchError, style: TextStyle(color: Colors.red)),
              if (_availableStrengths.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Filter by Strength',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green, width: 2),
                      ),
                      labelStyle: TextStyle(color: Colors.green[800]),
                    ),
                    dropdownColor: Colors.white,
                    iconEnabledColor: Colors.green[800],
                    style: TextStyle(color: Colors.black),
                    value: _selectedStrength,
                    isExpanded: true,
                    items: _availableStrengths.map((strength) {
                      return DropdownMenuItem(
                        value: strength,
                        child: Text(
                          strength,
                          style: TextStyle(color: Colors.black),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedStrength = value;
                      });
                    },
                  ),
                ),
              Expanded(
                child: _alternatives.isEmpty
                    ? Center(child: Text('No results'))
                    : ListView(
                        children: _alternatives.entries.map((entry) {
                          final brand = entry.key;
                          final meds = entry.value;
                          final filteredMeds = _selectedStrength == null
                              ? meds
                              : meds
                                  .where((m) =>
                                      m['strength']?.toString() ==
                                      _selectedStrength)
                                  .toList();

                          if (filteredMeds.isEmpty) return SizedBox.shrink();

                          return Card(
                            color: Colors.green[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: Colors.green.shade900, width: 1.5),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    brand,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[900],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ..._groupByStrength(filteredMeds)
                                      .entries
                                      .map((entry) {
                                    final items = entry.value;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Divider(
                                            thickness: 1,
                                            color: Colors.green[300]),
                                        ...items.map((med) => Text(
                                              '• ${med['strength']} ${med['dosage form']} • ${med['manufacturer']} • ${med['package container']}',
                                              style: TextStyle(
                                                  color: Colors.green[800]),
                                            )),
                                        const SizedBox(height: 8),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
