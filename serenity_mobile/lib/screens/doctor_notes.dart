import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      appBar: AppBar(
        title: const Text('Doctor Notes'),
      ),
      body: _notes.isEmpty
          ? const Center(
              child: Text('No notes available'),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    note['noteDetails'] ?? '',
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              },
            ),
    );
  }
}
