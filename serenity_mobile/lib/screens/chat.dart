import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String userName;
  final String userAvatar;
  final String userId;

  ChatScreen({
    required this.userName,
    required this.userAvatar,
    required this.userId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref('administrator/chats');
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _fetchChatHistory();
  }

  void _fetchChatHistory() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    String chatRoomId = _getChatRoomId(currentUser.uid, widget.userId);

    try {
      _dbRef
          .child(chatRoomId)
          .orderByChild('timestamp')
          .onValue
          .listen((event) {
        if (event.snapshot.exists) {
          List<Map<String, dynamic>> tempMessages = [];
          Map<dynamic, dynamic> messagesData =
              event.snapshot.value as Map<dynamic, dynamic>;

          messagesData.forEach((key, value) {
            tempMessages.add({
              'message': value['message'],
              'senderId': value['senderId'],
              'timestamp': value['timestamp'],
            });
          });

          tempMessages.sort((a, b) {
            return DateTime.parse(a['timestamp'])
                .compareTo(DateTime.parse(b['timestamp']));
          });

          setState(() {
            _messages = tempMessages;
          });

          _scrollToBottom();
        }
      });
    } catch (e) {
      // Handle errors here if needed
    }
  }

  String _getChatRoomId(String userId, String doctorId) {
    return '$doctorId-$userId';
  }

  void _sendMessage() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    String chatRoomId = _getChatRoomId(currentUser.uid, widget.userId);

    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      String messageId = _dbRef.child(chatRoomId).push().key ?? '';

      try {
        await _dbRef.child('$chatRoomId/$messageId').set({
          'message': message,
          'senderId': currentUser.uid,
          'timestamp': DateTime.now().toIso8601String(),
        });

        setState(() {
          _messageController.clear();
        });

        _scrollToBottom();
      } catch (e) {
        // Handle errors here if needed
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      DateTime dateTime = DateTime.parse(timestamp).toUtc();
      dateTime = dateTime.add(Duration(hours: 8));
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF92A68A),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.userAvatar),
            ),
            SizedBox(width: 10),
            Text(widget.userName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                var message = _messages[index];
                bool isSent = message['senderId'] ==
                    FirebaseAuth.instance.currentUser!.uid;
                return Align(
                  alignment:
                      isSent ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSent ? Colors.green[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.all(10),
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Column(
                      crossAxisAlignment: isSent
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['message'],
                          style: TextStyle(color: Colors.black),
                        ),
                        Text(
                          _formatTimestamp(message['timestamp']),
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
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
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
