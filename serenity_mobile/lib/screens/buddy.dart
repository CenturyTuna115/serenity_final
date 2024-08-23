import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:contacts_service/contacts_service.dart';

class BuddyScreen extends StatefulWidget {
  @override
  _BuddyScreenState createState() => _BuddyScreenState();
}

class _BuddyScreenState extends State<BuddyScreen> {
  List<Map<String, dynamic>> _buddies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBuddies();
  }

  Future<void> _fetchBuddies() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userBuddiesRef = FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}/buddies');
      DatabaseEvent event = await userBuddiesRef.once();

      if (event.snapshot.exists) {
        Map<dynamic, dynamic> buddiesData =
            event.snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> buddiesList = [];
        buddiesData.forEach((key, value) {
          buddiesList.add({
            'key': key, // Store the Firebase key for later removal
            'contact': Contact(
              displayName: value['displayName'],
              phones: [Item(label: "mobile", value: value['phoneNumber'])],
            ),
          });
        });

        setState(() {
          _buddies = buddiesList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _removeBuddy(String key) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userBuddiesRef = FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}/buddies/$key');

      userBuddiesRef.remove().then((_) {
        setState(() {
          _buddies.removeWhere((buddy) => buddy['key'] == key);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Buddy has been removed.')),
        );
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove buddy: $error')),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Support Buddies'),
        backgroundColor: const Color(0xFF6D9773),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buddies.isEmpty
              ? Center(child: Text('No buddies found.'))
              : ListView.builder(
                  itemCount: _buddies.length,
                  itemBuilder: (context, index) {
                    final buddy = _buddies[index]['contact'] as Contact;
                    final key = _buddies[index]['key'] as String;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundImage:
                            AssetImage('assets/dino.png'), // Default avatar
                      ),
                      title: Text(buddy.displayName ?? 'Unknown'),
                      subtitle: Text(buddy.phones?.isNotEmpty ?? false
                          ? buddy.phones!.first.value!
                          : 'No phone number'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _removeBuddy(key);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
