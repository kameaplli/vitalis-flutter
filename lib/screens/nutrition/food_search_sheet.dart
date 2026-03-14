import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_cache.dart';
import '../../core/constants.dart';
import '../../models/food_detail.dart';
import '../../models/food_item.dart';
import '../../providers/food_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/selected_person_provider.dart';
import 'allergen_badge.dart';
import 'recipe_creator_sheet.dart';

// ─── Food search bottom sheet (local typeahead + manual entry) ────────────────

class FoodSearchSheet extends ConsumerStatefulWidget {
  final void Function(FoodItem)? onFoodPicked;
  const FoodSearchSheet({super.key, this.onFoodPicked});
  @override
  ConsumerState<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<FoodSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<FoodItem>? _serverResults;
  bool _serverSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Local filter across all cached food categories — instant, no API call.
  List<FoodItem> _filterLocal(List<FoodCategory> categories) {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    final matches = <FoodItem>[];
    for (final cat in categories) {
      for (final item in cat.items) {
        if (item.name.toLowerCase().contains(q)) {
          matches.add(item);
          if (matches.length >= 30) return matches;
        }
      }
    }
    return matches;
  }

  /// Server-side fuzzy search when local results are empty or insufficient.
  Future<void> _searchServer(String query) async {
    if (query.length < 2) return;
    setState(() => _serverSearching = true);
    try {
      final res = await apiClient.dio.get(
        ApiConstants.foodSearch,
        queryParameters: {'q': query, 'limit': 20},
      );
      final data = res.data as Map<String, dynamic>;
      final results = (data['results'] as List? ?? [])
          .map((r) => FoodItem.fromJson(r as Map<String, dynamic>))
          .toList();
      if (mounted && _query == query) {
        setState(() => _serverResults = results);
      }
    } catch (_) {
      // Silently fail — local results still available
    } finally {
      if (mounted) setState(() => _serverSearching = false);
    }
  }

  void _showManualEntry() {
    final nameCtrl = TextEditingController(text: _query);
    final calCtrl = TextEditingController();
    final protCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Food Manually'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(
                  labelText: 'Food name *', isDense: true)),
              const SizedBox(height: 8),
              const Text('Nutrition per 100g:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              TextField(controller: calCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calories (kcal)', isDense: true)),
              const SizedBox(height: 6),
              TextField(controller: protCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Protein (g)', isDense: true)),
              const SizedBox(height: 6),
              TextField(controller: carbCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Carbs (g)', isDense: true)),
              const SizedBox(height: 6),
              TextField(controller: fatCtrl, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Fat (g)', isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final foodName = nameCtrl.text.trim();
              if (foodName.isEmpty) return;
              Navigator.pop(ctx);
              final cal = double.tryParse(calCtrl.text) ?? 0;
              final protein = double.tryParse(protCtrl.text) ?? 0;
              final carbs = double.tryParse(carbCtrl.text) ?? 0;
              final fat = double.tryParse(fatCtrl.text) ?? 0;

              String foodId = 'manual_${DateTime.now().millisecondsSinceEpoch}';
              try {
                final saveRes = await apiClient.dio.post(ApiConstants.customFoods, data: {
                  'name': foodName, 'calories': cal, 'protein': protein,
                  'carbs': carbs, 'fat': fat, 'serving_size': 100,
                });
                foodId = saveRes.data['food_id'] ?? foodId;
                await AppCache.clearFoodDb();
                ref.invalidate(foodDatabaseProvider);
              } catch (_) {}

              final food = FoodItem(
                id: foodId, name: foodName, cal: cal,
                protein: protein, carbs: carbs, fat: fat,
                servingSize: 100, emoji: '🍽️',
              );
              _addFood(food);
            },
            child: const Text('Add Food'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(FoodItem food) async {
    HapticFeedback.lightImpact();
    final favIds = ref.read(favoriteIdsProvider);
    try {
      if (favIds.contains(food.id)) {
        await apiClient.dio.delete(ApiConstants.foodFavorite(food.id));
      } else {
        await apiClient.dio.post(ApiConstants.foodFavorite(food.id));
      }
      ref.invalidate(favoriteFoodsProvider);
    } catch (_) {}
  }

  /// Build the pre-search view: Favorites, Recent, Frequent sections
  Widget _buildPreSearchView(ScrollController scrollCtrl) {
    final cs = Theme.of(context).colorScheme;
    final person = ref.watch(selectedPersonProvider);
    final favAsync = ref.watch(favoriteFoodsProvider);
    final recentFreqAsync = ref.watch(recentFrequentProvider(person));
    final yesterdayAsync = ref.watch(yesterdayMealsProvider(person));

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // ── Copy Yesterday's Meals ──
        yesterdayAsync.maybeWhen(
          data: (meals) {
            if (meals.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Copy Yesterday\'s Meals', Icons.content_copy),
                const SizedBox(height: 6),
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: meals.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final meal = meals[i];
                      final label = meal.mealType[0].toUpperCase() +
                          meal.mealType.substring(1);
                      final itemNames = meal.items
                          .map((f) => f['food_name'] ?? '')
                          .take(3)
                          .join(', ');
                      return ActionChip(
                        avatar: Icon(Icons.copy_rounded, size: 16, color: cs.primary),
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(
                              '${meal.totalCalories.toStringAsFixed(0)} kcal · $itemNames',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _copyYesterdayMeal(meal);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),

        // ── Favorites ──
        favAsync.maybeWhen(
          data: (favs) {
            if (favs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Favorites', Icons.star_rounded),
                const SizedBox(height: 6),
                ...favs.take(5).map((food) => _FoodSearchTile(
                      food: food,
                      badges: food.uniqueAllergens,
                      onAdd: _addFood,
                      isFavorite: true,
                      onToggleFavorite: () => _toggleFavorite(food),
                      onInfoTap: () => _showInfoCard(food),
                    )),
                const SizedBox(height: 12),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),

        // ── Recent Foods ──
        recentFreqAsync.maybeWhen(
          data: (data) {
            if (data.recent.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Recent', Icons.history),
                const SizedBox(height: 6),
                ...data.recent.take(5).map((food) {
                  final favIds = ref.watch(favoriteIdsProvider);
                  return _FoodSearchTile(
                    food: food,
                    badges: food.uniqueAllergens,
                    onAdd: _addFood,
                    isFavorite: favIds.contains(food.id),
                    onToggleFavorite: () => _toggleFavorite(food),
                    onInfoTap: () => _showInfoCard(food),
                  );
                }),
                const SizedBox(height: 12),
              ],
            );
          },
          orElse: () => _buildShimmerSection(),
        ),

        // ── Frequent Foods ──
        recentFreqAsync.maybeWhen(
          data: (data) {
            if (data.frequent.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Most Used', Icons.trending_up),
                const SizedBox(height: 6),
                ...data.frequent.take(5).map((food) {
                  final favIds = ref.watch(favoriteIdsProvider);
                  return _FoodSearchTile(
                    food: food,
                    badges: food.uniqueAllergens,
                    onAdd: _addFood,
                    isFavorite: favIds.contains(food.id),
                    onToggleFavorite: () => _toggleFavorite(food),
                    onInfoTap: () => _showInfoCard(food),
                  );
                }),
                const SizedBox(height: 12),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),

        // ── Manual entry + Recipe creator ──
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _showManualEntry,
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Enter manually'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await showModalBottomSheet<FoodItem>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const RecipeCreatorSheet(),
                  );
                  if (result != null && mounted) {
                    widget.onFoodPicked?.call(result);
                    if (widget.onFoodPicked != null) {
                      Navigator.pop(context);
                    } else {
                      ref.read(nutritionProvider.notifier).addFood(result);
                      Navigator.pop(context);
                    }
                  }
                },
                icon: const Icon(Icons.restaurant_menu, size: 18),
                label: const Text('Create recipe'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }

  Widget _buildShimmerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      )),
    );
  }

  /// Build grouped search results: Favorites > Recent > All
  Widget _buildGroupedResults(
    List<FoodItem> allResults,
    ScrollController scrollCtrl,
  ) {
    final favIds = ref.watch(favoriteIdsProvider);
    final person = ref.watch(selectedPersonProvider);
    final recentFreqData = ref.watch(recentFrequentProvider(person)).valueOrNull;

    final recentIds = recentFreqData?.recent.map((f) => f.id).toSet() ?? <String>{};

    // Split results into groups
    final favMatches = <FoodItem>[];
    final recentMatches = <FoodItem>[];
    final otherMatches = <FoodItem>[];

    for (final food in allResults) {
      if (favIds.contains(food.id)) {
        favMatches.add(food);
      } else if (recentIds.contains(food.id)) {
        recentMatches.add(food);
      } else {
        otherMatches.add(food);
      }
    }

    final sections = <Widget>[];

    if (favMatches.isNotEmpty) {
      sections.add(_sectionHeader('Favorites', Icons.star_rounded));
      sections.addAll(favMatches.map((f) => _FoodSearchTile(
            food: f, badges: f.uniqueAllergens, onAdd: _addFood,
            isFavorite: true, onToggleFavorite: () => _toggleFavorite(f),
            onInfoTap: () => _showInfoCard(f),
          )));
    }
    if (recentMatches.isNotEmpty) {
      sections.add(_sectionHeader('Recent', Icons.history));
      sections.addAll(recentMatches.map((f) => _FoodSearchTile(
            food: f, badges: f.uniqueAllergens, onAdd: _addFood,
            isFavorite: false, onToggleFavorite: () => _toggleFavorite(f),
            onInfoTap: () => _showInfoCard(f),
          )));
    }
    if (otherMatches.isNotEmpty) {
      sections.add(_sectionHeader('All Results', Icons.restaurant_menu));
      sections.addAll(otherMatches.map((f) => _FoodSearchTile(
            food: f, badges: f.uniqueAllergens, onAdd: _addFood,
            isFavorite: favIds.contains(f.id),
            onToggleFavorite: () => _toggleFavorite(f),
            onInfoTap: () => _showInfoCard(f),
          )));
    }

    sections.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: _showManualEntry,
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Can't find it? Add manually"),
          ),
        ),
      ),
    );

    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: sections,
    );
  }

  void _copyYesterdayMeal(YesterdayMeal meal) {
    for (final item in meal.items) {
      final food = FoodItem(
        id: item['food_id'] ?? '',
        name: item['food_name'] ?? '',
        cal: (item['calories'] as num?)?.toDouble(),
        protein: (item['protein'] as num?)?.toDouble(),
        carbs: (item['carbs'] as num?)?.toDouble(),
        fat: (item['fat'] as num?)?.toDouble(),
        servingSize: (item['serving_size'] as num?)?.toDouble() ?? 100,
        emoji: item['emoji'],
        unit: item['unit'],
      );
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
      ref.read(nutritionProvider.notifier).addFood(food,
          grams: (food.servingSize ?? 100) * qty);
    }
    ref.read(nutritionProvider.notifier).setMealType(meal.mealType);
    Navigator.pop(context);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied yesterday\'s ${meal.mealType}!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(foodDatabaseProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, scrollCtrl) {
        final categories = foodsAsync.valueOrNull ?? [];
        final filtered = _filterLocal(categories);

        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search foods...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          })
                      : null,
                ),
                onChanged: (v) {
                  final trimmed = v.trim();
                  setState(() {
                    _query = trimmed;
                    _serverResults = null;
                  });
                  // Trigger server search after typing pauses
                  if (trimmed.length >= 2) {
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted && _query == trimmed) _searchServer(trimmed);
                    });
                  }
                },
              ),
            ),
            // Results area
            Expanded(
              child: foodsAsync.isLoading
                  ? _buildShimmerSection()
                  : _query.isEmpty
                      ? _buildPreSearchView(scrollCtrl)
                      : () {
                          // Merge local + server results, dedup by id
                          final merged = <FoodItem>[];
                          final seenIds = <String>{};
                          // Server results first (includes recipes, custom foods, ranked by relevance)
                          if (_serverResults != null) {
                            for (final f in _serverResults!) {
                              if (seenIds.add(f.id)) merged.add(f);
                            }
                          }
                          // Then local results that weren't in server results
                          for (final f in filtered) {
                            if (seenIds.add(f.id)) merged.add(f);
                          }
                          if (merged.isNotEmpty) {
                            return _buildGroupedResults(merged, scrollCtrl);
                          }
                          if (_serverSearching) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          Text('No foods match "$_query"',
                                              style: TextStyle(color: Colors.grey.shade500)),
                                          const SizedBox(height: 16),
                                          OutlinedButton.icon(
                                            onPressed: _showManualEntry,
                                            icon: const Icon(Icons.add, size: 18),
                                            label: const Text('Add manually'),
                                          ),
                                        ],
                                      ),
                                    );
                        }(),
            ),
          ],
        );
      },
    );
  }

  void _addFood(FoodItem food) {
    HapticFeedback.mediumImpact();
    if (widget.onFoodPicked != null) {
      widget.onFoodPicked!(food);
    } else {
      ref.read(nutritionProvider.notifier).addFood(food);
    }
    Navigator.pop(context);
  }

  void _showInfoCard(FoodItem food) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FoodInfoCard(
        foodId: food.id,
        food: food,
        onLog: () {
          Navigator.pop(context); // close info card
          _addFood(food);
        },
      ),
    );
  }
}

// ─── Food Info Card Bottom Sheet (Level 2) — Nutrition Label Style ──────────

class _FoodInfoCard extends ConsumerWidget {
  final String foodId;
  final FoodItem food;
  final VoidCallback onLog;

  const _FoodInfoCard({required this.foodId, required this.food, required this.onLog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final detailAsync = ref.watch(foodDetailProvider(foodId));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) {
        return detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(child: Text('Failed to load details')),
          data: (detail) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // ── Header: Food name large, meta small ──────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.emoji ?? '🍽️', style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(detail.name, style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
                        if (detail.brand != null)
                          Text(detail.brandDisplay ?? detail.brand!,
                            style: TextStyle(fontSize: 11, color: cs.primary.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                  // Badges
                  if (detail.nutriscore != null || detail.novaGroup != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (detail.nutriscore != null)
                        _badge(detail.nutriscore!, _nutriscoreColor(detail.nutriscore!)),
                      if (detail.nutriscore != null && detail.novaGroup != null)
                        const SizedBox(width: 4),
                      if (detail.novaGroup != null)
                        _badge('N${detail.novaGroup}', _novaColor(detail.novaGroup!)),
                    ]),
                ],
              ),
              if (detail.source != null)
                Padding(
                  padding: const EdgeInsets.only(left: 36, top: 2),
                  child: Text('Source: ${detail.source}  ·  per ${(detail.servingSize ?? 100).toStringAsFixed(0)}${detail.unit ?? 'g'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, letterSpacing: 0.3)),
                ),
              const SizedBox(height: 10),

              // ── Nutrition Facts Card ─────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title bar
                    Container(
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: const Text('Nutrition Facts',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                    // Serving info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text('Serving size ${(detail.servingSize ?? 100).toStringAsFixed(0)}${detail.unit ?? 'g'}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const Divider(height: 1, thickness: 4, color: Colors.black),
                    // Calories
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          const Text('Calories', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          Text('${(detail.cal ?? 0).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 2, color: Colors.black),
                    // Macros
                    _nutritionRow('Total Fat', detail.fat, 'g', bold: true),
                    _thinDivider(),
                    _nutritionRow('Total Carbohydrate', detail.carbs, 'g', bold: true),
                    _nutritionSubRow('Dietary Fiber', detail.fiber, 'g'),
                    _nutritionSubRow('Sugars', detail.sugar, 'g'),
                    _thinDivider(),
                    _nutritionRow('Protein', detail.protein, 'g', bold: true),

                    // Micronutrients — top 2 by DRI% highlighted
                    if (detail.micronutrients.isNotEmpty) ...[
                      const Divider(height: 1, thickness: 4, color: Colors.black),
                      ...() {
                        final micros = detail.micronutrients.take(12).toList();
                        // Find top 2 nutrients by DRI %
                        final ranked = [...micros]
                          ..sort((a, b) => (b.driPercent ?? 0).compareTo(a.driPercent ?? 0));
                        final top2Tags = ranked
                            .where((m) => m.isRich)
                            .take(2)
                            .map((m) => m.tagname)
                            .toSet();
                        return micros.map((m) {
                          final isHighlight = top2Tags.contains(m.tagname);
                          return _nutritionRow(
                            m.name, m.value, m.unit,
                            highlight: isHighlight,
                            driPercent: m.driPercent,
                          );
                        });
                      }(),
                    ],
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Recipe Ingredients Breakdown ─────────────────────────────
              if (detail.isRecipe && detail.ingredients.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                        child: Row(children: [
                          Icon(Icons.restaurant_menu, size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text('RECIPE INGREDIENTS (${detail.ingredients.length})',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                              color: Colors.green.shade700, letterSpacing: 0.8)),
                        ]),
                      ),
                      ...detail.ingredients.map((ing) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(children: [
                          Text(ing.emoji ?? '🍽️', style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ing.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${ing.quantityGrams.toStringAsFixed(0)}g  ·  ${ing.calories.toStringAsFixed(0)} kcal  ·  P${ing.protein.toStringAsFixed(1)} C${ing.carbs.toStringAsFixed(1)} F${ing.fat.toStringAsFixed(1)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          )),
                          SizedBox(
                            width: 40,
                            child: Text('${ing.percentage.toStringAsFixed(0)}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                          ),
                        ]),
                      )),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),

              // ── Edit Recipe button ─────────────────────────────────────────
              if (detail.isRecipe) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final editIngredients = detail.ingredients.map((ing) => (
                        food: FoodItem(
                          id: ing.foodId,
                          name: ing.name,
                          emoji: ing.emoji,
                          cal: ing.quantityGrams > 0 ? ing.calories / ing.quantityGrams * 100 : 0,
                          protein: ing.quantityGrams > 0 ? ing.protein / ing.quantityGrams * 100 : 0,
                          carbs: ing.quantityGrams > 0 ? ing.carbs / ing.quantityGrams * 100 : 0,
                          fat: ing.quantityGrams > 0 ? ing.fat / ing.quantityGrams * 100 : 0,
                        ),
                        grams: ing.quantityGrams,
                      )).toList();
                      Navigator.pop(context); // close info card
                      showModalBottomSheet<FoodItem>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => RecipeCreatorSheet(
                          existingRecipeId: foodId,
                          existingName: detail.name,
                          existingIngredients: editIngredients,
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Recipe', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ── Ingredients Card (text) ────────────────────────────────────
              if (!(detail.isRecipe && detail.ingredients.isNotEmpty) &&
                  detail.ingredientsText != null && detail.ingredientsText!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                        child: const Text('INGREDIENTS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 80),
                          child: SingleChildScrollView(
                            child: Text(detail.ingredientsText!,
                              style: TextStyle(fontSize: 11, height: 1.4, color: Colors.grey.shade700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Source Variants Table ─────────────────────────────────────
              if (detail.sourceVariants.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('DATA SOURCES (${detail.sourceVariants.length})',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600, letterSpacing: 0.8)),
                ),
                _SourceVariantsTable(variants: detail.sourceVariants),
                const SizedBox(height: 10),
              ],

              // ── Log button ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onLog,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Log this food', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _nutritionRow(String label, double? value, String unit,
      {bool bold = false, bool highlight = false, double? driPercent}) {
    return Container(
      color: highlight ? const Color(0xFFFFF3E0) : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          if (highlight)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.star_rounded, size: 12, color: Colors.orange),
            ),
          Expanded(
            child: Text(label, style: TextStyle(
              fontSize: 11,
              fontWeight: bold || highlight ? FontWeight.w700 : FontWeight.w400,
              color: highlight ? Colors.orange.shade900 : null,
            )),
          ),
          if (driPercent != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text('${driPercent.toStringAsFixed(0)}% DV',
                style: TextStyle(fontSize: 11, color: highlight ? Colors.orange.shade700 : Colors.grey.shade500)),
            ),
          Text(value != null ? '${value.toStringAsFixed(1)}$unit' : '—',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: highlight ? Colors.orange.shade900 : null)),
        ],
      ),
    );
  }

  Widget _nutritionSubRow(String label, double? value, String unit) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 8, top: 1, bottom: 1),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const Spacer(),
          Text('${value.toStringAsFixed(1)}$unit',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _thinDivider() => Divider(height: 1, thickness: 0.5, color: Colors.grey.shade300,
    indent: 8, endIndent: 8);

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  Color _nutriscoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return const Color(0xFF1B8731);
      case 'B': return const Color(0xFF85BB2F);
      case 'C': return const Color(0xFFF5C623);
      case 'D': return const Color(0xFFE67E22);
      case 'E': return const Color(0xFFE74C3C);
      default: return Colors.grey;
    }
  }

  Color _novaColor(int group) {
    switch (group) {
      case 1: return const Color(0xFF1B8731);
      case 2: return const Color(0xFFF5C623);
      case 3: return const Color(0xFFE67E22);
      case 4: return const Color(0xFFE74C3C);
      default: return Colors.grey;
    }
  }
}

// ─── Source Variants Table ──────────────────────────────────────────────────

class _SourceVariantsTable extends StatelessWidget {
  final List<SourceVariant> variants;
  const _SourceVariantsTable({required this.variants});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            _HeaderCell('Source'),
            _HeaderCell('Cal'),
            _HeaderCell('P'),
            _HeaderCell('C'),
            _HeaderCell('F'),
          ],
        ),
        ...variants.map((v) => TableRow(
          children: [
            _DataCell(v.sourceLabel),
            _DataCell(v.cal?.toStringAsFixed(0) ?? '—'),
            _DataCell(v.protein?.toStringAsFixed(1) ?? '—'),
            _DataCell(v.carbs?.toStringAsFixed(1) ?? '—'),
            _DataCell(v.fat?.toStringAsFixed(1) ?? '—'),
          ],
        )),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
  );
}

class _DataCell extends StatelessWidget {
  final String text;
  const _DataCell(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
    child: Text(text, style: const TextStyle(fontSize: 11)),
  );
}

class _FoodSearchTile extends StatefulWidget {
  final FoodItem food;
  final List<FoodAllergenInfo> badges;
  final void Function(FoodItem) onAdd;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onInfoTap;
  const _FoodSearchTile({
    required this.food, required this.badges, required this.onAdd,
    this.isFavorite = false, this.onToggleFavorite, this.onInfoTap,
  });

  @override
  State<_FoodSearchTile> createState() => _FoodSearchTileState();
}

class _FoodSearchTileState extends State<_FoodSearchTile>
    with SingleTickerProviderStateMixin {
  bool _showBrand = false;
  bool _expanded = false; // Level 1 inline expansion
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.05, 0), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _slideCtrl,
        child: Column(
          children: [
            ListTile(
              leading: Text(food.emoji ?? '🍽️',
                  style: const TextStyle(fontSize: 22)),
              title: GestureDetector(
                onTap: () {
                  if (food.hasBrand) {
                    setState(() => _showBrand = !_showBrand);
                  } else {
                    setState(() => _expanded = !_expanded);
                  }
                },
                child: Row(
                  children: [
                    Expanded(child: Text(food.title)),
                    if (food.hasBrand && !_showBrand)
                      Icon(Icons.storefront, size: 14, color: Colors.grey.shade400),
                    if (food.sourceCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${food.sourceCount}',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showBrand && food.hasBrand)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(food.brandLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.7))),
                    ),
                  Text(
                    '${food.caloriesPerServing.toStringAsFixed(0)} kcal'
                    ' · ${(food.servingSize ?? 100).toStringAsFixed(0)}g serving',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (widget.badges.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Wrap(
                        spacing: 3,
                        runSpacing: 2,
                        children: widget.badges.take(4).map((a) =>
                          AllergenBadge(allergen: a),
                        ).toList(),
                      ),
                    ),
                  if (food.sourceBadge.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: food.isRecipe ? Colors.green : food.isCustomFood ? Colors.blue : Colors.purple,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(food.sourceBadge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info button (Level 2)
                  GestureDetector(
                    onTap: widget.onInfoTap,
                    child: Icon(Icons.info_outline_rounded,
                      size: 20, color: Colors.grey.shade400),
                  ),
                  const SizedBox(width: 2),
                  if (widget.onToggleFavorite != null)
                    GestureDetector(
                      onTap: widget.onToggleFavorite,
                      child: Icon(
                        widget.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: widget.isFavorite ? Colors.amber : Colors.grey.shade400,
                        size: 22,
                      ),
                    ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                    onPressed: () => widget.onAdd(food),
                  ),
                ],
              ),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            // Level 1: inline macro bar
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildMacroBar(food),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(FoodItem food) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _macroChip('P', food.protein, Colors.blue),
            _macroChip('C', food.carbs, Colors.orange),
            _macroChip('F', food.fat, Colors.red.shade400),
            if (food.fiber != null)
              _macroChip('Fib', food.fiber, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(String label, double? value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label: ${(value ?? 0).toStringAsFixed(1)}g',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }
}
