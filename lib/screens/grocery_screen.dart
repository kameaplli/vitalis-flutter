import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/grocery_models.dart';
import '../providers/grocery_provider.dart';
import '../providers/selected_person_provider.dart';

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
            itemBuilder: (ctx, i) => _ReceiptCard(receipt: receipts[i]),
          ),
        );
      },
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final GroceryReceipt receipt;
  const _ReceiptCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(symbol: '\$');

    Widget statusChip;
    switch (receipt.status) {
      case 'done':
        statusChip = Chip(
          label: const Text('Done'),
          avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
        break;
      case 'failed':
        statusChip = Chip(
          label: const Text('Failed'),
          avatar: const Icon(Icons.error_outline, size: 16, color: Colors.red),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
        break;
      default:
        statusChip = const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: receipt.status == 'done'
            ? () => _showItemsSheet(context, receipt)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      receipt.storeName ?? 'Unknown Store',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  statusChip,
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: cs.outline),
                  const SizedBox(width: 4),
                  Text(
                    receipt.receiptDate != null
                        ? DateFormat.yMMMd().format(receipt.receiptDate!)
                        : DateFormat.yMMMd().format(receipt.createdAt),
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                  const Spacer(),
                  if (receipt.totalAmount != null)
                    Text(
                      fmt.format(receipt.totalAmount),
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                ],
              ),
              if (receipt.status == 'done') ...[
                const SizedBox(height: 6),
                Text(
                  '${receipt.itemCount} items · '
                  '${receipt.foodItemCount} food · '
                  '${fmt.format(receipt.totalFoodSpend ?? 0)} food spend',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
              ],
              if (receipt.status == 'failed' && receipt.errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  receipt.errorMessage!,
                  style: const TextStyle(fontSize: 11, color: Colors.red),
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

  void _showItemsSheet(BuildContext context, GroceryReceipt receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (_, ctrl) => _ItemsSheet(receipt: receipt, scrollController: ctrl),
      ),
    );
  }
}

class _ItemsSheet extends StatelessWidget {
  final GroceryReceipt receipt;
  final ScrollController scrollController;

  const _ItemsSheet({required this.receipt, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final items = receipt.items ?? [];
    final fmt = NumberFormat.currency(symbol: '\$');
    final cs  = Theme.of(context).colorScheme;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: cs.outline.withOpacity(0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(receipt.storeName ?? 'Receipt Items',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (receipt.totalAmount != null)
                Text(fmt.format(receipt.totalAmount),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                        fontSize: 16)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: _catColor(item.category).withOpacity(0.15),
                  child: Icon(_catIcon(item.category),
                      size: 15, color: _catColor(item.category)),
                ),
                title: Text(item.normalizedName ?? item.rawText ?? ''),
                subtitle: Text(
                  '${_catLabel(item.category)}'
                  '${item.brand != null && item.brand!.isNotEmpty ? ' · ${item.brand}' : ''}'
                  '${item.estCalories != null ? ' · ${item.estCalories!.round()} kcal est.' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: item.totalPrice != null
                    ? Text(fmt.format(item.totalPrice),
                        style: const TextStyle(fontWeight: FontWeight.w500))
                    : null,
              );
            },
          ),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final key         = '${widget.person}:$_period';
    final spendAsync  = ref.watch(grocerySpendingProvider(key));
    final nutriAsync  = ref.watch(groceryNutritionProvider(key));

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
          const SizedBox(height: 20),

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
                      _SpendingDonut(spending: spending),
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
                      _CaloriesBarChart(spectrum: spectrum),
                    ],
                  ),
          ),
          const SizedBox(height: 80), // FAB padding
        ],
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

class _SpendingDonut extends StatelessWidget {
  final GrocerySpending spending;
  const _SpendingDonut({required this.spending});

  @override
  Widget build(BuildContext context) {
    final sections = spending.byCategory.map((c) {
      return PieChartSectionData(
        value:     c.amount,
        color:     _catColor(c.category),
        radius:    50,
        title:     c.percentage >= 8 ? '${c.percentage.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
            color: Colors.white),
      );
    }).toList();

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(PieChartData(
            sections:        sections,
            centerSpaceRadius: 60,
            sectionsSpace:   2,
          )),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('\$${spending.totalSpend.toStringAsFixed(2)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text('Total spend',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline)),
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

class _CaloriesBarChart extends StatelessWidget {
  final GroceryNutritionSpectrum spectrum;
  const _CaloriesBarChart({required this.spectrum});

  @override
  Widget build(BuildContext context) {
    final cats = spectrum.byCategory.take(8).toList();
    if (cats.isEmpty) return const SizedBox.shrink();
    final maxVal = cats.map((c) => c.calories).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        maxY: maxVal * 1.2,
        barTouchData: BarTouchData(enabled: false),
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
        gridData:    FlGridData(show: false),
        borderData:  FlBorderData(show: false),
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
