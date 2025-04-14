import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:serenity_mobile/screens/voices_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:serenity_mobile/widgets/app_bottom_nav_bar.dart';
import 'dart:async';
import 'dart:io';
import 'homepage.dart';
import 'messages.dart';
import 'emergencymode.dart';

class CustomizePage extends StatefulWidget {
  final int currentIndex;

  const CustomizePage({Key? key, this.currentIndex = 0}) : super(key: key);

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
  String? _currentPlayingUrl;
  late int currentIndex;
  StreamSubscription<PlaybackDisposition>? _playerSubscription;

  // Variables for recording timer
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;
  final Duration _maxRecordingDuration =
      const Duration(minutes: 2); // 2 minutes limit

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
    _audioPlayer.closePlayer();
    _playerSubscription?.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      appBar: AppBar(
        backgroundColor: const Color(0xFF92A68A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('', style: TextStyle(color: Colors.black)),
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
              // Banner Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 126, 243, 251),
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
                      style: TextStyle(fontSize: 14, color: Colors.grey),
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
              // Display recording timer if active
              if (_isRecording)
                Center(
                  child: Text(
                    'Recording: ${_formatDuration(_duration)}',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              // If recording is active, show pause/resume and stop controls
              if (_isRecording)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isPaused)
                      IconButton(
                        icon: const Icon(Icons.pause, size: 32),
                        onPressed: _pauseRecording,
                      ),
                    if (_isPaused)
                      IconButton(
                        icon: const Icon(Icons.play_arrow, size: 32),
                        onPressed: _resumeRecording,
                      ),
                    IconButton(
                      icon: const Icon(Icons.stop, size: 32),
                      onPressed: _stopRecording,
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton('Upload', Icons.upload,
                      const Color.fromARGB(255, 232, 131, 0)),
                  // When not recording, show record button
                  if (!_isRecording)
                    _buildActionButton('Record', Icons.mic,
                        const Color.fromARGB(255, 0, 60, 29)),
                  _buildActionButton('Voices', Icons.headset,
                      const Color.fromARGB(255, 0, 60, 29), onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VoicesScreen(),
                      ),
                    );
                    if (result != null && result is Map) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                          'selected_audio_url', result['url']);
                      await prefs.setString(
                          'selected_audio_name', result['name']);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Voice applied successfully')),
                      );
                    }
                  }),
                  _buildActionButton('Health', Icons.health_and_safety,
                      const Color.fromARGB(255, 0, 60, 29)),
                ],
              ),
              const SizedBox(height: 32),
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
              // Recommendations Grid
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 1, // Single column layout
                childAspectRatio: 4,
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
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ??
          () async {
            if (label == 'Record') {
              await _toggleRecording();
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
      if (!mounted) return;

      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }

      // Create recording path
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (!mounted) return;
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
          _isPaused = false;
          _recordedFilePath = path;
          _duration = Duration.zero;
        });
        // Start timer to update recording duration
        _recordingStartTime = DateTime.now();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _duration = DateTime.now().difference(_recordingStartTime!);
          });
          // Check if recording duration has reached 2 minutes
          if (_duration >= _maxRecordingDuration) {
            _stopRecording();
            timer.cancel();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording started')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
        setState(() {
          _isRecording = false;
          _recordedFilePath = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isRecording = false;
        _recordedFilePath = null;
      });
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pauseRecorder();
      _recordingTimer?.cancel();
      setState(() {
        _isPaused = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording paused')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pause recording: $e')),
      );
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resumeRecorder();
      // Adjust start time so the timer resumes correctly
      _recordingStartTime = DateTime.now().subtract(_duration);
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          6;
          _duration = DateTime.now().difference(_recordingStartTime!);
        });
        if (_duration >= _maxRecordingDuration) {
          _stopRecording();
          timer.cancel();
        }
      });
      setState(() {
        _isPaused = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording resumed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resume recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
      _recordingTimer?.cancel();
      _recordingTimer = null;
      if (_recordedFilePath != null) {
        await _uploadAudio(_recordedFilePath!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording stopped')),
      );
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _pickAndUploadAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a'],
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
      String fileExtension = filePath.endsWith('.m4a') ? 'm4a' : 'mp3';
      final fileName =
          'audio_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final reference = _storage.ref().child('audio/$fileName');
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
      // When uploading a recorded file, store a default name
      final audioData = {
        'url': downloadUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': filePath.endsWith('.m4a') ? 'recorded' : 'uploaded',
        'name': filePath.endsWith('.m4a') ? 'Recording' : null,
      };
      await _databaseRef.child('user_audio/${user.uid}').push().set(audioData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio uploaded successfully!')),
      );
    } catch (e) {
      print('Error uploading audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload audio: $e')),
      );
    }
  }

  Future<void> _deleteAudio(String key, String url) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final storageRef = _storage.refFromURL(url);
      await storageRef.delete();
      await _databaseRef.child('user_audio/${user.uid}/$key').remove();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete audio: $e')),
      );
    }
  }

  Future<void> _renameAudio(String key, String currentName) async {
    final TextEditingController controller =
        TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Audio'),
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
              child: const Text('Rename'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio renamed successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename audio: $e')),
        );
      }
    }
  }

  Future<void> _playAudio(String url) async {
    try {
      if (_isPlaying && _currentPlayingUrl == url) {
        await _audioPlayer.stopPlayer();
        _playerSubscription?.cancel();
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _currentPlayingUrl = null;
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
            _currentPlayingUrl = null;
          });
        },
      );
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
        _currentPlayingUrl = url;
      });
    } catch (e) {
      print('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play audio: $e')),
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
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                imagePath,
                width: 90,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 20),
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
