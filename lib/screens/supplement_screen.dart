import 'package:flutter/material.dart';
import 'health_screen.dart';

/// Dedicated supplement tracking screen — routes to HealthSubScreen with supplements category.
class SupplementScreen extends StatelessWidget {
  const SupplementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HealthSubScreen(category: 'supplements');
  }
}
