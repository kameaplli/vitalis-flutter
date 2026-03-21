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
  static const _step = 0.05; // 50 grams

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
                    child: Center(child: CircularProgressIndicator()),
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
                        Icon(Icons.monitor_weight_outlined, color: cs.primary, size: 20),
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
                          : const Icon(Icons.check_rounded),
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

// ─── Scroll Weight Picker ─────────────────────────────────────────────────────

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
  late FixedExtentScrollController _kgController;
  late FixedExtentScrollController _decimalController;

  int get _minKg => widget.minWeight.toInt();
  int get _maxKg => widget.maxWeight.toInt();
  int get _kgCount => _maxKg - _minKg + 1;

  bool _isUpdatingFromParent = false;

  // 50g increments: index 0=.00, 1=.05, 2=.10, ... 19=.95
  static const _decimalCount = 20;

  int _weightToDecimalIndex(double w) {
    final frac = w - w.toInt();
    return (frac * 20).round().clamp(0, 19);
  }

  @override
  void initState() {
    super.initState();
    final kg = widget.weight.toInt();
    _kgController = FixedExtentScrollController(initialItem: kg - _minKg);
    _decimalController = FixedExtentScrollController(
      initialItem: _weightToDecimalIndex(widget.weight),
    );
  }

  @override
  void didUpdateWidget(_WeightScrollPicker old) {
    super.didUpdateWidget(old);
    if ((old.weight - widget.weight).abs() > 0.01 && !_isUpdatingFromParent) {
      _isUpdatingFromParent = true;
      final kg = widget.weight.toInt();
      _kgController.jumpToItem(kg - _minKg);
      _decimalController.jumpToItem(_weightToDecimalIndex(widget.weight));
      _isUpdatingFromParent = false;
    }
  }

  @override
  void dispose() {
    _kgController.dispose();
    _decimalController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    if (_isUpdatingFromParent) return;
    final kg = _kgController.selectedItem + _minKg;
    final decIdx = _decimalController.selectedItem;
    final newWeight = (kg + decIdx * 0.05)
        .clamp(widget.minWeight, widget.maxWeight);
    widget.onChanged(double.parse(newWeight.toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    const itemHeight = 48.0;
    const visibleItems = 5;
    const pickerHeight = itemHeight * visibleItems;

    return Column(
      children: [
        // Current weight display
        Text(
          widget.weight.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            color: widget.primaryColor,
          ),
        ),
        Text(
          'kg',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: widget.onSurfaceColor.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),

        // Scroll wheels
        SizedBox(
          height: pickerHeight,
          child: Stack(
            children: [
              // Selection highlight band
              Center(
                child: Container(
                  height: itemHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.primaryColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Wheels row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Kg wheel
                  SizedBox(
                    width: 90,
                    height: pickerHeight,
                    child: ListWheelScrollView.useDelegate(
                      controller: _kgController,
                      itemExtent: itemHeight,
                      physics: const FixedExtentScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      diameterRatio: 2.0,
                      perspective: 0.002,
                      onSelectedItemChanged: (_) => _onScrollChanged(),
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _kgCount,
                        builder: (context, index) {
                          final kg = index + _minKg;
                          final isSelected = kg == widget.weight.toInt();
                          return Center(
                            child: Text(
                              '$kg',
                              style: TextStyle(
                                fontSize: isSelected ? 28 : 20,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? widget.onSurfaceColor
                                    : widget.onSurfaceColor
                                        .withValues(alpha: 0.35),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Dot separator
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '.',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: widget.onSurfaceColor,
                      ),
                    ),
                  ),

                  // Decimal wheel (50g steps: 00, 05, 10, ..., 95)
                  SizedBox(
                    width: 70,
                    height: pickerHeight,
                    child: ListWheelScrollView.useDelegate(
                      controller: _decimalController,
                      itemExtent: itemHeight,
                      physics: const FixedExtentScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      diameterRatio: 2.0,
                      perspective: 0.002,
                      onSelectedItemChanged: (_) => _onScrollChanged(),
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _decimalCount,
                        builder: (context, index) {
                          final grams = index * 5; // 0, 5, 10, ..., 95
                          final isSelected =
                              index == _weightToDecimalIndex(widget.weight);
                          return Center(
                            child: Text(
                              grams.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: isSelected ? 28 : 20,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: isSelected
                                    ? widget.onSurfaceColor
                                    : widget.onSurfaceColor
                                        .withValues(alpha: 0.35),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
