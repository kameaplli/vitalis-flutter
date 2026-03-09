import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/food_provider.dart';
import '../providers/selected_person_provider.dart';
import '../providers/nutrition_analytics_provider.dart';
import '../models/food_item.dart';
import '../models/nutrition_analytics.dart';
import '../models/insight_data.dart';
import '../core/timezone_util.dart';
import 'entries_screen.dart' show NutritionHistoryContent;

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

class _NutritionScreenState extends ConsumerState<NutritionScreen>
    with SingleTickerProviderStateMixin {
  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

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
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Log'),
            Tab(text: 'History'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // Tab 0: meal logging form
          SingleChildScrollView(
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
          // Tab 1: nutrition history
          const NutritionHistoryContent(),
          // Tab 2: analytics
          const _AnalyticsTab(),
        ],
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
    if (ok && mounted) {
      // Always refresh entries list and dashboard after any successful log/edit
      ref.invalidate(nutritionEntriesProvider);
      ref.invalidate(dashboardProvider(personId));
      if (isEdit) context.pop();
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
                if (sf.food.uniqueAllergens.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 3,
                      runSpacing: 2,
                      children: sf.food.uniqueAllergens.take(4).map((a) =>
                        _AllergenBadge(allergen: a),
                      ).toList(),
                    ),
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
  bool _barcodeScanning = false;
  bool _labelScanning = false;
  MobileScannerController? _scanCtrl;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl?.dispose();
    _scanCtrl?.dispose();
    super.dispose();
  }

  // ── Barcode scan ────────────────────────────────────────────────────────────

  void _startBarcodeScanning() {
    _scanCtrl?.dispose();
    _scanCtrl = MobileScannerController();
    setState(() { _barcodeScanning = true; });
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    if (!_barcodeScanning) return;
    setState(() { _barcodeScanning = false; });
    _scanCtrl?.stop();
    try {
      final res = await Dio().get(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
      );
      if (res.data['status'] == 1) {
        final p = res.data['product'] as Map<String, dynamic>;
        final n = (p['nutriments'] as Map<String, dynamic>?) ?? {};
        final productName = (p['product_name'] as String?)?.trim().isNotEmpty == true
            ? p['product_name'] as String
            : 'Product $barcode';

        // Allergen check via backend
        List<FoodAllergenInfo> allergens = [];
        try {
          final allergenRes = await apiClient.dio.get(
            ApiConstants.foodAllergenCheck,
            queryParameters: {'food_name': productName},
          );
          final rawAllergens = allergenRes.data['allergens'] as List<dynamic>? ?? [];
          allergens = rawAllergens
              .map((a) => FoodAllergenInfo.fromJson(a as Map<String, dynamic>))
              .toList();
        } catch (_) {}

        final food = FoodItem(
          id: barcode,
          name: productName,
          cal:      (n['energy-kcal_100g'] as num?)?.toDouble() ?? 0,
          protein:  (n['proteins_100g']     as num?)?.toDouble() ?? 0,
          carbs:    (n['carbohydrates_100g'] as num?)?.toDouble() ?? 0,
          fat:      (n['fat_100g']           as num?)?.toDouble() ?? 0,
          servingSize: 100,
          emoji: '🏷️',
          allergens: allergens,
        );
        _addFood(food);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Product not found: $barcode')));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barcode lookup failed')));
      }
    }
  }

  // ── Food label scan ─────────────────────────────────────────────────────────

  Future<void> _scanFoodLabel(ImageSource source) async {
    final img = await ImagePicker().pickImage(source: source);
    if (img == null) return;
    setState(() { _labelScanning = true; });
    try {
      final bytes = await img.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'label.jpg'),
      });
      final res = await apiClient.dio.post(
        ApiConstants.foodLabelScan, data: formData);
      final d = res.data as Map<String, dynamic>;
      if (mounted) _showLabelResult(d);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Label scan failed')));
      }
    } finally {
      if (mounted) setState(() { _labelScanning = false; });
    }
  }

  void _showLabelResult(Map<String, dynamic> d) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Label Scan Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Product name', isDense: true),
            ),
            const SizedBox(height: 10),
            Text('Per 100g:', style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600)),
            Text('Calories: ${d['calories_per_100g'] ?? '—'} kcal'),
            Text('Protein: ${d['protein_per_100g'] ?? '—'} g'),
            Text('Carbs: ${d['carbs_per_100g'] ?? '—'} g'),
            Text('Fat: ${d['fat_per_100g'] ?? '—'} g'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              final food = FoodItem(
                id: 'label_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim().isNotEmpty
                    ? nameCtrl.text.trim()
                    : 'Scanned Product',
                cal:     (d['calories_per_100g'] as num?)?.toDouble() ?? 0,
                protein: (d['protein_per_100g']  as num?)?.toDouble() ?? 0,
                carbs:   (d['carbs_per_100g']    as num?)?.toDouble() ?? 0,
                fat:     (d['fat_per_100g']      as num?)?.toDouble() ?? 0,
                servingSize: 100,
                emoji: '📋',
              );
              _addFood(food);
            },
            child: const Text('Add Food'),
          ),
        ],
      ),
    );
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
              // Search + scan buttons
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
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
                    const SizedBox(width: 6),
                    // Barcode scan
                    IconButton(
                      tooltip: 'Scan barcode',
                      icon: Icon(
                        _barcodeScanning ? Icons.cancel_outlined : Icons.qr_code_scanner,
                        color: _barcodeScanning
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: _barcodeScanning
                          ? () => setState(() { _barcodeScanning = false; _scanCtrl?.stop(); })
                          : _startBarcodeScanning,
                    ),
                    // Food label scan
                    _labelScanning
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : PopupMenuButton<ImageSource>(
                            icon: Icon(Icons.document_scanner_outlined,
                                color: Theme.of(context).colorScheme.primary),
                            tooltip: 'Scan food label',
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: ImageSource.camera,
                                child: Row(children: [
                                  Icon(Icons.camera_alt_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Camera'),
                                ]),
                              ),
                              const PopupMenuItem(
                                value: ImageSource.gallery,
                                child: Row(children: [
                                  Icon(Icons.photo_library_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Gallery'),
                                ]),
                              ),
                            ],
                            onSelected: _scanFoodLabel,
                          ),
                  ],
                ),
              ),
              // Barcode camera view
              if (_barcodeScanning)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MobileScanner(
                      controller: _scanCtrl!,
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty &&
                            barcodes.first.rawValue != null) {
                          _onBarcodeDetected(barcodes.first.rawValue!);
                        }
                      },
                    ),
                  ),
                ),
              // Tabs (hidden during search or barcode scan)
              if (_query.isEmpty && !_barcodeScanning)
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
              // Food list (hidden while barcode camera is open)
              if (!_barcodeScanning) Expanded(
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
        final badges = food.uniqueAllergens;
        return ListTile(
          leading: Text(food.emoji ?? '🍽️',
              style: const TextStyle(fontSize: 22)),
          title: Text(food.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${food.caloriesPerServing.toStringAsFixed(0)} kcal'
                ' · ${(food.servingSize ?? 100).toStringAsFixed(0)}g serving',
                style: const TextStyle(fontSize: 12),
              ),
              if (badges.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 2,
                    children: badges.take(4).map((a) =>
                      _AllergenBadge(allergen: a),
                    ).toList(),
                  ),
                ),
            ],
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

// ─── Allergen badge widget ────────────────────────────────────────────────────

class _AllergenBadge extends StatelessWidget {
  final FoodAllergenInfo allergen;
  const _AllergenBadge({required this.allergen});

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
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.shade700),
      ),
    );
  }
}

// ─── Nutrition AI Insights provider ──────────────────────────────────────────

// key = "person:days"
final _nutritionInsightsProvider =
    FutureProvider.family<WeeklyInsight?, String>((ref, key) async {
  try {
    final parts = key.split(':');
    final person = parts[0];
    final days = parts.length > 1 ? parts[1] : '30';
    final res = await apiClient.dio.get(
      ApiConstants.insightsNutrition,
      queryParameters: {'person': person, 'days': int.parse(days)},
    );
    return WeeklyInsight.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

// ─── Analytics tab ────────────────────────────────────────────────────────────

class _AnalyticsTab extends ConsumerStatefulWidget {
  const _AnalyticsTab();
  @override
  ConsumerState<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<_AnalyticsTab> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final key = '$person:$_days';
    final async = ref.watch(nutritionAnalyticsProvider(key));

    return Column(
      children: [
        // Period selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7d')),
              ButtonSegment(value: 30, label: Text('30d')),
              ButtonSegment(value: 90, label: Text('90d')),
            ],
            selected: {_days},
            onSelectionChanged: (s) => setState(() => _days = s.first),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) => _AnalyticsContent(data: data, days: _days, personKey: key),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsContent extends ConsumerWidget {
  final NutritionAnalyticsData data;
  final int days;
  final String personKey;
  const _AnalyticsContent({required this.data, required this.days, required this.personKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(_nutritionInsightsProvider(personKey));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // AI Insights card
        insightAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (insight) => insight != null
              ? _NutritionInsightsCard(insight: insight)
              : const SizedBox.shrink(),
        ),
        _MacroDonut(data: data),
        const SizedBox(height: 12),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text('Meal Type Breakdown',
                style: Theme.of(context).textTheme.titleMedium),
            initiallyExpanded: true,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 4),
            children: _mealTypes.map((mt) => _MealTypeCard(
                  mealType: mt,
                  macros: data.byMealType[mt],
                  topFoods: data.mealFoods[mt] ?? [],
                  maxCalories: _maxMealCalories(data),
                )).toList(),
          ),
        ),
      ],
    );
  }

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  double _maxMealCalories(NutritionAnalyticsData d) {
    double max = 1;
    for (final mt in _mealTypes) {
      final c = d.byMealType[mt]?.calories ?? 0;
      if (c > max) max = c;
    }
    return max;
  }
}

// ─── Nutrition AI Insights card ───────────────────────────────────────────────

class _NutritionInsightsCard extends StatelessWidget {
  final WeeklyInsight insight;
  const _NutritionInsightsCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAi = insight.source == 'ai';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isAi ? Icons.auto_awesome : Icons.bar_chart,
                  size: 16, color: isAi ? Colors.purple : Colors.teal),
              const SizedBox(width: 6),
              Text(isAi ? 'AI Nutrition Insights' : 'Nutrition Analysis',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isAi ? Colors.purple : Colors.teal)),
            ]),
            const SizedBox(height: 10),
            ...insight.insights.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.insights, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.title, style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(i.body, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            if (insight.recommendations.isNotEmpty) ...[
              const Divider(height: 16),
              ...insight.recommendations.map((r) {
                final color = r.priority == 'high' ? Colors.red
                    : (r.priority == 'medium' ? Colors.orange : Colors.green);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.lightbulb_outline, size: 14, color: color),
                    const SizedBox(width: 6),
                    Expanded(child: Text(r.action,
                        style: const TextStyle(fontSize: 12))),
                  ]),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Macro donut chart ────────────────────────────────────────────────────────

class _MacroDonut extends StatefulWidget {
  final NutritionAnalyticsData data;
  const _MacroDonut({required this.data});
  @override
  State<_MacroDonut> createState() => _MacroDonutState();
}

class _MacroDonutState extends State<_MacroDonut> {
  int? _touched;

  void _showMacroSheet(BuildContext context, String macro, List<MacroFood> foods) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _MacroFoodSheet(macro: macro, foods: foods),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.data.totals;
    final total = t.protein + t.carbs + t.fat;
    if (total <= 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No nutrition data for this period')),
        ),
      );
    }
    final sections = [
      PieChartSectionData(
        value: t.protein,
        color: const Color(0xFF1565C0),
        title: '${(t.protein / total * 100).toStringAsFixed(0)}%',
        radius: _touched == 0 ? 60 : 50,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: t.carbs,
        color: const Color(0xFF2E7D32),
        title: '${(t.carbs / total * 100).toStringAsFixed(0)}%',
        radius: _touched == 1 ? 60 : 50,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: t.fat,
        color: const Color(0xFFE65100),
        title: '${(t.fat / total * 100).toStringAsFixed(0)}%',
        radius: _touched == 2 ? 60 : 50,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
    const macroKeys = ['protein', 'carbs', 'fat'];
    const macroLabels = ['Protein', 'Carbs', 'Fat'];
    const macroColors = [Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFFE65100)];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Macro Distribution',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Tap a segment to see top foods',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent) {
                        final idx = response?.touchedSection?.touchedSectionIndex;
                        setState(() => _touched = idx);
                        if (idx != null) {
                          _showMacroSheet(
                            context,
                            macroLabels[idx],
                            widget.data.macroFoods[macroKeys[idx]] ?? [],
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(
                          color: macroColors[i], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(macroLabels[i], style: const TextStyle(fontSize: 12)),
                ]),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meal type card ───────────────────────────────────────────────────────────

class _MealTypeCard extends StatelessWidget {
  final String mealType;
  final MealTypeMacros? macros;
  final List<MacroFood> topFoods;
  final double maxCalories;

  const _MealTypeCard({
    required this.mealType,
    required this.macros,
    required this.topFoods,
    required this.maxCalories,
  });

  static const _icons = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch':     Icons.light_mode_outlined,
    'dinner':    Icons.nights_stay_outlined,
    'snack':     Icons.local_cafe_outlined,
  };

  void _showFoodSheet(BuildContext context) {
    if (topFoods.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => _MealFoodSheet(mealType: mealType, foods: topFoods),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = macros;
    if (m == null || m.calories == 0) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(_icons[mealType] ?? Icons.restaurant_outlined,
              color: Colors.grey),
          title: Text(_capitalize(mealType)),
          subtitle: const Text('No data'),
          dense: true,
        ),
      );
    }
    final frac = (m.calories / maxCalories).clamp(0.0, 1.0);
    final total = m.protein + m.carbs + m.fat;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showFoodSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_icons[mealType] ?? Icons.restaurant_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(_capitalize(mealType),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${m.calories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                if (topFoods.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16,
                      color: Colors.grey.shade500),
                ],
              ]),
              const SizedBox(height: 6),
              // Calorie bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 6),
              // Macro sub-bars (stacked horizontal)
              if (total > 0)
                Row(children: [
                  _macroChip('P', m.protein, total, const Color(0xFF1565C0)),
                  const SizedBox(width: 4),
                  _macroChip('C', m.carbs, total, const Color(0xFF2E7D32)),
                  const SizedBox(width: 4),
                  _macroChip('F', m.fat, total, const Color(0xFFE65100)),
                ]),
              Text('${m.logCount} logs',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroChip(String label, double val, double total, Color color) {
    return Expanded(
      flex: (val / total * 100).round().clamp(1, 100),
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Bottom sheet: top foods for a macro ─────────────────────────────────────

class _MacroFoodSheet extends StatelessWidget {
  final String macro;
  final List<MacroFood> foods;
  const _MacroFoodSheet({required this.macro, required this.foods});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('Top $macro Sources',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Expanded(
          child: foods.isEmpty
              ? const Center(child: Text('No data'))
              : ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: foods.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = foods[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(f.foodName, style: const TextStyle(fontSize: 14)),
                      subtitle: Text('${f.occurrences}\u00d7 logged'),
                      trailing: Text(
                        '${f.total.toStringAsFixed(1)} g',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      dense: true,
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─── Bottom sheet: top foods for a meal type ─────────────────────────────────

class _MealFoodSheet extends StatelessWidget {
  final String mealType;
  final List<MacroFood> foods;
  const _MealFoodSheet({required this.mealType, required this.foods});

  @override
  Widget build(BuildContext context) {
    final title = mealType.isEmpty
        ? 'Top Foods'
        : 'Top ${mealType[0].toUpperCase()}${mealType.substring(1)} Foods';
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Expanded(
          child: foods.isEmpty
              ? const Center(child: Text('No data'))
              : ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: foods.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = foods[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(f.foodName, style: const TextStyle(fontSize: 14)),
                      subtitle: Text('${f.occurrences}\u00d7 logged'),
                      trailing: Text(
                        '${f.total.toStringAsFixed(1)} kcal',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      dense: true,
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
