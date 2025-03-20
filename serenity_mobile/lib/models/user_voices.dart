import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserVoices extends StatefulWidget {
  const UserVoices({Key? key}) : super(key: key);

  @override
  _UserVoicesState createState() => _UserVoicesState();
}

class _UserVoicesState extends State<UserVoices> {
  final user = FirebaseAuth.instance.currentUser;
  final DatabaseReference dbRef = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> voicesList = [];

  @override
  void initState() {
    super.initState();
    _fetchUserVoices();
  }

  /// Fetch the logged-in user's recordings from:
  /// administrator/users/<UID>/user_audio
  Future<void> _fetchUserVoices() async {
    if (user == null) {
      // No user is logged in; you might show a message or redirect to login
      return;
    }

    try {
      // Get data at the path: administrator/users/<UID>/user_audio
      final voicesSnapshot = await dbRef
          .child('administrator')
          .child('users')
          .child(user!.uid)
          .child('user_audio')
          .get();

      if (voicesSnapshot.exists) {
        // Convert snapshot to a Map
        final data = voicesSnapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          final List<Map<String, dynamic>> loadedVoices = [];

          // Each key is a push ID; each value is the audio data
          data.forEach((key, value) {
            final voiceMap = value as Map<dynamic, dynamic>;

            // Convert each entry into a more readable Map<String, dynamic>
            loadedVoices.add({
              'id': key,
              'url': voiceMap['url'] ?? '',
              'name': voiceMap['name'] ?? 'Unnamed',
              'timestamp': voiceMap['timestamp'] ?? 0,
              'duration': voiceMap['duration'] ?? 0,
              'type': voiceMap['type'] ?? '',
            });
          });

          setState(() {
            voicesList = loadedVoices;
          });
        }
      }
    } catch (e) {
      print('Error fetching user voices: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Recordings'),
        backgroundColor: const Color(0xFF92A68A),
      ),
      body: voicesList.isEmpty
          ? const Center(child: Text('No recordings found.'))
          : ListView.builder(
              itemCount: voicesList.length,
              itemBuilder: (context, index) {
                final voice = voicesList[index];
                final voiceName = voice['name'] ?? 'Unnamed';
                final duration = voice['duration']?.toString() ?? '0';
                final type = voice['type'] ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 6.0),
                  child: ListTile(
                    title: Text(voiceName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Duration: ${duration}s\nType: $type',
                        style: const TextStyle(fontSize: 14)),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () {
                        // TODO: Implement playback logic (e.g., open a player screen or use a plugin)
                        print('Play: ${voice['url']}');
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
