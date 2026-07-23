import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: Text('Bildirimler yakında...', style: TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }
}
