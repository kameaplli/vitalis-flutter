import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/nutrient_provider.dart';
import '../../providers/selected_person_provider.dart';

// ─── Daily Micronutrient Summary ──────────────────────────────────────────────

class DailyMicronutrientSummary extends ConsumerStatefulWidget {
  const DailyMicronutrientSummary({super.key});
  @override
  ConsumerState<DailyMicronutrientSummary> createState() =>
      _DailyMicronutrientSummaryState();
}

class _DailyMicronutrientSummaryState
    extends ConsumerState<DailyMicronutrientSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = '$person|$today';
    final asyncData = ref.watch(dailyNutrientProvider(key));
    final cs = Theme.of(context).colorScheme;

    return asyncData.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        final summary = data.summary;
        final total = summary.lowCount + summary.approachingCount +
            summary.adequateCount + summary.excessiveCount;
        if (total == 0) return const SizedBox.shrink();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              // ── Compact header ────────────────────────────────────
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Micronutrients Today',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface)),
                            const SizedBox(height: 4),
                            // Status chips row
                            Row(
                              children: [
                                if (summary.adequateCount > 0)
                                  _StatusChip(
                                    count: summary.adequateCount,
                                    label: 'OK',
                                    color: Colors.green,
                                  ),
                                if (summary.approachingCount > 0)
                                  _StatusChip(
                                    count: summary.approachingCount,
                                    label: 'Low',
                                    color: Colors.orange,
                                  ),
                                if (summary.lowCount > 0)
                                  _StatusChip(
                                    count: summary.lowCount,
                                    label: 'Deficient',
                                    color: Colors.red,
                                  ),
                                if (summary.excessiveCount > 0)
                                  _StatusChip(
                                    count: summary.excessiveCount,
                                    label: 'High',
                                    color: Colors.purple,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Expanded detail ────────────────────────────────────
              if (_expanded) _MicronutrientDetail(data: data),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _StatusChip({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$count $label',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}

class _MicronutrientDetail extends StatelessWidget {
  final DailyNutrientAssessment data;
  const _MicronutrientDetail({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vitamins = data.nutrients
        .where((n) => n.category == 'vitamin')
        .toList();
    final minerals = data.nutrients
        .where((n) => n.category == 'mineral')
        .toList();
    final others = data.nutrients
        .where((n) => n.category != 'vitamin' && n.category != 'mineral' && n.category != 'macro')
        .toList();

    // Top concerns
    final concerns = data.summary.topConcerns;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Top concerns callout
          if (concerns.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top Concerns',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700)),
                  const SizedBox(height: 4),
                  ...concerns.take(3).map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c['display_name'] ?? c['tagname'] ?? '',
                            style: TextStyle(fontSize: 11, color: cs.onSurface),
                          ),
                        ),
                        Text(
                          '${((c['percent_dri'] as num?) ?? 0).toInt()}% DRI',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade600),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Vitamins
          if (vitamins.isNotEmpty) ...[
            const _NutrientSectionHeader(
                title: 'Vitamins', icon: Icons.wb_sunny_outlined, color: Colors.orange),
            const SizedBox(height: 4),
            ...vitamins.map((n) => _NutrientProgressRow(item: n)),
            const SizedBox(height: 10),
          ],

          // Minerals
          if (minerals.isNotEmpty) ...[
            const _NutrientSectionHeader(
                title: 'Minerals', icon: Icons.diamond_outlined, color: Colors.teal),
            const SizedBox(height: 4),
            ...minerals.map((n) => _NutrientProgressRow(item: n)),
            const SizedBox(height: 10),
          ],

          // Others
          if (others.isNotEmpty) ...[
            const _NutrientSectionHeader(
                title: 'Other', icon: Icons.more_horiz, color: Colors.blueGrey),
            const SizedBox(height: 4),
            ...others.map((n) => _NutrientProgressRow(item: n)),
          ],

          // Life stage label
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'DRI targets: ${_formatLifeStage(data.lifeStage)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatLifeStage(String code) {
    final labels = {
      'M_19_30': 'Male 19-30y', 'M_31_50': 'Male 31-50y',
      'M_51_70': 'Male 51-70y', 'M_71_PLUS': 'Male 71+y',
      'F_19_30': 'Female 19-30y', 'F_31_50': 'Female 31-50y',
      'F_51_70': 'Female 51-70y', 'F_71_PLUS': 'Female 71+y',
      'M_14_18': 'Male 14-18y', 'F_14_18': 'Female 14-18y',
      'M_9_13': 'Male 9-13y', 'F_9_13': 'Female 9-13y',
      'CHILD_4_8': 'Child 4-8y', 'CHILD_1_3': 'Child 1-3y',
      'INFANT_7_12': 'Infant 7-12m', 'INFANT_0_6': 'Infant 0-6m',
      'PREG_14_18': 'Pregnant 14-18y', 'PREG_19_30': 'Pregnant 19-30y',
      'PREG_31_50': 'Pregnant 31-50y',
      'LACT_14_18': 'Lactating 14-18y', 'LACT_19_30': 'Lactating 19-30y',
      'LACT_31_50': 'Lactating 31-50y',
    };
    return labels[code] ?? code;
  }
}

class _NutrientSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _NutrientSectionHeader({
    required this.title, required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _NutrientProgressRow extends StatelessWidget {
  final DailyNutrientItem item;
  const _NutrientProgressRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final target = item.target;
    final pct = item.percentDri ?? 0;
    final barPct = (pct / 100).clamp(0.0, 1.5);

    final statusColor = switch (item.status) {
      'adequate' => Colors.green,
      'approaching' => Colors.orange,
      'low' => Colors.red,
      'excessive' => Colors.purple,
      _ => Colors.grey,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(item.displayName,
                style: TextStyle(fontSize: 11, color: cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: barPct.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: statusColor.withValues(alpha: 0.12),
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: Text(
              target != null
                  ? '${_fmt(item.consumed)}/${_fmt(target)}${item.unit}'
                  : '${_fmt(item.consumed)}${item.unit}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              textAlign: TextAlign.right,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            child: Text(
              '${pct.toInt()}%',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 1) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}
