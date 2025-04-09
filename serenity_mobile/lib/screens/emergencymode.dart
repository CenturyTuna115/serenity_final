import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:serenity_mobile/screens/doctor_notes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'homepage.dart';
import 'messages.dart'; // Import MessagesTab
import 'package:serenity_mobile/widgets/app_bottom_nav_bar.dart';

class Emergencymode extends StatefulWidget {
  final int currentIndex;

  const Emergencymode({Key? key, this.currentIndex = 2}) : super(key: key);

  @override
  _EmergencymodeState createState() => _EmergencymodeState();
}

class _EmergencymodeState extends State<Emergencymode> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  double _shakeThreshold = 15.0;
  double _lastX = 0.0, _lastY = 0.0, _lastZ = 0.0;
  bool _audioPlaying = false; // Flag to indicate if audio is playing
  bool _audioPlayedRecently = false; // Cooldown flag
  late StreamSubscription<AccelerometerEvent> _subscription;
  String? _selectedAudioUrl;
  String _currentAudioName = 'Breathing Exercise';

  @override
  void initState() {
    super.initState();
    _loadSelectedAudio();
    _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      double deltaX = (event.x - _lastX).abs();
      double deltaY = (event.y - _lastY).abs();
      double deltaZ = (event.z - _lastZ).abs();

      // Detect shake
      if ((deltaX > _shakeThreshold ||
              deltaY > _shakeThreshold ||
              deltaZ > _shakeThreshold) &&
          !_audioPlayedRecently) {
        _playAudio();
        _startCooldown(); // Start cooldown after playing audio
      }

      _lastX = event.x;
      _lastY = event.y;
      _lastZ = event.z;
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSelectedAudio() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAudioUrl = prefs.getString('selected_audio_url');
      _currentAudioName = prefs.getString('selected_audio_name') ??
          (_selectedAudioUrl != null ? 'Custom Audio' : 'Breathing Exercise');
    });
  }

  void _playAudio() async {
    if (_selectedAudioUrl != null) {
      await _audioPlayer.play(UrlSource(_selectedAudioUrl!));
    } else {
      await _audioPlayer.play(AssetSource('audio/audio3.mp3'));
    }
    setState(() {
      _audioPlaying = true;
    });
  }

  void _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _audioPlaying = false; // Hide the cancel button
    });
  }

  // Cooldown timer to prevent repeated playback during continuous shakes
  void _startCooldown() {
    setState(() {
      _audioPlayedRecently = true;
    });
    Timer(const Duration(seconds: 2), () {
      setState(() {
        _audioPlayedRecently = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCEDFCC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF92A68A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => HomePage(currentIndex: 0)),
            );
          },
        ),
        title: const Text(
          'Bell mode',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Image.asset(
              'assets/logo.png',
              width: 50,
              height: 50,
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 250,
              height: 250,
              child: Lottie.asset(
                'assets/animation/calm.json',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Now Playing',
              style: TextStyle(
                color: Color(0xFFBABABA),
                fontSize: 18,
              ),
            ),
            Text(
              _currentAudioName,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Show Cancel Button if Audio is Playing
            if (_audioPlaying)
              ElevatedButton(
                onPressed: _stopAudio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Cancel Audio',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: (index) {
          Widget? nextPage;
          if (index == 0) {
            nextPage = HomePage(currentIndex: 0);
          } else if (index == 1) {
            nextPage = MessagesTab(currentIndex: 1);
          } else if (index == 2) {
            // Stay on the current page since it's already the emergency mode
            return;
          } else if (index == 3) {
            nextPage = const DoctorNotesScreen();
          }

          if (nextPage != null) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => nextPage!, // Added ! operator here
                transitionsBuilder: (_, a, __, c) =>
                    FadeTransition(opacity: a, child: c),
              ),
            );
          }
        },
      ),
    );
  }
}
