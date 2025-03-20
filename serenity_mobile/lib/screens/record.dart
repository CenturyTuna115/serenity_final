import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'dart:async';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({Key? key}) : super(key: key);

  @override
  _RecordsScreenState createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();

  StreamSubscription? _recorderSubscription;
  StreamSubscription? _playerSubscription;

  /// 1 minute max
  final Duration _maxDuration = const Duration(minutes: 1);

  bool _isRecording = false;
  bool _isPausedRecording = false; // For recording pause/resume
  bool _isPlaying = false;
  bool _isPausedPlaying = false; // For playback pause/resume

  String? _recordedFilePath;

  /// For counting **up** during recording
  Duration _recordPosition = Duration.zero;
  Duration _recordDuration =
      Duration.zero; // Always set to 1 minute for the bar

  /// For playback
  Duration _playPosition = Duration.zero;
  Duration _playDuration = Duration.zero;

  late String _recordingName;

  @override
  void initState() {
    super.initState();
    _recordingName = 'Recording ${DateTime.now().millisecondsSinceEpoch}';
    _initAudio();
  }

  /// Configure audio session, request permissions, and open recorder/player
  Future<void> _initAudio() async {
    try {
      final session = await AudioSession.instance;
      // If you get a "constant expression" error, remove `const` below
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
                  AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
            flags: AndroidAudioFlags.none,
          ),
          androidWillPauseWhenDucked: true,
        ),
      );

      // Request permissions
      await Permission.microphone.request();
      await Permission.storage.request();

      // Open recorder and player
      await _audioRecorder.openRecorder();
      await _audioPlayer.openPlayer();

      // Check codec support
      if (!await _audioRecorder.isEncoderSupported(Codec.aacMP4)) {
        throw Exception('AAC codec not supported on this device');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio initialization failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _recorderSubscription?.cancel();
    _playerSubscription?.cancel();
    _audioRecorder.closeRecorder();
    _audioPlayer.closePlayer();
    super.dispose();
  }

  /// Start recording (count **up** from 0 to 1:00)
  Future<void> _startRecording() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _audioRecorder.startRecorder(
        toFile: path,
        codec: Codec.aacMP4,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 128000,
      );

      // Cancel old subscription
      await _recorderSubscription?.cancel();

      // Listen for progress
      _recorderSubscription = _audioRecorder.onProgress?.listen((event) {
        if (!mounted) return;
        final elapsed = event.duration; // how long we've recorded so far

        // If we exceed 1 minute, stop automatically
        if (elapsed >= _maxDuration) {
          _stopRecording();
        } else {
          setState(() {
            // Count up from 0 to 1 minute
            _recordPosition = elapsed;
            _recordDuration = _maxDuration;
          });
        }
      });

      setState(() {
        _isRecording = true;
        _isPausedRecording = false;
        _recordedFilePath = path;

        // Start at 0:00
        _recordPosition = Duration.zero;
        // The "target" is 1 minute
        _recordDuration = _maxDuration;

        // Clear playback states
        _isPlaying = false;
        _isPausedPlaying = false;
        _playPosition = Duration.zero;
        _playDuration = Duration.zero;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  /// Pause/resume recording
  Future<void> _pauseResumeRecording() async {
    if (!_isRecording) return;

    if (_isPausedRecording) {
      // Resume
      await _audioRecorder
          .resumeRecorder(); // might not be supported on all devices
      setState(() => _isPausedRecording = false);
    } else {
      // Pause
      await _audioRecorder.pauseRecorder(); // might not be supported
      setState(() => _isPausedRecording = true);
    }
  }

  /// Stop recording
  Future<void> _stopRecording() async {
    try {
      await _recorderSubscription?.cancel();
      await _audioRecorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _isPausedRecording = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  /// Play the recorded file
  Future<void> _playAudio() async {
    if (_recordedFilePath == null) return;

    try {
      await _playerSubscription?.cancel();
      _playerSubscription = _audioPlayer.onProgress?.listen((event) {
        if (!mounted) return;
        setState(() {
          _playPosition = event.position;
          _playDuration = event.duration;
        });
      });

      await _audioPlayer.startPlayer(
        fromURI: _recordedFilePath,
        codec: Codec.aacMP4,
        whenFinished: () {
          setState(() {
            _isPlaying = false;
            _isPausedPlaying = false;
            _playPosition = Duration.zero;
          });
        },
      );

      setState(() {
        _isPlaying = true;
        _isPausedPlaying = false;
        _playPosition = Duration.zero;
        _playDuration = Duration.zero;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play recording: $e')),
      );
    }
  }

  /// Pause/resume playback
  Future<void> _pauseResumePlayback() async {
    if (_isPlaying && !_isPausedPlaying) {
      // Pause
      await _audioPlayer.pausePlayer();
      setState(() {
        _isPlaying = false;
        _isPausedPlaying = true;
      });
    } else if (_isPausedPlaying) {
      // Resume
      await _audioPlayer.resumePlayer();
      setState(() {
        _isPlaying = true;
        _isPausedPlaying = false;
      });
    }
  }

  /// Stop audio playback
  Future<void> _stopPlaying() async {
    await _playerSubscription?.cancel();
    await _audioPlayer.stopPlayer();
    setState(() {
      _isPlaying = false;
      _isPausedPlaying = false;
      _playPosition = Duration.zero;
    });
  }

  /// Upload
  Future<void> _uploadAudio(String filePath) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user is logged in');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Recorded file not found at $filePath');
      }

      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final reference = FirebaseStorage.instance.ref().child('audio/$fileName');

      final metadata = SettableMetadata(
        contentType: 'audio/mp4',
        customMetadata: {
          'uploaded_by': user.uid,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = reference.putFile(file, metadata);
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      await uploadTask;

      final downloadUrl = await reference.getDownloadURL();

      // Save to Realtime Database
      final audioData = {
        'url': downloadUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'recorded',
        // We'll store how many seconds we recorded in total
        'duration': _recordPosition.inSeconds,
        'name': _recordingName,
      };

      await FirebaseDatabase.instance
          .ref('administrator')
          .child('users')
          .child(user.uid)
          .child('user_audio')
          .push()
          .set(audioData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio uploaded successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
      try {
        await File(filePath).delete();
      } catch (_) {}
    }
  }

  /// Format mm:ss (no hours)
  String _formatDuration(Duration duration) {
    final twoDigits = (int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(duration.inMinutes.remainder(60));
    final s = twoDigits(duration.inSeconds.remainder(60));
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // RECORDING PROGRESS: goes from 0s -> 60s
    final recordProgress = _recordDuration.inSeconds > 0
        ? _recordPosition.inSeconds / _recordDuration.inSeconds
        : 0.0;
    // PLAYBACK PROGRESS: from 0 -> total
    final playProgress = _playDuration.inSeconds > 0
        ? _playPosition.inSeconds / _playDuration.inSeconds
        : 0.0;

    // Decide which progress/timer to show
    double progressValue = 0.0;
    String mainTimer = '00:00 / 01:00'; // default

    if (_isRecording) {
      // Count up: e.g. 00:05 / 01:00
      final now = _formatDuration(_recordPosition);
      final max = _formatDuration(_recordDuration);
      mainTimer = '$now / $max';
      progressValue = recordProgress.clamp(0.0, 1.0);
    } else if (_isPlaying || _isPausedPlaying) {
      final current = _formatDuration(_playPosition);
      final total = _formatDuration(_playDuration);
      mainTimer = '$current / $total';
      progressValue = playProgress.clamp(0.0, 1.0);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Audio (Count Up to 1 min)'),
        backgroundColor: const Color(0xFF92A68A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title text
            if (_isRecording && !_isPausedRecording)
              const Text(
                'Recording...',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              )
            else if (_isRecording && _isPausedRecording)
              const Text(
                'Recording Paused',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              )
            else if (_isPlaying && !_isPausedPlaying)
              const Text(
                'Playing...',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              )
            else if (_isPlaying && _isPausedPlaying)
              const Text(
                'Playback Paused',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              )
            else if (_recordedFilePath != null)
              const Text(
                'Ready to Play or Upload',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

            const SizedBox(height: 20),

            // Progress bar
            LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 20),

            // Timer text
            Text(
              mainTimer,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // RECORDING CONTROLS
                if (_isRecording)
                  IconButton(
                    icon: Icon(
                      _isPausedRecording ? Icons.play_arrow : Icons.pause,
                      size: 40,
                    ),
                    onPressed: _pauseResumeRecording,
                    color: Colors.blue,
                  ),
                if (_isRecording)
                  IconButton(
                    icon: const Icon(Icons.stop, size: 40),
                    onPressed: _stopRecording,
                    color: Colors.red,
                  ),

                // START RECORD
                if (!_isRecording && !_isPlaying && _recordedFilePath == null)
                  IconButton(
                    icon: const Icon(Icons.mic, size: 40),
                    onPressed: _startRecording,
                    color: Colors.red,
                  ),

                // PLAYBACK CONTROLS
                if (!_isRecording && _recordedFilePath != null)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, size: 40),
                    onPressed: _isPlaying ? null : _playAudio,
                    color: _isPlaying ? Colors.grey : Colors.green,
                  ),
                if (_isPlaying)
                  IconButton(
                    icon: Icon(
                      _isPausedPlaying ? Icons.play_arrow : Icons.pause,
                      size: 40,
                    ),
                    onPressed: _pauseResumePlayback,
                    color: Colors.blue,
                  ),
                if (_isPlaying)
                  IconButton(
                    icon: const Icon(Icons.stop, size: 40),
                    onPressed: _stopPlaying,
                    color: Colors.red,
                  ),
              ],
            ),

            // After Recording: user can Delete, Re-record, or Upload
            if (!_isRecording && _recordedFilePath != null && !_isPlaying)
              Column(
                children: [
                  const SizedBox(height: 20),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Recording Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _recordingName = value,
                    controller: TextEditingController(text: _recordingName),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Delete local file
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _recordedFilePath = null;
                            _recordPosition = Duration.zero;
                            _recordDuration = Duration.zero;
                            _playPosition = Duration.zero;
                            _playDuration = Duration.zero;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                      const SizedBox(width: 20),

                      // Re-record
                      ElevatedButton(
                        onPressed: _startRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text('Re-record'),
                      ),
                      const SizedBox(width: 20),

                      // Upload
                      ElevatedButton(
                        onPressed: () async {
                          if (_recordedFilePath != null) {
                            await _uploadAudio(_recordedFilePath!);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Upload'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
