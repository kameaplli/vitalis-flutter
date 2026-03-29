import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/easi_models.dart';
import 'package:hugeicons/hugeicons.dart';

// ─── Canvas dimensions ─────────────────────────────────────────────────────
// Matches body_map_clinical.png: 1548 wide × 1134 tall (front+back).
const double _kSvgW = 1548.0;
const double _kSvgH = 1134.0;
const double _kAspect = _kSvgH / _kSvgW; // ≈ 0.733

// Kept for API compatibility with eczema_screen callers.
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

// Severity colours used for drawn patch strokes.
const _patchColors = [
  Color(0xFF9E9E9E), // 0 — shouldn't be drawn
  Color(0xFFFF9800), // 1 — mild
  Color(0xFFEF6C00), // 2 — moderate
  Color(0xFFB71C1C), // 3 — severe
];

// ─── EczemaBodyMap ────────────────────────────────────────────────────────────

class EczemaBodyMap extends StatefulWidget {
  final EczemaBodyView view;
  final Map<String, EasiRegionScore> regionScores;
  final Map<String, double>? heatData;
  final String? activeZoneId;
  final void Function(BodyRegion)? onZoneTap;
  final bool readOnly;
  final bool showGroupBoundaries;
  final bool drawMode;
  final int drawSeverity;
  final List<DrawnPatch> drawnPatches;
  final void Function(DrawnPatch, BodyRegion?)? onPatchDrawn;

  const EczemaBodyMap({
    super.key,
    this.view = EczemaBodyView.front,
    this.regionScores = const {},
    this.heatData,
    this.activeZoneId,
    this.onZoneTap,
    this.readOnly = false,
    this.showGroupBoundaries = false,
    this.drawMode = false,
    this.drawSeverity = 1,
    this.drawnPatches = const [],
    this.onPatchDrawn,
  });

  static final _allRegions = [...kFrontRegions, ...kBackRegions];

  @override
  State<EczemaBodyMap> createState() => _EczemaBodyMapState();
}

class _EczemaBodyMapState extends State<EczemaBodyMap>
    with TickerProviderStateMixin {
  final _txController = TransformationController();

  // Drawing state (kept in codebase but hidden from UI)
  int _activePointers = 0;
  List<Offset> _stroke = [];
  Size _sz = Size.zero;

  // Zone selection animation
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Heatmap radiating animation
  late final AnimationController _heatCtrl;
  late final Animation<double> _heatAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseCtrl.addListener(() => setState(() {}));

    _heatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _heatAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heatCtrl, curve: Curves.easeOut),
    );
    _heatCtrl.addListener(() => setState(() {}));

    if (widget.heatData != null && widget.heatData!.isNotEmpty) {
      _heatCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(EczemaBodyMap old) {
    super.didUpdateWidget(old);
    if (widget.activeZoneId != null && widget.activeZoneId != old.activeZoneId) {
      _pulseCtrl.forward(from: 0.0);
    }
    // Start/stop heat animation based on heatData
    final hasHeat = widget.heatData != null && widget.heatData!.isNotEmpty;
    final hadHeat = old.heatData != null && old.heatData!.isNotEmpty;
    if (hasHeat && !hadHeat) {
      _heatCtrl.repeat();
    } else if (!hasHeat && hadHeat) {
      _heatCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _heatCtrl.dispose();
    _txController.dispose();
    super.dispose();
  }

  // Viewport-local point → 1548×1134 image pixels.
  Offset _viewportToImage(Offset viewportLocal) {
    if (_sz.isEmpty) return Offset.zero;
    final scene = _txController.toScene(viewportLocal);
    return Offset(scene.dx * _kSvgW / _sz.width,
                  scene.dy * _kSvgH / _sz.height);
  }

  // ── Zone tap ──────────────────────────────────────────────────────────────
  void _onTapUp(TapUpDetails d) {
    if (widget.readOnly || widget.onZoneTap == null) return;
    final imgPt = _viewportToImage(d.localPosition);
    for (final r in EczemaBodyMap._allRegions.reversed) {
      if (r.contains(imgPt)) { widget.onZoneTap!(r); return; }
    }
  }

  // ── Pointer tracking (multi-touch cancel for drawing) ─────────────────
  void _onPointerDown(PointerDownEvent e) {
    _activePointers++;
    if (_activePointers > 1 && _stroke.isNotEmpty) {
      setState(() => _stroke = []);
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _activePointers = (_activePointers - 1).clamp(0, 10);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _activePointers = (_activePointers - 1).clamp(0, 10);
    if (_stroke.isNotEmpty) setState(() => _stroke = []);
  }

  // ── Freehand draw (kept in codebase, hidden from UI) ──────────────────
  void _onPanStart(DragStartDetails d) {
    if (!widget.drawMode || _activePointers > 1) return;
    setState(() => _stroke = [_viewportToImage(d.localPosition)]);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!widget.drawMode || _stroke.isEmpty || _activePointers > 1) return;
    final pt = _viewportToImage(d.localPosition);
    if ((_stroke.last - pt).distance > 4) {
      setState(() => _stroke.add(pt));
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (!widget.drawMode) return;
    if (_stroke.length > 4) {
      _finalizeStroke();
    } else {
      setState(() => _stroke = []);
    }
  }

  void _finalizeStroke() {
    final pts = List<Offset>.from(_stroke);
    setState(() => _stroke = []);
    final cx = pts.map((p) => p.dx).reduce((a, b) => a + b) / pts.length;
    final cy = pts.map((p) => p.dy).reduce((a, b) => a + b) / pts.length;
    BodyRegion? zone;
    for (final r in EczemaBodyMap._allRegions.reversed) {
      if (r.contains(Offset(cx, cy))) { zone = r; break; }
    }
    widget.onPatchDrawn?.call(
      DrawnPatch(zoneId: zone?.id ?? '', severity: widget.drawSeverity, points: pts),
      zone,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final availW = constraints.maxWidth;
      final availH = constraints.maxHeight.isFinite
          ? constraints.maxHeight
          : availW * _kAspect;
      double w, h;
      if (availW * _kAspect <= availH) {
        w = availW;
        h = availW * _kAspect;
      } else {
        h = availH;
        w = availH / _kAspect;
      }
      _sz = Size(w, h);

      final content = SizedBox(
        width: w,
        height: h,
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(w, h),
            painter: _ZoneOverlayPainter(
              regions:       EczemaBodyMap._allRegions,
              regionScores:  widget.regionScores,
              heatData:      widget.heatData,
              activeZoneId:  widget.activeZoneId,
              drawnPatches:  widget.drawnPatches,
              currentStroke: _stroke,
              drawSeverity:  widget.drawSeverity,
              pulseT:        _pulseAnim.value,
              heatT:         _heatAnim.value,
            ),
          ),
        ),
      );

      // GestureDetector is OUTSIDE InteractiveViewer.
      // - In view mode: onTapUp for zone selection; InteractiveViewer handles pan/zoom.
      // - In draw mode: onPan* for freehand; InteractiveViewer is fully passive.
      return Center(
        child: ClipRect(
          child: SizedBox(
            width: w,
            height: h,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown:   _onPointerDown,
              onPointerUp:     _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp:     (!widget.drawMode && !widget.readOnly) ? _onTapUp : null,
                onPanStart:  widget.drawMode ? _onPanStart  : null,
                onPanUpdate: widget.drawMode ? _onPanUpdate : null,
                onPanEnd:    widget.drawMode ? _onPanEnd    : null,
                child: InteractiveViewer(
                  transformationController: _txController,
                  minScale: 1.0,
                  maxScale: 5.0,
                  panEnabled: !widget.drawMode,
                  scaleEnabled: !widget.drawMode,
                  // No boundaryMargin — at 1x zoom the map is locked in place.
                  // Panning only works when zoomed in.
                  clipBehavior: Clip.hardEdge,
                  interactionEndFrictionCoefficient: 0.0001,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

// ─── Zone Overlay Painter ─────────────────────────────────────────────────────

class _ZoneOverlayPainter extends CustomPainter {
  final List<BodyRegion> regions;
  final Map<String, EasiRegionScore> regionScores;
  final Map<String, double>? heatData;
  final String? activeZoneId;
  final List<DrawnPatch> drawnPatches;
  final List<Offset> currentStroke;
  final int drawSeverity;
  final double pulseT;
  final double heatT; // 0..1 repeating animation for heatmap glow

  const _ZoneOverlayPainter({
    required this.regions,
    required this.regionScores,
    this.heatData,
    this.activeZoneId,
    this.drawnPatches = const [],
    this.currentStroke = const [],
    this.drawSeverity = 1,
    this.pulseT = 0.0,
    this.heatT = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawZoneOverlays(canvas, size);
    _drawPatches(canvas, size);
    _drawCurrentStroke(canvas, size);
    _drawZoneNumbers(canvas, size);
  }

  void _drawZoneOverlays(Canvas canvas, Size size) {
    final sw = size.width / _kSvgW;
    final sh = size.height / _kSvgH;

    for (final region in regions) {
      final isActive = region.id == activeZoneId;

      Color? fill;
      double heatIntensity = 0;
      if (heatData != null) {
        final t = heatData![region.id];
        if (t != null && t > 0.01) {
          fill = severityColor(t);
          heatIntensity = t;
        }
      } else {
        final s = regionScores[region.id];
        if (s != null && s.attributeSum > 0) fill = _levelColor(s.level);
      }

      if (fill != null) {
        // Smooth polygon fill following the actual zone shape
        _paintZone(canvas, region,
            Paint()..color = fill.withValues(alpha: 0.30), sw, sh);
        // Bold outline tracing the zone polygon
        _paintZone(canvas, region,
            Paint()..color = fill.withValues(alpha: 0.85)
                   ..style = PaintingStyle.stroke
                   ..strokeWidth = 2.0
                   ..strokeJoin = StrokeJoin.round, sw, sh);

        // Heatmap radiating glow effect
        if (heatData != null && heatIntensity > 0.01) {
          _drawRadiatingGlow(canvas, region, fill, heatIntensity, sw, sh);
        }
      } else {
        // No data — draw a white outline so zone shape is visible on dark bg
        _paintZone(canvas, region,
            Paint()..color = const Color(0x50FFFFFF)
                   ..style = PaintingStyle.stroke
                   ..strokeWidth = 1.0
                   ..strokeJoin = StrokeJoin.round, sw, sh);
      }

      if (isActive) {
        final outlineColor = fill ?? const Color(0xFF1565C0);
        // Animated pulse: outer glow expands and fades
        final glowAlpha = 0.40 * (1.0 - pulseT * 0.6);
        final glowWidth = 4.0 + pulseT * 4.0;
        _paintZone(canvas, region,
            Paint()..color = outlineColor.withValues(alpha: glowAlpha)
                   ..style = PaintingStyle.stroke
                   ..strokeWidth = glowWidth
                   ..strokeJoin = StrokeJoin.round, sw, sh, inflate: 2.0);
        // Solid inner outline
        _paintZone(canvas, region,
            Paint()..color = outlineColor
                   ..style = PaintingStyle.stroke
                   ..strokeWidth = 2.5
                   ..strokeJoin = StrokeJoin.round, sw, sh);
        // Subtle fill
        _paintZone(canvas, region,
            Paint()..color = outlineColor.withValues(alpha: 0.18), sw, sh);
      }
    }
  }

  /// Draw expanding concentric rings around the zone centroid.
  /// Color and ring count depend on severity (heatIntensity 0..1).
  void _drawRadiatingGlow(Canvas canvas, BodyRegion region,
      Color baseColor, double intensity, double sw, double sh) {
    final c = region.centroid;
    final cx = c.dx * sw;
    final cy = c.dy * sh;

    // Zone size determines max radius
    final rect = region.svgRect;
    final zoneRadius = math.max(rect.width * sw, rect.height * sh) * 0.5;
    final maxRadius = zoneRadius * (0.6 + intensity * 0.8);

    // Number of rings: 2 for mild, 3 for moderate/severe
    final ringCount = intensity < 0.5 ? 2 : 3;

    for (int i = 0; i < ringCount; i++) {
      // Stagger each ring at a different phase
      final phase = (heatT + i * (1.0 / ringCount)) % 1.0;
      final radius = maxRadius * (0.3 + phase * 0.7);
      final alpha = (1.0 - phase) * 0.25 * intensity;

      if (alpha > 0.01) {
        canvas.drawCircle(
          Offset(cx, cy),
          radius,
          Paint()
            ..color = baseColor.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 + (1.0 - phase) * 2.0,
        );
      }
    }

    // Static glow at center
    canvas.drawCircle(
      Offset(cx, cy),
      zoneRadius * 0.25,
      Paint()
        ..color = baseColor.withValues(alpha: 0.15 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _drawPatches(Canvas canvas, Size size) {
    final sw = size.width / _kSvgW;
    final sh = size.height / _kSvgH;

    for (final patch in drawnPatches) {
      if (patch.points.length < 2) continue;
      final color = _patchColors[patch.severity.clamp(0, 3)];
      final paint = Paint()
        ..color = color.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 5.0;
      final path = Path();
      path.moveTo(patch.points[0].dx * sw, patch.points[0].dy * sh);
      for (int i = 1; i < patch.points.length; i++) {
        path.lineTo(patch.points[i].dx * sw, patch.points[i].dy * sh);
      }
      canvas.drawPath(path, paint);
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
    }
  }

  void _drawCurrentStroke(Canvas canvas, Size size) {
    if (currentStroke.length < 2) return;
    final sw = size.width / _kSvgW;
    final sh = size.height / _kSvgH;
    final color = _patchColors[drawSeverity.clamp(0, 3)];
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5.0;
    final path = Path();
    path.moveTo(currentStroke[0].dx * sw, currentStroke[0].dy * sh);
    for (int i = 1; i < currentStroke.length; i++) {
      path.lineTo(currentStroke[i].dx * sw, currentStroke[i].dy * sh);
    }
    canvas.drawPath(path, paint);
  }

  void _paintZone(
    Canvas canvas, BodyRegion region, Paint paint, double sw, double sh, {
    double inflate = 0,
  }) {
    if (region.isEllipse) {
      final r = region.ellipseRect;
      final scaled = Rect.fromLTWH(r.left * sw, r.top * sh, r.width * sw, r.height * sh);
      canvas.drawOval(inflate > 0 ? scaled.inflate(inflate) : scaled, paint);
    } else {
      final poly = region.polyPoints;
      if (poly.length < 3) return;

      final path = Path();
      path.moveTo(poly[0].dx * sw, poly[0].dy * sh);
      for (int i = 1; i < poly.length; i++) {
        path.lineTo(poly[i].dx * sw, poly[i].dy * sh);
      }
      path.close();

      if (inflate > 0 && paint.style == PaintingStyle.stroke) {
        canvas.drawPath(path, Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = paint.strokeWidth + inflate * 2
          ..strokeJoin = StrokeJoin.round);
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawZoneNumbers(Canvas canvas, Size size) {
    final sw       = size.width / _kSvgW;
    final sh       = size.height / _kSvgH;
    final fontSize = (size.width * 0.013).clamp(5.0, 8.5);

    for (final region in regions) {
      final c  = region.centroid;
      final cx = c.dx * sw;
      final cy = c.dy * sh;

      final isActive    = region.id == activeZoneId;
      final hasScore    = (regionScores[region.id]?.attributeSum ?? 0) > 0;
      final hasHeat     = (heatData?[region.id] ?? 0) > 0.01;
      final hasPatch    = drawnPatches.any((p) => p.zoneId == region.id);
      final highlighted = isActive || hasScore || hasHeat || hasPatch;

      final tp = TextPainter(
        text: TextSpan(
          text: '${region.number}',
          style: TextStyle(
            color: highlighted ? Colors.white : const Color(0xAAFFFFFF),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0.5, 0.5))],
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
      old.activeZoneId != activeZoneId ||
      old.drawnPatches != drawnPatches ||
      old.currentStroke != currentStroke ||
      old.drawSeverity != drawSeverity ||
      old.pulseT != pulseT ||
      old.heatT != heatT;
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
            width: compact ? 9 : 11, height: compact ? 9 : 11,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(b.$1, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
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
    final deltaColor = improved ? Colors.green : (delta > 0 ? Colors.red : Colors.grey);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── EASI delta banner ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: deltaColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: deltaColor.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            HugeIcon(icon:
              improved ? HugeIcons.strokeRoundedChartDecrease : (delta > 0 ? HugeIcons.strokeRoundedChartIncrease : HugeIcons.strokeRoundedMinusSign),
              color: deltaColor, size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              delta == 0
                  ? 'No change in EASI score'
                  : 'EASI ${improved ? "improved" : "worsened"} by ${delta.abs().toStringAsFixed(1)} points',
              style: TextStyle(color: deltaColor, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ]),
        ),
        const SizedBox(height: 8),

        // ── Compact EASI summary row ──
        Row(children: [
          _easiBadge('Visit A', easiA, severityA, labelA),
          const SizedBox(width: 8),
          HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          _easiBadge('Visit B', easiB, severityB, labelB),
        ]),
        const SizedBox(height: 12),

        // ── Body maps: stacked vertically, each uses full width ──
        _bodyMapCard('Visit A', labelA, easiA, scoresA, cs),
        const SizedBox(height: 10),
        _bodyMapCard('Visit B', labelB, easiB, scoresB, cs),
        const SizedBox(height: 12),

        // ── Region changes ──
        _buildDeltaTable(cs),
      ],
    );
  }

  Widget _easiBadge(String title, double easi, String severity, String label) {
    final color = _easiColor(easi);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text('EASI ${easi.toStringAsFixed(1)} · $severity',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
          Text(label.replaceAll('\n', ' '),
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _bodyMapCard(String title, String label, double easi,
      Map<String, EasiRegionScore> scores, ColorScheme cs) {
    final color = _easiColor(easi);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
          ),
          child: Row(children: [
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: cs.onSurface)),
            const Spacer(),
            Text('EASI ${easi.toStringAsFixed(1)}',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: EczemaBodyMap(regionScores: scores, readOnly: true),
        ),
      ]),
    );
  }

  Widget _buildDeltaTable(ColorScheme cs) {
    final allIds  = {...scoresA.keys, ...scoresB.keys};
    final changes = <(String, double, double)>[];

    for (final id in allIds) {
      final a  = scoresA[id];
      final b  = scoresB[id];
      final ea = a?.easiContribution(groupForRegion(id)) ?? 0;
      final eb = b?.easiContribution(groupForRegion(id)) ?? 0;
      if ((ea - eb).abs() > 0.01) changes.add((id, ea, eb));
    }
    changes.sort((x, y) => (y.$2 - y.$3).abs().compareTo((x.$2 - x.$3).abs()));
    if (changes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Region Changes',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ...changes.take(8).map((c) {
          final region  = findRegion(c.$1);
          final lbl     = region?.label ?? c.$1;
          final delta   = c.$3 - c.$2;
          final improved = delta < 0;
          final color   = improved ? Colors.green.shade600 : Colors.red.shade600;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(lbl, style: const TextStyle(fontSize: 11))),
              Text('${c.$2.toStringAsFixed(1)} → ${c.$3.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              const SizedBox(width: 6),
              Text('${improved ? "↓" : "↑"} ${delta.abs().toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            ]),
          );
        }),
      ],
    );
  }
}
