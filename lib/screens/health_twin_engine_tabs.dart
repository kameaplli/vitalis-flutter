import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/health_twin_engine_data.dart';
import '../providers/health_twin_engine_provider.dart';
import '../providers/selected_person_provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../widgets/themed_spinner.dart';

// ── Shared Empty State ──────────────────────────────────────────────────────

class _EmptyStateWidget extends StatelessWidget {
  final String message;
  final List<List<dynamic>> icon;

  const _EmptyStateWidget({
    required this.message,
    this.icon = HugeIcons.strokeRoundedInbox,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1: Correlations
// ═══════════════════════════════════════════════════════════════════════════

class CorrelationsTab extends ConsumerWidget {
  const CorrelationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personId = ref.watch(selectedPersonProvider);
    final asyncCorr = ref.watch(crossDomainCorrelationsProvider(personId));

    return asyncCorr.when(
      loading: () => const ThemedSpinner(),
      error: (e, _) => Center(child: Text('Failed to load: $e')),
      data: (data) {
        if (data == null || data.correlations.isEmpty) {
          return const _EmptyStateWidget(
            message:
                'Not enough cross-domain data yet.\nLog meals, mood, sleep, and exercise to discover correlations.',
            icon: HugeIcons.strokeRoundedIdea01,
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(crossDomainCorrelationsProvider(personId));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Top Insights ──
              if (data.topInsights.isNotEmpty) ...[
                _sectionHeader(context, 'Top Insights'),
                const SizedBox(height: 8),
                ...data.topInsights.take(5).map(
                      (insight) => _TopInsightCard(insight: insight),
                    ),
                const SizedBox(height: 20),
              ],

              // ── All Correlations ──
              _sectionHeader(context, 'All Correlations'),
              const SizedBox(height: 8),
              ..._groupedCorrelations(data.correlations).entries.map(
                    (entry) => _CorrelationGroupTile(
                      groupLabel: entry.key,
                      correlations: entry.value,
                    ),
                  ),
              const SizedBox(height: 20),

              // ── Domain Summary ──
              _sectionHeader(context, 'Domain Summary'),
              const SizedBox(height: 8),
              _DomainSummaryGrid(summary: data.domainSummary),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Map<String, List<CorrelationResult>> _groupedCorrelations(
      List<CorrelationResult> correlations) {
    final groups = <String, List<CorrelationResult>>{};
    for (final c in correlations) {
      final key = '${c.domainA} & ${c.domainB}';
      groups.putIfAbsent(key, () => []).add(c);
    }
    return groups;
  }
}

Widget _sectionHeader(BuildContext context, String title) {
  return Text(
    title,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
  );
}

// ── Top Insight Card ─────────────────────────────────────────────────────

class _TopInsightCard extends StatelessWidget {
  final TopInsight insight;
  const _TopInsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(insight.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                _StrengthBadge(strength: insight.strength),
              ],
            ),
            const SizedBox(height: 6),
            Text(insight.description, style: theme.textTheme.bodyMedium),
            if (insight.domains.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: insight.domains
                    .map((d) => Chip(
                          label: Text(d,
                              style: theme.textTheme.labelSmall),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          backgroundColor: cs.surfaceContainerLow,
                          side: BorderSide.none,
                        ))
                    .toList(),
              ),
            ],
            if (insight.recommendation != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedBulb,
                      size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(insight.recommendation!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.primary)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Strength Badge ───────────────────────────────────────────────────────

class _StrengthBadge extends StatelessWidget {
  final String strength;
  const _StrengthBadge({required this.strength});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (strength.toLowerCase()) {
      case 'strong':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case 'moderate':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade800;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        strength[0].toUpperCase() + strength.substring(1),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Correlation Group Tile ───────────────────────────────────────────────

class _CorrelationGroupTile extends StatelessWidget {
  final String groupLabel;
  final List<CorrelationResult> correlations;

  const _CorrelationGroupTile({
    required this.groupLabel,
    required this.correlations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text(groupLabel,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        trailing: Text('${correlations.length}',
            style: theme.textTheme.labelSmall),
        children: correlations.map((c) => _CorrelationItemTile(c: c)).toList(),
      ),
    );
  }
}

class _CorrelationItemTile extends StatefulWidget {
  final CorrelationResult c;
  const _CorrelationItemTile({required this.c});

  @override
  State<_CorrelationItemTile> createState() => _CorrelationItemTileState();
}

class _CorrelationItemTileState extends State<_CorrelationItemTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.c;
    final dirArrow = c.direction == 'positive' ? '\u2191' : '\u2193';

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${c.metricA} \u2194 ${c.metricB}',
                      style: theme.textTheme.bodySmall),
                ),
                Text(
                  '${c.correlation >= 0 ? "+" : ""}${c.correlation.toStringAsFixed(2)} $dirArrow',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _strengthColor(c.strength),
                  ),
                ),
                const SizedBox(width: 8),
                _StrengthBadge(strength: c.strength),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 6),
              Text(c.insight, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                '${c.dataPoints} data points \u2022 Confidence: ${c.confidence}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _strengthColor(String strength) {
    switch (strength.toLowerCase()) {
      case 'strong':
        return Colors.green;
      case 'moderate':
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }
}

// ── Domain Summary Grid ──────────────────────────────────────────────────

class _DomainSummaryGrid extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _DomainSummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (summary.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = summary.entries.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((e) {
        final hasData = e.value is Map && (e.value['has_data'] == true);
        final count = e.value is Map
            ? ((e.value['correlation_count'] as num?)?.toInt() ?? 0)
            : 0;

        return Container(
          width: (MediaQuery.of(context).size.width - 56) / 3,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: hasData
                ? cs.primaryContainer.withOpacity(0.3)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              HugeIcon(
                icon: _domainIcon(e.key),
                size: 20,
                color: hasData ? cs.primary : cs.outline,
              ),
              const SizedBox(height: 4),
              Text(
                _capitalize(e.key),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasData)
                Text('$count corr.',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.outline)),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<List<dynamic>> _domainIcon(String domain) {
    switch (domain.toLowerCase()) {
      case 'nutrition':
        return HugeIcons.strokeRoundedRestaurant01;
      case 'hydration':
        return HugeIcons.strokeRoundedDroplet;
      case 'mood':
        return HugeIcons.strokeRoundedSmileDizzy;
      case 'sleep':
        return HugeIcons.strokeRoundedBed;
      case 'exercise':
        return HugeIcons.strokeRoundedDumbbell01;
      case 'weight':
        return HugeIcons.strokeRoundedBodyWeight;
      case 'symptoms':
        return HugeIcons.strokeRoundedBandage;
      default:
        return HugeIcons.strokeRoundedCircle;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2: Engagement
// ═══════════════════════════════════════════════════════════════════════════

class EngagementTab extends ConsumerWidget {
  const EngagementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personId = ref.watch(selectedPersonProvider);
    final asyncSummary = ref.watch(engagementSummaryProvider(personId));
    final asyncAchievements = ref.watch(healthAchievementsProvider(personId));

    return asyncSummary.when(
      loading: () => const ThemedSpinner(),
      error: (e, _) => Center(child: Text('Failed to load: $e')),
      data: (summary) {
        if (summary == null) {
          return const _EmptyStateWidget(
            message: 'No engagement data available yet.',
            icon: HugeIcons.strokeRoundedAward01,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(engagementSummaryProvider(personId));
            ref.invalidate(healthAchievementsProvider(personId));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Health Level Card ──
              _HealthLevelCard(level: summary.healthLevel),
              const SizedBox(height: 16),

              // ── Streaks Row ──
              _sectionHeader(context, 'Streaks'),
              const SizedBox(height: 8),
              _StreaksRow(streaks: summary.streaks),
              const SizedBox(height: 16),

              // ── XP Summary ──
              _XpSummaryCard(xp: summary.xp),
              const SizedBox(height: 16),

              // ── Achievements Grid ──
              _sectionHeader(context, 'Achievements'),
              const SizedBox(height: 8),
              asyncAchievements.when(
                loading: () =>
                    const ThemedSpinner(),
                error: (e, _) => Text('Failed to load achievements: $e'),
                data: (achData) {
                  if (achData == null || achData.achievements.isEmpty) {
                    return const _EmptyStateWidget(
                      message: 'No achievements yet. Keep logging!',
                      icon: HugeIcons.strokeRoundedAward01,
                    );
                  }
                  return _AchievementsSection(data: achData);
                },
              ),
              const SizedBox(height: 16),

              // ── Recent Milestones ──
              if (summary.milestones.isNotEmpty) ...[
                _sectionHeader(context, 'Recent Milestones'),
                const SizedBox(height: 8),
                _MilestonesList(milestones: summary.milestones.take(5).toList()),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Health Level Card ────────────────────────────────────────────────────

class _HealthLevelCard extends StatelessWidget {
  final HealthLevel level;
  const _HealthLevelCard({required this.level});

  Color _parseHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final levelColor = _parseHex(level.color);
    final pointsToNext = level.nextLevel != null
        ? ((level.nextLevel!['min_score'] as num?)?.toDouble() ?? 0) -
            level.score7dAvg
        : 0.0;
    final nextName = level.nextLevel?['name'] as String? ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Level badge
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: levelColor.withOpacity(0.15),
                border: Border.all(color: levelColor, width: 3),
              ),
              child: Center(
                child: Text(
                  level.icon.isNotEmpty ? level.icon : '${level.level}',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              level.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: levelColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '7-day average: ${level.score7dAvg.toStringAsFixed(1)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.outline),
            ),
            Text(
              '${level.daysAtLevel} days at this level',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.outline),
            ),
            if (level.nextLevel != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: level.progressToNext.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerLow,
                  color: levelColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${pointsToNext.toStringAsFixed(1)} points to $nextName',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Streaks Row ──────────────────────────────────────────────────────────

class _StreaksRow extends StatelessWidget {
  final HealthStreaks streaks;
  const _StreaksRow({required this.streaks});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StreakCard(
              label: 'Logging', emoji: '\uD83D\uDD25', info: streaks.logging),
          const SizedBox(width: 8),
          _StreakCard(
              label: 'Complete',
              emoji: '\uD83C\uDFAF',
              info: streaks.completeness),
          const SizedBox(width: 8),
          _StreakCard(
              label: 'Hydration',
              emoji: '\uD83D\uDCA7',
              info: streaks.hydration),
          const SizedBox(width: 8),
          _StreakCard(
              label: 'Exercise',
              emoji: '\uD83D\uDCAA',
              info: streaks.exercise),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final String label;
  final String emoji;
  final StreakInfo info;

  const _StreakCard({
    required this.label,
    required this.emoji,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = info.current > 0;

    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surfaceContainerLow,
        border: isActive
            ? Border.all(color: Colors.teal, width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            '${info.current}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.teal : theme.colorScheme.outline,
            ),
          ),
          Text(label,
              style: theme.textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text('Best: ${info.best}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

// ── XP Summary Card ──────────────────────────────────────────────────────

class _XpSummaryCard extends StatelessWidget {
  final Map<String, dynamic> xp;
  const _XpSummaryCard({required this.xp});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalXp = (xp['total'] as num?)?.toInt() ?? 0;
    final weekXp = (xp['this_week'] as num?)?.toInt() ?? 0;
    final breakdown = xp['breakdown'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedStar, color: Colors.amber.shade700, size: 22),
                const SizedBox(width: 6),
                Text('Experience Points',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total XP',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.outline)),
                      Text('$totalXp',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This Week',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.outline)),
                      Text('$weekXp',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...breakdown.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_capitalize(e.key.replaceAll('_', ' ')),
                            style: theme.textTheme.bodySmall),
                        Text('+${e.value}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            )),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Achievements Section ─────────────────────────────────────────────────

class _AchievementsSection extends StatelessWidget {
  final AchievementsData data;
  const _AchievementsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Group by category
    final byCategory = <String, List<Achievement>>{};
    for (final a in data.achievements) {
      byCategory.putIfAbsent(a.category, () => []).add(a);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.totalUnlocked}/${data.totalAvailable} unlocked',
          style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
        ),
        const SizedBox(height: 8),
        ...byCategory.entries.map((catEntry) {
          final catName = catEntry.key;
          final items = catEntry.value;
          final unlocked = items.where((a) => a.unlocked).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Row(
                  children: [
                    Text(
                      _capitalize(catName),
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text('$unlocked/${items.length}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.outline)),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) =>
                    _AchievementTile(achievement: items[i]),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locked = !achievement.unlocked;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: locked
            ? cs.surfaceContainerLow
            : cs.primaryContainer.withOpacity(0.3),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            achievement.icon.isNotEmpty ? achievement.icon : '\u2B50',
            style: TextStyle(
              fontSize: 24,
              color: locked ? Colors.grey : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.name,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: locked ? cs.outline : null,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (locked && achievement.progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: achievement.progress!.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: cs.surfaceContainerLow,
                color: cs.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Milestones List ──────────────────────────────────────────────────────

class _MilestonesList extends StatelessWidget {
  final List<Map<String, dynamic>> milestones;
  const _MilestonesList({required this.milestones});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: milestones.asMap().entries.map((entry) {
        final m = entry.value;
        final date = m['date'] as String? ?? '';
        final desc = m['description'] as String? ?? m['title'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary,
                    ),
                  ),
                  if (entry.key < milestones.length - 1)
                    Container(
                      width: 2,
                      height: 32,
                      color: cs.outlineVariant,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(desc, style: theme.textTheme.bodySmall),
                    if (date.isNotEmpty)
                      Text(date,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.outline)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3: Predictions
// ═══════════════════════════════════════════════════════════════════════════

class PredictionsTab extends ConsumerWidget {
  const PredictionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personId = ref.watch(selectedPersonProvider);
    final asyncPredictions = ref.watch(healthPredictionsProvider(personId));
    final asyncScenarios = ref.watch(whatIfScenariosProvider(personId));
    final asyncLab = ref.watch(labFeedbackProvider(personId));

    return asyncPredictions.when(
      loading: () => const ThemedSpinner(),
      error: (e, _) => Center(child: Text('Failed to load: $e')),
      data: (predData) {
        if (predData == null) {
          return const _EmptyStateWidget(
            message:
                'Predictions need more data.\nKeep logging daily to unlock insights.',
            icon: HugeIcons.strokeRoundedChartLineData01,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(healthPredictionsProvider(personId));
            ref.invalidate(whatIfScenariosProvider(personId));
            ref.invalidate(labFeedbackProvider(personId));
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Data Quality Banner ──
              _DataQualityBanner(quality: predData.dataQuality),
              const SizedBox(height: 12),

              // ── Prediction Cards ──
              if (predData.predictions.isNotEmpty) ...[
                _sectionHeader(context, 'Predictions'),
                const SizedBox(height: 8),
                ...predData.predictions
                    .map((p) => _PredictionCard(prediction: p)),
                const SizedBox(height: 12),
              ],

              // ── Risk Flags ──
              if (predData.riskFlags.isNotEmpty) ...[
                _sectionHeader(context, 'Risk Flags'),
                const SizedBox(height: 8),
                ...predData.riskFlags.map((f) => _RiskFlagCard(flag: f)),
                const SizedBox(height: 12),
              ],

              // ── What-If Scenarios ──
              asyncScenarios.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (scenarios) {
                  if (scenarios.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(context, 'What If...'),
                      const SizedBox(height: 8),
                      ...scenarios
                          .map((s) => _WhatIfCard(scenario: s)),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),

              // ── Lab Feedback ──
              asyncLab.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (labData) {
                  if (labData == null || !labData.hasLabData) {
                    return const SizedBox.shrink();
                  }
                  return _LabFeedbackSection(data: labData);
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Data Quality Banner ──────────────────────────────────────────────────

class _DataQualityBanner extends StatelessWidget {
  final String quality;
  const _DataQualityBanner({required this.quality});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color bg;
    Color fg;
    List<List<dynamic>> icon;

    switch (quality.toLowerCase()) {
      case 'good':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        icon = HugeIcons.strokeRoundedCheckmarkCircle01;
        break;
      case 'fair':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        icon = HugeIcons.strokeRoundedInformationCircle;
        break;
      default:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        icon = HugeIcons.strokeRoundedAlert02;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          HugeIcon(icon: icon, color: fg, size: 20),
          const SizedBox(width: 8),
          Text(
            'Data quality: ${quality[0].toUpperCase()}${quality.substring(1)}',
            style:
                theme.textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Prediction Card ──────────────────────────────────────────────────────

class _PredictionCard extends StatelessWidget {
  final HealthPrediction prediction;
  const _PredictionCard({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String trendArrow;
    Color trendColor;
    switch (prediction.trend.toLowerCase()) {
      case 'improving':
        trendArrow = '\u2191';
        trendColor = Colors.green;
        break;
      case 'declining':
        trendArrow = '\u2193';
        trendColor = Colors.red;
        break;
      default:
        trendArrow = '\u2192';
        trendColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    _capitalize(prediction.metric.replaceAll('_', ' ')),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (prediction.current != null)
                  Text(
                    '${prediction.current!.toStringAsFixed(1)} $trendArrow',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: trendColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(prediction.confidence,
                      style: theme.textTheme.labelSmall),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Prediction values
            if (prediction.predictions.isNotEmpty) ...[
              Row(
                children: [
                  if (prediction.predictions['7d'] != null)
                    _predictionChip(theme, '7d',
                        prediction.predictions['7d'].toString()),
                  if (prediction.predictions['14d'] != null)
                    _predictionChip(theme, '14d',
                        prediction.predictions['14d'].toString()),
                  if (prediction.predictions['30d'] != null)
                    _predictionChip(theme, '30d',
                        prediction.predictions['30d'].toString()),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Insight
            Text(prediction.insight, style: theme.textTheme.bodySmall),

            // Goal info
            if (prediction.goal != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedFlag01, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Goal: ${prediction.goal!['target'] ?? ''}'
                        '${prediction.goal!['estimated_date'] != null ? ' (est. ${prediction.goal!['estimated_date']})' : ''}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Persistent gaps
            if (prediction.persistentGaps != null &&
                prediction.persistentGaps!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Persistent gaps:',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...prediction.persistentGaps!.take(5).map((g) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Text(
                      '\u2022 ${g['nutrient'] ?? g['name'] ?? ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _predictionChip(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          Text(value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Risk Flag Card ───────────────────────────────────────────────────────

class _RiskFlagCard extends StatelessWidget {
  final Map<String, dynamic> flag;
  const _RiskFlagCard({required this.flag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severity =
        (flag['severity'] as String? ?? 'low').toLowerCase();
    final message = flag['message'] as String? ?? '';

    Color bg;
    Color fg;
    List<List<dynamic>> icon;
    switch (severity) {
      case 'high':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        icon = HugeIcons.strokeRoundedAlert01;
        break;
      case 'medium':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        icon = HugeIcons.strokeRoundedAlert02;
        break;
      default:
        bg = Colors.yellow.shade50;
        fg = Colors.yellow.shade900;
        icon = HugeIcons.strokeRoundedInformationCircle;
    }

    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            HugeIcon(icon: icon, color: fg, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── What-If Card ─────────────────────────────────────────────────────────

class _WhatIfCard extends StatelessWidget {
  final WhatIfScenario scenario;
  const _WhatIfCard({required this.scenario});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Color diffColor;
    switch (scenario.difficulty.toLowerCase()) {
      case 'easy':
        diffColor = Colors.green;
        break;
      case 'hard':
        diffColor = Colors.red;
        break;
      default:
        diffColor = Colors.amber.shade700;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        title: Text(scenario.title,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: diffColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            scenario.difficulty,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: diffColor, fontWeight: FontWeight.w600),
          ),
        ),
        children: [
          if (scenario.description != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Text(scenario.description!, style: theme.textTheme.bodySmall),
            ),
          // Predicted impacts
          if (scenario.predictedImpact.isNotEmpty) ...[
            ...scenario.predictedImpact.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                          size: 18, color: cs.primary),
                      Expanded(
                        child: Text(
                          '${_capitalize(e.key.toString().replaceAll('_', ' '))}: ${e.value}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          // Food suggestions
          if (scenario.foodSuggestions != null &&
              scenario.foodSuggestions!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: scenario.foodSuggestions!
                  .map((f) => Chip(
                        label: Text(f, style: theme.textTheme.labelSmall),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        backgroundColor: cs.secondaryContainer,
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Lab Feedback Section ─────────────────────────────────────────────────

class _LabFeedbackSection extends StatelessWidget {
  final LabFeedbackData data;
  const _LabFeedbackSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, 'Lab Results \u00D7 Nutrition'),
        const SizedBox(height: 4),
        Text(
          '${data.labReportsCount} report${data.labReportsCount == 1 ? "" : "s"}'
          '${data.latestReportDate != null ? " \u2022 Latest: ${data.latestReportDate}" : ""}',
          style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
        ),
        const SizedBox(height: 10),

        // Feedback cards
        ...data.feedback.map((fb) => _LabBiomarkerCard(feedback: fb)),

        // Validated improvements
        if (data.validatedImprovements.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Validated Improvements',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...data.validatedImprovements.map((imp) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                        size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        imp['description'] as String? ?? imp['text'] as String? ?? imp['action'] as String? ?? imp.values.whereType<String>().join(' — '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              )),
        ],

        // Action items
        if (data.actionItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Action Items',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...data.actionItems.asMap().entries.map((entry) {
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.key + 1}.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['description'] as String? ??
                          item['action'] as String? ??
                          item['text'] as String? ??
                          item.values.whereType<String>().join(' — '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _LabBiomarkerCard extends StatelessWidget {
  final LabNutrientFeedback feedback;
  const _LabBiomarkerCard({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String trendArrow;
    Color trendColor;
    switch (feedback.trend.toLowerCase()) {
      case 'improving':
        trendArrow = '\u2191';
        trendColor = Colors.green;
        break;
      case 'declining':
        trendArrow = '\u2193';
        trendColor = Colors.red;
        break;
      default:
        trendArrow = '\u2192';
        trendColor = Colors.grey;
    }

    Color classColor;
    switch ((feedback.classification ?? '').toLowerCase()) {
      case 'low':
        classColor = Colors.amber.shade700;
        break;
      case 'high':
        classColor = Colors.red;
        break;
      default:
        classColor = Colors.green;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(feedback.biomarker,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (feedback.latestValue != null)
                  Text(
                    '${feedback.latestValue!.toStringAsFixed(1)}'
                    '${feedback.unit != null ? " ${feedback.unit}" : ""}'
                    ' $trendArrow',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: trendColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(width: 8),
                if (feedback.classification != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: classColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      feedback.classification!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: classColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),

            // Related nutrients
            if (feedback.relatedNutrients.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...feedback.relatedNutrients.take(4).map((n) {
                final name = n['nutrient'] as String? ?? '';
                final intakePct =
                    (n['intake_pct'] as num?)?.toDouble();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(name, style: theme.textTheme.bodySmall),
                      ),
                      if (intakePct != null)
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: (intakePct / 100).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: cs.surfaceContainerLow,
                                    color: intakePct >= 80
                                        ? Colors.green
                                        : intakePct >= 50
                                            ? Colors.amber
                                            : Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${intakePct.toStringAsFixed(0)}%',
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],

            // Insight
            const SizedBox(height: 6),
            Text(feedback.insight, style: theme.textTheme.bodySmall),

            // Recommendation
            if (feedback.recommendation != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedBulb,
                      size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      feedback.recommendation!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.primary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 4: Family Overview
// ═══════════════════════════════════════════════════════════════════════════

class FamilyOverviewTab extends ConsumerWidget {
  const FamilyOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFamily = ref.watch(familyOverviewProvider);

    return asyncFamily.when(
      loading: () => const ThemedSpinner(),
      error: (e, _) => Center(child: Text('Failed to load: $e')),
      data: (data) {
        if (data == null || data.members.isEmpty) {
          return const _EmptyStateWidget(
            message: 'No family members found.\nAdd family members in Profile.',
            icon: HugeIcons.strokeRoundedUserGroup,
          );
        }

        final summary = data.familySummary;
        final memberCount = data.members.length;
        final loggedToday =
            (summary['logged_today'] as num?)?.toInt() ?? 0;
        final avgCompleteness =
            (summary['avg_completeness'] as num?)?.toDouble();
        final totalAlerts =
            (summary['total_alerts'] as num?)?.toInt() ?? 0;

        // Common gaps
        final commonGaps =
            summary['common_gaps'] as List<dynamic>? ?? [];

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(familyOverviewProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Family Summary Bar ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      '$memberCount member${memberCount == 1 ? "" : "s"}, '
                      '$loggedToday logged today',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (avgCompleteness != null)
                      Text(
                        '${avgCompleteness.toStringAsFixed(0)}% avg',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    if (totalAlerts > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$totalAlerts alert${totalAlerts == 1 ? "" : "s"}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Colors.red.shade800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Member Cards ──
              ...data.members.map((member) => _FamilyMemberCard(
                    member: member,
                    onTap: () {
                      ref.read(selectedPersonProvider.notifier).state =
                          member.personId;
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  )),

              // ── Common Gaps ──
              if (commonGaps.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionHeader(context, 'Common Gaps'),
                const SizedBox(height: 6),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: commonGaps.map((g) {
                        final gap = g is Map<String, dynamic> ? g : {};
                        final nutrient =
                            gap['nutrient'] as String? ?? gap['name'] as String? ?? (g is Map ? g.values.whereType<String>().join(' — ') : '$g');
                        final suggestion = gap['suggestion'] as String?;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HugeIcon(icon: HugeIcons.strokeRoundedAlert02,
                                  size: 16, color: Colors.amber.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(nutrient,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w500)),
                                    if (suggestion != null)
                                      Text(suggestion,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              // ── Family Alerts ──
              if (data.familyAlerts.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionHeader(context, 'Family Alerts'),
                const SizedBox(height: 6),
                ...data.familyAlerts.map((alert) {
                  final memberName =
                      alert['member_name'] as String? ?? '';
                  final message = alert['message'] as String? ?? '';
                  final severity =
                      (alert['severity'] as String? ?? 'low')
                          .toLowerCase();

                  Color alertColor;
                  switch (severity) {
                    case 'high':
                      alertColor = Colors.red;
                      break;
                    case 'medium':
                      alertColor = Colors.amber.shade700;
                      break;
                    default:
                      alertColor = Colors.grey;
                  }

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedNotification01,
                              size: 18, color: alertColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                if (memberName.isNotEmpty)
                                  Text(memberName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              fontWeight:
                                                  FontWeight.w600)),
                                Text(message,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Family Member Card ───────────────────────────────────────────────────

class _FamilyMemberCard extends StatelessWidget {
  final FamilyMemberOverview member;
  final VoidCallback onTap;

  const _FamilyMemberCard({
    required this.member,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Color statusColor;
    String statusLabel;
    switch (member.status.toLowerCase()) {
      case 'good':
        statusColor = Colors.green;
        statusLabel = 'Good';
        break;
      case 'attention_needed':
        statusColor = Colors.amber.shade700;
        statusLabel = 'Needs Attention';
        break;
      case 'critical':
        statusColor = Colors.red;
        statusLabel = 'Critical';
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = 'No Data';
    }

    // Extract metrics from twin snapshot
    final snap = member.twinSnapshot ?? {};
    final completeness =
        (snap['completeness'] as num?)?.toDouble();
    final healthScore =
        (snap['health_score'] as num?)?.toDouble();
    final caloriesPct =
        (snap['calories_pct'] as num?)?.toDouble();
    final hydrationPct =
        (snap['hydration_pct'] as num?)?.toDouble();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: cs.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          [
                            if (member.age != null) '${member.age}y',
                            if (member.relationship.isNotEmpty)
                              member.relationship,
                          ].join(' \u2022 '),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: cs.outline),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Status reason
              if (member.statusReason != null &&
                  member.status != 'good' &&
                  member.status != 'no_data') ...[
                const SizedBox(height: 6),
                Text(member.statusReason!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: statusColor)),
              ],

              // Metrics row
              const SizedBox(height: 10),
              Row(
                children: [
                  if (completeness != null)
                    _metricChip(theme, 'Complete',
                        '${completeness.toStringAsFixed(0)}%'),
                  if (healthScore != null)
                    _metricChip(theme, 'Score',
                        healthScore.toStringAsFixed(0)),
                  if (caloriesPct != null)
                    _metricChip(theme, 'Calories',
                        '${caloriesPct.toStringAsFixed(0)}%'),
                  if (hydrationPct != null)
                    _metricChip(theme, 'Hydration',
                        '${hydrationPct.toStringAsFixed(0)}%'),
                ],
              ),

              // Top gaps
              if (member.topGaps.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: member.topGaps.take(3).map((g) {
                    final name =
                        g['nutrient'] as String? ?? g['name'] as String? ?? '';
                    return Chip(
                      label: Text(name, style: theme.textTheme.labelSmall),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding:
                          const EdgeInsets.symmetric(horizontal: 6),
                      backgroundColor: Colors.amber.shade50,
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
              ],

              // Footer: goals, alerts, streak
              const SizedBox(height: 8),
              Row(
                children: [
                  if (member.activeGoals.isNotEmpty) ...[
                    HugeIcon(icon: HugeIcons.strokeRoundedFlag01, size: 14, color: cs.outline),
                    const SizedBox(width: 2),
                    Text('${member.activeGoals.length} goals',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.outline)),
                    const SizedBox(width: 12),
                  ],
                  if (member.activeAlerts > 0) ...[
                    HugeIcon(icon: HugeIcons.strokeRoundedAlert02,
                        size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 2),
                    Text('${member.activeAlerts} alerts',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.amber.shade700)),
                    const SizedBox(width: 12),
                  ],
                  if (member.loggingStreak > 0) ...[
                    const Text('\uD83D\uDD25',
                        style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 2),
                    Text('${member.loggingStreak}d streak',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.outline)),
                  ],
                  const Spacer(),
                  HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 18, color: cs.outline),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricChip(ThemeData theme, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
