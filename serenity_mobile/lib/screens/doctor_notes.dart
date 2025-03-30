import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'messages.dart';
import 'emergencymode.dart';

class DoctorNotesScreen extends StatefulWidget {
  const DoctorNotesScreen({Key? key}) : super(key: key);

  @override
  State<DoctorNotesScreen> createState() => _DoctorNotesScreenState();
}

class _DoctorNotesScreenState extends State<DoctorNotesScreen> {
  // Reference to the node: "administrator/users"
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('administrator/users');
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _notes = [];
  int _selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    _fetchDoctorNotes();
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF92A68A),
        centerTitle: true,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex, // Use the currentIndex variable
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.mail),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.bell),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notes),
            label: '',
          ),
        ],
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: const Color(0xFF94AF94),
        selectedFontSize: 0.0,
        unselectedFontSize: 0.0,
        onTap: (index) {
          setState(() {
            _selectedIndex = index; // Update the selectedIndex on tap
          });
          if (index == 0) {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => HomePage()));
          } else if (index == 1) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => MessagesTab()));
          } else if (index == 2) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => Emergencymode()));
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
                          Text(
                            note['dateFiled'] ?? 'No date',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
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
