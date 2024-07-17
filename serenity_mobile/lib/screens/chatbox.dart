import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat.dart'; // Import the ChatScreen

class ChatBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Number of tabs
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF92A68A),
          title: Image.asset(
            'assets/logo.png',
            height: 40,
          ),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'messages'),
              Tab(text: 'calls'),
              Tab(text: 'Activity'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // Add search functionality here
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // Add more options functionality here
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            MessagesTab(),
            CallsTab(),
            ActivityTab(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: const Color(0xFF92A68A),
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
          selectedItemColor: const Color(0xFFFFA726),
          unselectedItemColor: const Color(0xFF94AF94),
          onTap: (index) {
            // Handle navigation for bottom navigation items
          },
        ),
      ),
    );
  }
}

class MessagesTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        var users = snapshot.data!.docs;
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var user = users[index].data() as Map<String, dynamic>;
            return ChatItem(
              name: user['username'], // Use the username field
              message: 'Tap to chat', // Placeholder message
              avatar: user['avatar'] ?? 'assets/dino.png', // Default avatar if not provided
              userId: users[index].id,
            );
          },
        );
      },
    );
  }
}

class CallsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Calls Tab'),
    );
  }
}

class ActivityTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Activity Tab'),
    );
  }
}

class ChatItem extends StatelessWidget {
  final String name;
  final String message;
  final String avatar;
  final String userId;

  ChatItem({required this.name, required this.message, required this.avatar, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GestureDetector(
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
        child: CircleAvatar(
          backgroundImage: NetworkImage(avatar),
        ),
      ),
      title: Text(name),
      subtitle: Text(message),
      trailing: Icon(Icons.circle, color: Colors.red, size: 10),
    );
  }
}
