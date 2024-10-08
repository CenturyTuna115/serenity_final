import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
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

    doctorsRef.get().then((snapshot) {
      if (snapshot.exists) {
        List<Map<String, dynamic>> loadedDoctors = [];
        List<Map<String, dynamic>> recommendedDocs = [];
        snapshot.children.forEach((doc) {
          final doctor = doc.value as Map<dynamic, dynamic>;
          bool matchesCondition = false;

          for (var condition in userConditions) {
            if (doctor['specialization'] == condition) {
              matchesCondition = true;
              break;
            }
          }

          final doctorInfo = {
            'doctorId': doc.key,
            'profilePic': doctor['profilePic'] ?? '',
            'name': doctor['name'] ?? 'Unknown',
            'experience': doctor['years'] ?? '0',
            'specialization': doctor['specialization'] ?? 'Unknown',
            'license': doctor['license'] ?? '',
            'description': doctor['description'] ?? '',
            'isFavorite': false,
            'matchesCondition': matchesCondition,
          };

          loadedDoctors.add(doctorInfo);

          if (matchesCondition) {
            recommendedDocs.add(doctorInfo);
          }
        });

        loadedDoctors.sort((a, b) {
          if (a['matchesCondition'] && !b['matchesCondition']) {
            return -1;
          } else if (!a['matchesCondition'] && b['matchesCondition']) {
            return 1;
          } else {
            return 0;
          }
        });

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

  void _toggleFavorite(int index) {
    setState(() {
      allDoctors[index]['isFavorite'] = !allDoctors[index]['isFavorite'];
      favoriteDoctors =
          allDoctors.where((doctor) => doctor['isFavorite']).toList();
    });
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
        return doctor['name']
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ||
            doctor['specialization']
                .toLowerCase()
                .contains(searchQuery.toLowerCase());
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
                    _buildDoctorList(_filterDoctors(allDoctors)), // All doctors
                    _buildDoctorList(
                        _filterDoctors(favoriteDoctors)), // Favorites
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color.fromARGB(255, 255, 255, 255),
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
        selectedFontSize: 0.0, // Ensures the icons stay in line
        unselectedFontSize: 0.0, // Ensures the icons stay in line
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MessagesTab()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Emergencymode()),
            );
          } else if (index == 3) {
            _logout(context);
          }
        },
      ),
    );
  }

  Widget _buildDoctorList(List<Map<String, dynamic>> doctors) {
    return ListView.builder(
      itemCount: doctors.length,
      itemBuilder: (context, index) {
        return DoctorCard(
          doctorId: doctors[index]['doctorId'],
          profilePic: doctors[index]['profilePic'],
          name: doctors[index]['name'],
          experience: doctors[index]['experience'],
          specialization: doctors[index]['specialization'],
          isFavorite: doctors[index]['isFavorite'],
          onFavoriteButtonPressed: () => _toggleFavorite(index),
        );
      },
    );
  }

  void _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Logout failed: $e');
    }
  }
}
