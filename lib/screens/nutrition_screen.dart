import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import '../providers/dashboard_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/food_provider.dart';
import '../providers/selected_person_provider.dart';
import '../providers/nutrition_analytics_provider.dart';
import '../models/food_item.dart';
import '../widgets/voice_meal_sheet.dart';
// ─── Extracted widget imports ─────────────────────────────────────────────────
import 'nutrition/barcode_scan_sheet.dart';
import 'nutrition/meal_suggestions.dart';
import 'nutrition/recent_meals.dart';
import 'nutrition/food_item_tile.dart';
import 'nutrition/food_search_sheet.dart';
import '../widgets/medical_disclaimer.dart';

// Re-export FoodSearchSheet so existing imports continue to work
export 'nutrition/food_search_sheet.dart' show FoodSearchSheet;

// ─── Main screen ──────────────────────────────────────────────────────────────

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void initState() {
    super.initState();
    // Restore any saved meal draft (e.g. user navigated away accidentally).
    Future.microtask(() {
      final notifier = ref.read(nutritionProvider.notifier);
      // Only load draft if no foods are already selected (avoids overwriting
      // an in-progress edit or an already-populated selection).
      if (ref.read(nutritionProvider).selectedFoods.isEmpty) {
        notifier.loadDraft();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nutrition = ref.watch(nutritionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isEditMode = nutrition.editEntryId != null;

    return Scaffold(
      appBar: AppBar(
        title: isEditMode ? const Text('Edit Entry') : null,
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
            // ── Full-width search bar ─────────────────────────────────────
            Material(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => _showFoodSearch(context),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: colorScheme.onSurfaceVariant, size: 22),
                      const SizedBox(width: 12),
                      Text('Search food...',
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Entry methods: 4 bigger cards ────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _BigEntryCard(
                    icon: Icons.qr_code_scanner,
                    label: 'Barcode',
                    color: Colors.orange,
                    onTap: () => _showBarcodeScan(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BigEntryCard(
                    icon: Icons.camera_alt_outlined,
                    label: 'Label',
                    color: Colors.green,
                    onTap: () => _showLabelScanOptions(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BigEntryCard(
                    icon: Icons.restaurant,
                    label: 'Photo AI',
                    color: Colors.teal,
                    onTap: () => _showPhotoFoodRecognition(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BigEntryCard(
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
                            ref.invalidate(dashboardProvider((personId, DateTime.now().toIso8601String().substring(0, 10))));
                            ref.invalidate(nutritionEntriesProvider);
                            ref.invalidate(nutritionAnalyticsProvider);
                            AppCache.clearAnalytics();
                          },
                        ),
                      );
                    },
                  ),
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
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
            MealSuggestionsSection(mealType: nutrition.mealType),

            const SizedBox(height: 8),

            // ── Recent meals carousel ────────────────────────────────────────
            const RecentMealsSection(),

            const SizedBox(height: 16),

            // ── Frequent individual foods ─────────────────────────────────────
            const FrequentFoodsSection(),

            // ── Selected foods ───────────────────────────────────────────────
            if (nutrition.selectedFoods.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Selected Foods (${nutrition.selectedFoods.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                  TextButton.icon(
                    onPressed: () => _showFoodSearch(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add More'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Column(
                children: nutrition.selectedFoods.map((sf) => FoodItemTile(
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
                      style: TextStyle(color: colorScheme.outline, fontSize: 14, fontWeight: FontWeight.w500)),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            const MedicalDisclaimer(),
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
      ref.invalidate(dashboardProvider((personId, DateTime.now().toIso8601String().substring(0, 10))));
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
      builder: (_) => BarcodeScanSheet(
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
                            fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                  Text('Per 100g:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  Text('Calories: ${cal.toStringAsFixed(0)} kcal'),
                  Text('Protein: ${protein.toStringAsFixed(1)} g'),
                  Text('Carbs: ${carbs.toStringAsFixed(1)} g'),
                  Text('Fat: ${fat.toStringAsFixed(1)} g'),
                  const SizedBox(height: 8),
                  Text('Saved to your food database.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.green.shade700, fontStyle: FontStyle.italic)),
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

// ─── Big entry method card ────────────────────────────────────────────────────

class _BigEntryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BigEntryCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: cs.onSurface,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
