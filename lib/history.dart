import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database.dart';
import 'homepage.dart';
import 'settings.dart';

class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _selectedIndex = 2;
  final String todayDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
  List<Map<String, dynamic>> _allMeds = [];
  List<Map<String, dynamic>> _filteredMeds = [];
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadAllMedications();
  }

  Future<void> _loadAllMedications() async {
    final db = await DatabaseHelper().database;
    final data = await db.query('medications');
    setState(() {
      _allMeds = data;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredMeds = _allMeds.where((med) {
        final matchesSearch = med['name']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
        final isActive = med['is_active'] == 1;

        if (_statusFilter == 'Active') return matchesSearch && isActive;
        if (_statusFilter == 'Inactive') return matchesSearch && !isActive;
        return matchesSearch;
      }).toList();
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return 'Invalid';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _buildSchedule(Map<String, dynamic> med) {
    final f = med['frequency'];
    final t = med['timings'];
    final h = med['hourly_interval'];
    if (f == 'Hourly') {
      return 'Every ${h ?? '...'}';
    } else {
      return '$f daily ${t?.replaceAll(",", ", ") ?? '...'}';
    }
  }

  String _calculateEndDate(Map<String, dynamic> med) {
    final startDateStr = med['start_date'];
    final duration = med['duration'];
    if (startDateStr == null || duration == null) return 'N/A';
    final start = DateTime.tryParse(startDateStr);
    if (start == null) return 'Invalid';
    final end = start.add(Duration(days: duration));
    return DateFormat('MMM d, yyyy').format(end);
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
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Medi',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextSpan(
                    text: 'scribe',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                ],
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medication History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by medication name',
                prefixIcon: Icon(Icons.search, color: Colors.green),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
            ),
            const SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButton<String>(
                value: _statusFilter,
                isExpanded: true,
                underline: SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: Colors.green),
                items: ['All', 'Active', 'Inactive']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    _statusFilter = val;
                    _applyFilters();
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _filteredMeds.isEmpty
                  ? Center(child: Text('No medications found.'))
                  : ListView.builder(
                      itemCount: _filteredMeds.length,
                      itemBuilder: (context, index) {
                        final med = _filteredMeds[index];
                        final name = med['strength'] != null &&
                                med['strength'].toString().isNotEmpty
                            ? '${med['name']} ${med['strength']}mg'
                            : med['name'];
                        final start =
                            _formatDate(med['start_date']?.toString());
                        final end = _calculateEndDate(med);
                        final schedule = _buildSchedule(med);

                        return Card(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.green, width: 1.5),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green,
                              child:
                                  Icon(Icons.medication, color: Colors.white),
                            ),
                            title: Text(name,
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle:
                                Text('$schedule\nStart: $start\nEnd: $end'),
                            isThreeLine: true,
                          ),
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
