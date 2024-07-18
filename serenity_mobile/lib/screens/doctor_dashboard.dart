import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'homepage.dart';
import 'doctor_card.dart';
import 'emergencymode.dart'; // Import Emergencymode

class DoctorDashboard extends StatefulWidget {
  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  String searchQuery = '';
  String selectedCategory = 'All';

  final List<String> categories = ['All', 'Favorites', 'Insomnia', 'Anxiety', 'PTSD'];
  final List<Map<String, String>> doctors = [
    {'name': 'Dr. BINI, BINING', 'experience': '4 years', 'specialization': 'Psychiatrist', 'rating': '5.0', 'time': '9:00 - 23:00', 'image': 'assets/bini.png'},
    {'name': 'Dr. Alex Johnson', 'experience': '6 years', 'specialization': 'Psychologist', 'rating': '4.8', 'time': '10:00 - 18:00', 'image': 'assets/johndoe.jpg'},
    {'name': 'Dr. Emily Davis', 'experience': '8 years', 'specialization': 'Therapist', 'rating': '4.9', 'time': '11:00 - 19:00', 'image': 'assets/smith.png'},
    {'name': 'Dr. Michael Smith', 'experience': '5 years', 'specialization': 'Counselor', 'rating': '4.7', 'time': '12:00 - 20:00', 'image': 'assets/bining.jpeg'},
    // Add more doctor details here
  ];

  List<Map<String, String>> favoriteDoctors = [];

  void toggleFavorite(Map<String, String> doctor) {
    setState(() {
      if (favoriteDoctors.contains(doctor)) {
        favoriteDoctors.remove(doctor);
      } else {
        favoriteDoctors.add(doctor);
      }
    });
  }

  bool isDoctorInCategory(Map<String, String> doctor, String category) {
    switch (category) {
      case 'PTSD':
        return doctor['specialization'] == 'Psychologist';
      case 'Insomnia':
        return doctor['specialization'] == 'Psychiatrist';
      case 'Anxiety':
        return doctor['specialization'] == 'Therapist' || doctor['specialization'] == 'Counselor';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.png'),
        ),
        title: Text(
          'Doctor Dash',
          style: TextStyle(
            fontFamily: 'Roboto', // Change to your desired font family
            fontSize: 20, // Change to your desired font size
            fontWeight: FontWeight.bold, 
            color: Color.fromARGB(255, 255, 255, 255) // Change to your desired font weight
          ),
        ),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 24, 83, 24),
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
                      color: selectedCategory == categories[index] ? Colors.green : Colors.grey[300],
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
              itemCount: selectedCategory == 'Favorites' ? favoriteDoctors.length : doctors.length,
              itemBuilder: (context, index) {
                final doctor = selectedCategory == 'Favorites' ? favoriteDoctors[index] : doctors[index];

                if (selectedCategory != 'All' && selectedCategory != 'Favorites' && !isDoctorInCategory(doctor, selectedCategory)) {
                  return Container();
                }
                if (searchQuery.isNotEmpty && !doctor['name']!.toLowerCase().contains(searchQuery.toLowerCase())) {
                  return Container();
                }
                return DoctorCard(
                  doctor: doctor,
                  isFavorite: favoriteDoctors.contains(doctor),
                  onFavoriteButtonPressed: () => toggleFavorite(doctor),
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
            icon: Icon(CupertinoIcons.ellipsis),
            label: '',
          ),
        ],
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: Color(0xFF94AF94),
        onTap: (index) {
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else if (index == 2) { // Bell icon index
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Emergencymode()),
            );
          }
          // Add other navigation cases if needed
        },
      ),
    );
  }
}
