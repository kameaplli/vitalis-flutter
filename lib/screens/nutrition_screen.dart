import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
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
import '../widgets/voice_meal_sheet.dart';
import '../widgets/nutrient_card.dart';
import '../providers/nutrient_provider.dart';

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
            Tab(text: 'Insights'),
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
            // ── Daily progress header ──────────────────────────────────────
            _DailyProgressHeader(nutrition: nutrition),

            const SizedBox(height: 16),

            // ── 5-method food entry hub ────────────────────────────────────
            Text('Add Food', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                _EntryMethodCard(
                  icon: Icons.search,
                  label: 'Search',
                  color: Colors.blue,
                  onTap: () => _showFoodSearch(context),
                ),
                const SizedBox(width: 8),
                _EntryMethodCard(
                  icon: Icons.qr_code_scanner,
                  label: 'Barcode',
                  color: Colors.orange,
                  onTap: () => _showBarcodeScan(context),
                ),
                const SizedBox(width: 8),
                _EntryMethodCard(
                  icon: Icons.camera_alt_outlined,
                  label: 'Label',
                  color: Colors.green,
                  onTap: () => _showLabelScanOptions(context),
                ),
                const SizedBox(width: 8),
                _EntryMethodCard(
                  icon: Icons.restaurant,
                  label: 'Photo AI',
                  color: Colors.teal,
                  onTap: () => _showPhotoFoodRecognition(context),
                ),
                const SizedBox(width: 8),
                _EntryMethodCard(
                  icon: Icons.mic,
                  label: 'Voice',
                  color: Colors.purple,
                  onTap: () {
                    final personId = ref.read(selectedPersonProvider);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => VoiceMealSheet(
                        personId: personId,
                        onLogged: () {
                          ref.invalidate(nutritionProvider);
                          ref.invalidate(dashboardProvider(personId));
                          ref.invalidate(nutritionEntriesProvider);
                          ref.invalidate(nutritionAnalyticsProvider);
                          AppCache.clearAnalytics();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Meal type + time row ───────────────────────────────────────
            Row(
              children: [
                ..._mealTypes.map((type) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(type[0].toUpperCase() + type.substring(1),
                        style: const TextStyle(fontSize: 12)),
                    selected: nutrition.mealType == type,
                    onSelected: (_) =>
                        ref.read(nutritionProvider.notifier).setMealType(type),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )),
              ],
            ),

            const SizedBox(height: 12),

            // ── Meal suggestions for selected meal type ───────────────────────
            _MealSuggestionsSection(mealType: nutrition.mealType),

            const SizedBox(height: 8),

            // ── Recent meals carousel ────────────────────────────────────────
            _RecentMealsSection(),

            const SizedBox(height: 16),

            // ── Frequent individual foods ─────────────────────────────────────
            _FrequentFoodsSection(),

            // ── Selected foods ───────────────────────────────────────────────
            if (nutrition.selectedFoods.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Selected Foods (${nutrition.selectedFoods.length})',
                      style: Theme.of(context).textTheme.titleSmall),
                  TextButton.icon(
                    onPressed: () => _showFoodSearch(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add More'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
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
            ] else ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Icon(Icons.restaurant_outlined, size: 40,
                      color: colorScheme.outlineVariant),
                  const SizedBox(height: 8),
                  Text('Tap an option above to add food',
                      style: TextStyle(color: colorScheme.outline, fontSize: 13)),
                ]),
              ),
            ],
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
    if (ok) {
      HapticFeedback.heavyImpact();
    }
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (ok) const Icon(Icons.check_circle, color: Colors.white, size: 20),
            if (ok) const SizedBox(width: 8),
            Text(ok
                ? (isEdit ? 'Entry updated!' : 'Meal logged successfully!')
                : 'Failed to save'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
    if (ok && mounted) {
      // Always refresh entries list, dashboard, and analytics after any successful log/edit
      ref.invalidate(nutritionEntriesProvider);
      ref.invalidate(dashboardProvider(personId));
      ref.invalidate(nutritionAnalyticsProvider);
      AppCache.clearAnalytics();
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

  void _showBarcodeScan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BarcodeScanSheet(
        onFoodAdded: (food) {
          ref.read(nutritionProvider.notifier).addFood(food);
          ref.invalidate(foodDatabaseProvider);
        },
      ),
    );
  }

  void _showPhotoFoodRecognition(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final image = await picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (image == null || !mounted) return;

    HapticFeedback.mediumImpact();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Analyzing your meal...')),
          ],
        ),
      ),
    );

    try {
      final bytes = await image.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'meal.jpg'),
      });
      final res = await apiClient.dio.post(
        ApiConstants.foodPhotoRecognize,
        data: formData,
      );
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading

      final foods = res.data['foods'] as List<dynamic>? ?? [];
      final desc = res.data['meal_description'] ?? '';
      if (foods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not identify foods in this photo')),
        );
        return;
      }

      // Show recognized foods for confirmation
      if (!mounted) return;
      _showRecognizedFoods(foods, desc);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo recognition failed: $e')),
      );
    }
  }

  void _showRecognizedFoods(List<dynamic> foods, String description) {
    final selected = List<bool>.filled(foods.length, true);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Recognized Foods'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(description,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ),
                ...List.generate(foods.length, (i) {
                  final f = foods[i] as Map<String, dynamic>;
                  final conf = ((f['confidence'] as num?) ?? 0) * 100;
                  return CheckboxListTile(
                    dense: true,
                    value: selected[i],
                    onChanged: (v) => ss(() => selected[i] = v ?? true),
                    title: Text(
                        '${f['emoji'] ?? '🍽️'} ${f['name']}'),
                    subtitle: Text(
                      '~${f['estimated_grams']}g · '
                      '${((f['calories_per_100g'] as num? ?? 0) * (f['estimated_grams'] as num? ?? 100) / 100).toStringAsFixed(0)} kcal · '
                      '${conf.toStringAsFixed(0)}% confidence',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                HapticFeedback.heavyImpact();
                for (int i = 0; i < foods.length; i++) {
                  if (!selected[i]) continue;
                  final f = foods[i] as Map<String, dynamic>;
                  final food = FoodItem(
                    id: 'photo_${DateTime.now().millisecondsSinceEpoch}_$i',
                    name: f['name'] ?? 'Unknown',
                    cal: (f['calories_per_100g'] as num?)?.toDouble(),
                    protein: (f['protein_per_100g'] as num?)?.toDouble(),
                    carbs: (f['carbs_per_100g'] as num?)?.toDouble(),
                    fat: (f['fat_per_100g'] as num?)?.toDouble(),
                    servingSize: (f['estimated_grams'] as num?)?.toDouble() ?? 100,
                    emoji: f['emoji'],
                  );
                  ref.read(nutritionProvider.notifier).addFood(food);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text('${selected.where((s) => s).length} foods added!'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                  'Add ${selected.where((s) => s).length} Foods'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLabelScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _scanLabel(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _scanLabel(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanLabel(ImageSource source) async {
    final img = await ImagePicker().pickImage(source: source);
    if (img == null || !mounted) return;

    // Show processing overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Analyzing nutrition label...\nThis may take a moment.')),
          ],
        ),
      ),
    );

    try {
      final bytes = await img.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'label.jpg'),
      });
      final res = await apiClient.dio.post(ApiConstants.foodLabelScan, data: formData);
      final d = res.data as Map<String, dynamic>;

      if (mounted) Navigator.pop(context); // dismiss processing dialog

      if (mounted) {
        final foodName = d['product_name'] as String? ?? 'Scanned Product';
        final cal = (d['calories_per_100g'] as num?)?.toDouble() ?? 0;
        final protein = (d['protein_per_100g'] as num?)?.toDouble() ?? 0;
        final carbs = (d['carbs_per_100g'] as num?)?.toDouble() ?? 0;
        final fat = (d['fat_per_100g'] as num?)?.toDouble() ?? 0;

        // Save to DB immediately
        String foodId = 'label_${DateTime.now().millisecondsSinceEpoch}';
        try {
          final saveRes = await apiClient.dio.post(ApiConstants.customFoods, data: {
            'name': foodName, 'calories': cal, 'protein': protein,
            'carbs': carbs, 'fat': fat,
            'fiber': (d['fiber_per_100g'] as num?)?.toDouble(),
            'sugar': (d['sugar_per_100g'] as num?)?.toDouble(),
            'serving_size': (d['serving_size_g'] as num?)?.toDouble() ?? 100,
          });
          foodId = saveRes.data['food_id'] ?? foodId;
          ref.invalidate(foodDatabaseProvider);
        } catch (_) {}

        final food = FoodItem(
          id: foodId, name: foodName, cal: cal,
          protein: protein, carbs: carbs, fat: fat,
          servingSize: (d['serving_size_g'] as num?)?.toDouble() ?? 100,
          emoji: '📋',
        );

        if (mounted) {
          // Show result with option to edit name before adding
          final nameCtrl = TextEditingController(text: foodName);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Label Scan Result'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(
                      labelText: 'Product name', isDense: true)),
                  const SizedBox(height: 10),
                  Text('Per 100g:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text('Calories: ${cal.toStringAsFixed(0)} kcal'),
                  Text('Protein: ${protein.toStringAsFixed(1)} g'),
                  Text('Carbs: ${carbs.toStringAsFixed(1)} g'),
                  Text('Fat: ${fat.toStringAsFixed(1)} g'),
                  const SizedBox(height: 8),
                  Text('Saved to your food database.',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontStyle: FontStyle.italic)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final editedName = nameCtrl.text.trim();
                    final finalFood = editedName.isNotEmpty && editedName != foodName
                        ? FoodItem(id: food.id, name: editedName, cal: food.cal,
                            protein: food.protein, carbs: food.carbs, fat: food.fat,
                            servingSize: food.servingSize, emoji: food.emoji)
                        : food;
                    ref.read(nutritionProvider.notifier).addFood(finalFood);
                  },
                  child: const Text('Add to Meal'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss processing dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Label scan failed: ${e is DioException ? e.message : e}')),
        );
      }
    }
  }
}

// ─── Daily progress header ───────────────────────────────────────────────────

class _DailyProgressHeader extends ConsumerWidget {
  final NutritionState nutrition;
  const _DailyProgressHeader({required this.nutrition});

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
    final di = _dailyIntake(age, gender);
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
                Text('kcal', style: TextStyle(fontSize: 10, color: cs.outline)),
              ]),
            ]),
          ),
          const SizedBox(width: 20),
          // Macro bars
          Expanded(
            child: Column(
              children: [
                _MiniMacroBar('Protein', nutrition.totalProtein, di.protein, Colors.blue, protPct),
                const SizedBox(height: 8),
                _MiniMacroBar('Carbs', nutrition.totalCarbs, di.carbs, Colors.orange, carbPct),
                const SizedBox(height: 8),
                _MiniMacroBar('Fat', nutrition.totalFat, di.fat, Colors.red, fatPct),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMacroBar extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color color;
  final double pct;
  const _MiniMacroBar(this.label, this.current, this.target, this.color, this.pct);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(width: 48, child: Text(label,
            style: TextStyle(fontSize: 11, color: cs.outline))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: cs.outlineVariant.withOpacity(0.3),
              color: pct > 1.0 ? Colors.red : color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 50, child: Text(
          '${current.toInt()}/${target.toInt()}g',
          style: TextStyle(fontSize: 10, color: cs.outline),
          textAlign: TextAlign.right,
        )),
      ],
    );
  }
}

// ─── Entry method card ──────────────────────────────────────────────────────

class _EntryMethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _EntryMethodCard({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 26, color: color),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Barcode scan bottom sheet ─────────────────────────────────────────────────

class _BarcodeScanSheet extends ConsumerStatefulWidget {
  final void Function(FoodItem) onFoodAdded;
  const _BarcodeScanSheet({required this.onFoodAdded});
  @override
  ConsumerState<_BarcodeScanSheet> createState() => _BarcodeScanSheetState();
}

class _BarcodeScanSheetState extends ConsumerState<_BarcodeScanSheet> {
  MobileScannerController? _scanCtrl;
  bool _processing = false;
  String _status = 'Point camera at a barcode';

  @override
  void initState() {
    super.initState();
    _scanCtrl = MobileScannerController();
  }

  @override
  void dispose() {
    _scanCtrl?.dispose();
    super.dispose();
  }

  Future<void> _onDetected(String barcode) async {
    if (_processing) return;
    setState(() { _processing = true; _status = 'Looking up product...'; });
    _scanCtrl?.stop();

    final dio = Dio();
    dio.options.headers['User-Agent'] = 'Vitalis/3.0 (vitalis-health-app)';

    final variants = <String>[barcode];
    if (barcode.length == 12) variants.add('0$barcode');
    if (barcode.length == 13 && barcode.startsWith('0')) variants.add(barcode.substring(1));

    Map<String, dynamic>? product;
    for (final code in variants) {
      try {
        final res = await dio.get('https://world.openfoodfacts.org/api/v2/product/$code');
        final data = res.data as Map<String, dynamic>;
        if (data['status'] == 'product_found' || data['status'] == 1) {
          product = data['product'] as Map<String, dynamic>?;
          break;
        }
      } catch (_) {}
    }

    if (product != null && mounted) {
      HapticFeedback.heavyImpact();
      setState(() { _status = 'Saving to database...'; });
      final n = (product['nutriments'] as Map<String, dynamic>?) ?? {};
      final productName = (product['product_name'] as String?)?.trim().isNotEmpty == true
          ? product['product_name'] as String : 'Product $barcode';
      final cal = (n['energy-kcal_100g'] as num?)?.toDouble() ?? 0;
      final protein = (n['proteins_100g'] as num?)?.toDouble() ?? 0;
      final carbs = (n['carbohydrates_100g'] as num?)?.toDouble() ?? 0;
      final fat = (n['fat_100g'] as num?)?.toDouble() ?? 0;
      final brand = product['brands'] as String?;

      // Save to DB
      String foodId = barcode;
      try {
        final saveRes = await apiClient.dio.post(ApiConstants.customFoods, data: {
          'name': productName, 'calories': cal, 'protein': protein,
          'carbs': carbs, 'fat': fat, 'serving_size': 100,
          'barcode': barcode, 'brand': brand,
          'ingredients_text': product['ingredients_text'] as String?,
          'image_url': product['image_front_url'] as String?,
        });
        foodId = saveRes.data['food_id'] ?? barcode;
        await AppCache.clearFoodDb();
        ref.invalidate(foodDatabaseProvider);
      } catch (_) {}

      final food = FoodItem(
        id: foodId, name: productName, cal: cal,
        protein: protein, carbs: carbs, fat: fat,
        servingSize: 100, emoji: '🏷️', brand: brand,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onFoodAdded(food);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added: $productName'), duration: const Duration(seconds: 2)),
        );
      }
    } else if (mounted) {
      // Product not found — offer manual entry
      _showManualBarcodeEntry(barcode);
    }
  }

  void _showManualBarcodeEntry(String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: $barcode', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            const Text('How would you like to add this product?', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showManualNutritionEntry(barcode);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Enter Manually'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showSupplementWebLookup(barcode);
            },
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search Online'),
          ),
        ],
      ),
    );
  }

  void _showManualNutritionEntry(String barcode) {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final protCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Barcode: $barcode', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              const Text('Enter nutrition per 100g:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product name', isDense: true)),
              const SizedBox(height: 6),
              TextField(controller: calCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Calories', isDense: true)),
              const SizedBox(height: 6),
              TextField(controller: protCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Protein (g)', isDense: true)),
              const SizedBox(height: 6),
              TextField(controller: carbCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbs (g)', isDense: true)),
              const SizedBox(height: 6),
              TextField(controller: fatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fat (g)', isDense: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final foodName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Product $barcode';
              final cal = double.tryParse(calCtrl.text) ?? 0;
              final protein = double.tryParse(protCtrl.text) ?? 0;
              final carbs = double.tryParse(carbCtrl.text) ?? 0;
              final fat = double.tryParse(fatCtrl.text) ?? 0;

              String foodId = barcode;
              try {
                final saveRes = await apiClient.dio.post(ApiConstants.customFoods, data: {
                  'name': foodName, 'calories': cal, 'protein': protein,
                  'carbs': carbs, 'fat': fat, 'serving_size': 100, 'barcode': barcode,
                });
                foodId = saveRes.data['food_id'] ?? barcode;
                await AppCache.clearFoodDb();
                ref.invalidate(foodDatabaseProvider);
              } catch (_) {}

              final food = FoodItem(
                id: foodId, name: foodName, cal: cal,
                protein: protein, carbs: carbs, fat: fat,
                servingSize: 100, emoji: '🏷️',
              );
              if (mounted) {
                Navigator.pop(context);
                widget.onFoodAdded(food);
              }
            },
            child: const Text('Add Food'),
          ),
        ],
      ),
    );
  }

  void _showSupplementWebLookup(String barcode) {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Supplement Online'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: $barcode', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            const Text('Enter the supplement details to search:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Supplement name *',
                hintText: 'e.g. Multivitamin, Vitamin D3 5000 IU',
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: brandCtrl,
              decoration: const InputDecoration(
                labelText: 'Brand (optional)',
                hintText: 'e.g. Nature Made, NOW Foods',
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a supplement name')),
                );
                return;
              }
              Navigator.pop(ctx);
              _performSupplementLookup(
                name: name,
                brand: brandCtrl.text.trim().isNotEmpty ? brandCtrl.text.trim() : null,
                barcode: barcode,
              );
            },
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSupplementLookup({
    required String name,
    String? brand,
    String? barcode,
  }) async {
    setState(() { _processing = true; _status = 'Searching online for supplement info...'; });

    try {
      final res = await apiClient.dio.post(ApiConstants.supplementLookup, data: {
        'name': name,
        'brand': brand,
        'barcode': barcode,
      });

      final data = res.data as Map<String, dynamic>;

      if (data['success'] != true) {
        if (mounted) {
          setState(() { _processing = false; _status = 'Point camera at a barcode'; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Supplement not found'), duration: const Duration(seconds: 3)),
          );
          // Fall back to manual entry
          _showManualNutritionEntry(barcode ?? '');
        }
        return;
      }

      if (mounted) {
        setState(() { _processing = false; _status = 'Point camera at a barcode'; });
        _showSupplementConfirmation(data, barcode);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _processing = false; _status = 'Point camera at a barcode'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: ${e.toString().length > 80 ? '${e.toString().substring(0, 80)}...' : e}'), duration: const Duration(seconds: 3)),
        );
        _showManualNutritionEntry(barcode ?? '');
      }
    }
  }

  void _showSupplementConfirmation(Map<String, dynamic> data, String? barcode) {
    final ingredients = (data['ingredients'] as List<dynamic>?) ?? [];
    final supplementName = data['supplement_name'] ?? 'Unknown Supplement';
    final brandName = data['brand'] ?? '';
    final servingSize = data['serving_size'] ?? '1 serving';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(supplementName, style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (brandName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Brand: $brandName', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  ),
                Text('Serving: $servingSize', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                const Text('Supplement Facts:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Divider(height: 12),
                if (ingredients.isEmpty)
                  const Text('No ingredients found', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ...ingredients.map<Widget>((ing) {
                  final ingMap = ing as Map<String, dynamic>;
                  final ingName = ingMap['name'] ?? '';
                  final amount = ingMap['amount'];
                  final unit = ingMap['unit'] ?? '';
                  final dv = ingMap['daily_value_percent'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(ingName, style: const TextStyle(fontSize: 13)),
                        ),
                        if (amount != null)
                          Text('$amount $unit', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        if (dv != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text('${dv.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ),
                      ],
                    ),
                  );
                }),
                if (data['other_ingredients'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Other: ${data['other_ingredients']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveSupplementToDb(data, barcode);
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Save & Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSupplementToDb(Map<String, dynamic> data, String? barcode) async {
    setState(() { _processing = true; _status = 'Saving supplement...'; });

    try {
      final ingredients = (data['ingredients'] as List<dynamic>?)
          ?.map((i) {
                final m = i as Map<String, dynamic>;
                return <String, dynamic>{
                  'name': m['name'] ?? '',
                  'amount': m['amount'],
                  'unit': m['unit'],
                  'daily_value_percent': m['daily_value_percent'],
                };
              })
          .toList() ?? [];

      final saveRes = await apiClient.dio.post(ApiConstants.supplementSave, data: {
        'supplement_name': data['supplement_name'] ?? 'Unknown Supplement',
        'brand': data['brand'],
        'barcode': barcode,
        'serving_size': data['serving_size'],
        'calories_per_serving': data['calories_per_serving'],
        'ingredients': ingredients,
        'other_ingredients': data['other_ingredients'],
      });

      final saveData = saveRes.data as Map<String, dynamic>;
      final foodId = saveData['food_id'] ?? barcode ?? '';

      await AppCache.clearFoodDb();
      ref.invalidate(foodDatabaseProvider);

      final food = FoodItem(
        id: foodId,
        name: data['supplement_name'] ?? 'Unknown Supplement',
        cal: (data['calories_per_serving'] as num?)?.toDouble() ?? 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        servingSize: 100,
        emoji: '\u{1F48A}',
        brand: data['brand'],
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onFoodAdded(food);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added: ${data['supplement_name']} (${ingredients.length} nutrients)'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _processing = false; _status = 'Point camera at a barcode'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, __) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (_processing)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                if (_processing) const SizedBox(width: 8),
                Text(_status, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (!_processing)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _scanCtrl!,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      _onDetected(barcodes.first.rawValue!);
                    }
                  },
                ),
              ),
            ),
          if (_processing)
            const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

// ─── Meal suggestions for selected meal type ─────────────────────────────────

class _MealSuggestionsSection extends ConsumerWidget {
  final String mealType;
  const _MealSuggestionsSection({required this.mealType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(mealSuggestionsProvider);
    return suggestionsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text('Loading suggestions...',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (suggestions) {
        final allMeals = suggestions[mealType];
        if (allMeals == null || allMeals.isEmpty) return const SizedBox.shrink();
        final meals = allMeals.take(3).toList();

        final cs = Theme.of(context).colorScheme;
        final mealLabel = mealType[0].toUpperCase() + mealType.substring(1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: cs.primary),
                const SizedBox(width: 4),
                Text('Suggested for $mealLabel',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) =>
                    _SuggestionCard(meal: meals[i]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  final RecentMeal meal;
  const _SuggestionCard({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    // Calculate total calories for the meal
    double totalCal = 0;
    for (final item in meal.items) {
      final cal = item.calPer100g ?? 0;
      totalCal += (cal / 100) * item.grams;
    }
    final emojis = meal.items
        .take(3)
        .map((i) => i.emoji ?? '🍽️')
        .join(' ');

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
        width: 190,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withOpacity(0.3),
              cs.primaryContainer.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: cs.primaryContainer),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emojis, style: const TextStyle(fontSize: 14)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${meal.count}x',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                meal.display,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${totalCal.round()} kcal',
              style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
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
  bool _showBrand = false;

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
      _showBrand = false;
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
    final food = sf.food;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Text(food.emoji ?? '🍽️',
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food title — tap to toggle brand
                    GestureDetector(
                      onTap: food.hasBrand
                          ? () => setState(() => _showBrand = !_showBrand)
                          : null,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(food.title,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (food.hasBrand && !_showBrand)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(Icons.storefront,
                                  size: 12,
                                  color: Colors.grey.shade400),
                            ),
                        ],
                      ),
                    ),
                    // Brand subtitle (tap to reveal)
                    if (_showBrand && food.hasBrand)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(food.brandLabel,
                            style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    Text(
                      '${sf.calories.toStringAsFixed(0)} kcal'
                      '  ·  P ${sf.protein.toStringAsFixed(1)}g'
                      '  C ${sf.carbs.toStringAsFixed(1)}g'
                      '  F ${sf.fat.toStringAsFixed(1)}g',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                    if (food.uniqueAllergens.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          spacing: 3,
                          runSpacing: 2,
                          children: food.uniqueAllergens.take(4).map((a) =>
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
          // Nutrient & Ingredients card (expandable)
          NutrientCard(
            foodId: food.id,
            foodName: food.title,
            ingredientsText: food.ingredientsText,
            nutrientCompleteness: food.nutrientCompleteness,
          ),
        ],
      ),
    );
  }
}

// ─── Daily Micronutrient Summary ──────────────────────────────────────────────

class _DailyMicronutrientSummary extends ConsumerStatefulWidget {
  const _DailyMicronutrientSummary();
  @override
  ConsumerState<_DailyMicronutrientSummary> createState() =>
      _DailyMicronutrientSummaryState();
}

class _DailyMicronutrientSummaryState
    extends ConsumerState<_DailyMicronutrientSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = '$person|$today';
    final asyncData = ref.watch(dailyNutrientProvider(key));
    final cs = Theme.of(context).colorScheme;

    return asyncData.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final summary = data.summary;
        final total = summary.lowCount + summary.approachingCount +
            summary.adequateCount + summary.excessiveCount;
        if (total == 0) return const SizedBox.shrink();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              // ── Compact header ────────────────────────────────────
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Micronutrients Today',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface)),
                            const SizedBox(height: 4),
                            // Status chips row
                            Row(
                              children: [
                                if (summary.adequateCount > 0)
                                  _StatusChip(
                                    count: summary.adequateCount,
                                    label: 'OK',
                                    color: Colors.green,
                                  ),
                                if (summary.approachingCount > 0)
                                  _StatusChip(
                                    count: summary.approachingCount,
                                    label: 'Low',
                                    color: Colors.orange,
                                  ),
                                if (summary.lowCount > 0)
                                  _StatusChip(
                                    count: summary.lowCount,
                                    label: 'Deficient',
                                    color: Colors.red,
                                  ),
                                if (summary.excessiveCount > 0)
                                  _StatusChip(
                                    count: summary.excessiveCount,
                                    label: 'High',
                                    color: Colors.purple,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Expanded detail ────────────────────────────────────
              if (_expanded) _MicronutrientDetail(data: data),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _StatusChip({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count $label',
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}

class _MicronutrientDetail extends StatelessWidget {
  final DailyNutrientAssessment data;
  const _MicronutrientDetail({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vitamins = data.nutrients
        .where((n) => n.category == 'vitamin')
        .toList();
    final minerals = data.nutrients
        .where((n) => n.category == 'mineral')
        .toList();
    final others = data.nutrients
        .where((n) => n.category != 'vitamin' && n.category != 'mineral' && n.category != 'macro')
        .toList();

    // Top concerns
    final concerns = data.summary.topConcerns;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Top concerns callout
          if (concerns.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top Concerns',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700)),
                  const SizedBox(height: 4),
                  ...concerns.take(3).map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c['display_name'] ?? c['tagname'] ?? '',
                            style: TextStyle(fontSize: 10, color: cs.onSurface),
                          ),
                        ),
                        Text(
                          '${((c['percent_dri'] as num?) ?? 0).toInt()}% DRI',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade600),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Vitamins
          if (vitamins.isNotEmpty) ...[
            _NutrientSectionHeader(
                title: 'Vitamins', icon: Icons.wb_sunny_outlined, color: Colors.orange),
            const SizedBox(height: 4),
            ...vitamins.map((n) => _NutrientProgressRow(item: n)),
            const SizedBox(height: 10),
          ],

          // Minerals
          if (minerals.isNotEmpty) ...[
            _NutrientSectionHeader(
                title: 'Minerals', icon: Icons.diamond_outlined, color: Colors.teal),
            const SizedBox(height: 4),
            ...minerals.map((n) => _NutrientProgressRow(item: n)),
            const SizedBox(height: 10),
          ],

          // Others
          if (others.isNotEmpty) ...[
            _NutrientSectionHeader(
                title: 'Other', icon: Icons.more_horiz, color: Colors.blueGrey),
            const SizedBox(height: 4),
            ...others.map((n) => _NutrientProgressRow(item: n)),
          ],

          // Life stage label
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'DRI targets: ${_formatLifeStage(data.lifeStage)}',
                style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLifeStage(String code) {
    final labels = {
      'M_19_30': 'Male 19-30y', 'M_31_50': 'Male 31-50y',
      'M_51_70': 'Male 51-70y', 'M_71_PLUS': 'Male 71+y',
      'F_19_30': 'Female 19-30y', 'F_31_50': 'Female 31-50y',
      'F_51_70': 'Female 51-70y', 'F_71_PLUS': 'Female 71+y',
      'M_14_18': 'Male 14-18y', 'F_14_18': 'Female 14-18y',
      'M_9_13': 'Male 9-13y', 'F_9_13': 'Female 9-13y',
      'CHILD_4_8': 'Child 4-8y', 'CHILD_1_3': 'Child 1-3y',
      'INFANT_7_12': 'Infant 7-12m', 'INFANT_0_6': 'Infant 0-6m',
      'PREG_14_18': 'Pregnant 14-18y', 'PREG_19_30': 'Pregnant 19-30y',
      'PREG_31_50': 'Pregnant 31-50y',
      'LACT_14_18': 'Lactating 14-18y', 'LACT_19_30': 'Lactating 19-30y',
      'LACT_31_50': 'Lactating 31-50y',
    };
    return labels[code] ?? code;
  }
}

class _NutrientSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _NutrientSectionHeader({
    required this.title, required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _NutrientProgressRow extends StatelessWidget {
  final DailyNutrientItem item;
  const _NutrientProgressRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final target = item.target;
    final pct = item.percentDri ?? 0;
    final barPct = (pct / 100).clamp(0.0, 1.5);

    final statusColor = switch (item.status) {
      'adequate' => Colors.green,
      'approaching' => Colors.orange,
      'low' => Colors.red,
      'excessive' => Colors.purple,
      _ => Colors.grey,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(item.displayName,
                style: TextStyle(fontSize: 9, color: cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: barPct.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: statusColor.withOpacity(0.12),
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: Text(
              target != null
                  ? '${_fmt(item.consumed)}/${_fmt(target)}${item.unit}'
                  : '${_fmt(item.consumed)}${item.unit}',
              style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant),
              textAlign: TextAlign.right,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            child: Text(
              '${pct.toInt()}%',
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: statusColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 1) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
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
                      _AllergenBadge(allergen: a),
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
              ButtonSegment(value: 1, label: Text('Today')),
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
    final microAsync = ref.watch(periodNutrientProvider(personKey));
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
        // Micronutrient insights
        microAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (micro) => micro != null
              ? _MicronutrientSection(data: micro, days: days)
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text('Meal Type Breakdown',
                style: Theme.of(context).textTheme.titleMedium),
            initiallyExpanded: false,
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
            ...insight.insights.map((i) => InkWell(
              onTap: () => _showInsightDetail(context, i),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
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
                          Row(
                            children: [
                              Expanded(child: Text(i.title, style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13))),
                              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(i.body, style: const TextStyle(fontSize: 12),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
            if (insight.recommendations.isNotEmpty) ...[
              const Divider(height: 16),
              ...insight.recommendations.map((r) {
                final color = r.priority == 'high' ? Colors.red
                    : (r.priority == 'medium' ? Colors.orange : Colors.green);
                return InkWell(
                  onTap: () => _showRecommendationDetail(context, r),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: color),
                      const SizedBox(width: 6),
                      Expanded(child: Text(r.action,
                          style: const TextStyle(fontSize: 12))),
                      Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
                    ]),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _showInsightDetail(BuildContext context, InsightItem insight) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(insight.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 12),
              Text(insight.body, style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 16),
              // Confidence indicator
              Row(
                children: [
                  Text('Confidence: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ...List.generate(5, (i) => Icon(
                    i < (insight.confidence * 5).round() ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: i < (insight.confidence * 5).round() ? cs.primary : Colors.grey.shade300,
                  )),
                ],
              ),
              if (_getFoodTips(insight.title).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('Foods that may help:', style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, color: cs.primary)),
                const SizedBox(height: 8),
                ..._getFoodTips(insight.title).map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(tip.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tip.text, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecommendationDetail(BuildContext context, Recommendation rec) {
    final color = rec.priority == 'high' ? Colors.red
        : (rec.priority == 'medium' ? Colors.orange : Colors.green);
    final priorityLabel = rec.priority == 'high' ? 'High Priority'
        : (rec.priority == 'medium' ? 'Suggested' : 'Good to Know');
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: color),
                  const SizedBox(width: 8),
                  Text('Recommendation', style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(priorityLabel, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              Text(rec.action, style: const TextStyle(fontSize: 14, height: 1.5)),
              if (_getFoodTips(rec.action).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('Helpful foods:', style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, color: color)),
                const SizedBox(height: 8),
                ..._getFoodTips(rec.action).map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(tip.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tip.text, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Context-aware food suggestions based on insight/recommendation keywords
  static List<_FoodTip> _getFoodTips(String text) {
    final lower = text.toLowerCase();
    final tips = <_FoodTip>[];

    if (lower.contains('protein')) {
      tips.addAll([
        const _FoodTip('🥚', 'Eggs — 13g protein per 100g'),
        const _FoodTip('🍗', 'Chicken breast — 31g protein per 100g'),
        const _FoodTip('🫘', 'Lentils (dal) — 9g protein per 100g cooked'),
        const _FoodTip('🥜', 'Peanuts — 26g protein per 100g'),
      ]);
    }
    if (lower.contains('fiber') || lower.contains('fibre')) {
      tips.addAll([
        const _FoodTip('🥬', 'Broccoli — 2.6g fiber per 100g'),
        const _FoodTip('🫘', 'Rajma (kidney beans) — 6.4g fiber per 100g'),
        const _FoodTip('🍎', 'Apple with skin — 2.4g fiber per apple'),
        const _FoodTip('🌾', 'Oats — 10g fiber per 100g'),
      ]);
    }
    if (lower.contains('vitamin d') || lower.contains('vit d')) {
      tips.addAll([
        const _FoodTip('🐟', 'Salmon — rich in Vitamin D'),
        const _FoodTip('🥛', 'Fortified milk — Vitamin D added'),
        const _FoodTip('🥚', 'Egg yolks — natural Vitamin D source'),
        const _FoodTip('☀️', '15 min sunlight exposure daily'),
      ]);
    }
    if (lower.contains('iron')) {
      tips.addAll([
        const _FoodTip('🥬', 'Spinach — 2.7mg iron per 100g'),
        const _FoodTip('🫘', 'Lentils — 3.3mg iron per 100g cooked'),
        const _FoodTip('🥩', 'Red meat — highly bioavailable iron'),
        const _FoodTip('🍊', 'Vitamin C foods help iron absorption'),
      ]);
    }
    if (lower.contains('calcium')) {
      tips.addAll([
        const _FoodTip('🥛', 'Milk — 125mg calcium per 100ml'),
        const _FoodTip('🧀', 'Paneer/cheese — calcium-rich dairy'),
        const _FoodTip('🥬', 'Kale — 150mg calcium per 100g'),
        const _FoodTip('🐟', 'Sardines with bones — excellent calcium'),
      ]);
    }
    if (lower.contains('calorie') || lower.contains('energy') || lower.contains('kcal')) {
      tips.addAll([
        const _FoodTip('📊', 'Track all meals including snacks'),
        const _FoodTip('🥗', 'Fill half your plate with vegetables'),
        const _FoodTip('💧', 'Stay hydrated — sometimes thirst mimics hunger'),
      ]);
    }
    if (lower.contains('breakfast')) {
      tips.addAll([
        const _FoodTip('🥣', 'Oatmeal with fruits — balanced start'),
        const _FoodTip('🥞', 'Dosa/idli — light, nutritious South Indian breakfast'),
        const _FoodTip('🥚', 'Eggs — protein to keep you full longer'),
      ]);
    }
    if (lower.contains('carb') || lower.contains('sugar') || lower.contains('glucose')) {
      tips.addAll([
        const _FoodTip('🌾', 'Choose whole grains over refined'),
        const _FoodTip('🍠', 'Sweet potato — complex carbs, lower GI'),
        const _FoodTip('🫘', 'Legumes — slow-releasing energy'),
      ]);
    }
    if (lower.contains('fat') && !lower.contains('breakfast')) {
      tips.addAll([
        const _FoodTip('🥑', 'Avocado — healthy monounsaturated fats'),
        const _FoodTip('🥜', 'Almonds — heart-healthy fats'),
        const _FoodTip('🐟', 'Fatty fish — omega-3 fatty acids'),
      ]);
    }

    // ── Vitamins ──────────────────────────────────────────
    if (lower.contains('vitamin a') || lower.contains('vit a') || lower.contains('retinol')) {
      tips.addAll([
        const _FoodTip('🥕', 'Carrots — 835µg vitamin A per 100g'),
        const _FoodTip('🍠', 'Sweet potato — 709µg per 100g'),
        const _FoodTip('🥬', 'Spinach — 469µg per 100g'),
        const _FoodTip('🥭', 'Mango — 54µg + beta-carotene'),
      ]);
    }
    if (lower.contains('vitamin b1') || lower.contains('vit b1') || lower.contains('thiamin')) {
      tips.addAll([
        const _FoodTip('🌻', 'Sunflower seeds — 1.5mg B1 per 100g'),
        const _FoodTip('🫘', 'Black beans — 0.4mg per 100g'),
        const _FoodTip('🌾', 'Brown rice — 0.4mg per 100g'),
        const _FoodTip('🥜', 'Peanuts — 0.6mg per 100g'),
      ]);
    }
    if (lower.contains('vitamin b2') || lower.contains('vit b2') || lower.contains('riboflavin')) {
      tips.addAll([
        const _FoodTip('🥛', 'Milk — 0.18mg B2 per 100ml'),
        const _FoodTip('🥚', 'Eggs — 0.46mg per 100g'),
        const _FoodTip('🍄', 'Mushrooms — 0.4mg per 100g'),
        const _FoodTip('🥬', 'Spinach — 0.19mg per 100g'),
      ]);
    }
    if (lower.contains('vitamin b6') || lower.contains('vit b6') || lower.contains('pyridoxine')) {
      tips.addAll([
        const _FoodTip('🍌', 'Banana — 0.4mg B6 per fruit'),
        const _FoodTip('🍗', 'Chicken — 0.5mg per 100g'),
        const _FoodTip('🥔', 'Potato — 0.3mg per 100g'),
        const _FoodTip('🌻', 'Sunflower seeds — 1.3mg per 100g'),
      ]);
    }
    if (lower.contains('vitamin b12') || lower.contains('vit b12') || lower.contains('cobalamin')) {
      tips.addAll([
        const _FoodTip('🐟', 'Salmon — 2.8µg B12 per 100g'),
        const _FoodTip('🥚', 'Eggs — 0.9µg per egg'),
        const _FoodTip('🥛', 'Milk — 0.5µg per 100ml'),
        const _FoodTip('🧀', 'Paneer/cheese — 1.1µg per 100g'),
      ]);
    }
    if (lower.contains('vitamin c') || lower.contains('vit c') || lower.contains('ascorbic')) {
      tips.addAll([
        const _FoodTip('🍊', 'Orange — 53mg vitamin C per fruit'),
        const _FoodTip('🫑', 'Bell pepper — 128mg per 100g'),
        const _FoodTip('🥝', 'Kiwi — 93mg per 100g'),
        const _FoodTip('🍋', 'Lemon — 53mg per 100g'),
      ]);
    }
    if (lower.contains('vitamin e') || lower.contains('vit e') || lower.contains('tocopherol')) {
      tips.addAll([
        const _FoodTip('🌻', 'Sunflower seeds — 35mg vit E per 100g'),
        const _FoodTip('🥜', 'Almonds — 26mg per 100g'),
        const _FoodTip('🥑', 'Avocado — 2.1mg per 100g'),
        const _FoodTip('🥬', 'Spinach — 2mg per 100g'),
      ]);
    }
    if (lower.contains('vitamin k') || lower.contains('vit k')) {
      tips.addAll([
        const _FoodTip('🥬', 'Kale — 390µg vitamin K per 100g'),
        const _FoodTip('🥦', 'Broccoli — 102µg per 100g'),
        const _FoodTip('🫛', 'Green peas — 25µg per 100g'),
        const _FoodTip('🥒', 'Cucumber — 16µg per 100g'),
      ]);
    }

    // ── Minerals ──────────────────────────────────────────
    if (lower.contains('zinc')) {
      tips.addAll([
        const _FoodTip('🥩', 'Red meat — 4.8mg zinc per 100g'),
        const _FoodTip('🌻', 'Pumpkin seeds — 7.8mg per 100g'),
        const _FoodTip('🫘', 'Chickpeas — 2.5mg per 100g'),
        const _FoodTip('🧀', 'Cheese — 3.1mg per 100g'),
      ]);
    }
    if (lower.contains('magnesium')) {
      tips.addAll([
        const _FoodTip('🌰', 'Cashews — 292mg magnesium per 100g'),
        const _FoodTip('🥬', 'Spinach — 79mg per 100g'),
        const _FoodTip('🍫', 'Dark chocolate — 228mg per 100g'),
        const _FoodTip('🍌', 'Banana — 27mg per fruit'),
      ]);
    }
    if (lower.contains('potassium')) {
      tips.addAll([
        const _FoodTip('🍌', 'Banana — 422mg potassium per fruit'),
        const _FoodTip('🥔', 'Potato — 421mg per medium'),
        const _FoodTip('🫘', 'White beans — 561mg per 100g'),
        const _FoodTip('🥑', 'Avocado — 485mg per 100g'),
      ]);
    }
    if (lower.contains('folate') || lower.contains('folic')) {
      tips.addAll([
        const _FoodTip('🥬', 'Spinach — 194µg folate per 100g'),
        const _FoodTip('🫘', 'Lentils — 181µg per 100g cooked'),
        const _FoodTip('🥦', 'Broccoli — 63µg per 100g'),
        const _FoodTip('🥑', 'Avocado — 81µg per 100g'),
      ]);
    }
    if (lower.contains('omega') || lower.contains('dha') || lower.contains('epa')) {
      tips.addAll([
        const _FoodTip('🐟', 'Salmon — 2.3g omega-3 per 100g'),
        const _FoodTip('🐟', 'Sardines — 1.5g omega-3 per 100g'),
        const _FoodTip('🌰', 'Walnuts — 2.5g ALA per 28g'),
        const _FoodTip('🌱', 'Flaxseeds — 2.4g ALA per tbsp'),
      ]);
    }

    return tips.take(4).toList();
  }
}

class _FoodTip {
  final String emoji;
  final String text;
  const _FoodTip(this.emoji, this.text);
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

// ─── Micronutrient Insights Section ──────────────────────────────────────────

class _MicronutrientSection extends StatelessWidget {
  final PeriodNutrientData data;
  final int days;
  const _MicronutrientSection({required this.data, required this.days});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = data.summary;
    final periodLabel = days == 1 ? 'Today' : '${days}d avg';

    // Top 3 lowest + top 3 highest = 6 key nutrients
    final topLow = data.consumedLess.take(3).toList();
    final topHigh = data.consumedMore.take(3).toList();

    if (s.daysWithData == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.science_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text('Micronutrient Status',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(periodLabel,
                    style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer)),
              ),
            ]),
            const SizedBox(height: 10),
            // Compact summary row
            Row(
              children: [
                _summaryChip(Icons.check_circle, Colors.green, '${s.adequateCount} OK'),
                const SizedBox(width: 8),
                _summaryChip(Icons.warning_amber, Colors.orange, '${s.approachingCount} Near'),
                const SizedBox(width: 8),
                _summaryChip(Icons.arrow_downward, Colors.red, '${s.lowCount} Low'),
                if (s.excessiveCount > 0) ...[
                  const SizedBox(width: 8),
                  _summaryChip(Icons.arrow_upward, Colors.deepPurple, '${s.excessiveCount} High'),
                ],
              ],
            ),
            // Top low nutrients
            if (topLow.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: [
                Icon(Icons.trending_down, size: 14, color: Colors.red.shade600),
                const SizedBox(width: 4),
                Text('Needs Attention', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.red.shade600)),
              ]),
              const SizedBox(height: 6),
              ...topLow.map((item) => _NutrientRow(item: item, isDeficient: true)),
            ],
            // Top high nutrients
            if (topHigh.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.trending_up, size: 14, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text('Above Target', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.green.shade600)),
              ]),
              const SizedBox(height: 6),
              ...topHigh.map((item) => _NutrientRow(item: item, isDeficient: false)),
            ],
            if (topLow.isEmpty && topHigh.isEmpty) ...[
              const SizedBox(height: 10),
              Text('All tracked nutrients are within range',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 6),
            Text(
              '${s.daysWithData} day${s.daysWithData > 1 ? 's' : ''} of data · ${s.totalTracked} nutrients tracked',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final PeriodNutrientItem item;
  final bool isDeficient;
  const _NutrientRow({required this.item, required this.isDeficient});

  @override
  Widget build(BuildContext context) {
    final pct = item.percentDri;
    final pctText = pct != null ? '${pct.toStringAsFixed(0)}%' : '--';
    final barFrac = pct != null ? (pct / 100).clamp(0.0, 1.5) / 1.5 : 0.0;

    Color barColor;
    if (pct == null) {
      barColor = Colors.grey;
    } else if (pct > 150) {
      barColor = Colors.deepPurple;
    } else if (pct >= 100) {
      barColor = Colors.green;
    } else if (pct >= 50) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              item.shortName ?? item.displayName,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: barFrac,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                color: barColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            child: Text(pctText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
                textAlign: TextAlign.right),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 60,
            child: Text(
              '${_formatValue(item.avgDaily)} ${item.unit}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double v) {
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 1) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}

