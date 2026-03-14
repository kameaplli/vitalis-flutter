import 'package:flutter/material.dart';
import '../../providers/nutrition_provider.dart';
import '../../widgets/nutrient_card.dart';
import 'allergen_badge.dart';

// ─── Food item tile with grams input ─────────────────────────────────────────

class FoodItemTile extends StatefulWidget {
  final SelectedFood sf;
  final VoidCallback onRemove;
  final void Function(double) onGramsChanged;

  const FoodItemTile({
    super.key,
    required this.sf,
    required this.onRemove,
    required this.onGramsChanged,
  });

  @override
  State<FoodItemTile> createState() => _FoodItemTileState();
}

class _FoodItemTileState extends State<FoodItemTile> {
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
  void didUpdateWidget(FoodItemTile old) {
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

  void _applyMultiplier(double multiplier) {
    final grams = multiplier * _baseServing;
    setState(() {
      _servings = multiplier.round().clamp(1, 99);
      _ctrl.text = grams.toStringAsFixed(0);
    });
    widget.onGramsChanged(grams);
  }

  double get _currentMultiplier {
    final val = double.tryParse(_ctrl.text);
    if (val == null || _baseServing == 0) return 1;
    return val / _baseServing;
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
                                fontSize: 11,
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
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (food.uniqueAllergens.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          spacing: 3,
                          runSpacing: 2,
                          children: food.uniqueAllergens.take(4).map((a) =>
                            AllergenBadge(allergen: a),
                          ).toList(),
                        ),
                      ),
                    if (food.sourceBadge.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: food.isRecipe ? Colors.green : food.isCustomFood ? Colors.blue : Colors.purple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(food.sourceBadge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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
          // Serving size preset chips
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 4, bottom: 2),
            child: Row(
              children: [0.5, 1.0, 1.5, 2.0].map((m) {
                final isSelected =
                    (_currentMultiplier - m).abs() < 0.01;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('${m}x',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        )),
                    selected: isSelected,
                    onSelected: (_) => _applyMultiplier(m),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 2),
                  ),
                );
              }).toList(),
            ),
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
