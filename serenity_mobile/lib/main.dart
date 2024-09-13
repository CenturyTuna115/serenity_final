import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:serenity_mobile/screens/splashScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Serenity',
      theme: ThemeData(
        primarySwatch: Colors.green,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFFFFA726),
          unselectedItemColor: Color(0xFF94AF94),
          backgroundColor: Color(0xFFF6F4EE),
          selectedIconTheme: IconThemeData(size: 24.0),
          unselectedIconTheme: IconThemeData(size: 24.0),
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: SplashScreen(), // Set the SplashScreen as the initial screen
    );
  }
}
