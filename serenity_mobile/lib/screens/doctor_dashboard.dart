import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/screens/doctor_notes.dart';
import 'package:serenity_mobile/utils/auth_utils.dart';
import 'doctor_card.dart';
import 'homepage.dart';
import 'login.dart';
import 'messages.dart';
import 'emergencymode.dart';
import 'package:lottie/lottie.dart'; // Import Lottie package

class DoctorDashboard extends StatefulWidget {
  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> allDoctors = [];
  List<Map<String, dynamic>> favoriteDoctors = [];
  List<Map<String, dynamic>> recommendedDoctors = [];
  String searchQuery = '';
  bool isSearching = false;
  List<dynamic> userConditions = [];
  bool isLoading = true;
  bool showSkipButton = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this); // 3 Tabs: All, Favorites, Recommendations
    _checkSkipOrDoctorAssigned();
    _fetchUserConditionAndDoctors();
  }

  void _checkSkipOrDoctorAssigned() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('administrator/users/${user.uid}');
      DataSnapshot snapshot = await userRef.get();

      if (snapshot.exists) {
        Map<String, dynamic> userData =
            Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
        bool skipClicked = userData['skip_clicked'] ?? false;
        bool assignedDoctor = userData['assigned_doctor'] ?? false;

        // Show skip button only if the user hasn't clicked skip or assigned a doctor
        if (!skipClicked && !assignedDoctor) {
          setState(() {
            showSkipButton = true;
          });
        }
      }
    }
  }

  void _fetchUserConditionAndDoctors() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('administrator/users/${user.uid}');
      DataSnapshot userSnapshot = await userRef.get();
      if (userSnapshot.exists) {
        setState(() {
          userConditions =
              userSnapshot.child('conditions').value as List<dynamic>? ?? [];
        });
      }

      _fetchDoctors();
    }
  }

  void _fetchDoctors() async {
    DatabaseReference doctorsRef =
        FirebaseDatabase.instance.ref('administrator/doctors');
    User? user = FirebaseAuth.instance.currentUser;

    doctorsRef.get().then((snapshot) async {
      if (snapshot.exists) {
        List<Map<String, dynamic>> loadedDoctors = [];
        List<Map<String, dynamic>> recommendedDocs = [];

        // First load all doctors
        snapshot.children.forEach((doc) {
          final doctor = doc.value as Map<dynamic, dynamic>;
          bool matchesCondition = false;

          // Handle specialization logic
          if (doctor['specialization'] is List) {
            matchesCondition = doctor['specialization']
                .any((spec) => userConditions.contains(spec));
          } else if (doctor['specialization'] is String) {
            matchesCondition =
                userConditions.contains(doctor['specialization']);
          }

          final doctorInfo = {
            'doctorId': doc.key,
            'profilePic': doctor['profilePic'] ?? '',
            'name': doctor['name'] ?? 'Unknown',
            'experience': doctor['years'] ?? '0',
            'specialization': doctor['specialization'] ?? 'Unknown',
            'license': doctor['license'] ?? '',
            'description': doctor['description'] ?? '',
            'isFavorite': false, // Default to false, will update from Firebase
            'matchesCondition': matchesCondition,
          };

          loadedDoctors.add(doctorInfo);

          if (matchesCondition) {
            recommendedDocs.add(doctorInfo);
          }
        });

        // If user is logged in, check their favorites
        if (user != null) {
          DatabaseReference favoritesRef = FirebaseDatabase.instance
              .ref('administrator/users/${user.uid}/favorites');

          DataSnapshot favoritesSnapshot = await favoritesRef.get();
          if (favoritesSnapshot.exists) {
            Map<String, dynamic> favorites = Map<String, dynamic>.from(
                favoritesSnapshot.value as Map<dynamic, dynamic>);

            // Update isFavorite status based on Firebase data
            for (var doctor in loadedDoctors) {
              if (favorites.containsKey(doctor['doctorId'])) {
                doctor['isFavorite'] = true;
              }
            }
          }
        }

        setState(() {
          allDoctors = loadedDoctors;
          favoriteDoctors =
              allDoctors.where((doctor) => doctor['isFavorite']).toList();
          recommendedDoctors = recommendedDocs;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    }).catchError((error) {
      print('Error fetching doctors: $error');
      setState(() {
        isLoading = false;
      });
    });
  }

  void _handleSkip() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userRef =
          FirebaseDatabase.instance.ref('administrator/users/${user.uid}');
      await userRef.update({
        'skip_clicked': true, // Mark skip as clicked
      });
      setState(() {
        showSkipButton = false;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    }
  }

  void _toggleFavorite(int index) async {
    final doctorId = allDoctors[index]['doctorId'];
    final isFavorite = !allDoctors[index]['isFavorite'];

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DatabaseReference userRef = FirebaseDatabase.instance
            .ref('administrator/users/${user.uid}/favorites/$doctorId');

        if (isFavorite) {
          await userRef.set(true);
          print('Added doctor $doctorId to favorites');
        } else {
          await userRef.remove();
          print('Removed doctor $doctorId from favorites');
        }

        setState(() {
          allDoctors[index]['isFavorite'] = isFavorite;
          favoriteDoctors =
              allDoctors.where((doctor) => doctor['isFavorite']).toList();
        });

        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isFavorite ? 'Added to favorites' : 'Removed from favorites'),
            duration: Duration(seconds: 1),
          ),
        );
      } catch (e) {
        print('Error updating favorites: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update favorites. Please try again.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login to save favorites')),
      );
    }
  }

  void _startSearch() {
    setState(() {
      isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      isSearching = false;
      searchQuery = '';
    });
  }

  void _updateSearchQuery(String newQuery) {
    setState(() {
      searchQuery = newQuery;
    });
  }

  List<Map<String, dynamic>> _filterDoctors(
      List<Map<String, dynamic>> doctors) {
    if (searchQuery.isEmpty) {
      return doctors;
    } else {
      return doctors.where((doctor) {
        final specialization = doctor['specialization'];
        if (specialization is String) {
          return specialization
              .toLowerCase()
              .contains(searchQuery.toLowerCase());
        } else if (specialization is List) {
          return specialization.any((spec) => spec
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase()));
        }
        return false;
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search doctors...',
                  border: InputBorder.none,
                ),
                style: TextStyle(color: Colors.white),
                onChanged: _updateSearchQuery,
              )
            : Center(
                child: Text(
                  'Doctor Dashboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
        backgroundColor: Color(0xFF92A68A),
        actions: [
          isSearching
              ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: _stopSearch,
                )
              : IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _startSearch,
                ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Recommendation'),
            Tab(text: 'All'),
            Tab(text: 'Favorites'),
          ],
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/animation/snail.json', // Path to Lottie animation
                    width: 250, // Size of Lottie
                    height: 250,
                  ),
                  const SizedBox(height: 20),
                  const Text('Loading doctors...'),
                ],
              ),
            )
          : Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDoctorList(_filterDoctors(recommendedDoctors)),
                    _buildDoctorList(_filterDoctors(allDoctors)),
                    _buildDoctorList(_filterDoctors(favoriteDoctors)),
                  ],
                ),
                if (showSkipButton)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: ElevatedButton(
                      onPressed: _handleSkip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        "Skip",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildDoctorList(List<Map<String, dynamic>> doctors) {
    return ListView.builder(
      itemCount: doctors.length,
      itemBuilder: (context, index) {
        final doctor = doctors[index];
        final specialization = doctor['specialization'];

        final specializationText = specialization is List
            ? specialization.join(', ')
            : specialization.toString();

        return DoctorCard(
          doctorId: doctor['doctorId'],
          profilePic: doctor['profilePic'],
          name: doctor['name'],
          experience: doctor['experience'],
          specialization: specializationText,
          isFavorite: doctor['isFavorite'],
          onFavoriteButtonPressed: () => _toggleFavorite(index),
          isAppointed: null,
        );
      },
    );
  }
}
