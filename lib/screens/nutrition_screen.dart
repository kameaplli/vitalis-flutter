import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/food_provider.dart';
import '../providers/selected_person_provider.dart';
import '../models/food_item.dart';
import '../core/timezone_util.dart';

// ─── Daily intake lookup by age / gender ─────────────────────────────────────

class _DailyIntake {
  final double calories, protein, carbs, fat;
  const _DailyIntake(this.calories, this.protein, this.carbs, this.fat);
}

_DailyIntake _dailyIntake(int? age, String? gender) {
  final male = (gender ?? '').toLowerCase().startsWith('m');
  final a = age ?? 30;
  if (a < 4)  return const _DailyIntake(1200, 13, 150, 40);
  if (a < 9)  return const _DailyIntake(1400, 19, 175, 45);
  if (a < 14) return _DailyIntake(male ? 1800 : 1600, 34, male ? 225 : 200, 50);
  if (a < 19) return _DailyIntake(male ? 2600 : 2000, male ? 52 : 46, male ? 325 : 250, male ? 75 : 65);
  if (a < 51) return _DailyIntake(male ? 2500 : 2000, male ? 56 : 46, male ? 300 : 250, male ? 70 : 65);
  return _DailyIntake(male ? 2300 : 1800, male ? 56 : 46, male ? 275 : 225, male ? 65 : 60);
}

// ─── Main screen ──────────────────────────────────────────────────────────────

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  Widget build(BuildContext context) {
    final nutrition = ref.watch(nutritionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isEditMode = nutrition.editEntryId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Entry' : 'Log Nutrition'),
        actions: [
          TextButton(
            onPressed: nutrition.selectedFoods.isEmpty || nutrition.isLoading
                ? null
                : () => _logMeal(context),
            child: nutrition.isLoading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(isEditMode ? 'Update Meal' : 'Log Meal'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Meal type ────────────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _mealTypes.map((type) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type[0].toUpperCase() + type.substring(1)),
                    selected: nutrition.mealType == type,
                    onSelected: (_) =>
                        ref.read(nutritionProvider.notifier).setMealType(type),
                  ),
                )).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // ── Date + Time ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(DateFormat('EEE, MMM d').format(DateTime.now())),
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 16),
                    label: Text('${nutrition.mealTime.format(context)} ${localTimezone()}'),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: nutrition.mealTime,
                      );
                      if (t != null) {
                        ref.read(nutritionProvider.notifier).setMealTime(t);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Recent meals carousel ────────────────────────────────────────
            _RecentMealsSection(),

            const SizedBox(height: 20),

            // ── Frequent individual foods ─────────────────────────────────────
            _FrequentFoodsSection(),

            // ── Selected foods ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Selected Foods',
                    style: Theme.of(context).textTheme.titleSmall),
                TextButton.icon(
                  onPressed: () => _showFoodSearch(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Food'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (nutrition.selectedFoods.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: colorScheme.outlineVariant,
                      style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.restaurant_outlined,
                        size: 48, color: colorScheme.outlineVariant),
                    const SizedBox(height: 8),
                    Text('No foods added yet',
                        style: TextStyle(color: colorScheme.outline)),
                  ],
                ),
              )
            else
              Column(
                children: nutrition.selectedFoods.map((sf) => _FoodItemTile(
                  key: ValueKey(sf.food.id),
                  sf: sf,
                  onRemove: () =>
                      ref.read(nutritionProvider.notifier).removeFood(sf.food.id),
                  onGramsChanged: (g) =>
                      ref.read(nutritionProvider.notifier).updateGrams(sf.food.id, g),
                )).toList(),
              ),

            const SizedBox(height: 16),

            // ── Macro breakdown ──────────────────────────────────────────────
            if (nutrition.selectedFoods.isNotEmpty)
              _MacroBreakdownCard(nutrition: nutrition),
          ],
        ),
      ),
    );
  }

  Future<void> _logMeal(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final personId = ref.read(selectedPersonProvider);
    final isEdit = ref.read(nutritionProvider).editEntryId != null;
    final ok = await ref.read(nutritionProvider.notifier).logNutrition(personId: personId);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(ok
          ? (isEdit ? 'Entry updated!' : 'Meal logged!')
          : 'Failed to save')),
    );
    if (ok && isEdit && mounted) {
      ref.invalidate(nutritionEntriesProvider);
      context.pop();
    }
  }

  void _showFoodSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FoodSearchSheet(),
    );
  }
}

// ─── Frequent individual foods ───────────────────────────────────────────────

class _FrequentFoodsSection extends ConsumerWidget {
  const _FrequentFoodsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(recentMealsProvider);
    return mealsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (meals) {
        if (meals.isEmpty) return const SizedBox.shrink();

        // Count how often each individual food appears across all meal combos
        final counts = <String, int>{};
        final foodMap = <String, RecentMealItem>{};
        for (final meal in meals) {
          for (final item in meal.items) {
            counts[item.foodId] = (counts[item.foodId] ?? 0) + 1;
            foodMap[item.foodId] = item;
          }
        }
        final top = (counts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .map((e) => foodMap[e.key]!)
            .toList();

        if (top.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Add',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: top.map((item) {
                final label = item.foodName.length > 14
                    ? '${item.foodName.substring(0, 13)}…'
                    : item.foodName;
                return ActionChip(
                  avatar: Text(item.emoji ?? '🍽️',
                      style: const TextStyle(fontSize: 14)),
                  label: Text(label,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => ref
                      .read(nutritionProvider.notifier)
                      .addFood(item.toFoodItem()),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

// ─── Recent meals carousel ────────────────────────────────────────────────────

class _RecentMealsSection extends ConsumerWidget {
  const _RecentMealsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(recentMealsProvider);
    return mealsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (meals) {
        if (meals.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Meals',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => _RecentMealChip(meal: meals[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentMealChip extends ConsumerWidget {
  final RecentMeal meal;
  const _RecentMealChip({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        ref.read(nutritionProvider.notifier).loadRecentMeal(
          meal.items
              .map((item) =>
                  SelectedFood(food: item.toFoodItem(), grams: item.grams))
              .toList(),
          meal.mealType,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surfaceContainerLowest,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meal.mealType.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                meal.display,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Food item tile with grams input ─────────────────────────────────────────

class _FoodItemTile extends StatefulWidget {
  final SelectedFood sf;
  final VoidCallback onRemove;
  final void Function(double) onGramsChanged;

  const _FoodItemTile({
    super.key,
    required this.sf,
    required this.onRemove,
    required this.onGramsChanged,
  });

  @override
  State<_FoodItemTile> createState() => _FoodItemTileState();
}

class _FoodItemTileState extends State<_FoodItemTile> {
  late TextEditingController _ctrl;
  late int _servings;

  double get _baseServing => widget.sf.food.servingSize ?? 100;

  @override
  void initState() {
    super.initState();
    _servings = (widget.sf.grams / _baseServing).round().clamp(1, 99);
    _ctrl = TextEditingController(
        text: widget.sf.grams.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(_FoodItemTile old) {
    super.didUpdateWidget(old);
    if (old.sf.food.id != widget.sf.food.id) {
      _servings = (widget.sf.grams / _baseServing).round().clamp(1, 99);
      _ctrl.text = widget.sf.grams.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _applyServings(int s) {
    _servings = s.clamp(1, 99);
    final grams = _servings * _baseServing;
    _ctrl.text = grams.toStringAsFixed(0);
    widget.onGramsChanged(grams);
  }

  @override
  Widget build(BuildContext context) {
    final sf = widget.sf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(sf.food.emoji ?? '🍽️',
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sf.food.name,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${sf.calories.toStringAsFixed(0)} kcal'
                  '  ·  P ${sf.protein.toStringAsFixed(1)}g'
                  '  C ${sf.carbs.toStringAsFixed(1)}g'
                  '  F ${sf.fat.toStringAsFixed(1)}g',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Servings stepper (×N)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _servings > 1 ? () => setState(() => _applyServings(_servings - 1)) : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.remove,
                      size: 16,
                      color: _servings > 1
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('${_servings}×',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
              ),
              InkWell(
                onTap: () => setState(() => _applyServings(_servings + 1)),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.add,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          // Grams input (edit base serving size)
          SizedBox(
            width: 68,
            child: TextFormField(
              controller: _ctrl,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                suffixText: 'g',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              ),
              onChanged: (v) {
                final val = double.tryParse(v);
                if (val != null && val > 0) {
                  // Update servings counter to reflect new grams
                  setState(() {
                    _servings = (val / _baseServing).round().clamp(1, 99);
                  });
                  widget.onGramsChanged(val);
                }
              },
              onTapOutside: (_) {
                final val = double.tryParse(_ctrl.text);
                if (val == null || val <= 0) {
                  _ctrl.text = sf.grams.toStringAsFixed(0);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: Colors.grey,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}

// ─── Macro breakdown card ─────────────────────────────────────────────────────

class _MacroBreakdownCard extends ConsumerWidget {
  final NutritionState nutrition;
  const _MacroBreakdownCard({required this.nutrition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final selectedPerson = ref.watch(selectedPersonProvider);
    int? personAge;
    String? personGender;
    if (selectedPerson == 'self') {
      personAge = auth.user?.age;
      personGender = auth.user?.gender;
    } else {
      final member = auth.user?.profile.children
          .where((c) => c.id == selectedPerson).firstOrNull;
      personAge = member?.age;
      personGender = member?.gender;
    }
    final intake = _dailyIntake(personAge, personGender);
    final protein = nutrition.totalProtein;
    final carbs = nutrition.totalCarbs;
    final fat = nutrition.totalFat;
    final macroTotal = protein + carbs + fat;

    final ageStr = personAge != null ? '${personAge}yr' : '—';
    final genderStr = personGender ?? '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Macro Breakdown',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Donut + legend ───────────────────────────────────────────
                Column(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: macroTotal <= 0
                          ? Center(
                              child: Text('—',
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 24)))
                          : PieChart(PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 28,
                              sections: [
                                _section(protein, macroTotal, Colors.blue),
                                _section(carbs, macroTotal, Colors.orange),
                                _section(fat, macroTotal, Colors.red),
                              ],
                            )),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dot(Colors.blue, 'P'),
                        const SizedBox(width: 6),
                        _dot(Colors.orange, 'C'),
                        const SizedBox(width: 6),
                        _dot(Colors.red, 'F'),
                      ],
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // ── Daily intake guide ───────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Guide ($genderStr, $ageStr)',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      _IntakeRow('Calories',
                          nutrition.totalCalories, intake.calories, 'kcal',
                          Colors.deepOrange),
                      _IntakeRow('Protein',
                          protein, intake.protein, 'g', Colors.blue),
                      _IntakeRow('Carbs',
                          carbs, intake.carbs, 'g', Colors.orange),
                      _IntakeRow('Fat',
                          fat, intake.fat, 'g', Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _section(double val, double total, Color color) =>
      PieChartSectionData(
        value: val,
        color: color,
        title: total > 0
            ? '${(val / total * 100).toStringAsFixed(0)}%'
            : '',
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 22,
      );

  Widget _dot(Color color, String label) => Row(
        children: [
          Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      );
}

class _IntakeRow extends StatelessWidget {
  final String label;
  final double current;
  final double daily;
  final String unit;
  final Color color;

  const _IntakeRow(this.label, this.current, this.daily, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = daily > 0 ? (current / daily).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500)),
              Text(
                '${current.toStringAsFixed(0)} / ${daily.toStringAsFixed(0)} $unit',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              color: pct >= 1.0 ? Colors.red : color,
              backgroundColor: color.withValues(alpha: 0.15),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Food search bottom sheet ─────────────────────────────────────────────────

class FoodSearchSheet extends ConsumerStatefulWidget {
  /// If provided, calls this callback instead of adding to nutritionProvider.
  final void Function(FoodItem)? onFoodPicked;
  const FoodSearchSheet({super.key, this.onFoodPicked});
  @override
  ConsumerState<FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<FoodSearchSheet>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _query = '';
  TabController? _tabCtrl;
  List<FoodCategory> _categories = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(foodDatabaseProvider);

    return foodsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (categories) {
        if (_tabCtrl == null || _categories.length != categories.length) {
          _tabCtrl?.dispose();
          _categories = categories;
          _tabCtrl = TabController(
              length: categories.length + 1, vsync: this);
        }

        // Filter by search query across all categories
        final allFiltered = <FoodItem>[];
        for (final cat in categories) {
          allFiltered.addAll(cat.items.where(
              (f) => _query.isEmpty || f.name.toLowerCase().contains(_query)));
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          maxChildSize: 0.96,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Search
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search foods…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            })
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                ),
              ),
              // Tabs (hidden during search)
              if (_query.isEmpty)
                TabBar(
                  controller: _tabCtrl!,
                  isScrollable: true,
                  tabs: [
                    const Tab(text: 'All'),
                    ...categories.map((c) => Tab(
                          text: c.name.length > 18
                              ? '${c.name.substring(0, 16)}…'
                              : c.name,
                        )),
                  ],
                ),
              // List
              Expanded(
                child: _query.isNotEmpty
                    ? _FoodList(
                        items: allFiltered,
                        scrollCtrl: scrollCtrl,
                        onAdd: _addFood,
                      )
                    : TabBarView(
                        controller: _tabCtrl!,
                        children: [
                          _FoodList(
                              items: allFiltered,
                              scrollCtrl: scrollCtrl,
                              onAdd: _addFood),
                          ...categories.map((c) => _FoodList(
                                items: c.items,
                                scrollCtrl: scrollCtrl,
                                onAdd: _addFood,
                              )),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addFood(FoodItem food) {
    if (widget.onFoodPicked != null) {
      widget.onFoodPicked!(food);
    } else {
      ref.read(nutritionProvider.notifier).addFood(food);
    }
    Navigator.pop(context);
  }
}

class _FoodList extends StatelessWidget {
  final List<FoodItem> items;
  final ScrollController scrollCtrl;
  final void Function(FoodItem) onAdd;

  const _FoodList(
      {required this.items,
      required this.scrollCtrl,
      required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No foods found'));
    }
    return ListView.builder(
      controller: scrollCtrl,
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final food = items[i];
        return ListTile(
          leading: Text(food.emoji ?? '🍽️',
              style: const TextStyle(fontSize: 22)),
          title: Text(food.name),
          subtitle: Text(
            '${food.caloriesPerServing.toStringAsFixed(0)} kcal'
            ' · ${(food.servingSize ?? 100).toStringAsFixed(0)}g serving',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon:
                const Icon(Icons.add_circle, color: Colors.green, size: 28),
            onPressed: () => onAdd(food),
          ),
        );
      },
    );
  }
}
