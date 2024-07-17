import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String userName;
  final String userAvatar;
  final String userId;

  ChatScreen({required this.userName, required this.userAvatar, required this.userId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF92A68A),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 20),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(widget.userName),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .where('users', arrayContains: FirebaseAuth.instance.currentUser!.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                var messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index].data() as Map<String, dynamic>;
                    bool isSent = message['senderId'] == FirebaseAuth.instance.currentUser!.uid;
                    return ChatBubble(
                      text: message['message'],
                      time: message['timestamp'].toDate().toString(),
                      isSent: isSent,
                      imageUrl: message['imageUrl'],
                    );
                  },
                );
              },
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
                    controller: messageController,
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
                    sendMessage(messageController.text);
                    messageController.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void sendMessage(String message) {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && message.isNotEmpty) {
      FirebaseFirestore.instance.collection('messages').add({
        'message': message,
        'senderId': currentUser.uid,
        'receiverId': widget.userId,
        'timestamp': FieldValue.serverTimestamp(),
        'users': [currentUser.uid, widget.userId],
      });
    }
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
        crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Image.network(imageUrl!),
            ),
          Container(
            decoration: BoxDecoration(
              color: isSent ? Colors.green[100] : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
