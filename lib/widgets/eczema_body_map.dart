import 'package:flutter/material.dart';
import '../models/easi_models.dart';

// ─── Canvas dimensions ─────────────────────────────────────────────────────
// Matches body_map_clinical.png: 1548 wide × 1134 tall (landscape, front+back).
const double _kSvgW = 1548.0;
const double _kSvgH = 1134.0;
const double _kAspect = _kSvgH / _kSvgW; // ≈ 0.733

// Kept for API compatibility with eczema_screen callers.
// The view parameter is no longer used for display — both front and back
// zones are always shown simultaneously on the full body diagram.
enum EczemaBodyView { front, back }

// ─── Severity colour ramp (0.0 = clear → 1.0 = very severe) ─────────────────
Color severityColor(double t) {
  if (t <= 0.00) return const Color(0xFF9E9E9E);
  if (t <  0.17) return const Color(0xFF43A047);
  if (t <  0.34) return const Color(0xFF8BC34A);
  if (t <  0.50) return const Color(0xFFFDD835);
  if (t <  0.67) return const Color(0xFFFF9800);
  if (t <  0.84) return const Color(0xFFF4511E);
  return const Color(0xFFB71C1C);
}

Color _levelColor(int level) => severityColor(level / 10.0);

// ─── EczemaBodyMap ────────────────────────────────────────────────────────────
// Renders body_map_clinical.png (front + back side-by-side) as the background,
// then draws semi-transparent severity overlays and zone numbers on top.

class EczemaBodyMap extends StatelessWidget {
  // view kept for API compat but no longer controls display.
  final EczemaBodyView view;
  final Map<String, EasiRegionScore> regionScores;
  final Map<String, double>? heatData;
  final String? activeZoneId;
  final void Function(BodyRegion)? onZoneTap;
  final bool readOnly;
  final bool showGroupBoundaries; // reserved for API compat

  const EczemaBodyMap({
    super.key,
    this.view = EczemaBodyView.front,
    this.regionScores = const {},
    this.heatData,
    this.activeZoneId,
    this.onZoneTap,
    this.readOnly = false,
    this.showGroupBoundaries = false,
  });

  // All 50 zones always visible.
  static final _allRegions = [...kFrontRegions, ...kBackRegions];

  void _handleTap(Offset local, Size size) {
    if (readOnly || onZoneTap == null) return;
    // Convert widget-local → SVG canvas coordinates.
    final svgPt = Offset(
      local.dx * _kSvgW / size.width,
      local.dy * _kSvgH / size.height,
    );
    // Iterate in reverse so zones drawn last (topmost) are hit-tested first.
    for (final r in _allRegions.reversed) {
      if (r.contains(svgPt)) {
        onZoneTap!(r);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final h = w * _kAspect;
      return SizedBox(
        width: w,
        height: h,
        child: GestureDetector(
          onTapDown: readOnly
              ? null
              : (d) => _handleTap(d.localPosition, Size(w, h)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1: clinical medical diagram PNG.
              Image.asset(
                'assets/body_map_clinical.png',
                width: w,
                height: h,
                fit: BoxFit.fill,
              ),
              // Layer 2: severity colour overlays + zone number labels.
              CustomPaint(
                size: Size(w, h),
                painter: _ZoneOverlayPainter(
                  regions: _allRegions,
                  regionScores: regionScores,
                  heatData: heatData,
                  activeZoneId: activeZoneId,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ─── Zone Overlay Painter ─────────────────────────────────────────────────────
// Draws only the coloured severity fills and zone numbers.
// The silhouette / anatomy is supplied by the SVG background layer.

class _ZoneOverlayPainter extends CustomPainter {
  final List<BodyRegion> regions;
  final Map<String, EasiRegionScore> regionScores;
  final Map<String, double>? heatData;
  final String? activeZoneId;

  const _ZoneOverlayPainter({
    required this.regions,
    required this.regionScores,
    this.heatData,
    this.activeZoneId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawZoneOverlays(canvas, size);
    _drawZoneNumbers(canvas, size);
  }

  void _drawZoneOverlays(Canvas canvas, Size size) {
    final sw = size.width / _kSvgW;
    final sh = size.height / _kSvgH;

    for (final region in regions) {
      final isActive = region.id == activeZoneId;

      Color? fill;
      if (heatData != null) {
        final t = heatData![region.id];
        if (t != null && t > 0.01) fill = severityColor(t);
      } else {
        final s = regionScores[region.id];
        if (s != null && s.attributeSum > 0) fill = _levelColor(s.level);
      }

      // Severity fill overlay.
      if (fill != null) {
        final fp = Paint()..color = fill.withValues(alpha: 0.62);
        _paintZone(canvas, region, fp, sw, sh);
      }

      // Active zone: outline + halo + light fill when unscored.
      if (isActive) {
        final outlineColor = fill ?? const Color(0xFF1565C0);

        final rp = Paint()
          ..color = outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        _paintZone(canvas, region, rp, sw, sh);

        final halo = Paint()
          ..color = outlineColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;
        _paintZone(canvas, region, halo, sw, sh, inflate: 2.0);

        if (fill == null) {
          final activeFill = Paint()
            ..color = const Color(0xFF1565C0).withValues(alpha: 0.15);
          _paintZone(canvas, region, activeFill, sw, sh);
        }
      }
    }
  }

  void _paintZone(
    Canvas canvas,
    BodyRegion region,
    Paint paint,
    double sw,
    double sh, {
    double inflate = 0,
  }) {
    if (region.isEllipse) {
      final r = region.ellipseRect;
      final scaled = Rect.fromLTWH(
        r.left * sw, r.top * sh, r.width * sw, r.height * sh,
      );
      canvas.drawOval(inflate > 0 ? scaled.inflate(inflate) : scaled, paint);
    } else {
      final poly = region.polyPoints;
      if (poly.isEmpty) return;
      final path = Path();
      path.moveTo(poly[0].dx * sw, poly[0].dy * sh);
      for (int i = 1; i < poly.length; i++) {
        path.lineTo(poly[i].dx * sw, poly[i].dy * sh);
      }
      path.close();
      if (inflate > 0 && paint.style == PaintingStyle.stroke) {
        final inflated = Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = (paint.strokeWidth) + inflate * 2;
        canvas.drawPath(path, inflated);
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawZoneNumbers(Canvas canvas, Size size) {
    final sw = size.width / _kSvgW;
    final sh = size.height / _kSvgH;
    final fontSize = (size.width * 0.013).clamp(5.0, 8.5);

    for (final region in regions) {
      final c = region.centroid;
      final cx = c.dx * sw;
      final cy = c.dy * sh;

      final isActive  = region.id == activeZoneId;
      final hasScore  = (regionScores[region.id]?.attributeSum ?? 0) > 0;
      final hasHeat   = (heatData?[region.id] ?? 0) > 0.01;
      final highlighted = isActive || hasScore || hasHeat;

      final tp = TextPainter(
        text: TextSpan(
          text: '${region.number}',
          style: TextStyle(
            color: highlighted ? Colors.white : const Color(0xFF37474F),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(
                color: Colors.black45,
                blurRadius: 2,
                offset: Offset(0.4, 0.4),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ZoneOverlayPainter old) =>
      old.regions != regions ||
      old.regionScores != regionScores ||
      old.heatData != heatData ||
      old.activeZoneId != activeZoneId;
}

// ─── Severity Legend ──────────────────────────────────────────────────────────

class EczemaSeverityLegend extends StatelessWidget {
  final bool compact;
  const EczemaSeverityLegend({super.key, this.compact = false});

  static const _bands = [
    ('Clear',        0.00),
    ('Almost Clear', 0.10),
    ('Mild',         0.30),
    ('Moderate',     0.55),
    ('Severe',       0.75),
    ('Very Severe',  1.00),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: compact ? 6 : 10,
      runSpacing: 4,
      children: _bands.map((b) {
        final color = severityColor(b.$2);
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: compact ? 9 : 11,
            height: compact ? 9 : 11,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(
            b.$1,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              color: Colors.grey.shade700,
            ),
          ),
        ]);
      }).toList(),
    );
  }
}

// ─── Visit Comparison Widget ──────────────────────────────────────────────────

class EczemaBodyComparison extends StatelessWidget {
  final Map<String, EasiRegionScore> scoresA;
  final Map<String, EasiRegionScore> scoresB;
  final String labelA;
  final String labelB;
  final double easiA;
  final double easiB;
  final String severityA;
  final String severityB;

  const EczemaBodyComparison({
    super.key,
    required this.scoresA,
    required this.scoresB,
    required this.labelA,
    required this.labelB,
    required this.easiA,
    required this.easiB,
    required this.severityA,
    required this.severityB,
    // view param kept for call-site compat but unused.
    EczemaBodyView view = EczemaBodyView.front,
  });

  Color _easiColor(double easi) {
    if (easi == 0)  return const Color(0xFF9E9E9E);
    if (easi <= 1)  return const Color(0xFF43A047);
    if (easi <= 7)  return const Color(0xFFFDD835);
    if (easi <= 21) return const Color(0xFFFF9800);
    if (easi <= 50) return const Color(0xFFF4511E);
    return const Color(0xFFB71C1C);
  }

  @override
  Widget build(BuildContext context) {
    final delta = easiB - easiA;
    final improved = delta < 0;
    final deltaColor =
        improved ? Colors.green : (delta > 0 ? Colors.red : Colors.grey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Side-by-side body maps (both show full front + back diagram).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSide(labelA, easiA, severityA, scoresA, true),
              Container(width: 1, color: Colors.grey.shade300),
              _buildSide(labelB, easiB, severityB, scoresB, false),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Delta summary chip.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: deltaColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: deltaColor.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              improved
                  ? Icons.trending_down
                  : (delta > 0 ? Icons.trending_up : Icons.trending_flat),
              color: deltaColor,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              delta == 0
                  ? 'No change in EASI score'
                  : 'EASI ${improved ? "improved" : "worsened"} by '
                    '${delta.abs().toStringAsFixed(1)} points',
              style: TextStyle(
                color: deltaColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        _buildDeltaTable(),
      ],
    );
  }

  Widget _buildSide(
    String label,
    double easi,
    String severity,
    Map<String, EasiRegionScore> scores,
    bool isA,
  ) {
    final color = _easiColor(easi);
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Text(
              'EASI ${easi.toStringAsFixed(1)} · $severity',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.only(
              left:  isA ? 0 : 4,
              right: isA ? 4 : 0,
            ),
            child: EczemaBodyMap(
              regionScores: scores,
              readOnly: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaTable() {
    final allIds = {...scoresA.keys, ...scoresB.keys};
    final changes = <(String, double, double)>[];

    for (final id in allIds) {
      final a = scoresA[id];
      final b = scoresB[id];
      final ea = a?.easiContribution(groupForRegion(id)) ?? 0;
      final eb = b?.easiContribution(groupForRegion(id)) ?? 0;
      if ((ea - eb).abs() > 0.01) changes.add((id, ea, eb));
    }
    changes.sort((x, y) => (y.$2 - y.$3).abs().compareTo((x.$2 - x.$3).abs()));

    if (changes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Region Changes',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ...changes.take(8).map((c) {
          final region = findRegion(c.$1);
          final lbl = region?.label ?? c.$1;
          final delta = c.$3 - c.$2;
          final improved = delta < 0;
          final color = improved ? Colors.green.shade600 : Colors.red.shade600;
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              Expanded(child: Text(lbl, style: const TextStyle(fontSize: 11))),
              Text(
                '${c.$2.toStringAsFixed(1)} → ${c.$3.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 6),
              Text(
                '${improved ? "↓" : "↑"} ${delta.abs().toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]),
          );
        }),
      ],
    );
  }
}
