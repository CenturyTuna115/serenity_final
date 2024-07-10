import 'package:flutter/material.dart';
import 'package:serenity_mobile/screens/emergencymode.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure all plugins are initialized
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]) // Optional: to lock orientation
      .then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Serenity',
      home: Emergencymode(),
    );
  }
}
