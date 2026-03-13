import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/nutrition_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import '../models/nutrition_log.dart';
import '../models/food_item.dart';
import '../providers/nutrition_analytics_provider.dart';
import '../widgets/friendly_error.dart';
import '../widgets/shimmer_placeholder.dart';

/// Standalone route screen — wraps NutritionHistoryContent in a Scaffold.
class EntriesScreen extends ConsumerWidget {
  const EntriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition History')),
      body: const NutritionHistoryContent(),
    );
  }
}

/// Reusable widget used both by EntriesScreen and the History tab in
/// NutritionScreen. Handles date filtering, grouped list, swipe-to-edit/delete.
class NutritionHistoryContent extends ConsumerStatefulWidget {
  const NutritionHistoryContent({super.key});
  @override
  ConsumerState<NutritionHistoryContent> createState() =>
      _NutritionHistoryContentState();
}

class _NutritionHistoryContentState
    extends ConsumerState<NutritionHistoryContent> {
  String? _startDate = DateTime.now()
      .subtract(const Duration(days: 2))
      .toIso8601String()
      .substring(0, 10);
  String? _endDate = DateTime.now().toIso8601String().substring(0, 10);

  String get _key {
    final person = ref.read(selectedPersonProvider);
    return '${person}_${_startDate ?? ''}_${_endDate ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(selectedPersonProvider);
    final entriesAsync = ref.watch(nutritionEntriesProvider(_key));

    return Column(
      children: [
        // Date range row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(children: [
            Expanded(
              child: Text(
                '${_startDate ?? '...'} → ${_endDate ?? '...'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list, size: 20),
              onPressed: () => _showFilterDialog(context),
            ),
            if (_startDate != null || _endDate != null)
              TextButton(
                onPressed: () =>
                    setState(() { _startDate = null; _endDate = null; }),
                child: const Text('Clear'),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(children: [
            Icon(Icons.swipe, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('Swipe right to edit · Swipe left to delete',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
        ),
        Expanded(
          child: entriesAsync.when(
            skipLoadingOnReload: true,
            loading: () => const ShimmerList(itemCount: 5, itemHeight: 72),
            error: (e, _) => FriendlyError(error: e, context: 'nutrition entries'),
            data: (entries) {
              if (entries.isEmpty) {
                return const Center(child: Text('No entries found'));
              }
              final grouped = <String, List<NutritionEntry>>{};
              for (final e in entries) {
                grouped.putIfAbsent(e.date, () => []).add(e);
              }
              final dates = grouped.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return ListView.builder(
                itemCount: dates.length,
                itemBuilder: (ctx, i) {
                  final date = dates[i];
                  final dayEntries = grouped[date]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                        child: Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      ...dayEntries.map((entry) => Dismissible(
                            key: Key(entry.id),
                            direction: DismissDirection.horizontal,
                            dismissThresholds: const {
                              DismissDirection.startToEnd: 0.3,
                              DismissDirection.endToStart: 0.3,
                            },
                            background: Container(
                              color: Colors.blue,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 16),
                              child: const Icon(Icons.edit, color: Colors.white, size: 18),
                            ),
                            secondaryBackground: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(Icons.delete, color: Colors.white, size: 18),
                            ),
                            confirmDismiss: (dir) async {
                              if (dir == DismissDirection.startToEnd) {
                                _openNutritionEdit(ctx, entry);
                                return false;
                              }
                              return _confirmDelete(ctx);
                            },
                            onDismissed: (dir) async {
                              if (dir == DismissDirection.endToStart) {
                                await apiClient.dio.delete(
                                    '${ApiConstants.nutritionLog}/${entry.id}');
                                ref.invalidate(nutritionEntriesProvider);
                                ref.invalidate(nutritionAnalyticsProvider);
                                AppCache.clearAnalytics();
                              }
                            },
                            child: ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -2),
                              leading: Icon(_mealIcon(entry.meal),
                                  color: _mealColor(entry.meal), size: 20),
                              title: Text(
                                entry.description.isEmpty
                                    ? entry.meal ?? 'Meal'
                                    : entry.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text('${entry.person} • ${entry.time}',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: Text(
                                '${entry.calories.toStringAsFixed(0)} kcal',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Edit — navigate to NutritionScreen with pre-filled data ─────────────

  Future<void> _openNutritionEdit(BuildContext context, NutritionEntry entry) async {
    // Parse time
    final timeParts = (entry.time ?? '12:00').split(':');
    final time = TimeOfDay(
      hour: int.tryParse(timeParts[0]) ?? 12,
      minute: int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0,
    );

    // Set up edit state
    ref.read(nutritionProvider.notifier).initForEdit(
      entry.id,
      entry.meal ?? 'lunch',
      time,
    );

    // Load food items from the API
    try {
      final res = await apiClient.dio.get('${ApiConstants.nutritionLog}/${entry.id}');
      final items = List<dynamic>.from(res.data['items'] ?? []);
      final foods = items.map((item) {
        final food = FoodItem(
          id: item['food_id'] as String? ?? '',
          name: item['food_name'] as String? ?? 'Unknown',
          cal: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          servingSize: 100,
        );
        // quantity in the API is in servings; convert to grams
        final servings = (item['quantity'] as num?)?.toDouble() ?? 1.0;
        final grams = servings * (food.servingSize ?? 100);
        return SelectedFood(food: food, grams: grams);
      }).toList();
      ref.read(nutritionProvider.notifier).setEditFoods(foods);
    } catch (_) {
      // Navigate anyway with empty foods — user can add items
    }

    if (mounted) context.push('/nutrition');
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _formatDate(String iso) {
    try {
      return DateFormat('EEEE, MMMM d').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  IconData _mealIcon(String? meal) {
    switch (meal) {
      case 'breakfast':
        return Icons.free_breakfast_outlined;
      case 'lunch':
        return Icons.lunch_dining_outlined;
      case 'dinner':
        return Icons.dinner_dining_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  Color _mealColor(String? meal) {
    switch (meal) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete entry?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Entries'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_startDate ?? 'Start date (any)'),
              leading: const Icon(Icons.calendar_today),
              onTap: () async {
                Navigator.pop(ctx);
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().subtract(
                      const Duration(days: 7)),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  setState(() => _startDate =
                      d.toIso8601String().substring(0, 10));
                }
              },
            ),
            ListTile(
              title: Text(_endDate ?? 'End date (any)'),
              leading: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                Navigator.pop(ctx);
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  setState(() => _endDate =
                      d.toIso8601String().substring(0, 10));
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

