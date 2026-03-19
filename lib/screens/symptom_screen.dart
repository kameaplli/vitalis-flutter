import 'package:flutter/material.dart';
import 'health_screen.dart';

/// Dedicated symptom tracking screen — routes to HealthSubScreen with symptoms category.
class SymptomScreen extends StatelessWidget {
  const SymptomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HealthSubScreen(category: 'symptoms');
  }
}
