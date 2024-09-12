import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:serenity_mobile/screens/chat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/screens/voicecallscreen.dart';
import 'dart:math';
import 'homepage.dart';
import 'emergencymode.dart';
import 'login.dart';

class MessagesTab extends StatelessWidget {
  final int currentIndex;

  const MessagesTab({Key? key, this.currentIndex = 1}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages'),
        backgroundColor: Color(0xFF92A68A),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => HomePage(currentIndex: 0)),
            );
          },
        ),
      ),
      body: MessagesListTab(),
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
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Color(0xFF94AF94),
        selectedFontSize: 0.0, // Ensures the icons stay aligned
        unselectedFontSize: 0.0, // Ensures the icons stay aligned
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => HomePage(currentIndex: 0)),
            );
          } else if (index == 1) {
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => Emergencymode(currentIndex: 2)),
            );
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

class MessagesListTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    User? currentUser = FirebaseAuth.instance.currentUser;
    final DatabaseReference dbRef =
        FirebaseDatabase.instance.ref('administrator/chats');

    return StreamBuilder<DatabaseEvent>(
      stream: dbRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
          return Center(child: Text('No messages found.'));
        }

        Map<dynamic, dynamic> chatsData =
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        List<ChatSummary> chatSummaries = [];

        for (var chatRoomId in chatsData.keys) {
          if (chatRoomId.contains(currentUser!.uid)) {
            var messagesMap = chatsData[chatRoomId] as Map<dynamic, dynamic>;

            var sortedMessages = messagesMap.entries.toList()
              ..sort((a, b) {
                DateTime dateA = DateTime.parse(a.value['timestamp']);
                DateTime dateB = DateTime.parse(b.value['timestamp']);
                return dateB.compareTo(dateA);
              });

            var lastMessage = sortedMessages.first.value;

            String doctorId = chatRoomId.substring(
                0, chatRoomId.indexOf(currentUser.uid) - 1);

            chatSummaries.add(ChatSummary(
              chatRoomId: chatRoomId,
              lastMessage: lastMessage['message'] ?? 'No message available',
              lastTimestamp: lastMessage['timestamp'] ?? '',
              withUserId: doctorId,
              isDoctor: doctorId == currentUser.uid,
            ));
          }
        }

        chatSummaries.sort((a, b) {
          DateTime dateA = DateTime.parse(a.lastTimestamp);
          DateTime dateB = DateTime.parse(b.lastTimestamp);
          return dateB.compareTo(dateA);
        });

        return ListView.builder(
          itemCount: chatSummaries.length,
          itemBuilder: (context, index) {
            ChatSummary chatSummary = chatSummaries[index];

            return StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('administrator/doctors/${chatSummary.withUserId}')
                  .onValue,
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return ListTile(
                    leading: CircularProgressIndicator(),
                    title: Text('Loading...'),
                    subtitle: Text('Fetching doctor info...'),
                  );
                } else if (userSnapshot.hasError) {
                  return ChatItem(
                    name: 'Error',
                    message: 'Failed to load doctor data',
                    avatar: 'assets/dino.png',
                    userId: chatSummary.withUserId,
                    chatRoomId: chatSummary.chatRoomId,
                  );
                } else if (!userSnapshot.hasData ||
                    !userSnapshot.data!.snapshot.exists) {
                  return ChatItem(
                    name: 'Unknown Doctor',
                    message: chatSummary.lastMessage,
                    avatar: 'assets/dino.png',
                    userId: chatSummary.withUserId,
                    chatRoomId: chatSummary.chatRoomId,
                  );
                }

                var userData =
                    userSnapshot.data!.snapshot.value as Map<dynamic, dynamic>;

                return ChatItem(
                  name: userData['name'] ?? 'Unknown Doctor',
                  message: chatSummary.lastMessage,
                  avatar: userData['profilePic'] ?? 'assets/dino.png',
                  userId: chatSummary.withUserId,
                  chatRoomId: chatSummary.chatRoomId,
                );
              },
            );
          },
        );
      },
    );
  }
}

class ChatSummary {
  final String chatRoomId;
  final String lastMessage;
  final String lastTimestamp;
  final String withUserId;
  final bool isDoctor;

  ChatSummary({
    required this.chatRoomId,
    required this.lastMessage,
    required this.lastTimestamp,
    required this.withUserId,
    required this.isDoctor,
  });
}

class ChatItem extends StatelessWidget {
  final String name;
  final String message;
  final String avatar;
  final String userId;
  final String chatRoomId;

  ChatItem({
    required this.name,
    required this.message,
    required this.avatar,
    required this.userId,
    required this.chatRoomId,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatar.startsWith('assets/')
            ? AssetImage(avatar) as ImageProvider
            : NetworkImage(avatar),
      ),
      title: Text(name),
      subtitle: Text(message),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.call, color: Color(0xFF4CAF50)),
            onPressed: () => _startVoiceCall(context, userId, avatar),
          ),
          Icon(Icons.circle, color: Colors.red, size: 10),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              userName: name,
              userAvatar: avatar,
              userId: userId,
            ),
          ),
        );
      },
    );
  }

  void _startVoiceCall(
      BuildContext context, String doctorId, String doctorAvatar) async {
    // Generate a random channel name
    String channelName = 'channel_${Random().nextInt(1000)}';
    String token =
        'your_generated_token'; // Replace with actual token generation logic

    // Reference to the Firebase Realtime Database
    DatabaseReference dbRef =
        FirebaseDatabase.instance.ref('agoraChannels').child(channelName);

    // Store the channel information in Firebase
    await dbRef.set({
      'channelName': channelName,
      'token': token,
      'doctorId': doctorId,
    });

    // Pass the generated channelName (channelId) to the VoiceCallScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VoiceCallScreen(
          doctorAvatar: doctorAvatar,
          doctorName: name, // Replace 'Doctor' with the actual doctor's name
          channelId: channelName, // Pass the generated channelName as channelId
        ),
      ),
    );
  }
}
