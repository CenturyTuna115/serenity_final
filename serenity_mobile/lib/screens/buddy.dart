import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:serenity_mobile/screens/contacts.dart';

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
    _checkFirstTimeUser();
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('isFirstTimeBuddy') ?? true;

    if (isFirstTime && mounted) {
      await prefs.setBool('isFirstTimeBuddy', false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _buddies.isEmpty) {
          _showAddBuddyDialog();
        }
      });
    }
  }

  Future<void> _showAddBuddyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Support Buddy'),
          content: const Text(
              'Would you like to add a support buddy from your contacts?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Later'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Add Now'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Contacts()),
                );
              },
            ),
          ],
        );
      },
    );
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
        backgroundColor: const Color(0xFF92A68A),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buddies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No buddies found.'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showAddBuddyDialog,
                        child: Text('Add Support Buddy'),
                      ),
                    ],
                  ),
                )
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
                        icon: Icon(Icons.delete, color: Colors.black),
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
