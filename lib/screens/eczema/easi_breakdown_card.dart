import 'package:flutter/material.dart';
import '../../models/easi_models.dart';
import 'eczema_helpers.dart';

// ─── EASI breakdown card ──────────────────────────────────────────────────────

class EasiBreakdownCard extends StatefulWidget {
  final Map<String, EasiRegionScore> scores;
  const EasiBreakdownCard({super.key, required this.scores});

  @override
  State<EasiBreakdownCard> createState() => _EasiBreakdownCardState();
}

class _EasiBreakdownCardState extends State<EasiBreakdownCard> {
  bool _expanded = false;

  Map<EasiGroup, double> get _groupScores {
    final m = <EasiGroup, double>{};
    for (final e in widget.scores.entries) {
      final g = groupForRegion(e.key);
      m[g] = (m[g] ?? 0) + e.value.easiContribution(g);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final total = computeEasi(widget.scores);
    if (total == 0 && !_expanded) {
      return const SizedBox.shrink();
    }
    final color = easiColor(total);
    final gs = _groupScores;

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('EASI Auto-Calculator',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text('${total.toStringAsFixed(1)} — ${easiLabel(total)}',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
            ]),

            // EASI progress bar (0–72)
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (total / 72.0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('0  Clear', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('7  Mild', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('21  Mod.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('50  Severe', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('72', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ]),

            if (_expanded) ...[
              const Divider(height: 16),
              ...EasiGroup.values.map((g) {
                final score = gs[g] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    SizedBox(
                      width: 130,
                      child: Text(g.label, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    Text('×${g.multiplier}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (score / 18.0).clamp(0, 1),
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(easiColor(score / 5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 36,
                      child: Text(score.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                );
              }),
            ],
          ]),
        ),
      ),
    );
  }
}
