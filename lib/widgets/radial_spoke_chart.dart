import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A single spoke in the radial chart.
class SpokeData {
  final String key;
  final String label;
  final String detail;       // shown in center when selected
  final double value;         // 0.0–1.0 (height of spoke)
  final Color color;
  final String? subtitle;     // optional secondary text

  const SpokeData({
    required this.key,
    required this.label,
    required this.detail,
    required this.value,
    required this.color,
    this.subtitle,
  });
}

/// Interactive radial spoke chart — rounded bars radiate from a center circle.
/// Tap a spoke to highlight it and show details in the center.
class RadialSpokeChart extends StatefulWidget {
  final List<SpokeData> spokes;
  final double size;
  final String? centerTitle;    // default center text
  final String? centerSubtitle;
  final Color? centerColor;
  final Color? ringColor;
  final VoidCallback? onCenterTap;

  const RadialSpokeChart({
    super.key,
    required this.spokes,
    this.size = 300,
    this.centerTitle,
    this.centerSubtitle,
    this.centerColor,
    this.ringColor,
    this.onCenterTap,
  });

  @override
  State<RadialSpokeChart> createState() => _RadialSpokeChartState();
}

class _RadialSpokeChartState extends State<RadialSpokeChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late final AnimationController _animCtrl;
  late Animation<double> _animValue;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animValue = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = widget.size;
    final centerR = size * 0.24;

    // Determine center content
    String centerTitle;
    String? centerSubtitle;
    Color? centerAccent;

    if (_selectedIndex != null && _selectedIndex! < widget.spokes.length) {
      final spoke = widget.spokes[_selectedIndex!];
      centerTitle = spoke.label;
      centerSubtitle = spoke.detail;
      centerAccent = spoke.color;
    } else {
      centerTitle = widget.centerTitle ?? '';
      centerSubtitle = widget.centerSubtitle;
      centerAccent = widget.centerColor;
    }

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _animValue,
        builder: (context, child) => GestureDetector(
          onTapDown: (details) => _handleTap(details, size, centerR),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Spokes layer
              CustomPaint(
                size: Size(size, size),
                painter: _SpokePainter(
                  spokes: widget.spokes,
                  selectedIndex: _selectedIndex,
                  centerRadius: centerR,
                  animProgress: _animValue.value,
                  isDark: isDark,
                ),
              ),
              // Center circle with content
              Container(
                width: centerR * 2 - 2,
                height: centerR * 2 - 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? cs.surfaceContainerHigh
                      : cs.surfaceContainerLowest,
                  border: Border.all(
                    color: widget.ringColor ??
                        cs.outlineVariant.withValues(alpha: 0.5),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (centerAccent ?? cs.primary).withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: () {
                    if (_selectedIndex != null) {
                      setState(() => _selectedIndex = null);
                    } else {
                      widget.onCenterTap?.call();
                    }
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Padding(
                      key: ValueKey('$centerTitle$centerSubtitle'),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            centerTitle,
                            style: TextStyle(
                              fontSize: centerR * 0.24,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (centerSubtitle != null && centerSubtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              centerSubtitle,
                              style: TextStyle(
                                fontSize: centerR * 0.15,
                                color: centerAccent ?? cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(TapDownDetails details, double size, double centerR) {
    final center = Offset(size / 2, size / 2);
    final tap = details.localPosition;
    final dx = tap.dx - center.dx;
    final dy = tap.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < centerR) return;

    final angle = (math.atan2(dy, dx) + math.pi * 2) % (math.pi * 2);
    final n = widget.spokes.length;
    if (n == 0) return;

    final spokeAngle = (2 * math.pi) / n;
    final startAngle = -math.pi / 2;
    final adjusted = (angle - startAngle + spokeAngle / 2 + math.pi * 2) % (math.pi * 2);
    final index = (adjusted / spokeAngle).floor() % n;

    setState(() {
      _selectedIndex = (_selectedIndex == index) ? null : index;
    });
  }
}

class _SpokePainter extends CustomPainter {
  final List<SpokeData> spokes;
  final int? selectedIndex;
  final double centerRadius;
  final double animProgress;
  final bool isDark;

  _SpokePainter({
    required this.spokes,
    required this.selectedIndex,
    required this.centerRadius,
    required this.animProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final n = spokes.length;
    if (n == 0) return;

    final maxLen = (size.width / 2) - centerRadius - 8;
    final spokeAngle = (2 * math.pi) / n;
    final startAngle = -math.pi / 2;

    // Bar width: thicker for fewer spokes, thinner for many
    final barWidth = math.min(14.0, (spokeAngle * centerRadius * 0.7)).clamp(6.0, 16.0);
    final barRadius = Radius.circular(barWidth / 2); // rounded ends

    for (int i = 0; i < n; i++) {
      final spoke = spokes[i];
      final isSelected = selectedIndex == i;
      final angle = startAngle + spokeAngle * i;

      // Spoke length: min 15% visible, scales with value
      final rawLen = (0.15 + spoke.value * 0.85) * maxLen;
      final len = rawLen * animProgress;
      final extra = isSelected ? 8.0 : 0.0;

      // Color
      Color color = spoke.color;
      if (selectedIndex != null && !isSelected) {
        color = Color.fromRGBO(
          color.r ~/ 1 * 255 ~/ 255,
          color.g ~/ 1 * 255 ~/ 255,
          color.b ~/ 1 * 255 ~/ 255,
          0.3,
        );
        color = spoke.color.withValues(alpha: 0.3);
      }

      final innerR = centerRadius + 5;
      final outerR = innerR + len + extra;

      // Save canvas, rotate to spoke angle, draw rounded rect
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      // The bar goes from (innerR, -barWidth/2) to (outerR, barWidth/2)
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(innerR, -barWidth / 2, outerR - innerR, barWidth),
        barRadius,
      );

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rect, paint);

      // Selection glow
      if (isSelected) {
        final glowPaint = Paint()
          ..color = spoke.color.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawRRect(rect.inflate(3), glowPaint);
        // Re-draw on top of glow for crisp bar
        canvas.drawRRect(rect, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SpokePainter old) =>
      old.selectedIndex != selectedIndex ||
      old.animProgress != animProgress ||
      old.spokes != spokes;
}
