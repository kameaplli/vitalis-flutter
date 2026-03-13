import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/api_client.dart';
import '../../core/app_cache.dart';
import '../../core/constants.dart';
import '../../providers/food_provider.dart';
import '../../models/food_item.dart';

// ─── Barcode scan bottom sheet ─────────────────────────────────────────────────

class BarcodeScanSheet extends ConsumerStatefulWidget {
  final void Function(FoodItem) onFoodAdded;
  const BarcodeScanSheet({super.key, required this.onFoodAdded});
  @override
  ConsumerState<BarcodeScanSheet> createState() => _BarcodeScanSheetState();
}

class _BarcodeScanSheetState extends ConsumerState<BarcodeScanSheet> {
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
          const SnackBar(content: Text('Product not found. Try entering manually.'), duration: Duration(seconds: 3)),
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
          const SnackBar(content: Text('Failed to save. Please try again.'), duration: Duration(seconds: 3)),
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
