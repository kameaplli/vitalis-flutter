import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/food_item.dart';
import '../../providers/food_provider.dart';
import 'food_search_sheet.dart';

// ─── Recipe creator bottom sheet ─────────────────────────────────────────────

class RecipeCreatorSheet extends ConsumerStatefulWidget {
  const RecipeCreatorSheet({super.key});

  @override
  ConsumerState<RecipeCreatorSheet> createState() => _RecipeCreatorSheetState();
}

class _RecipeCreatorSheetState extends ConsumerState<RecipeCreatorSheet> {
  final _nameController = TextEditingController();
  final List<({FoodItem food, double grams})> _ingredients = [];
  bool _saving = false;

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _ingredients.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ── Computed totals ──────────────────────────────────────────────────────

  double get _totalCal => _ingredients.fold(
      0.0, (sum, i) => sum + (i.food.cal ?? 0) / 100 * i.grams);

  double get _totalProtein => _ingredients.fold(
      0.0, (sum, i) => sum + (i.food.protein ?? 0) / 100 * i.grams);

  double get _totalCarbs => _ingredients.fold(
      0.0, (sum, i) => sum + (i.food.carbs ?? 0) / 100 * i.grams);

  double get _totalFat => _ingredients.fold(
      0.0, (sum, i) => sum + (i.food.fat ?? 0) / 100 * i.grams);

  // ── Add ingredient via FoodSearchSheet ───────────────────────────────────

  void _addIngredient() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FoodSearchSheet(
        onFoodPicked: (food) {
          setState(() {
            _ingredients.add((food: food, grams: 100.0));
          });
        },
      ),
    );
  }

  // ── Update grams for an ingredient ──────────────────────────────────────

  void _updateGrams(int index, String value) {
    final grams = double.tryParse(value);
    if (grams == null || grams <= 0) return;
    setState(() {
      final entry = _ingredients[index];
      _ingredients[index] = (food: entry.food, grams: grams);
    });
  }

  // ── Remove ingredient ───────────────────────────────────────────────────

  void _removeIngredient(int index) {
    setState(() => _ingredients.removeAt(index));
  }

  // ── Save recipe ─────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    try {
      await apiClient.dio.post(ApiConstants.customMeal, data: {
        'name': _nameController.text.trim(),
        'emoji': '\u{1F372}', // 🍲
        'ingredients': _ingredients
            .map((i) => {
                  'food_id': i.food.id,
                  'quantity_grams': i.grams,
                })
            .toList(),
      });

      ref.invalidate(foodDatabaseProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recipe saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving recipe: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Drag handle ───────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header bar ────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Create Recipe',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _canSave && !_saving ? _save : null,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Scrollable content ────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // Recipe name field
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Recipe name',
                      hintText: 'My Stir Fry',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 20),

                  // Ingredients header
                  Text(
                    'Ingredients',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  // Ingredient list
                  if (_ingredients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No ingredients yet.\nTap the button below to add foods.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._ingredients.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ingredient = entry.value;
                      final food = ingredient.food;
                      final grams = ingredient.grams;
                      final kcal =
                          ((food.cal ?? 0) / 100 * grams).toStringAsFixed(0);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              // Emoji + name
                              Text(
                                food.emoji ?? '\u{1F35D}', // 🍝
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      food.displayName ?? food.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '$kcal kcal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Grams field
                              SizedBox(
                                width: 72,
                                child: TextField(
                                  controller: TextEditingController(
                                    text: grams.toStringAsFixed(0),
                                  ),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    suffixText: 'g',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                  onSubmitted: (v) =>
                                      _updateGrams(idx, v),
                                  onChanged: (v) =>
                                      _updateGrams(idx, v),
                                ),
                              ),

                              // Delete button
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 20,
                                    color: colorScheme.error),
                                onPressed: () => _removeIngredient(idx),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 8),

                  // Add ingredient button
                  OutlinedButton.icon(
                    onPressed: _addIngredient,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Ingredient'),
                  ),
                ],
              ),
            ),

            // ── Totals bar ────────────────────────────────────────────
            if (_ingredients.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  border: Border(
                    top: BorderSide(
                        color: colorScheme.outlineVariant, width: 0.5),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _TotalChip(
                          label: 'Cal', value: _totalCal, unit: 'kcal'),
                      _TotalChip(
                          label: 'Protein', value: _totalProtein, unit: 'g'),
                      _TotalChip(
                          label: 'Carbs', value: _totalCarbs, unit: 'g'),
                      _TotalChip(
                          label: 'Fat', value: _totalFat, unit: 'g'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Small totals chip ───────────────────────────────────────────────────────

class _TotalChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;

  const _TotalChip({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${value.toStringAsFixed(0)} $unit',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
