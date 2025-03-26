import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:lottie/lottie.dart';
import 'doctor_card.dart';

class FavoritesScreen extends StatefulWidget {
  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> favoriteDoctors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFavoriteDoctors();
  }

  void _fetchFavoriteDoctors() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference userRef = FirebaseDatabase.instance
          .ref('administrator/users/${user.uid}/favorites');
      DatabaseReference doctorsRef =
          FirebaseDatabase.instance.ref('administrator/doctors');

      DataSnapshot favoritesSnapshot = await userRef.get();
      if (favoritesSnapshot.exists) {
        List<String> favoriteIds = [];
        favoritesSnapshot.children.forEach((child) {
          favoriteIds.add(child.key!);
        });

        DataSnapshot doctorsSnapshot = await doctorsRef.get();
        if (doctorsSnapshot.exists) {
          List<Map<String, dynamic>> loadedFavorites = [];
          doctorsSnapshot.children.forEach((doc) {
            if (favoriteIds.contains(doc.key)) {
              final doctor = doc.value as Map<dynamic, dynamic>;
              loadedFavorites.add({
                'doctorId': doc.key,
                'profilePic': doctor['profilePic'] ?? '',
                'name': doctor['name'] ?? 'Unknown',
                'experience': doctor['years'] ?? '0',
                'specialization': doctor['specialization'] ?? 'Unknown',
                'isFavorite': true,
              });
            }
          });

          setState(() {
            favoriteDoctors = loadedFavorites;
            isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorites'),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/animation/snail.json',
                    width: 250,
                    height: 250,
                  ),
                  SizedBox(height: 20),
                  Text('Loading favorites...'),
                ],
              ),
            )
          : favoriteDoctors.isEmpty
              ? Center(
                  child: Text(
                    'No favorite doctors yet',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  itemCount: favoriteDoctors.length,
                  itemBuilder: (context, index) {
                    final doctor = favoriteDoctors[index];
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
                      isFavorite: true,
                      onFavoriteButtonPressed: () {
                        // Remove from favorites
                        setState(() {
                          favoriteDoctors.removeAt(index);
                        });
                        // Update Firebase
                        User? user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          DatabaseReference userRef = FirebaseDatabase.instance.ref(
                              'administrator/users/${user.uid}/favorites/${doctor['doctorId']}');
                          userRef.remove();
                        }
                      },
                      isAppointed: null,
                    );
                  },
                ),
    );
  }
}
