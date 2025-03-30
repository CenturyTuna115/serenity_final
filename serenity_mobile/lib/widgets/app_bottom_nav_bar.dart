import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavigationBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFFF6F4EE),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.home, size: 24),
              activeIcon: Icon(CupertinoIcons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.mail, size: 24),
              activeIcon: Icon(CupertinoIcons.mail, size: 28),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.bell, size: 24),
              activeIcon: Icon(CupertinoIcons.bell_fill, size: 28),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notes, size: 24),
              activeIcon: Icon(Icons.notes, size: 28),
              label: 'Notes',
            ),
          ],
          currentIndex: currentIndex,
          selectedItemColor: const Color(0xFF2E7D32),
          unselectedItemColor: const Color(0xFF94AF94),
          selectedFontSize: 12,
          unselectedFontSize: 10,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (index) {
            HapticFeedback.lightImpact();
            onTap(index);
          },
        ),
      ),
    );
  }
}
