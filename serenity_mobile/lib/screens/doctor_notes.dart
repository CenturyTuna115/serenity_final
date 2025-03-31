import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'messages.dart';
import 'emergencymode.dart';
import '../widgets/app_bottom_nav_bar.dart';

class DoctorNotesScreen extends StatefulWidget {
  const DoctorNotesScreen({Key? key}) : super(key: key);

  @override
  State<DoctorNotesScreen> createState() => _DoctorNotesScreenState();
}

class _DoctorNotesScreenState extends State<DoctorNotesScreen> {
  // Reference to the node: "administrator/users"
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('administrator/users');
  final DatabaseReference _doctorsRef =
      FirebaseDatabase.instance.ref('administrator/doctors');
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _notes = [];
  Map<String, String> _doctorNames = {}; // Cache for doctor names
  int _selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    _fetchDoctorNotes();
  }

  Future<String> _getDoctorName(String doctorId) async {
    if (_doctorNames.containsKey(doctorId)) {
      return _doctorNames[doctorId]!;
    }

    try {
      final snapshot = await _doctorsRef.child(doctorId).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final name = data['name'] as String? ?? 'Unknown Doctor';
        _doctorNames[doctorId] = name;
        return name;
      }
    } catch (e) {
      print('Error fetching doctor name: $e');
    }
    return 'Unknown Doctor';
  }

  /// Fetch the doctor notes for the current user.
  void _fetchDoctorNotes() async {
    // Get the currently logged-in user
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final String userId = currentUser.uid;

    // Listen for changes in the doctorNotes node
    _dbRef.child(userId).child('doctorNotes').onValue.listen((event) {
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> tempNotes = [];

        // Convert each child into a Map<String, dynamic>
        data.forEach((key, value) {
          tempNotes.add({
            'dateFiled': value['dateFiled'] ?? '',
            'doctorID': value['doctorID'] ?? '',
            'noteDetails': value['noteDetails'] ?? '',
          });
        });

        setState(() {
          _notes = tempNotes;
        });

        // Fetch doctor names for all notes
        for (var note in _notes) {
          if (note['doctorID'] != '') {
            _getDoctorName(note['doctorID']).then((name) {
              if (mounted) {
                setState(() {
                  _doctorNames[note['doctorID']] = name;
                });
              }
            });
          }
        }

        // Scroll to bottom if needed
        _scrollToBottom();
      } else {
        setState(() {
          _notes.clear();
        });
      }
    });
  }

  /// Scroll the list to the bottom (so new notes are visible immediately).
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Build the UI to display the list of notes.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD7E9D7),
      appBar: AppBar(
        title: const Text(
          'Doctor Notes',
          style: TextStyle(
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        backgroundColor: const Color(0xFF92A68A),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePage(currentIndex: 0),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: 3,
        onTap: (index) {
          Widget? nextPage;
          if (index == 0) {
            nextPage = const HomePage(currentIndex: 0);
          } else if (index == 1) {
            nextPage = const MessagesTab(currentIndex: 1);
          } else if (index == 2) {
            nextPage = const Emergencymode(currentIndex: 2);
          } else if (index == 3) {
            return; // Stay on current page
          }

          if (nextPage != null) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => nextPage!,
                transitionsBuilder: (_, a, __, c) =>
                    FadeTransition(opacity: a, child: c),
              ),
            );
          }
        },
      ),
      body: _notes.isEmpty
          ? Center(
              child: Text(
                'No notes available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  final note = _notes[index];
                  final doctorName =
                      _doctorNames[note['doctorID']] ?? 'Loading...';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                note['dateFiled'] ?? 'No date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Dr. $doctorName',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            note['noteDetails'] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
