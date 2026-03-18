import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Shared chart styling — thin coral line, glowing latest dot, dashed reference.
/// Matches the app's signature graph look.
class ChartStyle {
  // Data line
  static const Color dataLineColor = Color(0xFFEF9A9A); // soft coral/salmon
  static const double dataLineWidth = 1.8;

  // Dots
  static const Color historicalDotColor = Color(0xFFEF9A9A);
  static const double historicalDotRadius = 3.5;
  static const Color latestDotColor = Color(0xFF66BB6A);  // green
  static const double latestDotRadius = 6.0;
  static const double latestGlowRadius = 14.0;

  // Reference / average line
  static const Color refLineColor = Color(0xFF9E9E9E);
  static const List<int> refDashArray = [6, 4];
  static const double refLineWidth = 1.0;

  // Projection / potential line
  static const Color projLineColor = Color(0xFF90CAF9); // light blue
  static const List<int> projDashArray = [4, 4];
  static const double projLineWidth = 1.2;

  /// Dot painter that shows small coral dots for historical points and
  /// a larger green glowing dot for the latest data point.
  static FlDotPainter dotPainter(
    FlSpot spot,
    double percent,
    LineChartBarData barData,
    int index, {
    Color? overrideColor,
  }) {
    final isLast = index == barData.spots.length - 1;
    if (isLast) {
      return _GlowDotPainter(
        radius: latestDotRadius,
        color: overrideColor ?? latestDotColor,
        glowRadius: latestGlowRadius,
      );
    }
    return FlDotCirclePainter(
      radius: historicalDotRadius,
      color: overrideColor ?? historicalDotColor,
      strokeWidth: 1.5,
      strokeColor: Colors.white,
    );
  }

  /// Standard data line config (solid, thin, coral).
  static LineChartBarData dataLine(
    List<FlSpot> spots, {
    Color? color,
    bool showDots = true,
    FlDotPainter Function(FlSpot, double, LineChartBarData, int)? dotPainterFn,
  }) {
    final c = color ?? dataLineColor;
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      color: c,
      barWidth: dataLineWidth,
      dotData: FlDotData(
        show: showDots && spots.length <= 30,
        getDotPainter: dotPainterFn ?? dotPainter,
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  /// Dashed reference / average line (gray).
  static LineChartBarData referenceLine(
    List<FlSpot> spots, {
    Color? color,
    String? label,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color ?? refLineColor,
      barWidth: refLineWidth,
      dashArray: refDashArray,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  /// Dashed projection / potential line (blue).
  static LineChartBarData projectionLine(List<FlSpot> spots, {Color? color}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color ?? projLineColor,
      barWidth: projLineWidth,
      dashArray: projDashArray,
      dotData: FlDotData(
        show: true,
        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
          radius: 4,
          color: color ?? projLineColor,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  /// Minimal grid — only faint horizontal lines, no vertical.
  static FlGridData get grid => FlGridData(
    show: true,
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) => FlLine(
      color: Colors.grey.withValues(alpha: 0.15),
      strokeWidth: 0.5,
      dashArray: [4, 4],
    ),
  );

  /// Clean border — no borders.
  static FlBorderData get border => FlBorderData(show: false);
}

/// Custom dot painter that draws a glowing circle for the latest data point.
class _GlowDotPainter extends FlDotPainter {
  final double radius;
  final Color color;
  final double glowRadius;

  _GlowDotPainter({
    required this.radius,
    required this.color,
    required this.glowRadius,
  });

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(offsetInCanvas, glowRadius, glowPaint);

    // Mid glow
    final midPaint = Paint()
      ..color = color.withValues(alpha: 0.35);
    canvas.drawCircle(offsetInCanvas, radius + 2, midPaint);

    // Core dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offsetInCanvas, radius, dotPaint);

    // White center highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(
      offsetInCanvas + const Offset(-1.5, -1.5),
      radius * 0.3,
      highlightPaint,
    );
  }

  @override
  Size getSize(FlSpot spot) => Size(glowRadius * 2, glowRadius * 2);

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (a is _GlowDotPainter && b is _GlowDotPainter) {
      return _GlowDotPainter(
        radius: a.radius + (b.radius - a.radius) * t,
        color: Color.lerp(a.color, b.color, t) ?? b.color,
        glowRadius: a.glowRadius + (b.glowRadius - a.glowRadius) * t,
      );
    }
    return b;
  }

  @override
  List<Object?> get props => [radius, color, glowRadius];
}
