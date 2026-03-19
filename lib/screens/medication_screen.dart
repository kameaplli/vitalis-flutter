import 'package:flutter/material.dart';
import 'health_screen.dart';

/// Dedicated medication tracking screen — routes to HealthSubScreen with medications category.
class MedicationScreen extends StatelessWidget {
  const MedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HealthSubScreen(category: 'medications');
  }
}
