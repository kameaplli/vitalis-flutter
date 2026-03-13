import 'package:flutter/material.dart';

class MedicalDisclaimer extends StatelessWidget {
  const MedicalDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'This app is for informational purposes only and does not provide medical advice. '
        'Always consult a qualified healthcare provider before making dietary or health changes.',
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
