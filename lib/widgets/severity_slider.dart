import 'package:flutter/material.dart';

class SeveritySlider extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const SeveritySlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  Color _colorForValue(int v) {
    if (v <= 3) return Colors.green;
    if (v <= 6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _colorForValue(value),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$value/10', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _colorForValue(value),
            thumbColor: _colorForValue(value),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}
