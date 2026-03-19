import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 5-axis radar/spider chart for trigger profile.
/// Axes: Food, Environment, Products, Stress, Sleep
class TriggerRadarChart extends StatelessWidget {
  /// Values from 0.0 to 1.0 for each axis.
  final double food;
  final double environment;
  final double products;
  final double stress;
  final double sleep;

  const TriggerRadarChart({
    super.key,
    this.food = 0,
    this.environment = 0,
    this.products = 0,
    this.stress = 0,
    this.sleep = 0,
  });

  @override
  Widget build(BuildContext context) {
    final values = [food, environment, products, stress, sleep];
    final labels = ['Food', 'Environment', 'Products', 'Stress', 'Sleep'];
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _RadarPainter(
          values: values,
          labels: labels,
          fillColor: cs.primary.withValues(alpha: 0.15),
          strokeColor: cs.primary,
          gridColor: Colors.grey.shade300,
          labelColor: cs.onSurface,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color fillColor;
  final Color strokeColor;
  final Color gridColor;
  final Color labelColor;

  _RadarPainter({
    required this.values,
    required this.labels,
    required this.fillColor,
    required this.strokeColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 30;
    final n = values.length;

    // Draw concentric grid rings
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final path = Path();
      for (int i = 0; i <= n; i++) {
        final angle = -math.pi / 2 + (2 * math.pi * (i % n) / n);
        final p = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    // Draw axis lines
    for (int i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      final end = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      canvas.drawLine(center, end, gridPaint);
    }

    // Draw data polygon
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final strokePaintPoly = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dataPath = Path();
    for (int i = 0; i <= n; i++) {
      final idx = i % n;
      final angle = -math.pi / 2 + (2 * math.pi * idx / n);
      final v = values[idx].clamp(0.0, 1.0);
      final r = radius * v;
      final p = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(dataPath, fillPaint);
    canvas.drawPath(dataPath, strokePaintPoly);

    // Draw data points
    final dotPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      final v = values[i].clamp(0.0, 1.0);
      final r = radius * v;
      final p = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      canvas.drawCircle(p, 4, dotPaint);
    }

    // Draw labels
    final textStyle = TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.w500);
    for (int i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      final labelRadius = radius + 18;
      final p = Offset(center.dx + labelRadius * math.cos(angle),
          center.dy + labelRadius * math.sin(angle));

      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final offset = Offset(p.dx - tp.width / 2, p.dy - tp.height / 2);
      tp.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values != values || old.strokeColor != strokeColor;
}
