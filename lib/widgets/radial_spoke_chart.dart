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

/// Interactive radial spoke chart — colored bars radiate from a center circle.
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
      duration: const Duration(milliseconds: 800),
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
    final centerR = size * 0.28; // center circle radius

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
                width: centerR * 2 - 4,
                height: centerR * 2 - 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? cs.surfaceContainerHigh
                      : cs.surfaceContainerLowest,
                  border: Border.all(
                    color: widget.ringColor ??
                        cs.outlineVariant.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (centerAccent ?? cs.primary).withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 2,
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
                    child: Column(
                      key: ValueKey('$centerTitle$centerSubtitle'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          centerTitle,
                          style: TextStyle(
                            fontSize: centerR * 0.22,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (centerSubtitle != null && centerSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            centerSubtitle,
                            style: TextStyle(
                              fontSize: centerR * 0.16,
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

    // Ignore taps inside center circle
    if (dist < centerR) return;

    // Find which spoke was tapped based on angle
    final angle = (math.atan2(dy, dx) + math.pi * 2) % (math.pi * 2);
    final n = widget.spokes.length;
    if (n == 0) return;

    final spokeAngle = (2 * math.pi) / n;
    // Spokes start at -pi/2 (top), offset by half spoke for hit area
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

    final maxSpokeLen = (size.width / 2) - centerRadius - 6; // max length
    final spokeAngle = (2 * math.pi) / n;
    final startAngle = -math.pi / 2; // start from top
    final gap = 1.5 * math.pi / 180; // 1.5° gap between spokes
    final spokeWidth = spokeAngle - gap;

    for (int i = 0; i < n; i++) {
      final spoke = spokes[i];
      final isSelected = selectedIndex == i;
      final angle = startAngle + spokeAngle * i;

      // Spoke length based on value (min 20% so empty spokes still visible)
      final rawLen = (0.2 + spoke.value * 0.8) * maxSpokeLen;
      final len = rawLen * animProgress;

      // Color: slightly dim unselected when something is selected
      Color color = spoke.color;
      if (selectedIndex != null && !isSelected) {
        color = color.withValues(alpha: 0.35);
      }

      // Draw spoke as a rounded rectangle (arc segment)
      final innerR = centerRadius + 4;
      final outerR = innerR + len;
      final extra = isSelected ? 6.0 : 0.0; // selected spoke extends further

      final path = Path();
      path.addArc(
        Rect.fromCircle(center: center, radius: innerR),
        angle - spokeWidth / 2,
        spokeWidth,
      );
      path.addArc(
        Rect.fromCircle(center: center, radius: outerR + extra),
        angle + spokeWidth / 2,
        -spokeWidth,
      );
      path.close();

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      // Rounded tip
      final tipR = (outerR + extra) * 1.0;
      final tipAngle = angle;
      final tipCenter = Offset(
        center.dx + tipR * math.cos(tipAngle),
        center.dy + tipR * math.sin(tipAngle),
      );
      final tipRadius = math.min(spokeWidth * innerR * 0.4, 5.0);
      canvas.drawCircle(tipCenter, tipRadius.clamp(1.5, 5.0), paint);

      // Selection glow
      if (isSelected) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawPath(path, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpokePainter old) =>
      old.selectedIndex != selectedIndex ||
      old.animProgress != animProgress ||
      old.spokes != spokes;
}
