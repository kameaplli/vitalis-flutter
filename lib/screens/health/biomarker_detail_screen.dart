import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/lab_result.dart';
import '../../providers/lab_provider.dart';
import '../../providers/selected_person_provider.dart';
import '../../widgets/friendly_error.dart';

// ── Design Tokens (matching dashboard) ───────────────────────────────────────

const _kOptimalColor = Color(0xFF4ADE80);    // soft green
const _kSufficientColor = Color(0xFF60A5FA); // soft blue
const _kSuboptimalColor = Color(0xFFFBBF24); // warm amber
const _kCriticalColor = Color(0xFFF87171);   // soft red
const _kUnknownColor = Color(0xFF94A3B8);    // slate

const _kDarkBg = Color(0xFF0F1923);
const _kCardBg = Color(0xFF1A2732);
const _kCardBorder = Color(0xFF2A3A48);
const _kTextPrimary = Color(0xFFF5F5F5);
const _kTextSecondary = Color(0xFF90A4AE);

Color _tierColor(String? tier) => switch (tier) {
      'optimal' => _kOptimalColor,
      'sufficient' => _kSufficientColor,
      'suboptimal' => _kSuboptimalColor,
      'critical' => _kCriticalColor,
      _ => _kUnknownColor,
    };

String _tierLabel(String? tier) => switch (tier) {
      'optimal' => 'OPTIMAL',
      'sufficient' => 'SUFFICIENT',
      'suboptimal' => 'NEEDS WORK',
      'critical' => 'CRITICAL',
      _ => 'UNKNOWN',
    };

class BiomarkerDetailScreen extends ConsumerWidget {
  final String biomarkerCode;
  const BiomarkerDetailScreen({super.key, required this.biomarkerCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final historyAsync = ref.watch(biomarkerHistoryProvider(
        (code: biomarkerCode, person: person)));

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _kDarkBg,
        colorScheme: const ColorScheme.dark(
          surface: _kDarkBg,
          primary: _kOptimalColor,
        ),
      ),
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: _kDarkBg,
          appBar: AppBar(
            backgroundColor: _kDarkBg,
            surfaceTintColor: Colors.transparent,
            title: Text(biomarkerCode,
                style: const TextStyle(
                    color: _kTextPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            iconTheme: const IconThemeData(color: _kTextPrimary),
          ),
          body: historyAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: _kOptimalColor)),
            error: (e, st) => FriendlyError(error: e),
            data: (history) => _DetailBody(history: history),
          ),
        );
      }),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final BiomarkerHistory history;
  const _DetailBody({required this.history});

  @override
  Widget build(BuildContext context) {
    final latestValue =
        history.dataPoints.isNotEmpty ? history.dataPoints.last.value : null;
    final latestTier =
        history.dataPoints.isNotEmpty ? history.dataPoints.last.tier : null;
    final tierColor = _tierColor(latestTier);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero: Name + Latest Value ────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(history.name,
                        style: const TextStyle(
                            color: _kTextPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        '${history.category ?? ''} ${history.healthPillar != null ? "  ${history.healthPillar}" : ""}',
                        style: const TextStyle(
                            color: _kTextSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (latestValue != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatValue(latestValue),
                        style: TextStyle(
                            color: tierColor,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                    const SizedBox(height: 2),
                    Text(history.unit,
                        style: const TextStyle(
                            color: _kTextSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ],
          ),

          if (latestTier != null) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tierColor.withValues(alpha: 0.3)),
              ),
              child: Text(_tierLabel(latestTier),
                  style: TextStyle(
                      color: tierColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ),
          ],

          if (history.description != null) ...[
            const SizedBox(height: 16),
            Text(history.description!,
                style: const TextStyle(
                    color: _kTextSecondary,
                    fontSize: 14,
                    height: 1.5)),
          ],

          // ── Insights ───────────────────────────────────────
          if (history.insights != null) ...[
            const SizedBox(height: 28),
            _SectionTitle('INSIGHTS'),
            const SizedBox(height: 12),
            // Status summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tierColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    latestTier == 'optimal'
                        ? Icons.check_circle_rounded
                        : latestTier == 'critical'
                            ? Icons.warning_rounded
                            : Icons.info_rounded,
                    color: tierColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      history.insights!.statusSummary,
                      style: TextStyle(
                        color: tierColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // What it means
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kCardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('What it means',
                      style: TextStyle(
                          color: _kTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(history.insights!.whatItMeans,
                      style: const TextStyle(
                          color: _kTextSecondary,
                          fontSize: 13,
                          height: 1.5)),
                ],
              ),
            ),
            // Action points
            if (history.insights!.actionPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded,
                            color: _kSuboptimalColor, size: 18),
                        const SizedBox(width: 8),
                        const Text('Action Points',
                            style: TextStyle(
                                color: _kTextPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final point in history.insights!.actionPoints)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _kOptimalColor.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(point,
                                  style: const TextStyle(
                                      color: _kTextSecondary,
                                      fontSize: 13,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 28),

          // ── Range Visualization ──────────────────────────
          if (history.ranges != null) ...[
            _SectionTitle('REFERENCE RANGES'),
            const SizedBox(height: 12),
            _WhoopLargeRangeBar(
              ranges: history.ranges!,
              currentValue: latestValue,
              unit: history.unit,
            ),

            // Evidence grade
            if (history.ranges!.evidenceGrade == 'midrange') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kCardBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16,
                        color: _kTextSecondary.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Optimal range based on midrange of standard clinical reference. '
                        'No specific guideline-endorsed optimal exists.',
                        style: TextStyle(
                            color: _kTextSecondary,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (history.ranges!.source != null) ...[
              const SizedBox(height: 8),
              Text('Source: ${history.ranges!.source}',
                  style: const TextStyle(
                      color: _kOptimalColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ],

          const SizedBox(height: 28),

          // ── History Chart ────────────────────────────────
          if (history.dataPoints.length >= 2) ...[
            _SectionTitle('TREND'),
            const SizedBox(height: 16),
            Container(
              height: 240,
              padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kCardBorder),
              ),
              child: _HistoryChart(
                dataPoints: history.dataPoints,
                ranges: history.ranges,
                unit: history.unit,
              ),
            ),
          ] else if (history.dataPoints.length == 1) ...[
            _SectionTitle('TREND'),
            const SizedBox(height: 8),
            const Text('Upload more reports to see trends over time.',
                style: TextStyle(color: _kTextSecondary, fontSize: 13)),
          ],

          const SizedBox(height: 28),

          // ── All Results ──────────────────────────────────
          if (history.dataPoints.isNotEmpty) ...[
            _SectionTitle('ALL RESULTS'),
            const SizedBox(height: 12),
            for (final dp in history.dataPoints.reversed)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kCardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _tierColor(dp.tier),
                        boxShadow: [
                          BoxShadow(
                              color: _tierColor(dp.tier)
                                  .withValues(alpha: 0.5),
                              blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(dp.date ?? '',
                        style: const TextStyle(
                            color: _kTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    if (dp.labProvider != null) ...[
                      const SizedBox(width: 8),
                      Text(dp.labProvider!,
                          style: const TextStyle(
                              color: _kTextSecondary, fontSize: 11)),
                    ],
                    const Spacer(),
                    Text(_formatValue(dp.value),
                        style: TextStyle(
                            color: _tierColor(dp.tier),
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    Text(history.unit,
                        style: const TextStyle(
                            color: _kTextSecondary, fontSize: 11)),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _formatValue(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    if (value < 10) return value.toStringAsFixed(2);
    if (value < 100) return value.toStringAsFixed(1);
    return value.toInt().toString();
  }
}

// ── Section Title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: _kOptimalColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                color: _kTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      ],
    );
  }
}

// ── Whoop Large Range Bar ────────────────────────────────────────────────────

class _WhoopLargeRangeBar extends StatelessWidget {
  final BiomarkerRange ranges;
  final double? currentValue;
  final String unit;

  const _WhoopLargeRangeBar({
    required this.ranges,
    this.currentValue,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        children: [
          // Gradient range bar with marker
          SizedBox(
            height: 28,
            child: LayoutBuilder(builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              double position = 0.5;

              if (currentValue != null &&
                  ranges.standardLow != null &&
                  ranges.standardHigh != null) {
                final low = ranges.standardLow!;
                final high = ranges.standardHigh!;
                final range = high - low;
                if (range > 0) {
                  final normalized = (currentValue! - low) / range;
                  position = 0.15 + normalized * 0.7;
                  position = position.clamp(0.02, 0.98);
                }
              }

              final markerX = position * barWidth;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Thin gradient bar
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 10,
                    height: 8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CustomPaint(
                        painter: _GradientBarPainter(),
                      ),
                    ),
                  ),
                  // Dot marker with glow
                  if (currentValue != null)
                    Positioned(
                      left: markerX - 7,
                      top: 7,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),

          const SizedBox(height: 16),

          // Range rows
          _RangeRow('Optimal', ranges.optimalLow, ranges.optimalHigh,
              unit, _kOptimalColor),
          _RangeRow('Sufficient', ranges.sufficientLow,
              ranges.sufficientHigh, unit, _kSufficientColor),
          _RangeRow('Standard', ranges.standardLow, ranges.standardHigh,
              unit, _kSuboptimalColor),
        ],
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  final String label;
  final double? low;
  final double? high;
  final String unit;
  final Color color;

  const _RangeRow(this.label, this.low, this.high, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    final range = low != null && high != null
        ? '${_fmt(low!)} - ${_fmt(high!)} $unit'
        : low != null
            ? '> ${_fmt(low!)} $unit'
            : high != null
                ? '< ${_fmt(high!)} $unit'
                : '--';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: _kTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Text(range,
              style: const TextStyle(
                  color: _kTextPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

// ── Gradient Bar Painter ─────────────────────────────────────────────────────

class _GradientBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      colors: [
        _kCriticalColor.withValues(alpha: 0.40),
        _kSuboptimalColor.withValues(alpha: 0.35),
        _kSufficientColor.withValues(alpha: 0.30),
        _kOptimalColor.withValues(alpha: 0.40),
        _kOptimalColor.withValues(alpha: 0.40),
        _kSufficientColor.withValues(alpha: 0.30),
        _kSuboptimalColor.withValues(alpha: 0.35),
        _kCriticalColor.withValues(alpha: 0.40),
      ],
      stops: const [0.0, 0.15, 0.25, 0.4, 0.6, 0.75, 0.85, 1.0],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TriangleMarkerPainter extends CustomPainter {
  final Color color;
  _TriangleMarkerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TriangleMarkerPainter old) =>
      old.color != color;
}

// ── History Chart ────────────────────────────────────────────────────────────

class _HistoryChart extends StatelessWidget {
  final List<BiomarkerDataPoint> dataPoints;
  final BiomarkerRange? ranges;
  final String unit;

  const _HistoryChart({
    required this.dataPoints,
    this.ranges,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i].value));
    }

    final values = dataPoints.map((d) => d.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b) * 0.85;
    final maxY = values.reduce((a, b) => a > b ? a : b) * 1.15;

    final rangeAnnotations = <HorizontalRangeAnnotation>[];
    if (ranges != null) {
      if (ranges!.optimalLow != null && ranges!.optimalHigh != null) {
        rangeAnnotations.add(HorizontalRangeAnnotation(
          y1: ranges!.optimalLow!.clamp(minY, maxY),
          y2: ranges!.optimalHigh!.clamp(minY, maxY),
          color: _kOptimalColor.withValues(alpha: 0.08),
        ));
      }
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: _kCardBorder.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 10, color: _kTextSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= dataPoints.length) return const SizedBox();
                final dp = dataPoints[i];
                final label = dp.date != null && dp.date!.length >= 10
                    ? dp.date!.substring(5, 10)
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 9, color: _kTextSecondary)),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: rangeAnnotations,
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: _kOptimalColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final tier = index < dataPoints.length
                    ? dataPoints[index].tier
                    : null;
                return FlDotCirclePainter(
                  radius: 5,
                  color: _tierColor(tier),
                  strokeWidth: 2,
                  strokeColor: _kDarkBg,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _kOptimalColor.withValues(alpha: 0.15),
                  _kOptimalColor.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _kCardBg,
            tooltipBorder: const BorderSide(color: _kCardBorder),
            tooltipRoundedRadius: 10,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final i = spot.spotIndex;
              final dp = dataPoints[i];
              return LineTooltipItem(
                '${dp.value} $unit\n${dp.date ?? ''}',
                const TextStyle(color: _kTextPrimary, fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
