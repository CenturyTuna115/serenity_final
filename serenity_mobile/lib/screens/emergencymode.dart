import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'homepage.dart';
import 'messages.dart'; // Import MessagesTab
import 'login.dart'; // Import Login screen
import 'package:firebase_auth/firebase_auth.dart';

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
  int _shakeCount = 0;
  late StreamSubscription<AccelerometerEvent> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = accelerometerEvents.listen((AccelerometerEvent event) {
      double deltaX = (event.x - _lastX).abs();
      double deltaY = (event.y - _lastY).abs();
      double deltaZ = (event.z - _lastZ).abs();

      if (deltaX > _shakeThreshold ||
          deltaY > _shakeThreshold ||
          deltaZ > _shakeThreshold) {
        _shakeCount++;
        if (_shakeCount > 2) {
          _playAudio();
          _shakeCount = 0;
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
            icon: Icon(CupertinoIcons.square_arrow_right),
            label: '',
          ),
        ],
        currentIndex: widget.currentIndex,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Color(0xFF94AF94),
        iconSize: 30.0, // Consistent icon size
        selectedFontSize: 0.0,
        unselectedFontSize: 0.0,
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
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
            // Stay on the current page since it's already the emergency mode
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
