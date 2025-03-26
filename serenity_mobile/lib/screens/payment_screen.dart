import 'package:flutter/material.dart';

class PaymentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Methods'),
        backgroundColor: Color(0xFF92A68A),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.credit_card),
            title: Text('Credit/Debit Card'),
            subtitle: Text('Visa •••• 4242'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.paypal),
            title: Text('PayPal'),
            subtitle: Text('user@example.com'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.account_balance_wallet),
            title: Text('Bank Transfer'),
            subtitle: Text('•••• 6789'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          Divider(),
          ListTile(
            title: Text('Current Subscription'),
            subtitle: Text('Premium Plan - \$9.99/month'),
          ),
          ListTile(
            title: Text('Billing History'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
          ListTile(
            title: Text('Add Payment Method'),
            leading: Icon(Icons.add),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
