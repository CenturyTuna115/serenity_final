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
      print('No current user found. Exiting fetchChatHistory.');
      return;
    }

    String chatRoomId = _getChatRoomId(currentUser.uid, widget.userId);

    print('Fetching chat history for room ID: $chatRoomId');

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

          // Sort the messages based on timestamp
          tempMessages.sort((a, b) {
            return DateTime.parse(a['timestamp'])
                .compareTo(DateTime.parse(b['timestamp']));
          });

          setState(() {
            _messages = tempMessages;
            _scrollToBottom(); // Auto-scroll to the bottom when new messages are fetched
            print('Fetched ${_messages.length} messages.');
          });
        } else {
          print('No chat history found for room ID: $chatRoomId');
        }
      });
    } catch (e, stacktrace) {
      print('Error fetching chat history: $e');
      print('Stacktrace: $stacktrace');
    }
  }

  String _getChatRoomId(String userId, String doctorId) {
    // Ensure the doctorId always comes first in the chat room ID
    return '$doctorId-$userId';
  }

  void _sendMessage() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('No current user found. Cannot send message.');
      return;
    }

    String chatRoomId = _getChatRoomId(currentUser.uid, widget.userId);

    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      String messageId = _dbRef.child(chatRoomId).push().key ?? '';

      print('Attempting to send message: $message with ID: $messageId');

      try {
        await _dbRef.child('$chatRoomId/$messageId').set({
          'message': message,
          'senderId': currentUser.uid,
          'timestamp': DateTime.now().toIso8601String(),
        });
        print('Message sent successfully');

        setState(() {
          _messageController.clear();
          _scrollToBottom(); // Auto-scroll to the bottom after sending a message
        });
      } catch (e, stacktrace) {
        print('Failed to send message: $e');
        print('Stacktrace: $stacktrace');
      }
    } else {
      print('Message is empty, not sending.');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      // Parse the timestamp into a DateTime object
      DateTime dateTime = DateTime.parse(timestamp).toUtc();

      // Convert to the Philippines timezone (PHT, UTC+8)
      dateTime = dateTime.add(Duration(hours: 8));

      // Format the time to display only the time
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      print('Error formatting timestamp: $e');
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
