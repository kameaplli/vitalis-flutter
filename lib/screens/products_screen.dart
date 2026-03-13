import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/product_data.dart';
import '../widgets/friendly_error.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final productsProvider = FutureProvider<List<ProductEntry>>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.products);
    return (res.data as List<dynamic>)
        .map((e) => ProductEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final productCorrelationProvider = FutureProvider<List<ProductCorrelation>>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.productCorrelation,
        queryParameters: {'days': 90});
    final data = res.data as Map<String, dynamic>;
    return (data['correlations'] as List<dynamic>)
        .map((e) => ProductCorrelation.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Screen ───────────────────────────────────────────────────────────────────

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Scanner'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'My Products'),
            Tab(text: 'Scan'),
            Tab(text: 'Analysis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProductsListTab(),
          _ScanTab(onScanned: () {
            ref.invalidate(productsProvider);
            _tabs.animateTo(0);
          }),
          _AnalysisTab(),
        ],
      ),
    );
  }
}

// ── Products List ────────────────────────────────────────────────────────────

class _ProductsListTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FriendlyError(error: e, context: 'products'),
      data: (products) {
        if (products.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No products logged yet', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 4),
                Text('Scan a product barcode or add manually',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        }
        final active = products.where((p) => p.isActive).toList();
        final stopped = products.where((p) => !p.isActive).toList();
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (active.isNotEmpty) ...[
              Text('Active Products', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...active.map((p) => _ProductCard(product: p)),
            ],
            if (stopped.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Past Products', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...stopped.map((p) => _ProductCard(product: p)),
            ],
          ],
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductEntry product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = product.safetyScore ?? 100;
    final scoreColor = score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);
    final scoreLabel = score >= 80 ? 'Safe' : (score >= 50 ? 'Caution' : 'Risky');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_typeIcon(product.productType), size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.productName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (product.brand != null && product.brand!.isNotEmpty)
                        Text(product.brand!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scoreColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(score >= 80 ? Icons.check_circle : Icons.warning,
                          size: 14, color: scoreColor),
                      const SizedBox(width: 4),
                      Text('${score.toInt()}% $scoreLabel',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scoreColor)),
                    ],
                  ),
                ),
              ],
            ),
            if (product.flaggedIrritants.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: product.flaggedIrritants.take(5).map((f) {
                  final color = f.risk == 'high' ? Colors.red : Colors.orange;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${f.ingredient} (${f.category})',
                        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'moisturizer': return Icons.water_drop;
      case 'cleanser': return Icons.cleaning_services;
      case 'detergent': return Icons.local_laundry_service;
      case 'shampoo': return Icons.shower;
      case 'sunscreen': return Icons.wb_sunny;
      default: return Icons.inventory_2;
    }
  }
}

// ── Scan Tab ─────────────────────────────────────────────────────────────────

class _ScanTab extends StatefulWidget {
  final VoidCallback onScanned;
  const _ScanTab({required this.onScanned});

  @override
  State<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<_ScanTab> {
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _ingredientsCtrl = TextEditingController();
  String _productType = 'moisturizer';
  bool _scanning = false;
  bool _saving = false;
  bool _lookingUp = false;
  Map<String, dynamic>? _scanResult;
  MobileScannerController? _scanCtrl;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _ingredientsCtrl.dispose();
    _scanCtrl?.dispose();
    super.dispose();
  }

  void _startScan() {
    _scanCtrl?.dispose();
    _scanCtrl = MobileScannerController();
    setState(() {
      _scanning = true;
      _scanResult = null;
    });
  }

  Future<void> _onBarcode(String barcode) async {
    setState(() {
      _scanning = false;
      _lookingUp = true;
    });
    _scanCtrl?.stop();

    // Try backend lookup (Open Beauty Facts + Open Food Facts)
    try {
      // First try the product scan endpoint directly with barcode
      // This does OBF + OFF lookup + ingredient check in one call
      final res = await apiClient.dio.post(ApiConstants.productScan, data: {
        'barcode': barcode,
        'product_name': '',
        'product_type': _productType,
      });
      final data = res.data as Map<String, dynamic>;

      // Product found and saved — show result
      setState(() {
        _scanResult = data;
        _nameCtrl.text = data['product_name'] ?? '';
        _brandCtrl.text = data['brand'] ?? '';
        _lookingUp = false;
      });
      widget.onScanned();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${data['product_name']} — saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    } catch (_) {
      // Product not found via auto-scan — try ingredient lookup for form pre-fill
    }

    try {
      final res = await apiClient.dio.get(
        ApiConstants.foodIngredients,
        queryParameters: {'barcode': barcode},
      );
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _nameCtrl.text = data['product_name'] ?? '';
        _ingredientsCtrl.text = data['ingredients_text'] ?? '';
        _lookingUp = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product found — review and save')),
        );
      }
    } catch (_) {
      setState(() => _lookingUp = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product not found for barcode $barcode. Enter details manually.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final res = await apiClient.dio.post(ApiConstants.productScan, data: {
        'product_name': _nameCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'product_type': _productType,
        'ingredients_text': _ingredientsCtrl.text.trim(),
      });
      setState(() {
        _scanResult = res.data as Map<String, dynamic>;
      });
      widget.onScanned();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, context: 'products'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_scanning) {
      return Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                controller: _scanCtrl!,
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                    _onBarcode(barcodes.first.rawValue!);
                  }
                },
              ),
            ),
          ),
          TextButton(onPressed: () => setState(() => _scanning = false),
            child: const Text('Cancel Scan')),
        ],
      );
    }

    if (_lookingUp) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Looking up product...', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 4),
            Text('Checking Open Beauty Facts & Open Food Facts',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Product Barcode'),
            onPressed: _startScan,
          ),
          const SizedBox(height: 16),
          const Text('Or enter manually:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Product Name', isDense: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _brandCtrl,
            decoration: const InputDecoration(labelText: 'Brand', isDense: true),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _productType,
            decoration: const InputDecoration(labelText: 'Type', isDense: true),
            items: const [
              DropdownMenuItem(value: 'moisturizer', child: Text('Moisturizer')),
              DropdownMenuItem(value: 'cleanser', child: Text('Cleanser')),
              DropdownMenuItem(value: 'shampoo', child: Text('Shampoo')),
              DropdownMenuItem(value: 'detergent', child: Text('Detergent')),
              DropdownMenuItem(value: 'sunscreen', child: Text('Sunscreen')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _productType = v ?? 'moisturizer'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ingredientsCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Ingredients (comma-separated)',
              isDense: true,
              hintText: 'water, glycerin, dimethicone...',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Check & Save Product'),
          ),
          if (_scanResult != null) ...[
            const SizedBox(height: 16),
            _ScanResultCard(result: _scanResult!),
          ],
        ],
      ),
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ScanResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final score = (result['safety_score'] as num?)?.toDouble() ?? 100;
    final flagged = (result['flagged'] as List<dynamic>?) ?? [];
    final color = score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: color, size: 24),
                const SizedBox(width: 8),
                Text('Safety Score: ${score.toInt()}%',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            if (flagged.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Flagged Irritants:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              ...flagged.map((f) {
                final fl = f as Map<String, dynamic>;
                final risk = fl['risk'] ?? 'medium';
                final c = risk == 'high' ? Colors.red : Colors.orange;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 14, color: c),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${fl['ingredient']} (${fl['category']})',
                          style: TextStyle(fontSize: 12, color: c))),
                    ],
                  ),
                );
              }),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No known irritants found!',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Analysis Tab ─────────────────────────────────────────────────────────────

class _AnalysisTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final corrAsync = ref.watch(productCorrelationProvider);
    return corrAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FriendlyError(error: e, context: 'product analysis'),
      data: (correlations) {
        if (correlations.isEmpty) {
          return const Center(
            child: Text('Need product data + eczema logs to show correlations',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('Product Impact on Eczema', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...correlations.map((c) {
              final color = c.verdict == 'worsened' ? Colors.red
                  : (c.verdict == 'improved' ? Colors.green : Colors.grey);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    c.verdict == 'worsened' ? Icons.trending_up
                        : (c.verdict == 'improved' ? Icons.trending_down : Icons.trending_flat),
                    color: color,
                  ),
                  title: Text(c.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Itch ${c.avgItchBefore.toStringAsFixed(1)} -> ${c.avgItchDuring.toStringAsFixed(1)} '
                    '(${c.change > 0 ? "+" : ""}${c.change.toStringAsFixed(1)}) over ${c.daysUsed}d',
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
