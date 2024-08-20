import 'package:flutter/material.dart';

class DoctorCard extends StatelessWidget {
  final Map<String, String> doctor;
  final List<String> credentials;
  final bool isFavorite;
  final VoidCallback onFavoriteButtonPressed;

  DoctorCard({
    required this.doctor,
    required this.credentials,
    required this.isFavorite,
    required this.onFavoriteButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                        image: NetworkImage(doctor[
                            'image']!), // Use the image path from the doctor data
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor['name']!,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '${doctor['experience']} ${doctor['specialization']}',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  'Time: ${doctor['time']}',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.yellow, size: 11),
                  SizedBox(width: 4),
                  Text(doctor['rating']!, style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: credentials.map((url) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Image.network(url, height: 50, fit: BoxFit.cover),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
