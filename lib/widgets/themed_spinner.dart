import 'package:flutter/material.dart';

/// A large, centered, theme-colored loading spinner.
/// Use this instead of bare `CircularProgressIndicator()` across all screens
/// to ensure users never see an empty page while data loads.
class ThemedSpinner extends StatelessWidget {
  final String? label;
  const ThemedSpinner({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: cs.primary,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 16),
            Text(
              label!,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
