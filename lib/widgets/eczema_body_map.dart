import 'package:flutter/material.dart';
import '../models/easi_models.dart';

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
    with SingleTickerProviderStateMixin {
  final _txController = TransformationController();

  // Drawing state
  int _activePointers = 0;
  List<Offset> _stroke = [];
  Size _sz = Size.zero;

  // Zone selection animation
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

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
  }

  @override
  void didUpdateWidget(EczemaBodyMap old) {
    super.didUpdateWidget(old);
    if (widget.activeZoneId != null && widget.activeZoneId != old.activeZoneId) {
      _pulseCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _txController.dispose();
    super.dispose();
  }

  // Content-local → 1548×1134 image pixels.
  Offset _toImage(Offset local) {
    if (_sz.isEmpty) return Offset.zero;
    return Offset(local.dx * _kSvgW / _sz.width,
                  local.dy * _kSvgH / _sz.height);
  }

  // ── Zone tap ──────────────────────────────────────────────────────────────
  void _onTapUp(TapUpDetails d) {
    if (widget.readOnly || widget.onZoneTap == null) return;
    final imgPt = _toImage(d.localPosition);
    for (final r in EczemaBodyMap._allRegions.reversed) {
      if (r.contains(imgPt)) { widget.onZoneTap!(r); return; }
    }
  }

  // ── Pointer tracking (Listener — multi-touch cancel only) ─────────────
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

  // ── Freehand draw via GestureDetector.onPan ───────────────────────────
  void _onPanStart(DragStartDetails d) {
    if (!widget.drawMode || _activePointers > 1) return;
    setState(() => _stroke = [_toImage(d.localPosition)]);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!widget.drawMode || _stroke.isEmpty || _activePointers > 1) return;
    final pt = _toImage(d.localPosition);
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
      final w = constraints.maxWidth;
      final h = w * _kAspect;
      _sz = Size(w, h);

      final content = SizedBox(
        width: w,
        height: h,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown:   _onPointerDown,
          onPointerUp:     _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: GestureDetector(
            onTapUp:    (!widget.drawMode && !widget.readOnly) ? _onTapUp : null,
            onPanStart: widget.drawMode ? _onPanStart : null,
            onPanUpdate: widget.drawMode ? _onPanUpdate : null,
            onPanEnd:   widget.drawMode ? _onPanEnd   : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/body_map_clinical.png',
                    width: w, height: h, fit: BoxFit.fill),
                RepaintBoundary(
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
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // ClipRect prevents the InteractiveViewer from rendering content
      // outside its bounds when zoomed, avoiding the "canvas slides left/right"
      // visual issue.
      return ClipRect(
        child: SizedBox(
          width: w,
          height: h,
          child: InteractiveViewer(
            transformationController: _txController,
            minScale: 1.0,
            maxScale: 5.0,
            panEnabled: !widget.drawMode,
            scaleEnabled: true,
            // Boundary margin allows slight overscroll for a "springy" feel
            // but keeps the image mostly locked in frame.
            boundaryMargin: const EdgeInsets.all(20),
            clipBehavior: Clip.hardEdge,
            interactionEndFrictionCoefficient: 0.0001, // smooth deceleration
            child: content,
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
  final double pulseT; // 0..1 animation progress for active zone

  const _ZoneOverlayPainter({
    required this.regions,
    required this.regionScores,
    this.heatData,
    this.activeZoneId,
    this.drawnPatches = const [],
    this.currentStroke = const [],
    this.drawSeverity = 1,
    this.pulseT = 0.0,
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
      if (heatData != null) {
        final t = heatData![region.id];
        if (t != null && t > 0.01) fill = severityColor(t);
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

  // Paint a zone shape (polygon or ellipse) with smooth joins.
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

      // Build a smooth path using the polygon vertices.
      // For filled/stroked shapes with many points, this traces the actual
      // body contour rather than a bounding rectangle.
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
            color: highlighted ? Colors.white : const Color(0xFF37474F),
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0.4, 0.4))],
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
      old.pulseT != pulseT;
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
          Text(b.$1, style: TextStyle(fontSize: compact ? 9 : 10, color: Colors.grey.shade700)),
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
    final delta   = easiB - easiA;
    final improved = delta < 0;
    final deltaColor = improved ? Colors.green : (delta > 0 ? Colors.red : Colors.grey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: deltaColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: deltaColor.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              improved ? Icons.trending_down : (delta > 0 ? Icons.trending_up : Icons.trending_flat),
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
        const SizedBox(height: 10),
        _buildDeltaTable(),
      ],
    );
  }

  Widget _buildSide(String label, double easi, String severity,
      Map<String, EasiRegionScore> scores, bool isA) {
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
            child: Text('EASI ${easi.toStringAsFixed(1)} · $severity',
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.only(left: isA ? 0 : 4, right: isA ? 4 : 0),
            child: EczemaBodyMap(regionScores: scores, readOnly: true),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaTable() {
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ...changes.take(8).map((c) {
          final region  = findRegion(c.$1);
          final lbl     = region?.label ?? c.$1;
          final delta   = c.$3 - c.$2;
          final improved = delta < 0;
          final color   = improved ? Colors.green.shade600 : Colors.red.shade600;
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              Expanded(child: Text(lbl, style: const TextStyle(fontSize: 11))),
              Text('${c.$2.toStringAsFixed(1)} → ${c.$3.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 11)),
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
