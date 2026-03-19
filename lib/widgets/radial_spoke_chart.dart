import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A single segment in the radial chart.
class SpokeData {
  final String key;
  final String label;
  final String detail;       // shown in center when selected
  final double value;         // 0.0–1.0 (height of segment)
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

/// Vibrant, high-contrast palette for health pillars.
/// Colors are maximally distinct for readability on both light and dark themes.
class ChartColors {
  static const Color emerald      = Color(0xFF10B981); // green — vitality
  static const Color sapphire     = Color(0xFF3B82F6); // blue — heart/cardio
  static const Color amber        = Color(0xFFF59E0B); // amber — metabolic
  static const Color rose         = Color(0xFFF43F5E); // rose — blood
  static const Color violet       = Color(0xFF8B5CF6); // violet — hormones
  static const Color teal         = Color(0xFF14B8A6); // teal — kidney/liver
  static const Color orange       = Color(0xFFF97316); // orange — immune
  static const Color indigo       = Color(0xFF6366F1); // indigo — thyroid
  static const Color pink         = Color(0xFFEC4899); // pink — nutrition
  static const Color cyan         = Color(0xFF06B6D4); // cyan — minerals
  static const Color lime         = Color(0xFF84CC16); // lime — inflammation
  static const Color fuchsia      = Color(0xFFD946EF); // fuchsia — vitamins

  /// Ordered palette — maximally distinct, vibrant colors.
  static const List<Color> palette = [
    emerald, sapphire, amber, rose, violet, teal,
    orange, indigo, pink, cyan, lime, fuchsia,
  ];

  /// Get color at index, cycling through palette.
  static Color at(int index) => palette[index % palette.length];
}

/// Interactive radial chart — wedge-shaped arc segments radiate from a center
/// circle, like a sunburst/nightingale rose chart.
/// Tap a segment to highlight it and show details in the center.
class RadialSpokeChart extends StatefulWidget {
  final List<SpokeData> spokes;
  final double size;
  final String? centerTitle;    // default center text
  final String? centerSubtitle;
  final Color? centerColor;
  final Color? ringColor;
  final VoidCallback? onCenterTap;
  final void Function(SpokeData spoke)? onSpokeTap;  // navigate on spoke tap

  const RadialSpokeChart({
    super.key,
    required this.spokes,
    this.size = 300,
    this.centerTitle,
    this.centerSubtitle,
    this.centerColor,
    this.ringColor,
    this.onCenterTap,
    this.onSpokeTap,
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
    final centerR = size * 0.22;

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
              // Wedge segments layer
              CustomPaint(
                size: Size(size, size),
                painter: _WedgePainter(
                  spokes: widget.spokes,
                  selectedIndex: _selectedIndex,
                  centerRadius: centerR,
                  animProgress: _animValue.value,
                  isDark: isDark,
                  bgColor: isDark
                      ? cs.surfaceContainerHigh
                      : cs.surfaceContainerLowest,
                ),
              ),
              // Center circle with content
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                width: centerR * 2,
                height: centerR * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedIndex != null
                      ? Color.lerp(
                          isDark ? cs.surfaceContainerHigh : Colors.white,
                          centerAccent ?? cs.primary,
                          0.08,
                        )
                      : isDark
                          ? cs.surfaceContainerHigh
                          : Colors.white,
                  border: _selectedIndex != null
                      ? Border.all(
                          color: (centerAccent ?? cs.primary).withValues(alpha: 0.5),
                          width: 2.5,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: (centerAccent ?? cs.primary).withValues(
                          alpha: _selectedIndex != null ? 0.35 : 0.10),
                      blurRadius: _selectedIndex != null ? 24 : 16,
                      spreadRadius: _selectedIndex != null ? 4 : 2,
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
                      padding: EdgeInsets.all(_selectedIndex != null ? 6 : 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            centerTitle,
                            style: TextStyle(
                              fontSize: _selectedIndex != null
                                  ? centerR * 0.20
                                  : centerR * 0.28,
                              fontWeight: FontWeight.w800,
                              color: centerAccent ?? cs.onSurface,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_selectedIndex != null && widget.spokes[_selectedIndex!].subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.spokes[_selectedIndex!].subtitle!,
                              style: TextStyle(
                                fontSize: centerR * 0.18,
                                color: centerAccent ?? cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (centerSubtitle != null && centerSubtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              centerSubtitle,
                              style: TextStyle(
                                fontSize: _selectedIndex != null
                                    ? centerR * 0.13
                                    : centerR * 0.16,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
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

    final gapAngle = _gapAngleFor(n);
    final segAngle = (2 * math.pi - n * gapAngle) / n;
    const startAngle = -math.pi / 2;

    // Find which segment was tapped
    final adjusted = (angle - startAngle + math.pi * 2) % (math.pi * 2);
    double cumulative = 0;
    for (int i = 0; i < n; i++) {
      cumulative += segAngle;
      if (adjusted < cumulative) {
        setState(() {
          _selectedIndex = _selectedIndex == i ? null : i;
        });
        return;
      }
      cumulative += gapAngle;
    }
  }

  static double _gapAngleFor(int n) {
    if (n <= 4) return 0.06;
    if (n <= 8) return 0.04;
    return 0.025;
  }
}

class _WedgePainter extends CustomPainter {
  final List<SpokeData> spokes;
  final int? selectedIndex;
  final double centerRadius;
  final double animProgress;
  final bool isDark;
  final Color bgColor;

  _WedgePainter({
    required this.spokes,
    required this.selectedIndex,
    required this.centerRadius,
    required this.animProgress,
    required this.isDark,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final n = spokes.length;
    if (n == 0) return;

    final maxRadius = size.width / 2 - 4;
    final innerR = centerRadius + 3;
    final maxLen = maxRadius - innerR;
    final gapAngle = _RadialSpokeChartState._gapAngleFor(n);
    final segAngle = (2 * math.pi - n * gapAngle) / n;
    const startAngle = -math.pi / 2;

    double currentAngle = startAngle;

    for (int i = 0; i < n; i++) {
      final spoke = spokes[i];
      final isSelected = selectedIndex == i;

      // Outer radius based on value: min 25% visible, scales with value
      final rawLen = (0.25 + spoke.value * 0.75) * maxLen;
      final len = rawLen * animProgress;
      final extra = isSelected ? 6.0 : 0.0;
      final outerR = innerR + len + extra;

      // Color
      Color color = spoke.color;
      if (selectedIndex != null && !isSelected) {
        color = spoke.color.withValues(alpha: 0.35);
      }

      // Draw arc wedge
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(
          center.dx + innerR * math.cos(currentAngle),
          center.dy + innerR * math.sin(currentAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: innerR),
          currentAngle,
          segAngle,
          false,
        )
        ..lineTo(
          center.dx + outerR * math.cos(currentAngle + segAngle),
          center.dy + outerR * math.sin(currentAngle + segAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: outerR),
          currentAngle + segAngle,
          -segAngle,
          false,
        )
        ..close();

      // Selection glow (draw behind)
      if (isSelected) {
        final glowPaint = Paint()
          ..color = spoke.color.withValues(alpha: 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawPath(path, glowPaint);
      }

      canvas.drawPath(path, paint);

      currentAngle += segAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _WedgePainter old) =>
      old.selectedIndex != selectedIndex ||
      old.animProgress != animProgress ||
      old.spokes != spokes;
}
