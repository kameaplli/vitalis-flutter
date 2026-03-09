import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/grocery_models.dart';
import '../models/insight_data.dart';
import '../providers/grocery_provider.dart';
import '../providers/selected_person_provider.dart';

// ── Grocery AI Insights provider ─────────────────────────────────────────────
// key = period (month|quarter|year) — maps to backend param
final _groceryInsightsProvider =
    FutureProvider.family<WeeklyInsight?, String>((ref, period) async {
  try {
    // Map frontend period names to backend names
    const periodMap = {'month': 'month', '3month': 'quarter', 'year': 'year'};
    final backendPeriod = periodMap[period] ?? 'month';
    final res = await apiClient.dio.get(
      ApiConstants.insightsGrocery,
      queryParameters: {'period': backendPeriod},
    );
    return WeeklyInsight.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

// Category colour palette
const _categoryColors = {
  'produce':       Color(0xFF4CAF50),
  'dairy':         Color(0xFF2196F3),
  'meat':          Color(0xFFE53935),
  'seafood':       Color(0xFF00BCD4),
  'bakery':        Color(0xFFFF8F00),
  'frozen':        Color(0xFF7986CB),
  'beverages':     Color(0xFF26C6DA),
  'snacks':        Color(0xFFFF7043),
  'pantry':        Color(0xFF8D6E63),
  'household':     Color(0xFF78909C),
  'personal_care': Color(0xFFAB47BC),
  'other':         Color(0xFF9E9E9E),
};

Color _catColor(String cat) => _categoryColors[cat] ?? const Color(0xFF9E9E9E);

String _catLabel(String cat) {
  const labels = {
    'produce':       'Produce',
    'dairy':         'Dairy',
    'meat':          'Meat',
    'seafood':       'Seafood',
    'bakery':        'Bakery',
    'frozen':        'Frozen',
    'beverages':     'Beverages',
    'snacks':        'Snacks',
    'pantry':        'Pantry',
    'household':     'Household',
    'personal_care': 'Personal Care',
    'other':         'Other',
  };
  return labels[cat] ?? cat;
}

class GroceryScreen extends ConsumerStatefulWidget {
  const GroceryScreen({super.key});

  @override
  ConsumerState<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends ConsumerState<GroceryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final cs     = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery Intelligence'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Receipts'),
            Tab(icon: Icon(Icons.bar_chart_outlined),    text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ReceiptsTab(person: person),
          _AnalyticsTab(person: person),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/grocery/scan'),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Scan Receipt'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
    );
  }
}

// ── Receipts tab ───────────────────────────────────────────────────────────────

class _ReceiptsTab extends ConsumerWidget {
  final String person;
  const _ReceiptsTab({required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groceryReceiptsProvider(person));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (receipts) {
        if (receipts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                const Text('No receipts yet'),
                const SizedBox(height: 8),
                const Text('Tap the button below to scan your first receipt',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(groceryReceiptsProvider(person)),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: receipts.length,
            itemBuilder: (ctx, i) => _DismissibleReceiptCard(
              receipt: receipts[i],
              person: person,
            ),
          ),
        );
      },
    );
  }
}

// ── Swipe-to-delete wrapper ────────────────────────────────────────────────────

class _DismissibleReceiptCard extends ConsumerWidget {
  final GroceryReceipt receipt;
  final String person;
  const _DismissibleReceiptCard(
      {required this.receipt, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(receipt.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete receipt?'),
            content: Text(
              'Remove ${receipt.storeName ?? 'this receipt'} and all its items? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        try {
          await apiClient.dio.delete(
              '${ApiConstants.groceryReceipts}/${receipt.id}');
          ref.invalidate(groceryReceiptsProvider(person));
          ref.invalidate(grocerySpendingProvider('$person:month'));
          ref.invalidate(grocerySpendingProvider('$person:3month'));
          ref.invalidate(grocerySpendingProvider('$person:year'));
          ref.invalidate(groceryNutritionProvider('$person:month'));
          ref.invalidate(groceryNutritionProvider('$person:3month'));
          ref.invalidate(groceryNutritionProvider('$person:year'));
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete receipt')),
            );
          }
        }
      },
      child: _ReceiptCard(receipt: receipt),
    );
  }
}

// ── Receipt card ───────────────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  final GroceryReceipt receipt;
  const _ReceiptCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(symbol: '\$');
    final isDone   = receipt.status == 'done';
    final isFailed = receipt.status == 'failed';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDone ? () => _openDetail(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Store icon
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isDone
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDone ? Icons.receipt_long : Icons.receipt_long_outlined,
                      size: 20,
                      color: isDone ? cs.primary : cs.outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.storeName ?? 'Unknown Store',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          receipt.receiptDate != null
                              ? DateFormat('EEE, d MMM yyyy')
                                  .format(receipt.receiptDate!)
                              : DateFormat('EEE, d MMM yyyy')
                                  .format(receipt.createdAt),
                          style: TextStyle(fontSize: 12, color: cs.outline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (receipt.totalAmount != null)
                        Text(
                          fmt.format(receipt.totalAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDone ? cs.primary : cs.outline,
                          ),
                        ),
                      const SizedBox(height: 4),
                      _StatusBadge(status: receipt.status),
                    ],
                  ),
                ],
              ),
              if (isDone) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.shopping_cart_outlined,
                      label: '${receipt.itemCount} items',
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.restaurant_outlined,
                      label: '${receipt.foodItemCount} food',
                      color: Colors.green,
                    ),
                    const Spacer(),
                    Text(
                      'Food: ${fmt.format(receipt.totalFoodSpend ?? 0)}',
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        size: 16, color: cs.outline),
                  ],
                ),
              ],
              if (isFailed && receipt.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  receipt.errorMessage!,
                  style: TextStyle(fontSize: 11, color: cs.error),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, ctrl) =>
            _ReceiptDetailSheet(receiptId: receipt.id, scrollController: ctrl),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'done':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 12, color: Colors.green),
              SizedBox(width: 3),
              Text('Done', style: TextStyle(fontSize: 11, color: Colors.green,
                  fontWeight: FontWeight.w600)),
            ],
          ),
        );
      case 'failed':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 12, color: Colors.red),
              SizedBox(width: 3),
              Text('Failed', style: TextStyle(fontSize: 11, color: Colors.red,
                  fontWeight: FontWeight.w600)),
            ],
          ),
        );
      default:
        return const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: color.withOpacity(0.8)),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8),
          fontWeight: FontWeight.w500)),
    ],
  );
}

// ── Receipt detail sheet (fetches items from API) ─────────────────────────────

class _ReceiptDetailSheet extends ConsumerWidget {
  final String receiptId;
  final ScrollController scrollController;
  const _ReceiptDetailSheet(
      {required this.receiptId, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groceryReceiptDetailProvider(receiptId));
    final cs    = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load receipt: $e')),
        data: (receipt) => _ReceiptDetailContent(
          receipt: receipt,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _ReceiptDetailContent extends ConsumerStatefulWidget {
  final GroceryReceipt receipt;
  final ScrollController scrollController;
  const _ReceiptDetailContent(
      {required this.receipt, required this.scrollController});

  @override
  ConsumerState<_ReceiptDetailContent> createState() => _ReceiptDetailContentState();
}

class _ReceiptDetailContentState extends ConsumerState<_ReceiptDetailContent> {
  late GroceryReceipt receipt;

  @override
  void initState() {
    super.initState();
    receipt = widget.receipt;
  }

  void _showEditItemDialog(BuildContext context, GroceryItem item) {
    // Close the receipt detail sheet first, then show edit sheet
    Navigator.of(context, rootNavigator: true).pop();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      showModalBottomSheet(
        context: this.context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _EditItemSheet(
            item: item,
            onSaved: () {
              ref.invalidate(groceryReceiptDetailProvider(widget.receipt.id));
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch for updates after edits
    final detailAsync = ref.watch(groceryReceiptDetailProvider(widget.receipt.id));
    final currentReceipt = detailAsync.valueOrNull ?? widget.receipt;
    final items = currentReceipt.items ?? [];
    final fmt   = NumberFormat.currency(symbol: '\$');
    final cs    = Theme.of(context).colorScheme;

    // Group items by category
    final Map<String, List<GroceryItem>> grouped = {};
    for (final item in items) {
      (grouped[item.category] ??= []).add(item);
    }
    // Sort categories by total spend descending
    final categories = grouped.keys.toList()
      ..sort((a, b) {
        final sa = grouped[a]!.fold(0.0, (s, i) => s + (i.totalPrice ?? 0));
        final sb = grouped[b]!.fold(0.0, (s, i) => s + (i.totalPrice ?? 0));
        return sb.compareTo(sa);
      });

    final foodSpend = items
        .where((i) => i.isFoodItem)
        .fold(0.0, (s, i) => s + (i.totalPrice ?? 0));
    final nonFoodSpend = items
        .where((i) => !i.isFoodItem)
        .fold(0.0, (s, i) => s + (i.totalPrice ?? 0));

    return Column(
      children: [
        // Pull handle
        const SizedBox(height: 12),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentReceipt.storeName ?? 'Receipt',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentReceipt.receiptDate != null
                              ? DateFormat('EEEE, d MMMM yyyy')
                                  .format(currentReceipt.receiptDate!)
                              : DateFormat('EEEE, d MMMM yyyy')
                                  .format(currentReceipt.createdAt),
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmt.format(currentReceipt.totalAmount ?? 0),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.primary),
                      ),
                      Text('Total',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Spend summary row
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Food',
                      value: fmt.format(foodSpend),
                      icon: Icons.restaurant_outlined,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Non-food',
                      value: fmt.format(nonFoodSpend),
                      icon: Icons.home_outlined,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Items',
                      value: '${items.length}',
                      icon: Icons.shopping_cart_outlined,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: cs.outlineVariant),

        // Items list grouped by category
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: categories.length,
            itemBuilder: (ctx, ci) {
              final cat   = categories[ci];
              final catItems = grouped[cat]!;
              final catTotal =
                  catItems.fold(0.0, (s, i) => s + (i.totalPrice ?? 0));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category header
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: _catColor(cat).withOpacity(0.08),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _catColor(cat).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_catIcon(cat),
                              size: 15, color: _catColor(cat)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _catLabel(cat),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _catColor(cat),
                            ),
                          ),
                        ),
                        Text(
                          '${catItems.length} item${catItems.length != 1 ? 's' : ''}'
                          ' · ${fmt.format(catTotal)}',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  // Items in this category (tap to edit)
                  ...catItems.map((item) => _ItemRow(
                    item: item,
                    fmt: fmt,
                    onEdit: () => _showEditItemDialog(context, item),
                  )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryTile(
      {required this.label, required this.value, required this.icon,
       required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final GroceryItem item;
  final NumberFormat fmt;
  final VoidCallback? onEdit;
  const _ItemRow({required this.item, required this.fmt, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quantity badge
          Container(
            width: 28, height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.quantity == item.quantity.roundToDouble()
                  ? '×${item.quantity.round()}'
                  : '×${item.quantity.toStringAsFixed(1)}',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.normalizedName ?? item.rawText ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                ),
                if (item.brand != null && item.brand!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      item.brand!,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
                if (item.estCalories != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '~${item.estCalories!.round()} kcal',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.totalPrice != null)
                Text(
                  fmt.format(item.totalPrice),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
              if (item.unitPrice != null &&
                  item.totalPrice != null &&
                  item.unitPrice != item.totalPrice)
                Text(
                  '${fmt.format(item.unitPrice)} ea',
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
            ],
          ),
          if (onEdit != null)
            SizedBox(
              width: 32, height: 32,
              child: IconButton(
                icon: Icon(Icons.edit_outlined, size: 16,
                    color: cs.onSurfaceVariant),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit item',
              ),
            ),
        ],
      ),
    );
  }
}

IconData _catIcon(String cat) {
  const icons = {
    'produce':       Icons.eco_outlined,
    'dairy':         Icons.water_drop_outlined,
    'meat':          Icons.set_meal_outlined,
    'seafood':       Icons.set_meal_outlined,
    'bakery':        Icons.bakery_dining_outlined,
    'frozen':        Icons.ac_unit_outlined,
    'beverages':     Icons.local_drink_outlined,
    'snacks':        Icons.cookie_outlined,
    'pantry':        Icons.kitchen_outlined,
    'household':     Icons.cleaning_services_outlined,
    'personal_care': Icons.soap_outlined,
  };
  return icons[cat] ?? Icons.shopping_basket_outlined;
}

// ── Edit grocery item sheet ───────────────────────────────────────────────────

class _EditItemSheet extends StatefulWidget {
  final GroceryItem item;
  final VoidCallback onSaved;
  const _EditItemSheet({required this.item, required this.onSaved});

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late String _category;
  bool _saving = false;

  static const _categories = [
    'produce', 'dairy', 'meat', 'seafood', 'bakery',
    'frozen', 'beverages', 'snacks', 'pantry',
    'household', 'personal_care', 'other',
  ];

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(
        text: widget.item.totalPrice?.toStringAsFixed(2) ?? '');
    _qtyCtrl = TextEditingController(
        text: widget.item.quantity == widget.item.quantity.roundToDouble()
            ? widget.item.quantity.round().toString()
            : widget.item.quantity.toStringAsFixed(1));
    _category = _categories.contains(widget.item.category)
        ? widget.item.category : 'other';
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{};
      if (_category != widget.item.category) body['category'] = _category;
      final newPrice = double.tryParse(_priceCtrl.text.trim());
      if (newPrice != null && newPrice != widget.item.totalPrice) {
        body['total_price'] = newPrice;
      }
      final newQty = double.tryParse(_qtyCtrl.text.trim());
      if (newQty != null && newQty != widget.item.quantity) {
        body['quantity'] = newQty;
      }

      if (body.isNotEmpty) {
        await apiClient.dio.put(
          '${ApiConstants.groceryItems}/${widget.item.id}',
          data: body,
        );
        widget.onSaved();
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),

            // Item name (read-only header)
            Text(widget.item.normalizedName ?? widget.item.rawText ?? 'Item',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (widget.item.rawText != null &&
                widget.item.rawText != widget.item.normalizedName)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('OCR: ${widget.item.rawText}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500],
                        fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 20),

            // Category dropdown
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                labelText: 'Category',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              items: _categories.map((c) => DropdownMenuItem(
                value: c,
                child: Row(children: [
                  Icon(_catIcon(c), size: 18, color: _catColor(c)),
                  const SizedBox(width: 10),
                  Text(_catLabel(c)),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _category = v ?? 'other'),
            ),
            const SizedBox(height: 14),

            // Price + Qty row
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Price',
                    isDense: true,
                    prefixText: '\$ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Analytics tab ──────────────────────────────────────────────────────────────

class _AnalyticsTab extends ConsumerStatefulWidget {
  final String person;
  const _AnalyticsTab({required this.person});

  @override
  ConsumerState<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<_AnalyticsTab> {
  String _period = 'month';

  void _showCategorySheet(BuildContext context, String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, ctrl) =>
            _CategoryItemsSheet(category: category, period: _period),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key        = '${widget.person}:$_period';
    final spendAsync = ref.watch(grocerySpendingProvider(key));
    final nutriAsync = ref.watch(groceryNutritionProvider(key));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period selector
          Row(
            children: [
              Text('Period:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'month',  label: Text('Month')),
                  ButtonSegment(value: '3month', label: Text('3 Mo')),
                  ButtonSegment(value: 'year',   label: Text('Year')),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() => _period = s.first),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AI Insights card
          Consumer(builder: (context, ref, _) {
            final insightAsync = ref.watch(_groceryInsightsProvider(_period));
            return insightAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (insight) => insight != null
                  ? _GroceryInsightsCard(insight: insight)
                  : const SizedBox.shrink(),
            );
          }),

          // Spending section
          Text('Spending by Category',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          spendAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (spending) => spending.byCategory.isEmpty
                ? const _EmptyAnalytics()
                : Column(
                    children: [
                      _SpendingDonut(
                        spending: spending,
                        period:   _period,
                        onTap:    (cat) => _showCategorySheet(context, cat),
                      ),
                      const SizedBox(height: 12),
                      _Legend(
                        items: spending.byCategory
                            .map((c) => _LegendItem(
                                  label:   _catLabel(c.category),
                                  value:   '\$${c.amount.toStringAsFixed(2)}',
                                  pct:     c.percentage,
                                  color:   _catColor(c.category),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Nutrition section
          Text('Nutrition Spectrum (estimated)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          nutriAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (spectrum) => spectrum.byCategory.isEmpty
                ? const _EmptyAnalytics()
                : Column(
                    children: [
                      _MacroSummary(spectrum: spectrum),
                      const SizedBox(height: 16),
                      _CaloriesBarChart(
                        spectrum: spectrum,
                        onTap:    (cat) => _showCategorySheet(context, cat),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 80), // FAB padding
        ],
      ),
    );
  }
}

class _GroceryInsightsCard extends StatelessWidget {
  final WeeklyInsight insight;
  const _GroceryInsightsCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final isAi = insight.source == 'ai';
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isAi ? Icons.auto_awesome : Icons.bar_chart,
                  size: 16, color: isAi ? Colors.purple : Colors.teal),
              const SizedBox(width: 6),
              Text(isAi ? 'AI Grocery Insights' : 'Grocery Analysis',
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

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No data yet. Scan some receipts to see analytics.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
}

// ── Spending donut chart (interactive) ────────────────────────────────────────

class _SpendingDonut extends StatefulWidget {
  final GrocerySpending spending;
  final String period;
  final void Function(String category) onTap;

  const _SpendingDonut({
    required this.spending,
    required this.period,
    required this.onTap,
  });

  @override
  State<_SpendingDonut> createState() => _SpendingDonutState();
}

class _SpendingDonutState extends State<_SpendingDonut> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final sections = widget.spending.byCategory.asMap().entries.map((entry) {
      final i       = entry.key;
      final c       = entry.value;
      final isTouched = _touchedIndex == i;
      return PieChartSectionData(
        value:      c.amount,
        color:      _catColor(c.category),
        radius:     isTouched ? 60 : 50,
        title:      c.percentage >= 8
            ? '${c.percentage.toStringAsFixed(0)}%'
            : '',
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(PieChartData(
            sections:          sections,
            centerSpaceRadius: 60,
            sectionsSpace:     2,
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, PieTouchResponse? resp) {
                if (!event.isInterestedForInteractions ||
                    resp == null ||
                    resp.touchedSection == null) {
                  setState(() => _touchedIndex = null);
                  return;
                }
                final idx = resp.touchedSection!.touchedSectionIndex;
                setState(() => _touchedIndex = idx);
                if (event is FlTapUpEvent &&
                    idx >= 0 &&
                    idx < widget.spending.byCategory.length) {
                  widget.onTap(widget.spending.byCategory[idx].category);
                }
              },
            ),
          )),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\$${widget.spending.totalSpend.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Total spend',
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem {
  final String label, value;
  final double pct;
  final Color color;
  const _LegendItem({required this.label, required this.value,
      required this.pct, required this.color});
}

class _Legend extends StatelessWidget {
  final List<_LegendItem> items;
  const _Legend({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(width: 12, height: 12,
                decoration: BoxDecoration(color: item.color,
                    borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(item.label, style: const TextStyle(fontSize: 13))),
            Text('${item.pct.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 8),
            Text(item.value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      )).toList(),
    );
  }
}

class _MacroSummary extends StatelessWidget {
  final GroceryNutritionSpectrum spectrum;
  const _MacroSummary({required this.spectrum});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _MacroTile('Calories', '${spectrum.totalCalories.round()} kcal', Colors.orange),
        _MacroTile('Protein',  '${spectrum.totalProtein.round()} g',    Colors.red),
        _MacroTile('Carbs',    '${spectrum.totalCarbs.round()} g',      Colors.amber),
        _MacroTile('Fat',      '${spectrum.totalFat.round()} g',        Colors.blue),
      ],
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ],
  );
}

// ── Calories bar chart (interactive) ─────────────────────────────────────────

class _CaloriesBarChart extends StatelessWidget {
  final GroceryNutritionSpectrum spectrum;
  final void Function(String category) onTap;

  const _CaloriesBarChart({required this.spectrum, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cats = spectrum.byCategory.take(8).toList();
    if (cats.isEmpty) return const SizedBox.shrink();
    final maxVal = cats.map((c) => c.calories).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        maxY: maxVal * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, BarTouchResponse? resp) {
            if (event is FlTapUpEvent &&
                resp != null &&
                resp.spot != null) {
              final idx = resp.spot!.touchedBarGroupIndex;
              if (idx >= 0 && idx < cats.length) {
                onTap(cats[idx].category);
              }
            }
          },
        ),
        titlesData: FlTitlesData(
          leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= cats.length) return const SizedBox.shrink();
                final label = _catLabel(cats[idx].category);
                final short = label.length > 5 ? label.substring(0, 5) : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(short,
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        gridData:   FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(cats.length, (i) {
          final cat = cats[i];
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY:   cat.calories,
              color: _catColor(cat.category),
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]);
        }),
      )),
    );
  }
}

// ── Category items drill-down sheet ───────────────────────────────────────────

class _CategoryItemsSheet extends ConsumerWidget {
  final String category;
  final String period;
  const _CategoryItemsSheet({required this.category, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key   = '$category:$period';
    final async = ref.watch(groceryCategoryItemsProvider(key));
    final cs    = Theme.of(context).colorScheme;
    final fmt   = NumberFormat.currency(symbol: '\$');

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                    color: _catColor(category),
                    borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 8),
              Text(
                _catLabel(category),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ]),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                if (data.items.isEmpty) {
                  return const Center(child: Text('No items found'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: data.items.length,
                  itemBuilder: (ctx, i) {
                    final item = data.items[i];
                    return ListTile(
                      title: Text(
                        item.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '×${item.quantity.toStringAsFixed(0)} · ${item.occurrences} visit${item.occurrences != 1 ? 's' : ''}'
                        '${item.caloriesEst != null ? ' · ~${item.caloriesEst!.round()} kcal' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(
                        fmt.format(item.totalSpend),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
