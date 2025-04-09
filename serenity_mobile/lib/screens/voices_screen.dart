import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'emergencymode.dart';

class VoicesScreen extends StatefulWidget {
  const VoicesScreen({Key? key}) : super(key: key);

  @override
  _VoicesScreenState createState() => _VoicesScreenState();
}

class _VoicesScreenState extends State<VoicesScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String? _selectedVoiceUrl;
  String? _selectedVoiceName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Voices'),
        backgroundColor: const Color(0xFF92A68A),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_selectedVoiceUrl != null) {
                Navigator.pop(context,
                    {'url': _selectedVoiceUrl, 'name': _selectedVoiceName});
              }
            },
          )
        ],
      ),
      body: StreamBuilder(
        stream: _databaseRef
            .child('user_audio/${FirebaseAuth.instance.currentUser?.uid}')
            .onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final data =
                Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
            final audioList = data.entries.toList()
              ..sort((a, b) =>
                  b.value['timestamp'].compareTo(a.value['timestamp']));

            return ListView.builder(
              itemCount: audioList.length,
              itemBuilder: (context, index) {
                final entry = audioList[index];
                final audioName = entry.value['name'] ??
                    (entry.value['type'] == 'recorded'
                        ? 'Recording ${index + 1}'
                        : 'Uploaded Audio ${index + 1}');
                final isSelected = _selectedVoiceUrl == entry.value['url'];

                return Card(
                  color: isSelected ? Colors.grey[200] : null,
                  child: ListTile(
                    leading: const Icon(Icons.audio_file),
                    title: Text(audioName),
                    subtitle: Text(
                      DateTime.fromMillisecondsSinceEpoch(
                              entry.value['timestamp'])
                          .toString()
                          .substring(0, 16),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _renameVoice(
                              entry.key, audioName, entry.value['url']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _deleteVoice(entry.key, entry.value['url']),
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _selectedVoiceUrl = entry.value['url'];
                        _selectedVoiceName = audioName;
                      });
                    },
                  ),
                );
              },
            );
          }
          return const Center(child: Text('No audio files available'));
        },
      ),
    );
  }

  Future<void> _renameVoice(String key, String currentName, String url) async {
    final TextEditingController controller =
        TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Voice'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'New name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      try {
        await _databaseRef
            .child('user_audio/${user.uid}/$key')
            .update({'name': newName});
        if (_selectedVoiceUrl == url) {
          setState(() {
            _selectedVoiceName = newName;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice renamed successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename voice: $e')),
        );
      }
    }
  }

  Future<void> _deleteVoice(String key, String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Voice'),
          content: const Text('Are you sure you want to delete this voice?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      try {
        final storageRef = _storage.refFromURL(url);
        await storageRef.delete();
        await _databaseRef.child('user_audio/${user.uid}/$key').remove();
        if (_selectedVoiceUrl == url) {
          setState(() {
            _selectedVoiceUrl = null;
            _selectedVoiceName = null;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete voice: $e')),
        );
      }
    }
  }
}
