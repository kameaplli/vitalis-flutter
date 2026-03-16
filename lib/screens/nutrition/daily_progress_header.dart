import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/selected_person_provider.dart';
import 'daily_intake.dart';
import '../../widgets/qorhealth_icon.dart';

// ─── Daily progress header ───────────────────────────────────────────────────

class DailyProgressHeader extends ConsumerWidget {
  final NutritionState nutrition;
  const DailyProgressHeader({super.key, required this.nutrition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final person = ref.watch(selectedPersonProvider);
    final user = ref.watch(authProvider).user;

    // Determine age/gender for daily intake
    int? age;
    String? gender;
    if (person == 'self') {
      age = user?.age;
      gender = user?.gender;
    } else {
      final fm = user?.profile.children.where((m) => m.id == person).toList() ?? [];
      if (fm.isNotEmpty) {
        age = fm.first.age;
        gender = fm.first.gender;
      }
    }
    final di = dailyIntake(age, gender);
    final cals = nutrition.totalCalories;
    final calPct = di.calories > 0 ? (cals / di.calories).clamp(0.0, 1.5) : 0.0;
    final protPct = di.protein > 0 ? (nutrition.totalProtein / di.protein).clamp(0.0, 1.5) : 0.0;
    final carbPct = di.carbs > 0 ? (nutrition.totalCarbs / di.carbs).clamp(0.0, 1.5) : 0.0;
    final fatPct = di.fat > 0 ? (nutrition.totalFat / di.fat).clamp(0.0, 1.5) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer.withOpacity(0.5), cs.surface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Calorie ring
          SizedBox(
            width: 72, height: 72,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 72, height: 72,
                child: CircularProgressIndicator(
                  value: calPct.clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: cs.outlineVariant.withOpacity(0.3),
                  color: calPct > 1.0 ? Colors.red : cs.primary,
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${cals.toInt()}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        letterSpacing: -0.5, color: cs.onSurface)),
                Text('kcal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    letterSpacing: 0.5, color: cs.outline)),
              ]),
            ]),
          ),
          const SizedBox(width: 20),
          // Macro bars
          Expanded(
            child: Column(
              children: [
                MiniMacroBar('Protein', nutrition.totalProtein, di.protein, Colors.blue, protPct),
                const SizedBox(height: 8),
                MiniMacroBar('Carbs', nutrition.totalCarbs, di.carbs, Colors.orange, carbPct),
                const SizedBox(height: 8),
                MiniMacroBar('Fat', nutrition.totalFat, di.fat, Colors.red, fatPct),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MiniMacroBar extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color color;
  final double pct;
  const MiniMacroBar(this.label, this.current, this.target, this.color, this.pct, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(width: 52, child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: cs.outlineVariant.withOpacity(0.2),
              color: pct > 1.0 ? Colors.red : color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 56, child: Text(
          '${current.toInt()}/${target.toInt()}g',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant),
          textAlign: TextAlign.right,
        )),
      ],
    );
  }
}

// ─── Entry method card ──────────────────────────────────────────────────────

class EntryMethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const EntryMethodCard({
    super.key,
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      child: Material(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QorhealthIcon(icon: icon, color: color),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
