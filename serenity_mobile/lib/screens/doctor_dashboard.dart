import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:serenity_mobile/screens/doctor_card.dart';

class DoctorDashboard extends StatefulWidget {
  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  String searchQuery = '';
  String selectedCategory = 'All';
  List<Map<String, dynamic>> doctors = [];
  List<Map<String, dynamic>> favoriteDoctors = [];

  final List<String> categories = [
    'All',
    'Favorites',
    'Insomnia',
    'Anxiety',
    'PTS'
  ];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    DatabaseReference doctorsRef =
        FirebaseDatabase.instance.ref().child('doctors');
    DatabaseEvent event = await doctorsRef.once();

    if (event.snapshot.exists) {
      Map<String, dynamic> doctorsData =
          Map<String, dynamic>.from(event.snapshot.value as Map);
      List<Map<String, dynamic>> tempDoctors = [];

      doctorsData.forEach((key, value) {
        Map<String, dynamic> doctor = Map<String, dynamic>.from(value);

        // Extract credentials as a list of URLs
        List<String> credentials = [];
        if (doctor['credentials'] != null) {
          credentials = List<String>.from(doctor['credentials']);
        }

        tempDoctors.add({
          'name': doctor['credentials']['name'],
          'experience': '${doctor['years']} years',
          'specialization': doctor['specialization'],
          'rating':
              '5.0', // You can update this to fetch the actual rating if available
          'time':
              '9:00 - 23:00', // You can update this to fetch the actual available time if available
          'image': doctor['profilePic'],
          'credentials': credentials, // Include the credentials array
        });
      });

      setState(() {
        doctors = tempDoctors;
      });
    }
  }

  void toggleFavorite(Map<String, dynamic> doctor) {
    setState(() {
      if (favoriteDoctors.contains(doctor)) {
        favoriteDoctors.remove(doctor);
      } else {
        favoriteDoctors.add(doctor);
      }
    });
  }

  bool isDoctorInCategory(Map<String, dynamic> doctor, String category) {
    switch (category) {
      case 'PTSD':
        return doctor['specialization'] == 'Psychologist';
      case 'Insomnia':
        return doctor['specialization'] == 'Psychiatrist';
      case 'Anxiety':
        return doctor['specialization'] == 'Therapist' ||
            doctor['specialization'] == 'Counselor';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Dashboard'),
        backgroundColor: const Color(0xFF92A68A),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Container(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = categories[index];
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: selectedCategory == categories[index]
                          ? Colors.green
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(child: Text(categories[index])),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: selectedCategory == 'Favorites'
                  ? favoriteDoctors.length
                  : doctors.length,
              itemBuilder: (context, index) {
                final doctor = selectedCategory == 'Favorites'
                    ? favoriteDoctors[index]
                    : doctors[index];

                if (selectedCategory != 'All' &&
                    selectedCategory != 'Favorites' &&
                    !isDoctorInCategory(doctor, selectedCategory)) {
                  return Container();
                }
                if (searchQuery.isNotEmpty &&
                    !doctor['name']!
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase())) {
                  return Container();
                }
                return DoctorCard(
                  doctor: Map<String, String>.from(doctor),
                  isFavorite: favoriteDoctors.contains(doctor),
                  onFavoriteButtonPressed: () => toggleFavorite(doctor),
                  credentials: [],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
