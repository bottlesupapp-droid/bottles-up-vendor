import 'package:flutter/material.dart';

class ClubDetailsScreen extends StatelessWidget {
  final String clubId;
  
  const ClubDetailsScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Club Details')),
      body: Center(child: Text('Club Details for ID: $clubId - Coming Soon')),
    );
  }
} 