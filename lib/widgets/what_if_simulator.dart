import 'package:flutter/material.dart';

/// "What-if" simulator card.
/// Shows how avoiding a trigger or improving a factor would change predicted itch.
class WhatIfSimulator extends StatefulWidget {
  final double currentAvgItch;
  final List<WhatIfScenario> scenarios;

  const WhatIfSimulator({
    super.key,
    required this.currentAvgItch,
    required this.scenarios,
  });

  @override
  State<WhatIfSimulator> createState() => _WhatIfSimulatorState();
}

class WhatIfScenario {
  final String label;
  final String description;
  final double predictedItch;
  final IconData icon;

  const WhatIfScenario({
    required this.label,
    required this.description,
    required this.predictedItch,
    this.icon = Icons.lightbulb_outline,
  });
}

class _WhatIfSimulatorState extends State<WhatIfSimulator> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current baseline
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.show_chart, size: 20),
              const SizedBox(width: 8),
              Text('Current avg itch: ', style: const TextStyle(fontSize: 13)),
              Text(widget.currentAvgItch.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('/10', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Scenario cards
        ...widget.scenarios.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final isSelected = _selectedIndex == i;
          final improvement = widget.currentAvgItch - s.predictedItch;
          final improved = improvement > 0;

          return GestureDetector(
            onTap: () => setState(() => _selectedIndex = isSelected ? null : i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (improved ? Colors.green.shade50 : Colors.red.shade50)
                    : cs.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? (improved ? Colors.green : Colors.red)
                      : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(s.icon, size: 20, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(s.description, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.currentAvgItch.toStringAsFixed(1),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                                    decoration: TextDecoration.lineThrough)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text(s.predictedItch.toStringAsFixed(1),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                    color: improved ? Colors.green : Colors.red)),
                          ],
                        ),
                        Text(
                          improved
                              ? '-${improvement.toStringAsFixed(1)} itch'
                              : '+${(-improvement).toStringAsFixed(1)} itch',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: improved ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                  ] else
                    Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
