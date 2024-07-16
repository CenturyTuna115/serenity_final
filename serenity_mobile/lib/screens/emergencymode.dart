import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'homepage.dart'; // Import HomePage

class Emergencymode extends StatefulWidget {
  const Emergencymode({super.key});

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
    await _audioPlayer.play(AssetSource('audio/serenityaudiodemo.mp3'));
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
          onPressed: () {},
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
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.volume_up,
                  size: 100,
                  color: Color(0xFF6A8065),
                ),
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
            const SizedBox(height: 30),
            const CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(
                  'https://via.placeholder.com/150'), // Placeholder image URL
            ),
            const Text(
              'Messaging buddy',
              style: TextStyle(
                color: Color(0xFFBABABA),
                fontSize: 18,
              ),
            ),
            const Text(
              'Jasper Bahaghari',
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
            icon: Icon(CupertinoIcons.ellipsis),
            label: '',
          ),
        ],
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Color(0xFF92A68A),
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          }
        },
      ),
    );
  }
}
