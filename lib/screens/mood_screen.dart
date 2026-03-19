import 'package:flutter/material.dart';
import 'health_screen.dart';

/// Dedicated mood tracking screen — routes to HealthSubScreen with mood category.
class MoodScreen extends StatelessWidget {
  const MoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HealthSubScreen(category: 'mood');
  }
}
