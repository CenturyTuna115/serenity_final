import 'package:flutter/material.dart';

class SubscriptionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscription'),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: Column(
        children: [
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Premium Membership',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('\$9.99/month',
                      style: TextStyle(fontSize: 24, color: Colors.green)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    child: Text('Subscribe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFA726),
                    ),
                    onPressed: () {
                      // Handle subscription
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Subscription processing...')));
                    },
                  ),
                ],
              ),
            ),
          ),
          Divider(),
          ListTile(
            title: Text('Subscription History'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to history
            },
          ),
        ],
      ),
    );
  }
}
