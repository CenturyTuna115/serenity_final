import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'buddy.dart'; // Import the BuddyScreen

class Contacts extends StatefulWidget {
  @override
  _ContactsState createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = []; // For filtered contacts based on search
  bool _isLoading = true;
  Map<String, dynamic> _addedBuddies = {};
  String _searchQuery = '';

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
        _filteredContacts = _contacts;
        _isLoading = false;
      });
    } catch (e) {
      print(e.toString());
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterContacts(String query) {
    List<Contact> filtered = _contacts.where((contact) {
      return contact.displayName?.toLowerCase().contains(query.toLowerCase()) ??
          false;
    }).toList();
    setState(() {
      _filteredContacts = filtered;
    });
  }

  Future<void> _callContact(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _fetchAddedBuddies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dbRef = FirebaseDatabase.instance
        .ref('administrator/users/${user.uid}/buddies');
    final snapshot = await dbRef.get();

    if (snapshot.exists) {
      final buddies = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        _addedBuddies = buddies.map((key, value) =>
            MapEntry(key, value != null)); // Convert to simple bool presence
      });
    }
  }

  Future<void> _toggleBuddy(Contact contact) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final identifier = contact.identifier ?? '';
    final isAdded = _addedBuddies.containsKey(identifier);
    final dbRef = FirebaseDatabase.instance
        .ref('administrator/users/${user.uid}/buddies/$identifier');

    if (isAdded) {
      await dbRef.remove();
    } else {
      await dbRef.set({
        'displayName': contact.displayName ?? 'Unknown',
        'phoneNumber': contact.phones?.isNotEmpty ?? false
            ? contact.phones!.first.value!
            : 'No phone number'
      });
    }

    setState(() {
      if (isAdded) {
        _addedBuddies.remove(identifier);
      } else {
        _addedBuddies[identifier] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF92A68A),
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
                    builder: (context) => BuddyScreen(),
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
                _filterContacts(value);
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _filteredContacts.length,
              itemBuilder: (context, index) {
                var contact = _filteredContacts[index];
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
    );
  }
}
