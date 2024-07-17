import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BuddyList extends StatefulWidget {
  @override
  _BuddyListState createState() => _BuddyListState();
}

class _BuddyListState extends State<BuddyList> {
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> buddies = [];
  List<Map<String, dynamic>> searchResults = [];

  @override
  void initState() {
    super.initState();
    fetchBuddies();
  }

  void fetchBuddies() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      QuerySnapshot buddiesSnapshot = await FirebaseFirestore.instance
          .collection('buddies')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      setState(() {
        buddies = buddiesSnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
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
        .where('name', isGreaterThanOrEqualTo: query)
        .get();

    setState(() {
      searchResults = usersSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    });
  }

  void addBuddy(Map<String, dynamic> user) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance.collection('buddies').add({
        'userId': currentUser.uid,
        'buddyId': user['uid'],
        'buddyName': user['name'],
        'gesture': 'Panic Attack', // Customize this as needed
        'support': 'Shake gesture', // Customize this as needed
      });
      fetchBuddies();
    }
  }

  void removeBuddy(String buddyId) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      QuerySnapshot buddiesSnapshot = await FirebaseFirestore.instance
          .collection('buddies')
          .where('userId', isEqualTo: currentUser.uid)
          .where('buddyId', isEqualTo: buddyId)
          .get();

      for (var doc in buddiesSnapshot.docs) {
        await FirebaseFirestore.instance.collection('buddies').doc(doc.id).delete();
      }
      fetchBuddies();
    }
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
                hintText: 'Search',
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
              'Choose your Support buddy!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: searchResults.isEmpty
                ? ListView.builder(
                    itemCount: buddies.length,
                    itemBuilder: (context, index) {
                      var buddy = buddies[index];
                      return BuddyTile(
                        buddyName: buddy['buddyName'],
                        gesture: buddy['gesture'],
                        support: buddy['support'],
                        avatarUrl: buddy['avatar'] ?? 'assets/default_avatar.png', // Change this to your default avatar asset
                        onRemove: () => removeBuddy(buddy['buddyId']),
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      var user = searchResults[index];
                      bool isBuddy = buddies.any((buddy) => buddy['buddyId'] == user['uid']);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(user['avatar']),
                        ),
                        title: Text(user['name']),
                        subtitle: Text(isBuddy ? 'Buddy' : 'Add as Buddy'),
                        trailing: isBuddy
                            ? IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () => removeBuddy(user['uid']),
                              )
                            : IconButton(
                                icon: Icon(Icons.add),
                                onPressed: () => addBuddy(user),
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

class BuddyTile extends StatelessWidget {
  final String buddyName;
  final String gesture;
  final String support;
  final String avatarUrl;
  final VoidCallback onRemove;

  BuddyTile({
    required this.buddyName,
    required this.gesture,
    required this.support,
    required this.avatarUrl,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(avatarUrl),
      ),
      title: Text(buddyName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(support),
          Text(
            gesture,
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(Icons.edit),
        onPressed: onRemove,
      ),
    );
  }
}
