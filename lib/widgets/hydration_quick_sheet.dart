import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/hydration_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/selected_person_provider.dart';
import '../widgets/friendly_error.dart';

/// A bottom sheet with preset hydration amounts for quick logging.
class HydrationQuickSheet extends ConsumerStatefulWidget {
  const HydrationQuickSheet({super.key});

  /// Show the bottom sheet from any context.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const HydrationQuickSheet(),
    );
  }

  @override
  ConsumerState<HydrationQuickSheet> createState() =>
      _HydrationQuickSheetState();
}

class _HydrationQuickSheetState extends ConsumerState<HydrationQuickSheet> {
  bool _logging = false;
  bool _success = false;

  static const _presets = [
    (amount: 250, label: 'Glass', iconSize: 20.0),
    (amount: 500, label: 'Bottle', iconSize: 24.0),
    (amount: 750, label: 'Large Bottle', iconSize: 28.0),
    (amount: 0, label: 'Custom', iconSize: 22.0),
  ];

  Future<void> _logAmount(int ml) async {
    if (_logging) return;
    setState(() => _logging = true);

    final person = ref.read(selectedPersonProvider);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    try {
      await apiClient.dio.post(ApiConstants.hydrationLog, data: {
        'quantity': ml,
        'beverage_type': 'water',
        'date': today,
        'time': timeStr,
        if (person != 'self') 'family_member_id': person,
      });

      // Invalidate relevant providers
      ref.invalidate(hydrationHistoryProvider('${person}_1_$today'));
      ref.invalidate(todayHydrationProvider(person));
      ref.invalidate(dashboardProvider((person, today)));

      HapticFeedback.lightImpact();

      if (!mounted) return;
      setState(() {
        _logging = false;
        _success = true;
      });

      // Auto-dismiss after showing success
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _logging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(friendlyErrorMessage(e, context: 'hydration'))),
      );
    }
  }

  Future<void> _showCustomDialog() async {
    final ctrl = TextEditingController();
    try {
      final ml = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Custom Amount'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (ml)',
              suffixText: 'ml',
            ),
            autofocus: true,
            onSubmitted: (v) {
              final parsed = int.tryParse(v.trim());
              Navigator.pop(ctx, parsed);
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final v = int.tryParse(ctrl.text.trim());
                Navigator.pop(ctx, v);
              },
              child: const Text('Log'),
            ),
          ],
        ),
      );
      if (ml != null && ml > 0) _logAmount(ml);
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_success) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Icon(Icons.check_circle_rounded,
                    size: 64, color: Colors.blue.shade400),
              ),
              const SizedBox(height: 12),
              Text('Logged!',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              HugeIcon(
                  icon: HugeIcons.strokeRoundedDroplet,
                  size: 22,
                  color: Colors.blue),
              const SizedBox(width: 8),
              Text('Quick Hydration',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          // 2x2 grid
          if (_logging)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: _presets.map((p) {
                final isCustom = p.amount == 0;
                return Material(
                  color: isCustom
                      ? cs.surfaceContainerHighest
                      : Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: isCustom ? _showCustomDialog : () => _logAmount(p.amount),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(
                          icon: isCustom
                              ? HugeIcons.strokeRoundedEdit02
                              : HugeIcons.strokeRoundedDroplet,
                          size: p.iconSize,
                          color: isCustom ? cs.onSurfaceVariant : Colors.blue,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isCustom ? 'Custom' : '${p.amount} ml',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isCustom ? cs.onSurfaceVariant : Colors.blue.shade700,
                          ),
                        ),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
