import 'package:flutter/material.dart';
import '../../models/food_item.dart';

// ─── Allergen badge widget ────────────────────────────────────────────────────

class AllergenBadge extends StatelessWidget {
  final FoodAllergenInfo allergen;
  const AllergenBadge({super.key, required this.allergen});

  @override
  Widget build(BuildContext context) {
    final isHigh = allergen.risk == 'high';
    final color = isHigh ? Colors.red : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        '${allergen.emoji} ${allergen.displayName}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.shade700),
      ),
    );
  }
}
