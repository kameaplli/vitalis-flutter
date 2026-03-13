import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/app_cache.dart';
import '../../core/constants.dart';
import '../../models/food_item.dart';
import '../../providers/food_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/selected_person_provider.dart';
import 'allergen_badge.dart';

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
      final results = (data['results'] as List? ?? []).map((r) {
        final m = r as Map<String, dynamic>;
        return FoodItem(
          id: m['id'] ?? '',
          name: m['name'] ?? '',
          displayName: m['display_name'],
          brand: m['brand'],
          brandDisplay: m['brand_display'],
          cal: (m['cal'] as num?)?.toDouble(),
          protein: (m['protein'] as num?)?.toDouble(),
          carbs: (m['carbs'] as num?)?.toDouble(),
          fat: (m['fat'] as num?)?.toDouble(),
          emoji: m['emoji'],
          unit: m['unit'],
          servingSize: (m['serving_size'] as num?)?.toDouble(),
          category: m['category'],
          source: m['source'],
          imageUrl: m['image_url'],
        );
      }).toList();
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
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
                  );
                }),
                const SizedBox(height: 12),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),

        // ── Manual entry fallback ──
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _showManualEntry,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Enter food manually'),
            ),
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
          )));
    }
    if (recentMatches.isNotEmpty) {
      sections.add(_sectionHeader('Recent', Icons.history));
      sections.addAll(recentMatches.map((f) => _FoodSearchTile(
            food: f, badges: f.uniqueAllergens, onAdd: _addFood,
            isFavorite: false, onToggleFavorite: () => _toggleFavorite(f),
          )));
    }
    if (otherMatches.isNotEmpty) {
      sections.add(_sectionHeader('All Results', Icons.restaurant_menu));
      sections.addAll(otherMatches.map((f) => _FoodSearchTile(
            food: f, badges: f.uniqueAllergens, onAdd: _addFood,
            isFavorite: favIds.contains(f.id),
            onToggleFavorite: () => _toggleFavorite(f),
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
                      : filtered.isNotEmpty
                          ? _buildGroupedResults(filtered, scrollCtrl)
                          : _serverSearching
                              ? const Center(child: CircularProgressIndicator())
                              : (_serverResults != null && _serverResults!.isNotEmpty)
                                  ? _buildGroupedResults(_serverResults!, scrollCtrl)
                                  : Center(
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
                                    ),
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
}

class _FoodSearchTile extends StatefulWidget {
  final FoodItem food;
  final List<FoodAllergenInfo> badges;
  final void Function(FoodItem) onAdd;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  const _FoodSearchTile({
    required this.food, required this.badges, required this.onAdd,
    this.isFavorite = false, this.onToggleFavorite,
  });

  @override
  State<_FoodSearchTile> createState() => _FoodSearchTileState();
}

class _FoodSearchTileState extends State<_FoodSearchTile>
    with SingleTickerProviderStateMixin {
  bool _showBrand = false;
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
        child: ListTile(
          leading: Text(food.emoji ?? '🍽️',
              style: const TextStyle(fontSize: 22)),
          title: GestureDetector(
            onTap: food.hasBrand
                ? () => setState(() => _showBrand = !_showBrand)
                : null,
            child: Row(
              children: [
                Expanded(child: Text(food.title)),
                if (food.hasBrand && !_showBrand)
                  Icon(Icons.storefront, size: 14, color: Colors.grey.shade400),
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
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onToggleFavorite != null)
                GestureDetector(
                  onTap: widget.onToggleFavorite,
                  child: Icon(
                    widget.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: widget.isFavorite ? Colors.amber : Colors.grey.shade400,
                    size: 22,
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                onPressed: () => widget.onAdd(food),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
