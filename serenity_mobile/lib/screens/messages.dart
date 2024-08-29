import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat.dart'; // Import the ChatScreen

class MessagesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Messages'),
          backgroundColor: Color(0xFF92A68A),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: MessagesListTab(),
      ),
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
                return dateB.compareTo(dateA); // Most recent first
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
                    avatar: 'assets/dino.png', // Default avatar
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
      trailing: Icon(Icons.circle, color: Colors.red, size: 10),
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
}
