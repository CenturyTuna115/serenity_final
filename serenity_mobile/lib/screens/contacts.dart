import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chatbox.dart';
import 'homepage.dart';
import 'login.dart';
import 'emergencymode.dart';
import 'buddy.dart'; // Import the BuddyScreen

class Contacts extends StatefulWidget {
  @override
  _ContactsState createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
  List<Contact> _contacts = [];
  bool _isLoading = true;
  Map<String, bool> _addedBuddies = {};

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _fetchAddedBuddies();
  }

  Future<void> _fetchContacts() async {
    PermissionStatus permissionStatus = await Permission.contacts.status;

    if (permissionStatus != PermissionStatus.granted) {
      permissionStatus = await Permission.contacts.request();
      if (permissionStatus != PermissionStatus.granted) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    try {
      Iterable<Contact> contacts =
          await ContactsService.getContacts(withThumbnails: false);
      setState(() {
        _contacts = contacts.toList();
        _isLoading = false;
      });
    } catch (e) {
      print(e.toString());
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAddedBuddies() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userBuddiesRef = FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}/buddies');
      DatabaseEvent event = await userBuddiesRef.once();
      if (event.snapshot.exists) {
        Map<dynamic, dynamic> buddiesData =
            event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          buddiesData.forEach((key, value) {
            _addedBuddies[key] = true;
          });
        });
      }
    }
  }

  void _callContact(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  void _toggleBuddy(Contact contact) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final identifier = contact.identifier ?? '';
      if (identifier.isEmpty) return;

      DatabaseReference userBuddiesRef = FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}/buddies');

      setState(() {
        bool isAdded = _addedBuddies[identifier] ?? false;
        _addedBuddies[identifier] = !isAdded;

        if (!isAdded) {
          // Add buddy to Firebase
          userBuddiesRef.child(identifier).set({
            'displayName': contact.displayName ?? 'Unknown',
            'phoneNumber': contact.phones?.isNotEmpty ?? false
                ? contact.phones!.first.value!
                : 'No phone number',
          });
        } else {
          // Remove buddy from Firebase
          userBuddiesRef.child(identifier).remove();
        }

        String message = isAdded
            ? 'You have removed your friend as your support buddy.'
            : 'You have added your friend as your support buddy.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: 2),
          ),
        );
      });
    }
  }

  List<Contact> _getAddedBuddies() {
    return _contacts.where((contact) {
      final identifier = contact.identifier ?? '';
      return _addedBuddies[identifier] ?? false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6D9773),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            Text('Contact List'),
            Spacer(),
            IconButton(
              icon: Icon(CupertinoIcons.group, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BuddyScreen(), // Removed 'buddies' parameter
                  ),
                );
              },
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
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
                // Implement search functionality
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                var contact = _contacts[index];
                final identifier = contact.identifier ?? '';
                bool isAdded = _addedBuddies[identifier] ?? false;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        AssetImage('assets/dino.png'), // Default avatar
                  ),
                  title: Text(
                    contact.displayName ?? 'Unknown',
                    style: TextStyle(
                      color: Color(0xFF388443),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Contact\n', // Placeholder text
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        TextSpan(
                          text: contact.phones?.isNotEmpty ?? false
                              ? contact.phones!.first.value!
                              : 'No phone number',
                          style: TextStyle(
                            color: Color(0xFFB46617),
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.call, color: Colors.green),
                        onPressed: () {
                          if (contact.phones?.isNotEmpty ?? false) {
                            _callContact(contact.phones!.first.value!);
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(isAdded ? Icons.check : Icons.add,
                            color: isAdded ? Colors.green : Colors.blue),
                        onPressed: () {
                          _toggleBuddy(contact);
                        },
                      ),
                    ],
                  ),
                );
              },
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
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatBox()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Emergencymode()),
            );
          } else if (index == 3) {
            FirebaseAuth.instance.signOut();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
              (Route<dynamic> route) => false,
            );
          }
        },
      ),
    );
  }
}
