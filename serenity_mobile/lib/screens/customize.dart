import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:serenity_mobile/screens/doctor_notes.dart';
import 'package:serenity_mobile/utils/auth_utils.dart';
import 'dart:async';
import 'dart:io';
import 'homepage.dart';
import 'messages.dart';
import 'emergencymode.dart';
import 'login.dart';
import 'record.dart';

class CustomizePage extends StatefulWidget {
  final int currentIndex;

  CustomizePage({Key? key, this.currentIndex = 0}) : super(key: key);

  @override
  _CustomizePageState createState() => _CustomizePageState();
}

class _CustomizePageState extends State<CustomizePage> {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  String? _recordedFilePath;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late int currentIndex;
  StreamSubscription<RecordingDisposition>? _recorderSubscription;
  StreamSubscription<PlaybackDisposition>? _playerSubscription;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.currentIndex;
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _audioRecorder.openRecorder();
  }

  @override
  void dispose() {
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 255, 255), // Background color
      appBar: AppBar(
        backgroundColor: Color(0xFF92A68A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          '',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo.png', // Replace with your logo asset path
              height: 30,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 126, 243, 251),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/dino.png', // Replace with your image path
                      height: 150,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Shake It Your Way! \n Tailor Your Calm with Serenity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your Health Trusted Companion',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Customize',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                      'Upload', Icons.upload, Color.fromARGB(255, 232, 131, 0)),
                  _buildActionButton(
                      'Record', Icons.mic, Color.fromARGB(255, 0, 60, 29)),
                  _buildActionButton(
                      'Voices', Icons.headset, Color.fromARGB(255, 0, 60, 29)),
                  _buildActionButton('Health', Icons.health_and_safety,
                      Color.fromARGB(255, 0, 60, 29)),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Your Audio Files',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder(
                stream: _databaseRef
                    .child(
                        'user_audio/${FirebaseAuth.instance.currentUser?.uid}')
                    .onValue,
                builder: (context, snapshot) {
                  if (snapshot.hasData &&
                      snapshot.data!.snapshot.value != null) {
                    final data = Map<String, dynamic>.from(
                        snapshot.data!.snapshot.value as Map);
                    final audioList = data.entries.toList()
                      ..sort((a, b) =>
                          b.value['timestamp'].compareTo(a.value['timestamp']));

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: audioList.length,
                      itemBuilder: (context, index) {
                        final entry = audioList[index];
                        return Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.audio_file),
                              title: Text(entry.value['type'] == 'recorded'
                                  ? 'Recording ${index + 1}'
                                  : 'Uploaded Audio ${index + 1}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateTime.fromMillisecondsSinceEpoch(
                                          entry.value['timestamp'])
                                      .toString()
                                      .substring(0, 16)),
                                  if (_isPlaying &&
                                      _recordedFilePath == entry.key)
                                    Column(
                                      children: [
                                        SizedBox(height: 4),
                                        LinearProgressIndicator(
                                          value: _duration.inSeconds > 0
                                              ? _position.inSeconds /
                                                  _duration.inSeconds
                                              : 0,
                                          backgroundColor: Colors.grey[300],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.green),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                    _isPlaying && _recordedFilePath == entry.key
                                        ? Icons.stop
                                        : Icons.play_arrow),
                                onPressed: () => _playAudio(entry.value['url']),
                              ),
                            ),
                            Divider(height: 1),
                          ],
                        );
                      },
                    );
                  }
                  return const Center(child: Text('No audio files yet'));
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Recommendation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 1, // Single column for the row design
                childAspectRatio: 4, // Adjust for horizontal layout
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildRecommendationTile(
                      'River Flow', 'assets/gesture/river.jpg'),
                  _buildRecommendationTile(
                      'Birds Humm', 'assets/gesture/birds.jpg'),
                  _buildRecommendationTile(
                      'Breathing', 'assets/gesture/breath.png'),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFF6F4EE),
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
            icon: Icon(Icons.note),
            label: '',
          ),
        ],
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: const Color(0xFF94AF94),
        iconSize: 30.0,
        selectedFontSize: 0.0,
        unselectedFontSize: 0.0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => HomePage(currentIndex: 0)),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => MessagesTab(currentIndex: 1)),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => Emergencymode(currentIndex: 2)),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const DoctorNotesScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: () async {
        if (label == 'Record') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RecordsScreen()),
          ).then((_) {
            setState(() {});
          });
        } else if (label == 'Upload') {
          await _pickAndUploadAudio();
        }
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // Check microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }

      // Initialize recorder
      await _audioRecorder.openRecorder();

      // Create recording path
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording with error handling
      try {
        await _audioRecorder.startRecorder(
          toFile: path,
          codec: Codec.aacMP4,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 128000,
        );

        setState(() {
          _isRecording = true;
          _recordedFilePath = path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording started')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: ${e.toString()}')),
        );
        setState(() {
          _isRecording = false;
          _recordedFilePath = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        _isRecording = false;
        _recordedFilePath = null;
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });
      await _uploadAudio(_recordedFilePath!);
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _pickAndUploadAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        await _uploadAudio(file.path);
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }

  Future<void> _uploadAudio(String filePath) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final reference = _storage.ref().child('audio/$fileName');

      // Show upload progress
      final task = reference.putFile(File(filePath));
      task.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Uploading... ${(progress * 100).toStringAsFixed(1)}%')),
        );
      });

      await task;
      final downloadUrl = await reference.getDownloadURL();

      await _databaseRef.child('user_audio/${user.uid}').push().set({
        'url': downloadUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': _recordedFilePath == filePath ? 'recorded' : 'uploaded'
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio uploaded successfully!')),
      );
    } catch (e) {
      print('Error uploading audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload audio: ${e.toString()}')),
      );
    }
  }

  Future<void> _playAudio(String url) async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stopPlayer();
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
        return;
      }

      await _audioPlayer.openPlayer();
      await _audioPlayer.startPlayer(
        fromURI: url,
        codec: Codec.aacMP4,
        whenFinished: () {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        },
      );

      // Add progress listener
      _playerSubscription = _audioPlayer.onProgress!.listen((e) {
        setState(() {
          _position = e.position;
          if (_duration == Duration.zero) {
            _duration = e.duration;
          }
        });
      });

      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      print('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play audio: ${e.toString()}')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildRecommendationTile(String title, String imagePath) {
    return GestureDetector(
      onTap: () {
        // Handle recommendation click
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFD7E9D7),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(8), // Rounded corners for the image
              child: Image.asset(
                imagePath,
                width: 90, // Adjust the size of the image
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 20), // Space between image and text
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
