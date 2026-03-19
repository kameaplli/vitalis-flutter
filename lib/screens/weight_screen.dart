import 'dart:math';
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

                    // Circular dial
                    _WeightDial(
                      weight: _weight,
                      minWeight: _minWeight,
                      maxWeight: _maxWeight,
                      step: _step,
                      primaryColor: cs.primary,
                      onSurfaceColor: cs.onSurface,
                      surfaceColor: cs.surface,
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

// ─── Circular Dial Weight Picker ──────────────────────────────────────────────

class _WeightDial extends StatefulWidget {
  final double weight;
  final double minWeight;
  final double maxWeight;
  final double step;
  final Color primaryColor;
  final Color onSurfaceColor;
  final Color surfaceColor;
  final Color outlineColor;
  final ValueChanged<double> onChanged;

  const _WeightDial({
    required this.weight,
    required this.minWeight,
    required this.maxWeight,
    required this.step,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.surfaceColor,
    required this.outlineColor,
    required this.onChanged,
  });

  @override
  State<_WeightDial> createState() => _WeightDialState();
}

class _WeightDialState extends State<_WeightDial> {
  // One full rotation = 10 kg (200 ticks of 50g)
  static const _kgPerRotation = 10.0;

  double? _startAngle;
  double _startWeight = 0;

  double _angleFromPosition(Offset position, Offset center) {
    return atan2(position.dy - center.dy, position.dx - center.dx);
  }

  void _onPanStart(DragStartDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    _startAngle = _angleFromPosition(details.localPosition, center);
    _startWeight = widget.weight;
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_startAngle == null) return;
    final center = Offset(size.width / 2, size.height / 2);
    final currentAngle = _angleFromPosition(details.localPosition, center);

    var delta = currentAngle - _startAngle!;
    // Normalize to [-pi, pi]
    if (delta > pi) delta -= 2 * pi;
    if (delta < -pi) delta += 2 * pi;

    // Convert angle delta to weight change
    // Clockwise (positive delta) = increase weight
    final weightDelta = (delta / (2 * pi)) * _kgPerRotation;
    var newWeight = _startWeight + weightDelta;

    // Snap to step
    newWeight = (newWeight / widget.step).round() * widget.step;
    newWeight = newWeight.clamp(widget.minWeight, widget.maxWeight);

    if ((newWeight - widget.weight).abs() >= widget.step * 0.5) {
      widget.onChanged(newWeight);
    }

    // Update start for continuous rotation
    _startAngle = currentAngle;
    _startWeight = newWeight;
  }

  @override
  Widget build(BuildContext context) {
    const dialSize = 220.0;

    return SizedBox(
      width: dialSize,
      height: dialSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanStart: (d) => _onPanStart(d, size),
            onPanUpdate: (d) => _onPanUpdate(d, size),
            child: CustomPaint(
              size: size,
              painter: _DialPainter(
                weight: widget.weight,
                primaryColor: widget.primaryColor,
                onSurfaceColor: widget.onSurfaceColor,
                surfaceColor: widget.surfaceColor,
                outlineColor: widget.outlineColor,
                kgPerRotation: _kgPerRotation,
                step: widget.step,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.weight.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: widget.onSurfaceColor,
                      ),
                    ),
                    Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.onSurfaceColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double weight;
  final Color primaryColor;
  final Color onSurfaceColor;
  final Color surfaceColor;
  final Color outlineColor;
  final double kgPerRotation;
  final double step;

  _DialPainter({
    required this.weight,
    required this.primaryColor,
    required this.onSurfaceColor,
    required this.surfaceColor,
    required this.outlineColor,
    required this.kgPerRotation,
    required this.step,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer ring
    final ringPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ringPaint);

    // Inner background
    final bgPaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 16, bgPaint);

    // Draw tick marks around the dial
    // Show ticks for the visible range around current weight
    final ticksPerRotation = (kgPerRotation / step).round(); // 200 ticks
    final anglePerTick = 2 * pi / ticksPerRotation;

    // The current weight maps to the top (12 o'clock = -pi/2)
    // Each tick represents one step (0.05 kg)
    final baseWeight = (weight / step).round() * step;

    for (int i = 0; i < ticksPerRotation; i++) {
      final angle = -pi / 2 + i * anglePerTick;
      final tickWeight = baseWeight + (i - ticksPerRotation ~/ 2) * step;
      final isWholeKg = ((tickWeight * 100).round() % 100).abs() == 0;
      final isHalfKg = ((tickWeight * 100).round() % 50).abs() == 0;
      final isCurrent = i == ticksPerRotation ~/ 2;

      double tickInner;
      double tickOuter;
      double strokeWidth;
      Color tickColor;

      if (isCurrent) {
        tickInner = radius - 28;
        tickOuter = radius - 2;
        strokeWidth = 3;
        tickColor = primaryColor;
      } else if (isWholeKg) {
        tickInner = radius - 22;
        tickOuter = radius - 4;
        strokeWidth = 2;
        tickColor = onSurfaceColor.withValues(alpha: 0.6);
      } else if (isHalfKg) {
        tickInner = radius - 18;
        tickOuter = radius - 6;
        strokeWidth = 1.5;
        tickColor = onSurfaceColor.withValues(alpha: 0.3);
      } else {
        tickInner = radius - 14;
        tickOuter = radius - 8;
        strokeWidth = 1;
        tickColor = onSurfaceColor.withValues(alpha: 0.12);
      }

      final tickPaint = Paint()
        ..color = tickColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final innerPoint = Offset(
        center.dx + tickInner * cos(angle),
        center.dy + tickInner * sin(angle),
      );
      final outerPoint = Offset(
        center.dx + tickOuter * cos(angle),
        center.dy + tickOuter * sin(angle),
      );

      canvas.drawLine(innerPoint, outerPoint, tickPaint);

      // Draw weight labels at whole kg ticks (not too close together)
      if (isWholeKg && !isCurrent) {
        final labelRadius = radius - 34;
        final labelPos = Offset(
          center.dx + labelRadius * cos(angle),
          center.dy + labelRadius * sin(angle),
        );
        final textPainter = TextPainter(
          text: TextSpan(
            text: tickWeight.round().toString(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: onSurfaceColor.withValues(alpha: 0.4),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        canvas.save();
        canvas.translate(
          labelPos.dx - textPainter.width / 2,
          labelPos.dy - textPainter.height / 2,
        );
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    // Top indicator triangle
    final indicatorPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    final indicatorPath = Path()
      ..moveTo(center.dx, center.dy - radius + 1)
      ..lineTo(center.dx - 5, center.dy - radius - 7)
      ..lineTo(center.dx + 5, center.dy - radius - 7)
      ..close();
    canvas.drawPath(indicatorPath, indicatorPaint);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.weight != weight ||
      old.primaryColor != primaryColor;
}
