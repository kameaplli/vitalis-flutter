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

class _WeightScrollPicker extends StatelessWidget {
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

  void _adjust(double delta) {
    final newW = (weight + delta).clamp(minWeight, maxWeight);
    onChanged(double.parse(newW.toStringAsFixed(1)));
  }

  @override
  Widget build(BuildContext context) {
    // Snap to 0.1 kg (100g) for clean display
    final divisions = ((maxWeight - minWeight) * 10).round();

    return Column(
      children: [
        // Current weight display
        Text(
          weight.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            color: primaryColor,
          ),
        ),
        Text(
          'kg',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: onSurfaceColor.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),

        // Fine adjustment buttons: -0.1 / -1 / +1 / +0.1
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AdjustButton(label: '-1', onTap: () => _adjust(-1)),
            const SizedBox(width: 8),
            _AdjustButton(label: '-0.1', onTap: () => _adjust(-0.1)),
            const SizedBox(width: 24),
            _AdjustButton(label: '+0.1', onTap: () => _adjust(0.1)),
            const SizedBox(width: 8),
            _AdjustButton(label: '+1', onTap: () => _adjust(1)),
          ],
        ),
        const SizedBox(height: 8),

        // Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: primaryColor,
            inactiveTrackColor: primaryColor.withValues(alpha: 0.15),
            thumbColor: primaryColor,
            overlayColor: primaryColor.withValues(alpha: 0.12),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          ),
          child: Slider(
            value: weight.clamp(minWeight, maxWeight),
            min: minWeight,
            max: maxWeight,
            divisions: divisions,
            onChanged: (v) {
              onChanged(double.parse(v.toStringAsFixed(1)));
            },
          ),
        ),

        // Min/Max labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${minWeight.toInt()} kg',
                style: TextStyle(
                  fontSize: 11,
                  color: onSurfaceColor.withValues(alpha: 0.4),
                ),
              ),
              Text(
                '${maxWeight.toInt()} kg',
                style: TextStyle(
                  fontSize: 11,
                  color: onSurfaceColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
