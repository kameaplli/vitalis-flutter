import 'package:flutter/material.dart';

/// Quick Log severity levels for one-tap logging.
enum QuickSeverity {
  clear('Clear', '😊', Colors.green),
  mild('Mild', '🙂', Colors.lightGreen),
  moderate('Moderate', '😐', Colors.orange),
  severe('Severe', '😣', Colors.deepOrange),
  extreme('Extreme', '😫', Colors.red);

  final String label;
  final String emoji;
  final Color color;
  const QuickSeverity(this.label, this.emoji, this.color);

  /// Map to 0-10 itch severity for storage.
  int get itchValue {
    switch (this) {
      case QuickSeverity.clear: return 0;
      case QuickSeverity.mild: return 2;
      case QuickSeverity.moderate: return 5;
      case QuickSeverity.severe: return 7;
      case QuickSeverity.extreme: return 10;
    }
  }
}

/// Callback with the selected severity and optional body zones / food associations.
typedef QuickLogCallback = void Function({
  required QuickSeverity severity,
  List<String>? bodyZones,
  List<String>? foodAssociations,
  String? notes,
});

/// Bottom sheet for quick eczema logging with 3 interaction levels.
///
/// Level 1: One-tap emoji (5s) — just severity.
/// Level 2: Standard (15s) — severity + body zones + recent foods.
/// Level 3: Expand to full EASI log.
class QuickLogSheet extends StatefulWidget {
  final QuickLogCallback onSubmit;
  final VoidCallback? onExpandToFull;
  final List<String> frequentZones;
  final List<String> recentFoods;

  const QuickLogSheet({
    super.key,
    required this.onSubmit,
    this.onExpandToFull,
    this.frequentZones = const [],
    this.recentFoods = const [],
  });

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  QuickSeverity? _selected;
  bool _expanded = false;
  final Set<String> _selectedZones = {};
  final Set<String> _selectedFoods = {};

  void _submit() {
    if (_selected == null) return;
    widget.onSubmit(
      severity: _selected!,
      bodyZones: _selectedZones.isNotEmpty ? _selectedZones.toList() : null,
      foodAssociations: _selectedFoods.isNotEmpty ? _selectedFoods.toList() : null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text("How's your skin right now?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 16),

          // Level 1: Emoji severity row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: QuickSeverity.values.map((s) {
              final isSelected = _selected == s;
              return GestureDetector(
                onTap: () => setState(() => _selected = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? s.color.withAlpha(40) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? s.color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(s.emoji, style: TextStyle(fontSize: isSelected ? 32 : 26)),
                      const SizedBox(height: 4),
                      Text(s.label, style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? s.color : Colors.grey,
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Expand toggle for Level 2
          if (_selected != null && !_expanded)
            TextButton.icon(
              onPressed: () => setState(() => _expanded = true),
              icon: const Icon(Icons.expand_more, size: 18),
              label: const Text('Add details', style: TextStyle(fontSize: 12)),
            ),

          // Level 2: Body zones + recent foods
          if (_expanded) ...[
            const SizedBox(height: 8),
            if (widget.frequentZones.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Problem areas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: widget.frequentZones.map((z) => FilterChip(
                  label: Text(z, style: const TextStyle(fontSize: 11)),
                  selected: _selectedZones.contains(z),
                  onSelected: (_) => setState(() {
                    _selectedZones.contains(z) ? _selectedZones.remove(z) : _selectedZones.add(z);
                  }),
                  selectedColor: cs.primaryContainer,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.recentFoods.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Recent foods', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: widget.recentFoods.map((f) => FilterChip(
                  label: Text(f, style: const TextStyle(fontSize: 11)),
                  selected: _selectedFoods.contains(f),
                  onSelected: (_) => setState(() {
                    _selectedFoods.contains(f) ? _selectedFoods.remove(f) : _selectedFoods.add(f);
                  }),
                  selectedColor: cs.secondaryContainer,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            // Level 3: Expand to full log
            if (widget.onExpandToFull != null)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onExpandToFull!();
                },
                icon: const Icon(Icons.open_in_full, size: 16),
                label: const Text('Full detailed log', style: TextStyle(fontSize: 12)),
              ),
          ],

          const SizedBox(height: 16),

          // Submit button
          if (_selected != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Log it'),
              ),
            ),
        ],
      ),
    );
  }
}
