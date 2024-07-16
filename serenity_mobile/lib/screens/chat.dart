import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String userName;
  final String userAvatar;

  ChatScreen({required this.userName, required this.userAvatar});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF92A68A),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 20), // Adjust the size of the arrow
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(userName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () {
              // Add call functionality here
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // Add more options functionality here
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(8.0),
              children: [
                ChatBubble(
                  text: 'Hello, Good afternoon. how may I help?',
                  time: '17:07',
                  isSent: false,
                ),
                ChatBubble(
                  text: 'hello doc!',
                  time: '17:09',
                  isSent: true,
                ),
                ChatBubble(
                  text: 'This is my sched you can appoint 📅',
                  time: '17:12',
                  isSent: false,
                  imageUrl: 'assets/dino.png', // Replace with your image asset
                ),
                ChatBubble(
                  text: 'okay thanks!',
                  time: '17:13',
                  isSent: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.camera_alt),
                  onPressed: () {
                    // Add camera functionality here
                  },
                ),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    // Add send functionality here
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isSent;
  final String? imageUrl;

  ChatBubble({
    required this.text,
    required this.time,
    required this.isSent,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Image.asset(imageUrl!),
            ),
          Container(
            decoration: BoxDecoration(
              color: isSent ? Colors.green[100] : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment:
                  isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(color: Colors.black),
                ),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
