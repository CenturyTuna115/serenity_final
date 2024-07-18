import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:serenity_mobile/resources/common/toast.dart';
import 'chat.dart'; // Import the chat screen

class FriendRequestList extends StatefulWidget {
  @override
  _FriendRequestListState createState() => _FriendRequestListState();
}

class _FriendRequestListState extends State<FriendRequestList> {
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> searchResults = [];

  @override
  void initState() {
    super.initState();
    fetchFriends();
  }

  void fetchFriends() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentReference userDocRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      DocumentSnapshot userDoc = await userDocRef.get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        List friendIds =
            userData['friends']?.where((id) => id != null).toList() ?? [];

        if (friendIds.isNotEmpty) {
          QuerySnapshot friendsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: friendIds)
              .get();

          setState(() {
            friends = friendsSnapshot.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();
          });
        } else {
          setState(() {
            friends = [];
          });
        }
      }
    }
  }

  void searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
      });
      return;
    }

    QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: query)
        .get();

    setState(() {
      searchResults = usersSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    });
  }

  void addFriend(Map<String, dynamic> user) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentReference userDocRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      DocumentSnapshot userDoc = await userDocRef.get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      List friendIds =
          userData['friends']?.where((id) => id != null).toList() ?? [];

      if (!friendIds.contains(user['uid'])) {
        friendIds.add(user['uid']);
        await userDocRef.update({'friends': friendIds});
        fetchFriends();

        // Show success notification using custom toast
        showToast(
            message: '${user['full_name']} has been added to your friends.');

        // Ensure the UI updates after adding the friend
        setState(() {
          friends.add(user);
        });
      }
    }
  }

  void removeFriend(String friendId) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentReference userDocRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      DocumentSnapshot userDoc = await userDocRef.get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      List friendIds =
          userData['friends']?.where((id) => id != null).toList() ?? [];

      if (friendIds.contains(friendId)) {
        friendIds.remove(friendId);
        await userDocRef.update({'friends': friendIds});
        fetchFriends();

        // Ensure the UI updates after removing the friend
        setState(() {
          friends.removeWhere((friend) => friend['uid'] == friendId);
        });
      }
    }
  }

  void startChat(String friendId, String friendName, String friendAvatar) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          userName: friendName,
          userAvatar: friendAvatar,
          userId: friendId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFD7E9D7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF92A68A),
        title: Image.asset(
          'assets/logo.png',
          height: 40,
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                searchUsers(value);
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Add your friend!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: searchResults.isEmpty
                ? ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      var friend = friends[index];
                      return FriendTile(
                        friendName: friend['full_name'] ?? 'Unknown Friend',
                        avatarUrl: friend['avatar'] ?? 'assets/dino.png',
                        friendId: friend['uid'],
                        onRemove: friend['uid'] != null
                            ? () => removeFriend(friend['uid'])
                            : null,
                        onStartChat: friend['uid'] != null
                            ? () => startChat(
                                  friend['uid'],
                                  friend['full_name'],
                                  friend['avatar'] ?? 'assets/dino.png',
                                )
                            : null,
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      var user = searchResults[index];
                      bool isFriend =
                          friends.any((friend) => friend['uid'] == user['uid']);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['avatar'] != null
                              ? NetworkImage(user['avatar'])
                              : AssetImage('assets/dino.png') as ImageProvider,
                        ),
                        title: Text(user['full_name'] ?? 'Unknown User'),
                        subtitle: Text(isFriend ? 'Friend' : 'Add as Friend'),
                        trailing: isFriend
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.chat),
                                    onPressed: user['uid'] != null
                                        ? () => startChat(
                                              user['uid'],
                                              user['full_name'],
                                              user['avatar'] ??
                                                  'assets/dino.png',
                                            )
                                        : null,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete),
                                    onPressed: user['uid'] != null
                                        ? () => removeFriend(user['uid'])
                                        : null,
                                  ),
                                ],
                              )
                            : IconButton(
                                icon: Icon(Icons.add),
                                onPressed: () => addFriend(user),
                              ),
                      );
                    },
                  ),
          ),
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
    );
  }
}

class FriendTile extends StatelessWidget {
  final String friendName;
  final String avatarUrl;
  final String? friendId;
  final VoidCallback? onRemove;
  final VoidCallback? onStartChat;

  FriendTile({
    required this.friendName,
    required this.avatarUrl,
    this.friendId,
    this.onRemove,
    this.onStartChat,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatarUrl != null
            ? NetworkImage(avatarUrl)
            : AssetImage('assets/dino.png') as ImageProvider,
      ),
      title: Text(friendName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onStartChat != null)
            IconButton(
              icon: Icon(Icons.chat),
              onPressed: onStartChat,
            ),
          if (onRemove != null)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
