import 'package:flutter/material.dart';
import 'doctor_profile.dart'; // Import the DoctorProfile screen

class DoctorCard extends StatelessWidget {
  final String profilePic;
  final String name;
  final String experience;
  final String specialization;
  final String license;
  final String description;
  final bool isFavorite;
  final VoidCallback onFavoriteButtonPressed;

  DoctorCard({
    required this.profilePic,
    required this.name,
    required this.experience,
    required this.specialization,
    required this.license,
    required this.description,
    required this.isFavorite,
    required this.onFavoriteButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorProfile(
              profilePic: profilePic,
              name: name,
              specialization: specialization,
              experience: experience,
              license: license,
              description: description,
            ),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Center(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(profilePic),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Color(0xFF92A68A) : null,
                      ),
                      onPressed: onFavoriteButtonPressed,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                name,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '$experience years of experience in $specialization',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 4),
              Text(
                'License: $license',
                style: TextStyle(fontSize: 11),
              ),
              SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
