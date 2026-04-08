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

  // Always stored in kg internally
  double _weightKg = 70.0;
  bool _useLbs = false;
  bool _initialized = false;

  // Ranges in kg
  static const _minKg = 20.0;
  static const _maxKg = 250.0;
  static const _lbsPerKg = 2.20462262;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _initToIdealWeight(double? idealWeight) {
    if (_initialized || idealWeight == null) return;
    _initialized = true;
    setState(() {
      _weightKg = (idealWeight * 10).round() / 10.0;
      _weightKg = _weightKg.clamp(_minKg, _maxKg);
    });
  }

  double get _displayWeight => _useLbs ? _weightKg * _lbsPerKg : _weightKg;
  String get _unitLabel => _useLbs ? 'lbs' : 'kg';

  Future<void> _logWeight() async {
    setState(() => _isSaving = true);
    try {
      final person = ref.read(selectedPersonProvider);
      final famId = person == 'self' ? null : person;
      await apiClient.dio.post(ApiConstants.weightLog, data: {
        'weight': _weightKg, // always stored in kg
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
    final displayVal = _displayWeight;
    final displayStr = displayVal.toStringAsFixed(1);

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

            // ── Wheel weight picker ────────────────────────────────────────
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
                        const Spacer(),
                        // Unit toggle
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('kg')),
                            ButtonSegment(value: true, label: Text('lbs')),
                          ],
                          selected: {_useLbs},
                          onSelectionChanged: (v) => setState(() => _useLbs = v.first),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Weight display
                    Text(
                      '$displayStr $_unitLabel',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: cs.primary,
                      ),
                    ),
                    if (_useLbs)
                      Text(
                        '${_weightKg.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Wheel picker
                    _WeightWheelPicker(
                      weightKg: _weightKg,
                      useLbs: _useLbs,
                      primaryColor: cs.primary,
                      onChanged: (kg) => setState(() => _weightKg = kg),
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
                      label: Text('Log $displayStr $_unitLabel'),
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

// ─── Weight Wheel Picker ──────────────────────────────────────────────────────

/// Two-wheel weight picker: whole units + decimal tenths.
/// Supports kg and lbs — always converts to kg via onChanged.
class _WeightWheelPicker extends StatefulWidget {
  final double weightKg;
  final bool useLbs;
  final Color primaryColor;
  final ValueChanged<double> onChanged;

  const _WeightWheelPicker({
    required this.weightKg,
    required this.useLbs,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  State<_WeightWheelPicker> createState() => _WeightWheelPickerState();
}

class _WeightWheelPickerState extends State<_WeightWheelPicker> {
  static const _itemExtent = 48.0;
  static const _kgPerLb = 0.45359237;
  static const _lbsPerKg = 2.20462262;

  // kg range: 20.0 – 250.0, lbs range: 44.0 – 551.0
  static const _minKg = 20;
  static const _maxKg = 250;
  static const _minLbs = 44;
  static const _maxLbs = 551;

  late FixedExtentScrollController _wholeCtrl;
  late FixedExtentScrollController _decimalCtrl;
  bool _suppressing = false;

  int _wholeMin = _minKg;
  int _wholeMax = _maxKg;

  @override
  void initState() {
    super.initState();
    _setupControllers();
  }

  void _setupControllers() {
    final display = widget.useLbs ? widget.weightKg * _lbsPerKg : widget.weightKg;
    _wholeMin = widget.useLbs ? _minLbs : _minKg;
    _wholeMax = widget.useLbs ? _maxLbs : _maxKg;
    final whole = display.truncate().clamp(_wholeMin, _wholeMax);
    final decimal = ((display - display.truncate()) * 10).round().clamp(0, 9);
    _wholeCtrl = FixedExtentScrollController(initialItem: whole - _wholeMin);
    _decimalCtrl = FixedExtentScrollController(initialItem: decimal);
  }

  @override
  void didUpdateWidget(covariant _WeightWheelPicker old) {
    super.didUpdateWidget(old);
    if (old.useLbs != widget.useLbs) {
      _wholeCtrl.dispose();
      _decimalCtrl.dispose();
      _setupControllers();
    }
  }

  void _onWheelChanged() {
    if (_suppressing) return;
    _suppressing = true;
    final whole = _wholeCtrl.selectedItem + _wholeMin;
    final decimal = _decimalCtrl.selectedItem % 10;
    final displayVal = whole + decimal / 10.0;
    final kg = widget.useLbs ? displayVal * _kgPerLb : displayVal;
    final clamped = kg.clamp(20.0, 250.0);
    widget.onChanged(double.parse(clamped.toStringAsFixed(1)));
    HapticFeedback.selectionClick();
    _suppressing = false;
  }

  @override
  void dispose() {
    _wholeCtrl.dispose();
    _decimalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wholeCount = _wholeMax - _wholeMin + 1;

    return SizedBox(
      height: _itemExtent * 5,
      child: Stack(
        children: [
          // Selection highlight bar
          Center(
            child: Container(
              height: _itemExtent,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: widget.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.primaryColor.withValues(alpha: 0.3)),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Whole number wheel
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  controller: _wholeCtrl,
                  itemExtent: _itemExtent,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 1.8,
                  perspective: 0.003,
                  onSelectedItemChanged: (_) => _onWheelChanged(),
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: wholeCount,
                    builder: (ctx, i) {
                      final val = i + _wholeMin;
                      return Center(
                        child: Text(
                          '$val',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Decimal dot
              Text(
                '.',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                ),
              ),
              // Decimal wheel (0-9)
              SizedBox(
                width: 50,
                child: ListWheelScrollView.useDelegate(
                  controller: _decimalCtrl,
                  itemExtent: _itemExtent,
                  physics: const FixedExtentScrollPhysics(),
                  diameterRatio: 1.8,
                  perspective: 0.003,
                  onSelectedItemChanged: (_) => _onWheelChanged(),
                  childDelegate: ListWheelChildLoopingListDelegate(
                    children: List.generate(10, (i) => Center(
                      child: Text(
                        '$i',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    )),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Unit label
              Text(
                widget.useLbs ? 'lbs' : 'kg',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
