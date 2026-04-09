import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/food_item.dart';
import '../../providers/nutrition_provider.dart';

// ─── Thali template data model ───────────────────────────────────────────────

class _ThaliItem {
  final String name;
  final double calPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double servingGrams;
  final String? emoji;

  const _ThaliItem({
    required this.name,
    required this.calPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.servingGrams,
    this.emoji,
  });
}

class _ThaliTemplate {
  final String name;
  final String emoji;
  final String description;
  final String region;
  final String mealType; // breakfast, lunch, dinner
  final List<_ThaliItem> items;

  const _ThaliTemplate({
    required this.name,
    required this.emoji,
    required this.description,
    required this.region,
    required this.mealType,
    required this.items,
  });

  int get approxCalories {
    double total = 0;
    for (final item in items) {
      total += item.calPer100g / 100 * item.servingGrams;
    }
    return total.round();
  }
}

// ─── Hardcoded thali templates ───────────────────────────────────────────────

const _templates = <_ThaliTemplate>[
  // ── South Indian ──
  _ThaliTemplate(
    name: 'South Indian Lunch',
    emoji: '🍛',
    description: 'Sambar, rasam, rice, poriyal, curd',
    region: 'South',
    mealType: 'lunch',
    items: [
      _ThaliItem(name: 'Steamed Rice', calPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, servingGrams: 200, emoji: '🍚'),
      _ThaliItem(name: 'Sambar', calPer100g: 65, proteinPer100g: 3.5, carbsPer100g: 8, fatPer100g: 2, servingGrams: 150, emoji: '🍲'),
      _ThaliItem(name: 'Rasam', calPer100g: 25, proteinPer100g: 1, carbsPer100g: 4, fatPer100g: 0.5, servingGrams: 120, emoji: '🥣'),
      _ThaliItem(name: 'Poriyal (Vegetable Stir Fry)', calPer100g: 80, proteinPer100g: 2, carbsPer100g: 6, fatPer100g: 5, servingGrams: 80, emoji: '🥗'),
      _ThaliItem(name: 'Curd / Yogurt', calPer100g: 60, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.3, servingGrams: 100, emoji: '🥛'),
    ],
  ),
  _ThaliTemplate(
    name: 'Idli Sambar Breakfast',
    emoji: '🫓',
    description: 'Soft idlis with sambar & chutney',
    region: 'South',
    mealType: 'breakfast',
    items: [
      _ThaliItem(name: 'Idli (4 pcs)', calPer100g: 130, proteinPer100g: 3.9, carbsPer100g: 25, fatPer100g: 0.4, servingGrams: 240, emoji: '🫓'),
      _ThaliItem(name: 'Sambar', calPer100g: 65, proteinPer100g: 3.5, carbsPer100g: 8, fatPer100g: 2, servingGrams: 120, emoji: '🍲'),
      _ThaliItem(name: 'Coconut Chutney', calPer100g: 150, proteinPer100g: 2, carbsPer100g: 6, fatPer100g: 13, servingGrams: 40, emoji: '🥥'),
    ],
  ),
  _ThaliTemplate(
    name: 'Dosa Breakfast',
    emoji: '🥞',
    description: 'Masala dosa with sambar & chutney',
    region: 'South',
    mealType: 'breakfast',
    items: [
      _ThaliItem(name: 'Masala Dosa (2 pcs)', calPer100g: 165, proteinPer100g: 3, carbsPer100g: 22, fatPer100g: 7, servingGrams: 240, emoji: '🥞'),
      _ThaliItem(name: 'Sambar', calPer100g: 65, proteinPer100g: 3.5, carbsPer100g: 8, fatPer100g: 2, servingGrams: 120, emoji: '🍲'),
      _ThaliItem(name: 'Coconut Chutney', calPer100g: 150, proteinPer100g: 2, carbsPer100g: 6, fatPer100g: 13, servingGrams: 40, emoji: '🥥'),
    ],
  ),

  // ── North Indian ──
  _ThaliTemplate(
    name: 'North Indian Thali',
    emoji: '🍛',
    description: 'Dal, sabzi, roti, rice, raita',
    region: 'North',
    mealType: 'lunch',
    items: [
      _ThaliItem(name: 'Dal Tadka', calPer100g: 110, proteinPer100g: 7, carbsPer100g: 13, fatPer100g: 3, servingGrams: 150, emoji: '🫘'),
      _ThaliItem(name: 'Mixed Vegetable Sabzi', calPer100g: 90, proteinPer100g: 2.5, carbsPer100g: 8, fatPer100g: 5, servingGrams: 100, emoji: '🥘'),
      _ThaliItem(name: 'Chapati / Roti (3 pcs)', calPer100g: 240, proteinPer100g: 8, carbsPer100g: 44, fatPer100g: 3.5, servingGrams: 120, emoji: '🫓'),
      _ThaliItem(name: 'Steamed Rice', calPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, servingGrams: 100, emoji: '🍚'),
      _ThaliItem(name: 'Raita', calPer100g: 55, proteinPer100g: 3, carbsPer100g: 4, fatPer100g: 3, servingGrams: 80, emoji: '🥒'),
    ],
  ),
  _ThaliTemplate(
    name: 'Paratha Breakfast',
    emoji: '🫓',
    description: 'Aloo paratha with curd & pickle',
    region: 'North',
    mealType: 'breakfast',
    items: [
      _ThaliItem(name: 'Aloo Paratha (2 pcs)', calPer100g: 220, proteinPer100g: 5, carbsPer100g: 30, fatPer100g: 9, servingGrams: 200, emoji: '🫓'),
      _ThaliItem(name: 'Curd / Yogurt', calPer100g: 60, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.3, servingGrams: 100, emoji: '🥛'),
      _ThaliItem(name: 'Mango Pickle', calPer100g: 150, proteinPer100g: 1, carbsPer100g: 10, fatPer100g: 12, servingGrams: 15, emoji: '🥭'),
    ],
  ),
  _ThaliTemplate(
    name: 'Rajma Chawal',
    emoji: '🫘',
    description: 'Kidney bean curry with rice & salad',
    region: 'North',
    mealType: 'lunch',
    items: [
      _ThaliItem(name: 'Rajma Curry', calPer100g: 120, proteinPer100g: 7.5, carbsPer100g: 15, fatPer100g: 3, servingGrams: 180, emoji: '🫘'),
      _ThaliItem(name: 'Steamed Rice', calPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, servingGrams: 200, emoji: '🍚'),
      _ThaliItem(name: 'Onion Salad', calPer100g: 40, proteinPer100g: 1, carbsPer100g: 9, fatPer100g: 0.1, servingGrams: 50, emoji: '🧅'),
    ],
  ),

  // ── Telugu ──
  _ThaliTemplate(
    name: 'Telugu Bhojanam',
    emoji: '🍛',
    description: 'Pappu, pulusu, rice, vepudu, perugu',
    region: 'Telugu',
    mealType: 'lunch',
    items: [
      _ThaliItem(name: 'Steamed Rice', calPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, servingGrams: 250, emoji: '🍚'),
      _ThaliItem(name: 'Pappu (Dal)', calPer100g: 110, proteinPer100g: 7, carbsPer100g: 13, fatPer100g: 3, servingGrams: 150, emoji: '🫘'),
      _ThaliItem(name: 'Pulusu / Charu', calPer100g: 30, proteinPer100g: 1, carbsPer100g: 5, fatPer100g: 0.5, servingGrams: 120, emoji: '🥣'),
      _ThaliItem(name: 'Kura / Vepudu', calPer100g: 85, proteinPer100g: 2, carbsPer100g: 6, fatPer100g: 5.5, servingGrams: 100, emoji: '🥘'),
      _ThaliItem(name: 'Perugu (Curd)', calPer100g: 60, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.3, servingGrams: 100, emoji: '🥛'),
      _ThaliItem(name: 'Avakaya Pickle', calPer100g: 150, proteinPer100g: 1, carbsPer100g: 8, fatPer100g: 12, servingGrams: 15, emoji: '🌶️'),
    ],
  ),
  _ThaliTemplate(
    name: 'Pesarattu Breakfast',
    emoji: '🥞',
    description: 'Moong dal dosa with upma & chutney',
    region: 'Telugu',
    mealType: 'breakfast',
    items: [
      _ThaliItem(name: 'Pesarattu (2 pcs)', calPer100g: 140, proteinPer100g: 7, carbsPer100g: 18, fatPer100g: 4, servingGrams: 200, emoji: '🥞'),
      _ThaliItem(name: 'Upma', calPer100g: 120, proteinPer100g: 3, carbsPer100g: 18, fatPer100g: 4, servingGrams: 100, emoji: '🍚'),
      _ThaliItem(name: 'Ginger Chutney', calPer100g: 100, proteinPer100g: 1.5, carbsPer100g: 10, fatPer100g: 6, servingGrams: 30, emoji: '🫚'),
    ],
  ),

  // ── Quick / Simple ──
  _ThaliTemplate(
    name: 'Quick Dal Rice',
    emoji: '⚡',
    description: 'Simple dal with rice — 10 min meal',
    region: 'Quick',
    mealType: 'lunch',
    items: [
      _ThaliItem(name: 'Steamed Rice', calPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, servingGrams: 200, emoji: '🍚'),
      _ThaliItem(name: 'Dal Tadka', calPer100g: 110, proteinPer100g: 7, carbsPer100g: 13, fatPer100g: 3, servingGrams: 150, emoji: '🫘'),
    ],
  ),
  _ThaliTemplate(
    name: 'Curd Rice',
    emoji: '⚡',
    description: 'Comfort food — curd rice with pickle',
    region: 'Quick',
    mealType: 'lunch',
    items: [
      _ThaliItem(name: 'Curd Rice', calPer100g: 105, proteinPer100g: 3, carbsPer100g: 16, fatPer100g: 3, servingGrams: 250, emoji: '🍚'),
      _ThaliItem(name: 'Mango Pickle', calPer100g: 150, proteinPer100g: 1, carbsPer100g: 10, fatPer100g: 12, servingGrams: 15, emoji: '🥭'),
    ],
  ),
  _ThaliTemplate(
    name: 'Egg Rice Quick Bowl',
    emoji: '⚡',
    description: 'Egg fried rice — high protein quick meal',
    region: 'Quick',
    mealType: 'dinner',
    items: [
      _ThaliItem(name: 'Egg Fried Rice', calPer100g: 160, proteinPer100g: 6, carbsPer100g: 22, fatPer100g: 5, servingGrams: 300, emoji: '🍳'),
    ],
  ),
  _ThaliTemplate(
    name: 'Upma & Banana',
    emoji: '⚡',
    description: 'Light breakfast — upma with fruit',
    region: 'Quick',
    mealType: 'breakfast',
    items: [
      _ThaliItem(name: 'Upma', calPer100g: 120, proteinPer100g: 3, carbsPer100g: 18, fatPer100g: 4, servingGrams: 200, emoji: '🍚'),
      _ThaliItem(name: 'Banana', calPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, servingGrams: 120, emoji: '🍌'),
    ],
  ),
];

// ─── Filter chips ────────────────────────────────────────────────────────────

const _regions = ['All', 'South', 'North', 'Telugu', 'Quick'];

// ─── Widget ──────────────────────────────────────────────────────────────────

class ThaliTemplatesSection extends ConsumerStatefulWidget {
  const ThaliTemplatesSection({super.key});

  @override
  ConsumerState<ThaliTemplatesSection> createState() =>
      _ThaliTemplatesSectionState();
}

class _ThaliTemplatesSectionState extends ConsumerState<ThaliTemplatesSection> {
  String _selectedRegion = 'All';
  bool _expanded = false;

  List<_ThaliTemplate> get _filtered {
    if (_selectedRegion == 'All') return _templates;
    return _templates.where((t) => t.region == _selectedRegion).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header — tap to expand/collapse
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedRestaurant01,
                size: 18,
                color: Colors.deepOrange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Indian Thali Templates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: cs.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),

        if (_expanded) ...[
          const SizedBox(height: 8),

          // Filter chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _regions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final region = _regions[i];
                final selected = _selectedRegion == region;
                return ChoiceChip(
                  label: Text(region,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                      )),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedRegion = region),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Template cards — horizontal scroll
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _ThaliCard(
                template: _filtered[i],
                onTap: () => _loadTemplate(_filtered[i]),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  void _loadTemplate(_ThaliTemplate template) {
    HapticFeedback.mediumImpact();

    final selectedFoods = <SelectedFood>[];
    for (final item in template.items) {
      final food = FoodItem(
        id: 'thali_${item.name.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
        name: item.name,
        cal: item.calPer100g,
        protein: item.proteinPer100g,
        carbs: item.carbsPer100g,
        fat: item.fatPer100g,
        servingSize: item.servingGrams,
        emoji: item.emoji,
      );
      selectedFoods.add(SelectedFood(food: food, grams: item.servingGrams));
    }

    if (selectedFoods.isNotEmpty) {
      ref.read(nutritionProvider.notifier).loadRecentMeal(
            selectedFoods,
            template.mealType,
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(template.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${template.name} loaded — tap Log Meal to save',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.deepOrange.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

// ─── Individual thali card ───────────────────────────────────────────────────

class _ThaliCard extends StatelessWidget {
  final _ThaliTemplate template;
  final VoidCallback onTap;

  const _ThaliCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: emoji + name
              Row(
                children: [
                  Text(template.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                template.description,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const Spacer(),

              // Bottom: calories + item count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '~${template.approxCalories} kcal',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${template.items.length} items',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepOrange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
