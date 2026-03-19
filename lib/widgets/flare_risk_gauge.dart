import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Speedometer-style flare risk gauge (0-100).
class FlareRiskGauge extends StatelessWidget {
  final int score;
  final String? label;

  const FlareRiskGauge({super.key, required this.score, this.label});

  Color get _color {
    if (score >= 60) return const Color(0xFFE53935);
    if (score >= 30) return const Color(0xFFFF9800);
    return const Color(0xFF43A047);
  }

  String get _level {
    if (score >= 60) return 'High Risk';
    if (score >= 30) return 'Moderate';
    return 'Low Risk';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 140,
      child: CustomPaint(
        painter: _GaugePainter(score: score, color: _color),
        child: Padding(
          padding: const EdgeInsets.only(top: 50),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _color)),
              Text(label ?? _level,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width / 2 - 15;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi, // start at left
      math.pi, // sweep 180 degrees
      false,
      bgPaint,
    );

    // Color zones (green, yellow, red)
    final zones = [
      (Colors.green.shade300, 0.0, 0.3),
      (Colors.orange.shade300, 0.3, 0.6),
      (Colors.red.shade300, 0.6, 1.0),
    ];
    for (final (c, start, end) in zones) {
      final zonePaint = Paint()
        ..color = c.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi + (math.pi * start),
        math.pi * (end - start),
        false,
        zonePaint,
      );
    }

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final sweep = (score / 100).clamp(0.0, 1.0) * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      sweep,
      false,
      valuePaint,
    );

    // Needle indicator
    final angle = math.pi + sweep;
    final needleTip = Offset(
      center.dx + (radius + 2) * math.cos(angle),
      center.dy + (radius + 2) * math.sin(angle),
    );
    final needlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(needleTip, 5, needlePaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.score != score;
}
