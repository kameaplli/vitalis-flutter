import 'package:flutter/material.dart';

// ─── Trigger chip ────────────────────────────────────────────────────────────

class TrigChip extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const TrigChip(this.label, this.value, this.onChanged, {super.key});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: value,
      onSelected: onChanged,
      visualDensity: VisualDensity.compact,
      selectedColor: Colors.orange.withValues(alpha: 0.20),
    );
  }
}
