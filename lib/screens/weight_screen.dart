import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/weight_provider.dart';
import '../providers/selected_person_provider.dart';
import '../providers/dashboard_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../widgets/weight_chart_widget.dart';
import '../widgets/medical_disclaimer.dart';
import '../widgets/friendly_error.dart';
import '../widgets/days_slider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../widgets/themed_spinner.dart';

/// Standalone route screen — wraps WeightContent in a Scaffold.
class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: null),
      body: const WeightContent(),
    );
  }
}

/// Reusable widget used both by WeightScreen and the Weight tab in HealthScreen.
class WeightContent extends ConsumerStatefulWidget {
  const WeightContent({super.key});
  @override
  ConsumerState<WeightContent> createState() => _WeightContentState();
}

class _WeightContentState extends ConsumerState<WeightContent> {
  int _days = 30;
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  static const _minWeight = 20.0;
  static const _maxWeight = 250.0;
  static const _step = 0.050; // 50 grams (scoreboard tiles)

  double _weight = 70.0;
  bool _initialized = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _initToIdealWeight(double? idealWeight) {
    if (_initialized || idealWeight == null) return;
    _initialized = true;
    setState(() {
      _weight = (idealWeight / _step).round() * _step;
      _weight = _weight.clamp(_minWeight, _maxWeight);
    });
  }

  Future<void> _logWeight() async {
    setState(() => _isSaving = true);
    try {
      final person = ref.read(selectedPersonProvider);
      final famId = person == 'self' ? null : person;
      await apiClient.dio.post(ApiConstants.weightLog, data: {
        'weight': _weight,
        'notes': _notesCtrl.text,
        if (famId != null) 'family_member_id': famId,
      });
      _notesCtrl.clear();
      ref.invalidate(weightHistoryProvider);
      ref.invalidate(dashboardProvider((person, DateTime.now().toIso8601String().substring(0, 10))));
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Weight logged!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to log weight')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final histAsync = ref.watch(weightHistoryProvider('${person}_$_days'));
    final cs = Theme.of(context).colorScheme;

    _initToIdealWeight(histAsync.valueOrNull?.idealWeight);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(weightHistoryProvider('${person}_$_days'));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            // ── Chart ────────────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('History',
                          style: Theme.of(context).textTheme.titleSmall),
                      DaysSlider(
                        value: _days,
                        onChanged: (d) => setState(() => _days = d),
                        compact: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                histAsync.when(
                  skipLoadingOnReload: true,
                  loading: () => const SizedBox(
                    height: 280,
                    child: const ThemedSpinner(),
                  ),
                  error: (e, _) => SizedBox(
                    height: 280,
                    child: FriendlyError(error: e, context: 'weight history'),
                  ),
                  data: (history) {
                    final latest = history.entries.isNotEmpty ? history.entries.last : null;
                    final idealMin = history.idealMin;
                    final idealMax = history.idealMax;
                    String? bmiLabel;
                    if (latest != null && idealMin != null && idealMax != null) {
                      final w = latest.weight;
                      if (w < idealMin) {
                        bmiLabel = '${(idealMin - w).toStringAsFixed(1)} kg below ideal';
                      } else if (w > idealMax) {
                        bmiLabel = '${(w - idealMax).toStringAsFixed(1)} kg above ideal';
                      } else {
                        bmiLabel = 'In healthy weight range';
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WeightChartWidget(history: history),
                        if (bmiLabel != null) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: (latest!.weight >= (idealMin ?? 0) && latest.weight <= (idealMax ?? 999))
                                    ? cs.primaryContainer.withValues(alpha: 0.5)
                                    : cs.errorContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (latest.weight >= (idealMin ?? 0) && latest.weight <= (idealMax ?? 999))
                                      ? cs.primary
                                      : cs.error,
                                ),
                              ),
                              child: Text(
                                bmiLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: (latest.weight >= (idealMin ?? 0) && latest.weight <= (idealMax ?? 999))
                                      ? cs.primary
                                      : cs.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Circular dial weight picker ──────────────────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedBodyWeight, color: cs.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('Log Weight', style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Scroll weight picker
                    _WeightScrollPicker(
                      weight: _weight,
                      minWeight: _minWeight,
                      maxWeight: _maxWeight,
                      primaryColor: cs.primary,
                      onSurfaceColor: cs.onSurface,
                      outlineColor: cs.outlineVariant,
                      onChanged: (w) {
                        setState(() => _weight = w);
                        HapticFeedback.selectionClick();
                      },
                    ),

                    const SizedBox(height: 12),
                    // Notes
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Submit
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _logWeight,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01),
                      label: Text('Log ${_weight.toStringAsFixed(1)} kg'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            const MedicalDisclaimer(),
          ],
        ),
      ),
    );
  }
}

// ─── Weight Slider Picker ─────────────────────────────────────────────────────

/// Cricket scoreboard-style weight picker with 5 scrolling tiles.
/// First 3 tiles = kg digits (hundreds, tens, ones).
/// Last 2 tiles = gram digits (hundreds, tens) — 50g increments.
/// Example: [0][7][2] . [4][5] = 72.450 kg
class _WeightScrollPicker extends StatefulWidget {
  final double weight;
  final double minWeight;
  final double maxWeight;
  final Color primaryColor;
  final Color onSurfaceColor;
  final Color outlineColor;
  final ValueChanged<double> onChanged;

  const _WeightScrollPicker({
    required this.weight,
    required this.minWeight,
    required this.maxWeight,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.outlineColor,
    required this.onChanged,
  });

  @override
  State<_WeightScrollPicker> createState() => _WeightScrollPickerState();
}

class _WeightScrollPickerState extends State<_WeightScrollPicker> {
  static const _tileHeight = 56.0;
  // Gram tens tile only allows 0 and 5 (50g increments)
  static const _gramTensValues = [0, 5];

  late final FixedExtentScrollController _kgHundreds;
  late final FixedExtentScrollController _kgTens;
  late final FixedExtentScrollController _kgOnes;
  late final FixedExtentScrollController _gramHundreds;
  late final FixedExtentScrollController _gramTens;

  bool _suppressing = false;

  @override
  void initState() {
    super.initState();
    _initControllers(widget.weight);
  }

  void _initControllers(double w) {
    final kg = w.truncate();
    final grams = ((w - kg) * 1000).round();
    final d0 = (kg ~/ 100) % 10;
    final d1 = (kg ~/ 10) % 10;
    final d2 = kg % 10;
    final g0 = (grams ~/ 100) % 10;
    final g1raw = (grams ~/ 10) % 10;
    // Snap to nearest valid gram tens value (0 or 5)
    final g1idx = g1raw >= 3 ? 1 : 0;

    _kgHundreds = FixedExtentScrollController(initialItem: d0);
    _kgTens = FixedExtentScrollController(initialItem: d1);
    _kgOnes = FixedExtentScrollController(initialItem: d2);
    _gramHundreds = FixedExtentScrollController(initialItem: g0);
    _gramTens = FixedExtentScrollController(initialItem: g1idx);
  }

  @override
  void didUpdateWidget(covariant _WeightScrollPicker old) {
    super.didUpdateWidget(old);
    if ((old.weight - widget.weight).abs() > 0.001 && !_suppressing) {
      _suppressing = true;
      final kg = widget.weight.truncate();
      final grams = ((widget.weight - kg) * 1000).round();
      _kgHundreds.jumpToItem((kg ~/ 100) % 10);
      _kgTens.jumpToItem((kg ~/ 10) % 10);
      _kgOnes.jumpToItem(kg % 10);
      _gramHundreds.jumpToItem((grams ~/ 100) % 10);
      final g1raw = (grams ~/ 10) % 10;
      _gramTens.jumpToItem(g1raw >= 3 ? 1 : 0);
      _suppressing = false;
    }
  }

  void _onTileChanged() {
    if (_suppressing) return;
    _suppressing = true;
    final kg = _kgHundreds.selectedItem * 100 +
        _kgTens.selectedItem * 10 +
        _kgOnes.selectedItem;
    final grams = _gramHundreds.selectedItem * 100 +
        _gramTensValues[_gramTens.selectedItem % _gramTensValues.length] * 10;
    final w = (kg + grams / 1000.0).clamp(widget.minWeight, widget.maxWeight);
    widget.onChanged(double.parse(w.toStringAsFixed(2)));
    _suppressing = false;
  }

  @override
  void dispose() {
    _kgHundreds.dispose();
    _kgTens.dispose();
    _kgOnes.dispose();
    _gramHundreds.dispose();
    _gramTens.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Show formatted weight above the tiles
    final kg = widget.weight.truncate();
    final grams = ((widget.weight - kg) * 1000).round();
    final gramStr = grams.toString().padLeft(3, '0');

    return Column(
      children: [
        // Current weight readout
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
            children: [
              TextSpan(
                text: '$kg',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: widget.primaryColor,
                ),
              ),
              TextSpan(
                text: '.',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: widget.primaryColor,
                ),
              ),
              TextSpan(
                text: gramStr,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: widget.primaryColor.withValues(alpha: 0.7),
                ),
              ),
              const TextSpan(text: '  '),
              TextSpan(
                text: 'kg',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Scoreboard tiles
        SizedBox(
          height: _tileHeight * 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTile(_kgHundreds, List.generate(3, (i) => i), cs), // 0-2 (max 250)
              const SizedBox(width: 4),
              _buildTile(_kgTens, List.generate(10, (i) => i), cs),
              const SizedBox(width: 4),
              _buildTile(_kgOnes, List.generate(10, (i) => i), cs),
              // Decimal dot
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '.',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
              ),
              _buildTile(_gramHundreds, List.generate(10, (i) => i), cs),
              const SizedBox(width: 4),
              _buildTile(_gramTens, _gramTensValues, cs),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                'kilograms',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 100,
              child: Text(
                'grams',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTile(
    FixedExtentScrollController ctrl,
    List<int> values,
    ColorScheme cs,
  ) {
    return Container(
      width: 44,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: _tileHeight,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 1.5,
        perspective: 0.003,
        onSelectedItemChanged: (_) {
          HapticFeedback.selectionClick();
          _onTileChanged();
        },
        childDelegate: ListWheelChildLoopingListDelegate(
          children: values
              .map((v) => Center(
                    child: Text(
                      '$v',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: cs.onSurface,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
