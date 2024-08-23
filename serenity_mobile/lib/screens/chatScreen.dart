import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String userName;
  final String userAvatar;
  final String userId;

  ChatScreen({required this.userName, required this.userAvatar, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(userName),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: Center(
        child: Text('Chat with $userName'),
      ),
    );
  }
}
