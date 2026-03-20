import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_card_config_provider.dart';

/// Bottom sheet to customize which dashboard cards are visible and their order.
/// Supports drag-to-reorder and toggle on/off — like Android quick settings.
class DashboardCustomizeSheet extends ConsumerWidget {
  const DashboardCustomizeSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DashboardCustomizeSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(dashboardCardConfigProvider);
    final notifier = ref.read(dashboardCardConfigProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.dashboard_customize_rounded, color: cs.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Customize Dashboard',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: cs.onSurface, letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      notifier.resetToDefaults();
                      HapticFeedback.mediumImpact();
                    },
                    child: const Text('Reset'),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant, size: 20),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Drag to reorder \u2022 Toggle to show/hide',
                style: TextStyle(
                  fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),

            // Reorderable card list
            Expanded(
              child: ReorderableListView.builder(
                scrollController: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: config.cards.length,
                onReorder: (oldIndex, newIndex) {
                  HapticFeedback.lightImpact();
                  notifier.reorder(oldIndex, newIndex);
                },
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (_, __) => Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      shadowColor: cs.shadow.withValues(alpha: 0.3),
                      child: child,
                    ),
                  );
                },
                itemBuilder: (context, index) {
                  final card = config.cards[index];
                  final type = card.type;
                  final visible = card.visible;

                  return _CardConfigTile(
                    key: ValueKey(type.key),
                    index: index,
                    type: type,
                    visible: visible,
                    onToggle: () {
                      HapticFeedback.selectionClick();
                      notifier.toggleCard(type);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CardConfigTile extends StatelessWidget {
  final DashboardCardType type;
  final bool visible;
  final VoidCallback onToggle;
  final int index;

  const _CardConfigTile({
    super.key,
    required this.type,
    required this.visible,
    required this.onToggle,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: visible
              ? cs.surface
              : cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: visible
                ? cs.primary.withValues(alpha: 0.2)
                : cs.outlineVariant.withValues(alpha: 0.15),
            width: visible ? 1.5 : 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: visible
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Center(
              child: Text(type.emoji, style: TextStyle(
                fontSize: 20,
                color: visible ? null : cs.onSurfaceVariant.withValues(alpha: 0.4),
              )),
            ),
          ),
          title: Text(
            type.displayName,
            style: TextStyle(
              fontSize: 14.5, fontWeight: FontWeight.w600,
              color: visible ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          subtitle: Text(
            type.description,
            style: TextStyle(
              fontSize: 12,
              color: visible
                  ? cs.onSurfaceVariant.withValues(alpha: 0.7)
                  : cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: visible,
                onChanged: (_) => onToggle(),
                activeColor: cs.primary,
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle_rounded,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4), size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
