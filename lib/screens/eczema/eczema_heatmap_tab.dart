import 'package:flutter/material.dart';
import 'eczema_helpers.dart';

// ─── Top region row ────────────────────────────────────────────────────────────

class TopRegionRow extends StatelessWidget {
  final String label;
  final double frequency;
  final double avgEasi;
  const TopRegionRow({super.key, required this.label, required this.frequency, required this.avgEasi});

  @override
  Widget build(BuildContext context) {
    final color = easiColor(avgEasi / 5.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frequency.clamp(0.0, 1.0), minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(frequency * 100).round()}%  EASI ${avgEasi.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}
