import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:lottie/lottie.dart';  // Import Lottie package
import 'dart:async';
import 'homepage.dart'; 
import 'messages.dart'; // Import MessagesTab
import 'emergencymode.dart';
import 'login.dart'; // Import Login screen

class Emergencymode extends StatefulWidget {
  const Emergencymode({super.key});

  @override
  _EmergencymodeState createState() => _EmergencymodeState();
}

class _EmergencymodeState extends State<Emergencymode> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  double _shakeThreshold = 25.0;  // Increase the threshold to make it less sensitive
  double _lastX = 0.0, _lastY = 0.0, _lastZ = 0.0;
  int _shakeCount = 0;
  int _requiredShakeCount = 3; // More shakes required
  late StreamSubscription<AccelerometerEvent> _subscription;
  bool _audioPlayedRecently = false; // Cooldown flag

  @override
  void initState() {
    super.initState();
    _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      double deltaX = (event.x - _lastX).abs();
      double deltaY = (event.y - _lastY).abs();
      double deltaZ = (event.z - _lastZ).abs();

      if ((deltaX > _shakeThreshold || deltaY > _shakeThreshold || deltaZ > _shakeThreshold) && !_audioPlayedRecently) {
        _shakeCount++;
        if (_shakeCount >= _requiredShakeCount) {
          _playAudio();
          _shakeCount = 0;
          _audioPlayedRecently = true;
          _startCooldown(); // Start cooldown after playing audio
        }
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

  // Cooldown timer to prevent frequent audio plays
  void _startCooldown() {
    Timer(const Duration(seconds: 10), () {
      _audioPlayedRecently = false;
    });
  }

  void _playAudio() async {
    await _audioPlayer.play(AssetSource('audio/audio3.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCEDFCC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF92A68A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.left_chevron, color: Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
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
            // Larger Lottie animation
            Container(
              width: 300,  // Increase the size
              height: 300, // Increase the size
              child: Lottie.asset(
                'assets/animation/calm.json', // Path to Lottie animation
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 50),
            const Text(
              'Now Playing',
              style: TextStyle(
                color: Color(0xFFBABABA),
                fontSize: 18,
              ),
            ),
            const Text(
              'Breathing Exercise',
              style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF92A68A),
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
            icon: Icon(CupertinoIcons.square_arrow_right),
            label: '',
          ),
        ],
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Color(0xFF94AF94),
        selectedFontSize: 0.0,  // Ensures icons stay aligned
        unselectedFontSize: 0.0, // Ensures icons stay aligned
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MessagesTab()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Emergencymode()),
            );
          } else if (index == 3) {
            _logout(context);
          }
        },
      ),
    );
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }
}
