import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'homepage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class UserEdit extends StatefulWidget {
  @override
  _UserEditState createState() => _UserEditState();
}

class _UserEditState extends State<UserEdit> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  File? _profileImage;
  String? _profileImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}')
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone_number'] ?? '';
          _profileImageUrl = data['profile_image'] ?? '';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_profileImage == null) return null;

    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images/${user.uid}.jpg');

      await storageRef.putFile(_profileImage!);
      final downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _isUploading = false;
        _profileImageUrl = downloadUrl;
      });

      return downloadUrl;
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: const Color(0xFF92A68A),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: null, // Disabled but kept for visual consistency
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : (_profileImageUrl != null &&
                                    _profileImageUrl!.isNotEmpty)
                                ? NetworkImage(_profileImageUrl!)
                                : AssetImage('assets/dino.png')
                                    as ImageProvider,
                      ),
                      if (_isUploading)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black54,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length != 11) {
                    return 'Phone number must be 11 digits';
                  }
                  return null;
                },
                keyboardType: TextInputType.phone,
                maxLength: 11,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        final imageUrl = await _uploadImage();
                        final updates = {
                          'email': _emailController.text,
                          'phone_number': _phoneController.text,
                          'profile_image': imageUrl ?? '',
                        };

                        final databaseRef = FirebaseDatabase.instance
                            .ref('administrator/users/${user.uid}');
                        print('Attempting to update database with: $updates');

                        try {
                          await databaseRef.update(updates);
                          print('Database update successful');

                          // Save profile image URL to SharedPreferences
                          final prefs = await SharedPreferences.getInstance();
                          if (imageUrl != null) {
                            await prefs.setString('profileImageUrl', imageUrl);
                            // Force update the profile image in all screens
                            await FirebaseDatabase.instance
                                .ref(
                                    'administrator/users/${user.uid}/profile_image')
                                .set(imageUrl ?? '');
                          } else if (_profileImageUrl != null) {
                            await prefs.setString(
                                'profileImageUrl', _profileImageUrl!);
                            await FirebaseDatabase.instance
                                .ref(
                                    'administrator/users/${user.uid}/profile_image')
                                .set(_profileImageUrl!);
                          }
                          // Notify listeners of changes
                          if (mounted) {
                            Navigator.of(context).pop();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => HomePage(),
                              ),
                            );
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Profile updated successfully')),
                          );
                          Navigator.pop(context);
                        } catch (dbError) {
                          print('Database error: $dbError');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text('Database update failed: $dbError')),
                          );
                        }
                      }
                    } catch (e) {
                      print('General error: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating profile: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF92A68A),
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text('Save Changes', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
