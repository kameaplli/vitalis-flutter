import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/health_provider.dart';
import '../providers/selected_person_provider.dart';
import '../widgets/person_selector.dart';
import '../widgets/days_slider.dart';
import '../widgets/friendly_error.dart';
import '../widgets/shimmer_placeholder.dart';
import '../widgets/medical_disclaimer.dart';

// ── Mood data ────────────────────────────────────────────────────────────────

class _MoodOption {
  final String emoji;
  final String label;
  final Color color;
  final String category;

  const _MoodOption(this.emoji, this.label, this.color, this.category);

  String get display => '$emoji $label';
}

const _moodCategories = ['Positive', 'Neutral', 'Low Energy', 'Negative'];

final _allMoods = <_MoodOption>[
  // Positive / energized
  _MoodOption('😊', 'Happy',     Color(0xFFFFD54F), 'Positive'),
  _MoodOption('🤩', 'Excited',   Color(0xFFFF8A65), 'Positive'),
  _MoodOption('🔥', 'Pumped Up', Color(0xFFEF5350), 'Positive'),
  _MoodOption('💪', 'Motivated', Color(0xFF66BB6A), 'Positive'),
  _MoodOption('🙏', 'Grateful',  Color(0xFF81D4FA), 'Positive'),
  _MoodOption('💕', 'Loved',     Color(0xFFF48FB1), 'Positive'),
  _MoodOption('😌', 'Calm',      Color(0xFF80CBC4), 'Positive'),
  _MoodOption('🧘', 'Peaceful',  Color(0xFFA5D6A7), 'Positive'),
  // Neutral / mixed
  _MoodOption('😐', 'Neutral',   Color(0xFFBDBDBD), 'Neutral'),
  _MoodOption('🤔', 'Confused',  Color(0xFFFFCC80), 'Neutral'),
  _MoodOption('😬', 'Nervous',   Color(0xFFE6EE9C), 'Neutral'),
  _MoodOption('🧠', 'Focused',   Color(0xFF90CAF9), 'Neutral'),
  _MoodOption('😏', 'Horny',     Color(0xFFCE93D8), 'Neutral'),
  // Low energy / rest
  _MoodOption('😴', 'Sleepy',    Color(0xFF9FA8DA), 'Low Energy'),
  _MoodOption('🥱', 'Tired',     Color(0xFFBCAAA4), 'Low Energy'),
  _MoodOption('😮\u200D💨', 'Exhausted', Color(0xFF90A4AE), 'Low Energy'),
  // Negative / stressed
  _MoodOption('😔', 'Sad',         Color(0xFF7986CB), 'Negative'),
  _MoodOption('😰', 'Anxious',     Color(0xFFFFAB91), 'Negative'),
  _MoodOption('😤', 'Stressed',    Color(0xFFEF9A9A), 'Negative'),
  _MoodOption('😠', 'Irritated',   Color(0xFFE57373), 'Negative'),
  _MoodOption('🤯', 'Overwhelmed', Color(0xFFFF8A80), 'Negative'),
  _MoodOption('😞', 'Lonely',      Color(0xFFB39DDB), 'Negative'),
  _MoodOption('😡', 'Angry',       Color(0xFFE53935), 'Negative'),
  _MoodOption('😢', 'Frustrated',  Color(0xFF9575CD), 'Negative'),
];

_MoodOption _findMood(String display) {
  return _allMoods.firstWhere(
    (m) => m.display == display,
    orElse: () => _allMoods[0],
  );
}

Color _scoreColor(int score) {
  if (score <= 3) return const Color(0xFFE53935);
  if (score <= 5) return const Color(0xFFFF9800);
  if (score <= 7) return const Color(0xFF66BB6A);
  return const Color(0xFF2E7D32);
}

String _scoreEmoji(int score) {
  if (score <= 2) return '😢';
  if (score <= 4) return '😔';
  if (score <= 6) return '😐';
  if (score <= 8) return '😊';
  return '🤩';
}

// ── Main Screen ──────────────────────────────────────────────────────────────

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});
  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final key = '${person}_$_days';
    final logsAsync = ref.watch(moodProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Journal'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DaysSlider(
              value: _days,
              onChanged: (d) => setState(() => _days = d),
              compact: true,
            ),
          ),
        ],
      ),
      body: logsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const ShimmerList(itemCount: 6, itemHeight: 80),
        error: (e, _) => FriendlyError(error: e, context: 'mood logs'),
        data: (entries) => _MoodBody(
          entries: entries,
          days: _days,
          onAdd: () => _openMoodPicker(context, ref),
          onEdit: (item) => _openMoodPicker(context, ref, item: item),
          onDelete: (id) async {
            await apiClient.dio.delete('${ApiConstants.mood}/$id');
            ref.invalidate(moodProvider);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMoodPicker(context, ref),
        icon: const Text('😊', style: TextStyle(fontSize: 22)),
        label: const Text('Log Mood'),
      ),
    );
  }

  void _openMoodPicker(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoodPickerSheet(
        existingItem: item,
        onSaved: () => ref.invalidate(moodProvider),
        ref: ref,
      ),
    );
  }
}

// ── Body (stats + chart + history) ───────────────────────────────────────────

class _MoodBody extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final int days;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(String) onDelete;

  const _MoodBody({
    required this.entries,
    required this.days,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧘', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No mood entries yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Tap the button below to log how you feel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _StatsRow(entries: entries)),
        SliverToBoxAdapter(child: _MoodTrendChart(entries: entries, days: days)),
        SliverToBoxAdapter(child: _MoodDistribution(entries: entries)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(children: [
              Text('Recent Entries',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const Spacer(),
              Text('${entries.length} entries',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
            ]),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = entries[index];
              return _MoodEntryCard(
                item: item,
                onEdit: () => onEdit(item),
                onDelete: () => onDelete(item['id'] as String),
              );
            },
            childCount: entries.length,
          ),
        ),
        const SliverToBoxAdapter(child: MedicalDisclaimer()),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const _StatsRow({required this.entries});

  @override
  Widget build(BuildContext context) {
    final scores = entries.map((e) => e['score'] as int? ?? 0).where((s) => s > 0).toList();
    final avgScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final streak = _calculateStreak(entries);

    final moodCounts = <String, int>{};
    for (final e in entries) {
      final moodsList = e['moods'] as List<dynamic>?;
      final moodStr = moodsList != null && moodsList.isNotEmpty
          ? moodsList.first.toString() : (e['mood'] as String? ?? '');
      if (moodStr.isNotEmpty) moodCounts[moodStr] = (moodCounts[moodStr] ?? 0) + 1;
    }
    String topMood = '😊';
    if (moodCounts.isNotEmpty) {
      topMood = moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      if (topMood.contains(' ')) topMood = topMood.split(' ').first;
    }

    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        Expanded(child: _StatCard(icon: '🔥', value: '$streak', label: 'Day Streak',
          color: streak >= 7 ? const Color(0xFFFF6D00) : streak >= 3 ? const Color(0xFFFFA726) : cs.outline)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(icon: _scoreEmoji(avgScore.round()), value: avgScore.toStringAsFixed(1),
          label: 'Avg Score', color: _scoreColor(avgScore.round()))),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(icon: topMood, value: '${entries.length}',
          label: 'Entries', color: cs.primary)),
      ]),
    );
  }

  int _calculateStreak(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) return 0;
    final dates = <DateTime>{};
    for (final e in entries) {
      final parsed = DateTime.tryParse(e['date'] as String? ?? '');
      if (parsed != null) dates.add(DateTime(parsed.year, parsed.month, parsed.day));
    }
    if (dates.isEmpty) return 0;
    final sorted = dates.toList()..sort((a, b) => b.compareTo(a));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (todayDate.difference(sorted.first).inDays > 1) return 0;
    int streak = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i - 1].difference(sorted[i]).inDays == 1) { streak++; } else { break; }
    }
    return streak;
  }
}

class _StatCard extends StatelessWidget {
  final String icon; final String value; final String label; final Color color;
  const _StatCard({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

// ── Mood Trend Chart ─────────────────────────────────────────────────────────

class _MoodTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final int days;
  const _MoodTrendChart({required this.entries, required this.days});

  @override
  Widget build(BuildContext context) {
    final byDate = <String, List<int>>{};
    for (final e in entries) {
      final d = e['date'] as String? ?? '';
      final s = e['score'] as int? ?? 0;
      if (d.isNotEmpty && s > 0) byDate.putIfAbsent(d, () => []).add(s);
    }
    if (byDate.length < 2) return const SizedBox.shrink();

    final sortedDates = byDate.keys.toList()..sort();
    final displayDates = sortedDates.length > 14 ? sortedDates.sublist(sortedDates.length - 14) : sortedDates;
    final spots = <FlSpot>[];
    for (int i = 0; i < displayDates.length; i++) {
      final avg = byDate[displayDates[i]]!;
      spots.add(FlSpot(i.toDouble(), avg.reduce((a, b) => a + b) / avg.length));
    }

    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mood Trend', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(LineChartData(
              minY: 0, maxY: 10.5,
              gridData: FlGridData(show: true, horizontalInterval: 2, drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.3), strokeWidth: 1)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 2,
                  getTitlesWidget: (value, _) => value == 0 || value > 10 ? const SizedBox.shrink()
                    : Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.6))))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                  interval: max(1, (displayDates.length / 5).ceil().toDouble()),
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= displayDates.length) return const SizedBox.shrink();
                    final parts = displayDates[idx].split('-');
                    return Text('${parts.length >= 3 ? parts[2] : ''}/${parts.length >= 2 ? parts[1] : ''}',
                      style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant.withValues(alpha: 0.6)));
                  })),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [LineChartBarData(
                spots: spots, isCurved: true, curveSmoothness: 0.3, color: cs.primary, barWidth: 3,
                dotData: FlDotData(show: true, getDotPainter: (spot, _, __, ___) =>
                  FlDotCirclePainter(radius: 4, color: _scoreColor(spot.y.round()), strokeWidth: 2, strokeColor: Colors.white)),
                belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [cs.primary.withValues(alpha: 0.2), cs.primary.withValues(alpha: 0.0)])),
              )],
              lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => cs.inverseSurface,
                getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                  '${_scoreEmoji(s.y.round())} ${s.y.toStringAsFixed(1)}',
                  TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.bold, fontSize: 13))).toList())),
            )),
          ),
        ]),
      ),
    );
  }
}

// ── Mood Distribution ────────────────────────────────────────────────────────

class _MoodDistribution extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const _MoodDistribution({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.length < 3) return const SizedBox.shrink();
    final catCounts = <String, int>{'Positive': 0, 'Neutral': 0, 'Low Energy': 0, 'Negative': 0};
    for (final e in entries) {
      final allMoods = (e['moods'] as List<dynamic>?) ?? [e['mood'] ?? ''];
      for (final m in allMoods) {
        final option = _allMoods.where((o) => o.display == m.toString()).firstOrNull;
        if (option != null) catCounts[option.category] = (catCounts[option.category] ?? 0) + 1;
      }
    }
    final total = catCounts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final catColors = {'Positive': const Color(0xFF66BB6A), 'Neutral': const Color(0xFFFFB74D),
      'Low Energy': const Color(0xFF90A4AE), 'Negative': const Color(0xFFE57373)};
    final catEmojis = {'Positive': '😊', 'Neutral': '😐', 'Low Energy': '😴', 'Negative': '😔'};
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mood Distribution', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(height: 28, child: Row(
              children: _moodCategories.map((cat) {
                final count = catCounts[cat] ?? 0;
                if (count == 0) return const SizedBox.shrink();
                final pct = count / total;
                return Expanded(
                  flex: (pct * 100).round().clamp(1, 100),
                  child: Container(color: catColors[cat], alignment: Alignment.center,
                    child: pct > 0.12 ? Text(catEmojis[cat] ?? '', style: const TextStyle(fontSize: 14)) : null),
                );
              }).toList(),
            )),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 6,
            children: _moodCategories.where((c) => (catCounts[c] ?? 0) > 0).map((cat) {
              final pct = ((catCounts[cat] ?? 0) / total * 100).round();
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(
                  color: catColors[cat], borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text('$cat $pct%', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
              ]);
            }).toList()),
        ]),
      ),
    );
  }
}

// ── Entry Card ───────────────────────────────────────────────────────────────

class _MoodEntryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MoodEntryCard({required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final allMoods = (item['moods'] as List<dynamic>?) ?? [item['mood'] ?? ''];
    final score = item['score'] as int? ?? 0;
    final energy = item['energy_level'];
    final date = item['date'] as String? ?? '';
    final time = item['time'] as String? ?? '';
    final notes = item['notes'] as String? ?? '';
    final sc = _scoreColor(score);
    final cs = Theme.of(context).colorScheme;

    final emojis = allMoods.map((m) {
      final s = m.toString();
      return s.contains(' ') ? s.split(' ').first : s;
    }).toList();

    String dateDisplay = '';
    final parsed = DateTime.tryParse(date);
    if (parsed != null) {
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day).difference(DateTime(parsed.year, parsed.month, parsed.day)).inDays;
      if (diff == 0) { dateDisplay = 'Today'; }
      else if (diff == 1) { dateDisplay = 'Yesterday'; }
      else if (diff < 7) { dateDisplay = const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][parsed.weekday - 1]; }
      else { dateDisplay = '${parsed.day}/${parsed.month}'; }
    }
    if (time.isNotEmpty) dateDisplay += ' $time';

    return Dismissible(
      key: Key(item['id'] as String? ?? ''),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white)),
      confirmDismiss: (_) async => await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(title: const Text('Delete entry?'), actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ])),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sc.withValues(alpha: 0.2))),
          child: Row(children: [
            Container(width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [sc.withValues(alpha: 0.25), sc.withValues(alpha: 0.08)]),
                borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text('$score', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: sc, letterSpacing: -0.5)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(emojis.join(' '), style: const TextStyle(fontSize: 20, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(allMoods.map((m) { final s = m.toString(); return s.contains(' ') ? s.split(' ').last : s; }).join(', '),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.7)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              if (notes.isNotEmpty) ...[const SizedBox(height: 2),
                Text(notes, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
                  maxLines: 1, overflow: TextOverflow.ellipsis)],
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(dateDisplay, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
              if (energy != null && energy.toString().isNotEmpty) ...[const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt, size: 12, color: Colors.amber.shade600),
                  Text('$energy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade700)),
                ])],
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Mood Picker Bottom Sheet ─────────────────────────────────────────────────

class _MoodPickerSheet extends StatefulWidget {
  final Map<String, dynamic>? existingItem;
  final VoidCallback onSaved;
  final WidgetRef ref;
  const _MoodPickerSheet({this.existingItem, required this.onSaved, required this.ref});

  @override
  State<_MoodPickerSheet> createState() => _MoodPickerSheetState();
}

class _MoodPickerSheetState extends State<_MoodPickerSheet> {
  final _selected = <String>{};
  int _score = 7;
  int _energy = 5;
  late String _selectedPerson;
  late final TextEditingController _notesCtrl;
  String _activeCategory = 'Positive';

  bool get _isEdit => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    _selectedPerson = widget.ref.read(selectedPersonProvider);
    if (_isEdit) {
      final item = widget.existingItem!;
      final existingMoods = item['moods'] as List<dynamic>?;
      if (existingMoods != null && existingMoods.isNotEmpty) {
        for (final m in existingMoods) _selected.add(m.toString());
      }
      if (_selected.isEmpty) _selected.add(item['mood'] as String? ?? _allMoods[0].display);
      _score = item['score'] as int? ?? 7;
      _energy = item['energy_level'] as int? ?? 5;
      _selectedPerson = item['family_member_id'] as String? ?? 'self';
    }
    _notesCtrl = TextEditingController(text: _isEdit ? (widget.existingItem!['notes'] as String? ?? '') : '');
  }

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = _scoreColor(_score);

    return Container(
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            Text(_isEdit ? 'Edit Mood' : 'How are you feeling?',
              style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Tap one or more moods below', textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            PersonSelector(selectedId: _selectedPerson, onChanged: (v) => setState(() => _selectedPerson = v ?? 'self')),
            const SizedBox(height: 16),
            // Category tabs
            SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
              children: _moodCategories.map((cat) {
                final isActive = _activeCategory == cat;
                final catColor = {'Positive': const Color(0xFF66BB6A), 'Neutral': const Color(0xFFFFB74D),
                  'Low Energy': const Color(0xFF90A4AE), 'Negative': const Color(0xFFE57373)}[cat]!;
                return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                  label: Text(cat), selected: isActive,
                  onSelected: (_) => setState(() => _activeCategory = cat),
                  selectedColor: catColor.withValues(alpha: 0.2),
                  labelStyle: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? catColor : cs.onSurfaceVariant),
                  side: BorderSide(color: isActive ? catColor.withValues(alpha: 0.5) : cs.outlineVariant),
                  visualDensity: VisualDensity.compact));
              }).toList())),
            const SizedBox(height: 16),
            _buildMoodGrid(cs),
            const SizedBox(height: 20),
            if (_selected.isNotEmpty) ...[
              Wrap(spacing: 6, runSpacing: 6, children: _selected.map((m) {
                final option = _findMood(m);
                return Chip(label: Text(option.display, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: _selected.length > 1 ? () => setState(() => _selected.remove(m)) : null,
                  backgroundColor: option.color.withValues(alpha: 0.15),
                  side: BorderSide(color: option.color.withValues(alpha: 0.3)),
                  visualDensity: VisualDensity.compact);
              }).toList()),
              const SizedBox(height: 20),
            ],
            // Score slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sc.withValues(alpha: 0.15))),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_scoreEmoji(_score), style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Text('Score: $_score', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: sc)),
                ]),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(activeTrackColor: sc, inactiveTrackColor: sc.withValues(alpha: 0.15),
                    thumbColor: sc, overlayColor: sc.withValues(alpha: 0.15), trackHeight: 6),
                  child: Slider(value: _score.toDouble(), min: 1, max: 10, divisions: 9,
                    onChanged: (v) { HapticFeedback.selectionClick(); setState(() => _score = v.round()); })),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Awful', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  Text('Amazing', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            // Energy level
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.bolt, color: Colors.amber.shade600, size: 20), const SizedBox(width: 6),
                  Text('Energy Level: $_energy', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
                ]),
                const SizedBox(height: 8),
                Row(children: List.generate(10, (i) {
                  final level = i + 1;
                  final isActive = level <= _energy;
                  return Expanded(child: GestureDetector(
                    onTap: () { HapticFeedback.selectionClick(); setState(() => _energy = level); },
                    child: Container(height: 28, margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.amber.shade400.withValues(alpha: 0.3 + (level / 10) * 0.7)
                          : cs.outlineVariant.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6)),
                      child: Center(child: isActive ? Icon(Icons.bolt, size: 14, color: Colors.amber.shade700) : null))));
                })),
              ]),
            ),
            const SizedBox(height: 16),
            TextField(controller: _notesCtrl, maxLines: 2,
              decoration: InputDecoration(hintText: 'Add a note (optional)',
                hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                filled: true, fillColor: cs.surfaceContainerLow,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16))),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _selected.isEmpty ? null : _save,
              icon: Icon(_isEdit ? Icons.check : Icons.add),
              label: Text(_isEdit ? 'Update' : 'Log Mood'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodGrid(ColorScheme cs) {
    final categoryMoods = _allMoods.where((m) => m.category == _activeCategory).toList();
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, childAspectRatio: 0.85, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: categoryMoods.length,
      itemBuilder: (context, index) {
        final mood = categoryMoods[index];
        final isSelected = _selected.contains(mood.display);
        return GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); setState(() {
            if (isSelected) { if (_selected.length > 1) _selected.remove(mood.display); }
            else { _selected.add(mood.display); }
          }); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: isSelected ? mood.color.withValues(alpha: 0.2) : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? mood.color : cs.outlineVariant.withValues(alpha: 0.3),
                width: isSelected ? 2.5 : 1),
              boxShadow: isSelected ? [BoxShadow(color: mood.color.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))] : null),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(mood.emoji, style: TextStyle(fontSize: isSelected ? 32 : 28)),
              const SizedBox(height: 4),
              Text(mood.label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? mood.color : cs.onSurfaceVariant), textAlign: TextAlign.center),
              if (isSelected) Padding(padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle, size: 14, color: mood.color)),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final famId = _selectedPerson == 'self' ? null : _selectedPerson;
    final moodsList = _selected.toList();
    final now = DateTime.now();
    final data = {
      'mood': moodsList.first, 'moods': moodsList, 'score': _score, 'energy_level': _energy,
      'notes': _notesCtrl.text.trim(),
      'date': now.toIso8601String().substring(0, 10),
      'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'family_member_id': famId,
    };
    try {
      if (_isEdit) { await apiClient.dio.put('${ApiConstants.mood}/${widget.existingItem!['id']}', data: data); }
      else { await apiClient.dio.post(ApiConstants.mood, data: data); }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }
}
