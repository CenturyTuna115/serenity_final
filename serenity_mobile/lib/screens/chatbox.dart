import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    return ListView(
      children: [
        ChatItem(name: 'Shawn', message: 'hey are u okay?', avatar: 'assets/avatar1.png'),
        ChatItem(name: 'Bunb', message: 'hey are u okay?', avatar: 'assets/avatar2.png'),
        ChatItem(name: 'Max', message: 'bro do u want me to call ur mom?', avatar: 'assets/avatar3.png'),
        ChatItem(name: 'Marga', message: 'stay calm nj!!', avatar: 'assets/avatar4.png'),
        ChatItem(name: 'Miki', message: 'dude! choose the gesture!', avatar: 'assets/avatar5.png'),
        ChatItem(name: 'Shain', message: 'hey u can call me for appointment.', avatar: 'assets/avatar6.png'),
      ],
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

  ChatItem({required this.name, required this.message, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GestureDetector(
        onTap: () {
          if (name == 'Shawn') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatScreen(userName: name, userAvatar: avatar)),
            );
          }
        },
        child: CircleAvatar(
          backgroundImage: AssetImage(avatar),
        ),
      ),
      title: Text(name),
      subtitle: Text(message),
      trailing: Icon(Icons.circle, color: Colors.red, size: 10),
    );
  }
}
