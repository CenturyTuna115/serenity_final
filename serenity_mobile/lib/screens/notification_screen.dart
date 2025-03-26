import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _appNotifications = true;
  bool _emailNotifications = false;
  bool _smsNotifications = false;
  bool _reminderNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Settings'),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('App Notifications'),
            value: _appNotifications,
            onChanged: (value) {
              setState(() {
                _appNotifications = value;
              });
            },
          ),
          SwitchListTile(
            title: Text('Email Notifications'),
            value: _emailNotifications,
            onChanged: (value) {
              setState(() {
                _emailNotifications = value;
              });
            },
          ),
          SwitchListTile(
            title: Text('SMS Notifications'),
            value: _smsNotifications,
            onChanged: (value) {
              setState(() {
                _smsNotifications = value;
              });
            },
          ),
          SwitchListTile(
            title: Text('Reminder Notifications'),
            value: _reminderNotifications,
            onChanged: (value) {
              setState(() {
                _reminderNotifications = value;
              });
            },
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Customize which notifications you receive from Serenity',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
