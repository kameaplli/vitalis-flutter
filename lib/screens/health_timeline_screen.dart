import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/sync_models.dart';
import '../providers/selected_person_provider.dart';
import '../widgets/source_badge.dart';
import 'package:hugeicons/hugeicons.dart';
import '../widgets/themed_spinner.dart';

// ── Unified Health Timeline Screen ──────────────────────────────────────────
// Shows ALL health data from ALL sources in a single chronological feed.

class HealthTimelineScreen extends ConsumerStatefulWidget {
  const HealthTimelineScreen({super.key});

  @override
  ConsumerState<HealthTimelineScreen> createState() =>
      _HealthTimelineScreenState();
}

class _HealthTimelineScreenState extends ConsumerState<HealthTimelineScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  final List<TimelineObservation> _items = [];

  String _category = 'all';
  int _days = 7;
  int _offset = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _initialLoading = true;

  static const _categories = <String, String>{
    'all': 'All',
    'vitals': 'Vitals',
    'activity': 'Activity',
    'sleep': 'Sleep',
    'body': 'Body',
    'fitness': 'Fitness',
    'nutrition': 'Nutrition',
    'mental': 'Mental',
  };

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _fetchPage();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _fetchPage();
    }
  }

  Future<void> _fetchPage() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);

    try {
      final person = ref.read(selectedPersonProvider);
      final resp = await apiClient.dio.get(
        ApiConstants.syncTimeline,
        queryParameters: {
          'person': person,
          'days': _days,
          'offset': _offset,
          'limit': 50,
          'category': _category,
        },
      );
      final data = TimelineResponse.fromJson(resp.data as Map<String, dynamic>);

      if (!mounted) return;
      setState(() {
        _items.addAll(data.observations);
        _offset += data.observations.length;
        _hasMore = data.hasMore;
        _loading = false;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _initialLoading = false;
      });
    }
  }

  void _setCategory(String cat) {
    if (cat == _category) return;
    setState(() {
      _category = cat;
      _items.clear();
      _offset = 0;
      _hasMore = true;
      _initialLoading = true;
    });
    _fetchPage();
  }

  void _setDays(int d) {
    if (d == _days) return;
    setState(() {
      _days = d;
      _items.clear();
      _offset = 0;
      _hasMore = true;
      _initialLoading = true;
    });
    _fetchPage();
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _offset = 0;
      _hasMore = true;
      _initialLoading = true;
    });
    await _fetchPage();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Timeline'),
        centerTitle: true,
        actions: [
          PopupMenuButton<int>(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar01),
            tooltip: 'Date range',
            onSelected: _setDays,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 1, child: Text('Today')),
              const PopupMenuItem(value: 3, child: Text('Last 3 days')),
              const PopupMenuItem(value: 7, child: Text('Last 7 days')),
              const PopupMenuItem(value: 14, child: Text('Last 2 weeks')),
              const PopupMenuItem(value: 30, child: Text('Last 30 days')),
              const PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _categories.entries.map((e) {
                final selected = e.key == _category;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) => _setCategory(e.key),
                    selectedColor: cs.primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          // Timeline
          Expanded(
            child: _initialLoading
                ? const ThemedSpinner()
                : _items.isEmpty
                    ? _EmptyState(category: _category)
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              );
                            }

                            final obs = _items[index];
                            final prevObs =
                                index > 0 ? _items[index - 1] : null;

                            // Show date header if this is the first item
                            // or the date changed from the previous item
                            final showDateHeader =
                                _shouldShowDateHeader(obs, prevObs);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showDateHeader)
                                  _DateHeader(dateTime: obs.startTime),
                                _TimelineEntry(observation: obs),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateHeader(
      TimelineObservation current, TimelineObservation? prev) {
    if (prev == null) return true;
    final currDate = current.startTime;
    final prevDate = prev.startTime;
    if (currDate == null || prevDate == null) return false;
    return currDate.year != prevDate.year ||
        currDate.month != prevDate.month ||
        currDate.day != prevDate.day;
  }
}

// ── Date header ─────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final DateTime? dateTime;
  const _DateHeader({this.dateTime});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    String label;
    if (dateTime == null) {
      label = 'Unknown date';
    } else if (dateTime!.year == now.year &&
        dateTime!.month == now.month &&
        dateTime!.day == now.day) {
      label = 'Today, ${DateFormat('MMM d').format(dateTime!)}';
    } else if (dateTime!.year == now.year &&
        dateTime!.month == now.month &&
        dateTime!.day == now.day - 1) {
      label = 'Yesterday, ${DateFormat('MMM d').format(dateTime!)}';
    } else {
      label = DateFormat('EEEE, MMM d').format(dateTime!);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline entry card ─────────────────────────────────────────────────────

class _TimelineEntry extends StatefulWidget {
  final TimelineObservation observation;
  const _TimelineEntry({required this.observation});

  @override
  State<_TimelineEntry> createState() => _TimelineEntryState();
}

class _TimelineEntryState extends State<_TimelineEntry> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final obs = widget.observation;
    final time = obs.startTime;
    final timeStr =
        time != null ? DateFormat('HH:mm').format(time.toLocal()) : '--:--';
    final info = _dataTypeInfo(obs.dataType);
    final hasDetails = obs.valueJson != null || obs.valueText != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: cs.surfaceContainerLow,
        child: InkWell(
          onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Time
                    SizedBox(
                      width: 44,
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: info.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: HugeIcon(icon: info.icon, size: 16, color: info.color),
                    ),
                    const SizedBox(width: 10),
                    // Data type name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            obs.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_formatValue(obs).isNotEmpty)
                            Text(
                              _formatValue(obs),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: info.color,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Source badge
                    SourceBadge(
                      sourceId: obs.sourceId ?? (obs.isManual ? 'manual' : 'unknown'),
                      sourceName: obs.deviceName ?? obs.sourceName,
                      fontSize: 10,
                    ),
                    if (hasDetails) ...[
                      const SizedBox(width: 4),
                      HugeIcon(icon:
                        _expanded ? HugeIcons.strokeRoundedArrowUp01 : HugeIcons.strokeRoundedArrowDown01,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),

                // Expanded details
                if (_expanded && hasDetails) ...[
                  const SizedBox(height: 8),
                  Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  _buildDetails(obs, cs),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatValue(TimelineObservation obs) {
    if (obs.valueNumeric != null) {
      final v = obs.valueNumeric!;
      final formatted = v == v.roundToDouble()
          ? v.toInt().toString()
          : v.toStringAsFixed(1);
      final unit = obs.unit ?? '';
      return '$formatted $unit'.trim();
    }
    if (obs.valueText != null && obs.valueText!.isNotEmpty) {
      return obs.valueText!;
    }
    return '';
  }

  Widget _buildDetails(TimelineObservation obs, ColorScheme cs) {
    final details = <Widget>[];

    // Duration
    if (obs.effectiveStart != null && obs.effectiveEnd != null) {
      final start = DateTime.tryParse(obs.effectiveStart!);
      final end = DateTime.tryParse(obs.effectiveEnd!);
      if (start != null && end != null) {
        final dur = end.difference(start);
        if (dur.inMinutes > 0) {
          final hours = dur.inHours;
          final mins = dur.inMinutes % 60;
          final durStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
          details.add(_DetailRow(label: 'Duration', value: durStr));
        }
      }
    }

    // JSON details (workout, sleep stages, etc.)
    if (obs.valueJson != null) {
      try {
        final parsed = jsonDecode(obs.valueJson!);
        if (parsed is Map<String, dynamic>) {
          for (final entry in parsed.entries) {
            if (entry.value != null && entry.value != 0) {
              details.add(_DetailRow(
                label: _humanizeKey(entry.key),
                value: entry.value.toString(),
              ));
            }
          }
        }
      } catch (_) {}
    }

    // Text value (sleep stage names, etc.)
    if (obs.valueText != null &&
        obs.valueText!.isNotEmpty &&
        obs.valueNumeric != null) {
      details.add(_DetailRow(label: 'Type', value: obs.valueText!));
    }

    if (details.isEmpty) {
      return Text(
        obs.valueJson ?? obs.valueText ?? '',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details,
    );
  }

  String _humanizeKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

// ── Detail row ──────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String category;
  const _EmptyState({required this.category});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedActivity01, size: 64,
                color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No health data yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category == 'all'
                  ? 'Connect a wearable device or log health data\nto see your timeline here.'
                  : 'No data in this category yet.\nTry a different filter or connect a device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data type visual info ───────────────────────────────────────────────────

class _DataTypeVisual {
  final List<List<dynamic>> icon;
  final Color color;
  const _DataTypeVisual({required this.icon, required this.color});
}

_DataTypeVisual _dataTypeInfo(String dataType) {
  switch (dataType) {
    case 'steps':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedRunningShoes, color: Color(0xFF22C55E));
    case 'heart_rate':
    case 'resting_heart_rate':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedFavourite, color: Color(0xFFEF4444));
    case 'heart_rate_variability':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedChartLineData01, color: Color(0xFFEC4899));
    case 'weight':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedBodyWeight, color: Color(0xFF8B5CF6));
    case 'body_fat_pct':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedPercentCircle, color: Color(0xFFF97316));
    case 'spo2':
    case 'blood_oxygen':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedFastWind, color: Color(0xFF3B82F6));
    case 'blood_glucose':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedDroplet, color: Color(0xFFF59E0B));
    case 'blood_pressure':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedDashboardSpeed02, color: Color(0xFFDC2626));
    case 'body_temperature':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedThermometer, color: Color(0xFFEA580C));
    case 'active_calories':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedFire, color: Color(0xFFF97316));
    case 'distance':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedRuler, color: Color(0xFF06B6D4));
    case 'water':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedDroplet, color: Color(0xFF3B82F6));
    case 'workout':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedDumbbell01, color: Color(0xFF10B981));
    case 'sleep_session':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedBed, color: Color(0xFF6366F1));
    case 'sleep_stage':
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedBed, color: Color(0xFF818CF8));
    default:
      return const _DataTypeVisual(
          icon: HugeIcons.strokeRoundedChartLineData01, color: Color(0xFF6B7280));
  }
}
