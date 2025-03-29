import 'package:flutter/material.dart';

class DoctorNotesScreen extends StatelessWidget {
  const DoctorNotesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Notes'),
      ),
      body: Center(
        child: Text('Doctor Notes Content'),
      ),
    );
  }
}
