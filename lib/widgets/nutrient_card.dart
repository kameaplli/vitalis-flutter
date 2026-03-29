import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/nutrient_provider.dart';
import 'package:hugeicons/hugeicons.dart';

/// Expandable nutrient & ingredients card for a food item.
///
/// Shows a compact summary (macro bars + completeness) that expands to show
/// full vitamin/mineral breakdown and ingredients list.
class NutrientCard extends ConsumerStatefulWidget {
  final String foodId;
  final String foodName;
  final String? ingredientsText;
  final double? nutrientCompleteness;

  const NutrientCard({
    super.key,
    required this.foodId,
    required this.foodName,
    this.ingredientsText,
    this.nutrientCompleteness,
  });

  @override
  ConsumerState<NutrientCard> createState() => _NutrientCardState();
}

class _NutrientCardState extends ConsumerState<NutrientCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completeness = widget.nutrientCompleteness ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          // ── Compact header (always visible) ──────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedTestTube01, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nutrients & Ingredients',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface)),
                        const SizedBox(height: 2),
                        _CompletenessBar(value: completeness),
                      ],
                    ),
                  ),
                  HugeIcon(icon:
                    _expanded ? HugeIcons.strokeRoundedArrowUp01 : HugeIcons.strokeRoundedArrowDown01,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded detail ──────────────────────────────────────────
          if (_expanded) _NutrientDetail(
            foodId: widget.foodId,
            ingredientsText: widget.ingredientsText,
          ),
        ],
      ),
    );
  }
}

// ─── Completeness bar ────────────────────────────────────────────────────────

class _CompletenessBar extends StatelessWidget {
  final double value; // 0.0 – 1.0
  const _CompletenessBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).clamp(0, 100).toInt();
    final color = pct >= 70
        ? Colors.green
        : pct >= 40
            ? Colors.orange
            : Colors.grey;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$pct% data',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}

// ─── Expanded nutrient detail ────────────────────────────────────────────────

class _NutrientDetail extends ConsumerWidget {
  final String foodId;
  final String? ingredientsText;

  const _NutrientDetail({required this.foodId, this.ingredientsText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(foodNutrientProvider(foodId));
    final cs = Theme.of(context).colorScheme;

    return asyncData.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Could not load nutrient data',
            style: TextStyle(fontSize: 12, color: cs.error)),
      ),
      data: (data) {
        if (data == null) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No nutrient data available',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Macros summary row
              _MacroRow(macros: data.macros),
              const SizedBox(height: 10),

              // Vitamins
              if (data.vitamins.isNotEmpty) ...[
                const _SectionHeader(title: 'Vitamins', icon: HugeIcons.strokeRoundedSun01, color: Colors.orange),
                const SizedBox(height: 4),
                _NutrientGrid(nutrients: data.vitamins),
                const SizedBox(height: 10),
              ],

              // Minerals
              if (data.minerals.isNotEmpty) ...[
                const _SectionHeader(title: 'Minerals', icon: HugeIcons.strokeRoundedDiamond01, color: Colors.teal),
                const SizedBox(height: 4),
                _NutrientGrid(nutrients: data.minerals),
                const SizedBox(height: 10),
              ],

              // Other
              if (data.otherNutrients.isNotEmpty) ...[
                const _SectionHeader(title: 'Other', icon: HugeIcons.strokeRoundedMoreHorizontal, color: Colors.blueGrey),
                const SizedBox(height: 4),
                _NutrientGrid(nutrients: data.otherNutrients),
                const SizedBox(height: 10),
              ],

              // Ingredients
              if (_hasIngredients(data)) ...[
                _SectionHeader(title: 'Ingredients', icon: HugeIcons.strokeRoundedMenu01, color: cs.primary),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data.ingredientsText ?? ingredientsText ?? '',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],

              // Source badge
              if (data.source != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Source: ${_formatSource(data.source!)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _hasIngredients(FoodNutrientData data) {
    final text = data.ingredientsText ?? ingredientsText;
    return text != null && text.isNotEmpty;
  }

  String _formatSource(String source) {
    const labels = {
      'usda_foundation': 'USDA Foundation',
      'usda_sr': 'USDA SR Legacy',
      'usda_branded': 'USDA Branded',
      'off': 'Open Food Facts',
      'cnf': 'Canadian NF',
      'fineli': 'Fineli',
      'custom': 'Custom',
    };
    return labels[source] ?? source.replaceAll('_', ' ');
  }
}

// ─── Macro row ───────────────────────────────────────────────────────────────

class _MacroRow extends StatelessWidget {
  final Map<String, double> macros;
  const _MacroRow({required this.macros});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MacroChip(label: 'Cal', value: macros['calories_per_100g'], unit: 'kcal', color: Colors.red.shade400),
        const SizedBox(width: 6),
        _MacroChip(label: 'Protein', value: macros['protein_per_100g'], unit: 'g', color: Colors.blue),
        const SizedBox(width: 6),
        _MacroChip(label: 'Carbs', value: macros['carbs_per_100g'], unit: 'g', color: Colors.orange),
        const SizedBox(width: 6),
        _MacroChip(label: 'Fat', value: macros['fat_per_100g'], unit: 'g', color: Colors.red),
        const SizedBox(width: 6),
        _MacroChip(label: 'Fiber', value: macros['fiber_per_100g'], unit: 'g', color: Colors.green),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final Color color;

  const _MacroChip({
    required this.label,
    this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              value != null ? value!.toStringAsFixed(value! >= 100 ? 0 : 1) : '—',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final List<List<dynamic>> icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(title,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

// ─── Nutrient grid ───────────────────────────────────────────────────────────

class _NutrientGrid extends StatelessWidget {
  final List<NutrientValue> nutrients;
  const _NutrientGrid({required this.nutrients});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: nutrients.map((n) => _NutrientChip(nutrient: n)).toList(),
    );
  }
}

class _NutrientChip extends StatelessWidget {
  final NutrientValue nutrient;
  const _NutrientChip({required this.nutrient});

  @override
  Widget build(BuildContext context) {
    final hasData = nutrient.hasData;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: hasData
            ? cs.primaryContainer.withValues(alpha: 0.4)
            : cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            nutrient.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: hasData ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            hasData
                ? '${_formatValue(nutrient.value!)}${nutrient.unit}'
                : '—',
            style: TextStyle(
              fontSize: 11,
              color: hasData
                  ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                  : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}
