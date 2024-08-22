import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'doctor_card.dart';

class DoctorDashboard extends StatefulWidget {
  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> allDoctors = [];
  List<Map<String, dynamic>> favoriteDoctors = [];
  String searchQuery = '';
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDoctors();
  }

  void _fetchDoctors() async {
    DatabaseReference doctorsRef =
        FirebaseDatabase.instance.ref('administrator/doctors');

    doctorsRef.get().then((snapshot) {
      if (snapshot.exists) {
        List<Map<String, dynamic>> loadedDoctors = [];
        snapshot.children.forEach((doc) {
          final doctor = doc.value as Map<dynamic, dynamic>;
          loadedDoctors.add({
            'doctorId': doc.key, // Adding doctorId to the loaded data
            'profilePic': doctor['profilePic'] ?? '',
            'name': doctor['name'] ?? 'Unknown',
            'experience': doctor['years'] ?? '0',
            'specialization': doctor['specialization'] ?? 'Unknown',
            'license': doctor['license'] ?? '',
            'description': doctor['description'] ?? '',
            'isFavorite': false,
          });
        });
        setState(() {
          allDoctors = loadedDoctors;
          favoriteDoctors =
              allDoctors.where((doctor) => doctor['isFavorite']).toList();
        });
      } else {
        print('No data available');
      }
    }).catchError((error) {
      print('Error fetching data: $error');
    });
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

  List<Map<String, dynamic>> _filterDoctors(List<Map<String, dynamic>> doctors) {
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
            : Text('Doctor Dashboard'),
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
            Tab(text: 'All'),
            Tab(text: 'Favorites'),
          ],
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDoctorList(_filterDoctors(allDoctors)),
          _buildDoctorList(_filterDoctors(favoriteDoctors)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF92A68A),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Logout',
          ),
        ],
        selectedItemColor: const Color(0xFFFFA726),
        unselectedItemColor: const Color(0xFF94AF94),
        onTap: (index) {
          // Handle navigation based on the tapped item index
        },
      ),
    );
  }

  Widget _buildDoctorList(List<Map<String, dynamic>> doctors) {
    return ListView.builder(
      itemCount: doctors.length,
      itemBuilder: (context, index) {
        return DoctorCard(
          doctorId: doctors[index]['doctorId'], // Pass the doctorId to DoctorCard
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
}
