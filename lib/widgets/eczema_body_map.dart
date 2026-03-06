import 'package:flutter/material.dart';
import '../models/easi_models.dart';

// ─── Canvas dimensions ────────────────────────────────────────────────────────
const double _kW = 220.0;
const double _kH = 500.0;
const double _kAspect = _kH / _kW; // ≈ 2.273

enum EczemaBodyView { front, back }

// ─── Clinical colour palette ──────────────────────────────────────────────────
const Color _kSkinFill   = Color(0xFFFDF9F5); // warm near-white
const Color _kBodyStroke = Color(0xFF37474F); // dark blue-grey (pencil on form)
const Color _kSepLine    = Color(0xFF90A4AE); // subtle anatomical boundary
const Color _kNumColor   = Color(0xFF455A64); // zone number label (unstyled)

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

class EczemaBodyMap extends StatelessWidget {
  final EczemaBodyView view;
  final Map<String, EasiRegionScore> regionScores;
  final Map<String, double>? heatData;   // optional heat-map mode: 0.0–1.0
  final String? activeZoneId;
  final void Function(BodyRegion)? onZoneTap;
  final bool readOnly;
  final bool showGroupBoundaries;        // reserved; kept for API compatibility

  const EczemaBodyMap({
    super.key,
    required this.view,
    this.regionScores = const {},
    this.heatData,
    this.activeZoneId,
    this.onZoneTap,
    this.readOnly = false,
    this.showGroupBoundaries = false,
  });

  List<BodyRegion> get _regions =>
      view == EczemaBodyView.front ? kFrontRegions : kBackRegions;

  void _handleTap(Offset local, Size size) {
    if (readOnly || onZoneTap == null) return;
    // Convert widget-local coordinates → 220×500 canvas space.
    final svgPt = Offset(
      local.dx * _kW / size.width,
      local.dy * _kH / size.height,
    );
    // Iterate in reverse so zones drawn last (topmost) are hit-tested first.
    for (final r in _regions.reversed) {
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
          onTapDown: readOnly ? null : (d) => _handleTap(d.localPosition, Size(w, h)),
          child: CustomPaint(
            size: Size(w, h),
            painter: _ClinicalBodyPainter(
              regions: _regions,
              regionScores: regionScores,
              heatData: heatData,
              activeZoneId: activeZoneId,
              isFront: view == EczemaBodyView.front,
            ),
          ),
        ),
      );
    });
  }
}

// ─── Clinical Body Painter ────────────────────────────────────────────────────

class _ClinicalBodyPainter extends CustomPainter {
  final List<BodyRegion> regions;
  final Map<String, EasiRegionScore> regionScores;
  final Map<String, double>? heatData;
  final String? activeZoneId;
  final bool isFront;

  const _ClinicalBodyPainter({
    required this.regions,
    required this.regionScores,
    this.heatData,
    this.activeZoneId,
    required this.isFront,
  });

  // ── Coordinate helpers ────────────────────────────────────────────────────

  double _x(double v, double sw) => v * sw;
  double _y(double v, double sh) => v * sh;

  // ── Paint factories ───────────────────────────────────────────────────────

  Paint get _fillPaint => Paint()
    ..color = _kSkinFill
    ..style = PaintingStyle.fill;

  Paint get _strokePaint => Paint()
    ..color = _kBodyStroke
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint get _sepPaint => Paint()
    ..color = _kSepLine
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7;

  void _fill(Canvas c, Path p) {
    c.drawPath(p, _fillPaint);
    c.drawPath(p, _strokePaint);
  }

  void _fillOval(Canvas c, Rect r) {
    c.drawOval(r, _fillPaint);
    c.drawOval(r, _strokePaint);
  }

  // ── Main paint entry ──────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width / _kW;
    final sh = size.height / _kH;

    // 1. Anatomical silhouette (skin fill + outline)
    _drawClinicalSilhouette(canvas, sw, sh);

    // 2. Coloured zone overlays (severity / heat)
    _drawZoneOverlays(canvas, size, sw, sh);

    // 3. Clinical zone numbers
    _drawZoneNumbers(canvas, size);

    // 4. Thin separator lines at joint / zone boundaries
    _drawAnatomicalSeparators(canvas, sw, sh);
  }

  // ── Anatomical Silhouette ─────────────────────────────────────────────────
  // Traced from the provided medical diagram on a 220×500 logical canvas.
  // Arms spread outward (x=22–56 right, x=164–198 left); torso narrower at
  // waist than at shoulders. Drawn back-to-front so joints overlap cleanly.

  void _drawClinicalSilhouette(Canvas canvas, double sw, double sh) {
    double x(double v) => _x(v, sw);
    double y(double v) => _y(v, sh);

    // ── FEET (drawn first — behind everything) ──────────────────────────────
    _fill(canvas, Path()
      ..moveTo(x(58), y(462))
      ..lineTo(x(100), y(462))
      ..lineTo(x(97), y(484))
      ..quadraticBezierTo(x(80), y(492), x(55), y(480))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(162), y(462))
      ..lineTo(x(120), y(462))
      ..lineTo(x(123), y(484))
      ..quadraticBezierTo(x(140), y(492), x(165), y(480))
      ..close());

    // ── LOWER LEGS ──────────────────────────────────────────────────────────
    _fill(canvas, Path()
      ..moveTo(x(73), y(392))
      ..lineTo(x(100), y(392))
      ..lineTo(x(97), y(462))
      ..lineTo(x(74), y(462))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(147), y(392))
      ..lineTo(x(120), y(392))
      ..lineTo(x(123), y(462))
      ..lineTo(x(146), y(462))
      ..close());

    // ── KNEES (ellipses) ────────────────────────────────────────────────────
    _fillOval(canvas, Rect.fromLTWH(x(70), y(370), x(30), y(22)));
    _fillOval(canvas, Rect.fromLTWH(x(120), y(370), x(30), y(22)));

    // ── THIGHS ──────────────────────────────────────────────────────────────
    _fill(canvas, Path()
      ..moveTo(x(68), y(240))
      ..lineTo(x(105), y(240))
      ..quadraticBezierTo(x(103), y(305), x(101), y(370))
      ..lineTo(x(70), y(370))
      ..quadraticBezierTo(x(69), y(305), x(68), y(240))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(152), y(240))
      ..lineTo(x(115), y(240))
      ..quadraticBezierTo(x(117), y(305), x(119), y(370))
      ..lineTo(x(150), y(370))
      ..quadraticBezierTo(x(151), y(305), x(152), y(240))
      ..close());

    // ── HANDS ───────────────────────────────────────────────────────────────
    _fill(canvas, Path()
      ..moveTo(x(14), y(220))
      ..lineTo(x(54), y(220))
      ..lineTo(x(56), y(252))
      ..lineTo(x(12), y(248))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(206), y(220))
      ..lineTo(x(166), y(220))
      ..lineTo(x(164), y(252))
      ..lineTo(x(208), y(248))
      ..close());

    // ── FOREARMS ────────────────────────────────────────────────────────────
    _fill(canvas, Path()
      ..moveTo(x(20), y(168))
      ..lineTo(x(54), y(168))
      ..lineTo(x(52), y(220))
      ..lineTo(x(18), y(220))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(200), y(168))
      ..lineTo(x(166), y(168))
      ..lineTo(x(168), y(220))
      ..lineTo(x(202), y(220))
      ..close());

    // ── UPPER ARMS ──────────────────────────────────────────────────────────
    _fill(canvas, Path()
      ..moveTo(x(24), y(80))
      ..lineTo(x(56), y(80))
      ..lineTo(x(54), y(168))
      ..lineTo(x(22), y(168))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(196), y(80))
      ..lineTo(x(164), y(80))
      ..lineTo(x(166), y(168))
      ..lineTo(x(198), y(168))
      ..close());

    // ── TORSO ───────────────────────────────────────────────────────────────
    // Wider at shoulders (x=58–162), narrows at waist (x=68–152),
    // slight hip flare, ends at groin split (x=98–122 centre).
    _fill(canvas, Path()
      ..moveTo(x(58), y(76))
      ..lineTo(x(99), y(76))
      ..lineTo(x(121), y(76))
      ..lineTo(x(162), y(76))
      ..quadraticBezierTo(x(170), y(80), x(168), y(95))
      ..quadraticBezierTo(x(164), y(110), x(156), y(122))
      ..lineTo(x(152), y(168))
      ..quadraticBezierTo(x(151), y(180), x(150), y(195))
      ..quadraticBezierTo(x(150), y(210), x(153), y(220))
      ..quadraticBezierTo(x(152), y(232), x(148), y(240))
      ..lineTo(x(122), y(240))
      ..quadraticBezierTo(x(116), y(242), x(110), y(242))
      ..quadraticBezierTo(x(104), y(242), x(98), y(240))
      ..lineTo(x(72), y(240))
      ..quadraticBezierTo(x(68), y(232), x(67), y(220))
      ..quadraticBezierTo(x(70), y(210), x(70), y(195))
      ..quadraticBezierTo(x(69), y(180), x(68), y(168))
      ..lineTo(x(64), y(122))
      ..quadraticBezierTo(x(56), y(110), x(52), y(95))
      ..quadraticBezierTo(x(50), y(80), x(58), y(76))
      ..close());

    // ── NECK ────────────────────────────────────────────────────────────────
    _fill(canvas, Path()
      ..moveTo(x(101), y(54))
      ..lineTo(x(119), y(54))
      ..lineTo(x(121), y(76))
      ..lineTo(x(99), y(76))
      ..close());

    // ── HEAD ────────────────────────────────────────────────────────────────
    _fillOval(canvas,
        Rect.fromCenter(center: Offset(x(110), y(30)), width: x(46), height: y(52)));

    // EARS
    final earPaint = Paint()
      ..color = _kBodyStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(x(87), y(30)), width: x(5), height: y(10)),
        earPaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(x(133), y(30)), width: x(5), height: y(10)),
        earPaint);

    // CLAVICLE HINT (front view only)
    if (isFront) {
      final clav = Paint()
        ..color = _kBodyStroke.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;
      canvas.drawLine(Offset(x(99), y(76)),  Offset(x(64),  y(82)), clav);
      canvas.drawLine(Offset(x(121), y(76)), Offset(x(156), y(82)), clav);
    }
  }

  // ── Anatomical separator lines ─────────────────────────────────────────────

  void _drawAnatomicalSeparators(Canvas canvas, double sw, double sh) {
    double x(double v) => _x(v, sw);
    double y(double v) => _y(v, sh);
    final p = _sepPaint;

    // Midline through torso
    canvas.drawLine(Offset(x(110), y(54)), Offset(x(110), y(242)), p);

    // Wrist
    canvas.drawLine(Offset(x(14),  y(220)), Offset(x(54),  y(220)), p);
    canvas.drawLine(Offset(x(166), y(220)), Offset(x(206), y(220)), p);

    // Elbow
    canvas.drawLine(Offset(x(20),  y(168)), Offset(x(54),  y(168)), p);
    canvas.drawLine(Offset(x(166), y(168)), Offset(x(200), y(168)), p);

    // Axilla
    canvas.drawLine(Offset(x(24),  y(80)), Offset(x(56),  y(80)), p);
    canvas.drawLine(Offset(x(164), y(80)), Offset(x(196), y(80)), p);

    // Chest / upper-abd boundary
    canvas.drawLine(Offset(x(64), y(122)), Offset(x(156), y(122)), p);

    // Upper-abd / lower-abd boundary
    canvas.drawLine(Offset(x(68), y(168)), Offset(x(152), y(168)), p);

    if (isFront) {
      // Lower-abd / groin boundary
      canvas.drawLine(Offset(x(68), y(215)), Offset(x(152), y(215)), p);
    } else {
      // Lower-back / sacrum-buttock boundary
      canvas.drawLine(Offset(x(68), y(215)), Offset(x(152), y(215)), p);
    }

    // Knee band
    canvas.drawLine(Offset(x(70),  y(370)), Offset(x(100), y(370)), p);
    canvas.drawLine(Offset(x(120), y(370)), Offset(x(150), y(370)), p);
    canvas.drawLine(Offset(x(70),  y(392)), Offset(x(100), y(392)), p);
    canvas.drawLine(Offset(x(120), y(392)), Offset(x(150), y(392)), p);

    // Ankle / foot
    canvas.drawLine(Offset(x(74),  y(462)), Offset(x(97),  y(462)), p);
    canvas.drawLine(Offset(x(123), y(462)), Offset(x(146), y(462)), p);
  }

  // ── Zone overlays ──────────────────────────────────────────────────────────
  // Drawn on top of the silhouette, before the number labels.

  void _drawZoneOverlays(Canvas canvas, Size size, double sw, double sh) {
    for (final region in regions) {
      final isActive = region.id == activeZoneId;

      // Determine fill colour (heat-map takes priority over EASI scores).
      Color? fill;
      if (heatData != null) {
        final t = heatData![region.id];
        if (t != null && t > 0.01) fill = severityColor(t);
      } else {
        final s = regionScores[region.id];
        if (s != null && s.attributeSum > 0) fill = _levelColor(s.level);
      }

      // Severity fill
      if (fill != null) {
        final fp = Paint()..color = fill.withValues(alpha: 0.58);
        _paintZone(canvas, region, fp, sw, sh);
      }

      // Active zone: solid outline + halo + light fill when unscored
      if (isActive) {
        final outlineColor = fill ?? const Color(0xFF1565C0);

        final rp = Paint()
          ..color = outlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        _paintZone(canvas, region, rp, sw, sh);

        final halo = Paint()
          ..color = outlineColor.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5;
        _paintZone(canvas, region, halo, sw, sh, inflate: 2.5);

        if (fill == null) {
          final activeFill = Paint()
            ..color = const Color(0xFF1565C0).withValues(alpha: 0.12);
          _paintZone(canvas, region, activeFill, sw, sh);
        }
      }
    }
  }

  // Draw a single zone using either an ellipse or a polygon path.
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
        r.left * sw,
        r.top * sh,
        r.width * sw,
        r.height * sh,
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
      canvas.drawPath(path, paint);
    }
  }

  // ── Zone number labels ─────────────────────────────────────────────────────
  // Each zone shows its clinical number at its centroid.

  void _drawZoneNumbers(Canvas canvas, Size size) {
    final sw = size.width / _kW;
    final sh = size.height / _kH;
    // Font size scales proportionally with the widget width.
    final fontSize = size.width * 0.038;

    for (final region in regions) {
      final c = region.centroid;
      final cx = c.dx * sw;
      final cy = c.dy * sh;

      final isActive  = region.id == activeZoneId;
      final hasScore  = regionScores[region.id]?.attributeSum != null &&
                        regionScores[region.id]!.attributeSum > 0;
      final hasHeat   = heatData != null && (heatData![region.id] ?? 0) > 0.01;
      final highlighted = isActive || hasScore || hasHeat;

      final tp = TextPainter(
        text: TextSpan(
          text: '${region.number}',
          style: TextStyle(
            color: highlighted ? Colors.white : _kNumColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0.5, 0.5),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(cx - tp.width / 2, cy - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_ClinicalBodyPainter old) =>
      old.regions != regions ||
      old.regionScores != regionScores ||
      old.heatData != heatData ||
      old.activeZoneId != activeZoneId ||
      old.isFront != isFront;
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

class EczemaBodyComparison extends StatefulWidget {
  final EczemaBodyView view;
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
    required this.view,
    required this.scoresA,
    required this.scoresB,
    required this.labelA,
    required this.labelB,
    required this.easiA,
    required this.easiB,
    required this.severityA,
    required this.severityB,
  });

  @override
  State<EczemaBodyComparison> createState() => _EczemaBodyComparisonState();
}

class _EczemaBodyComparisonState extends State<EczemaBodyComparison> {
  late EczemaBodyView _view;

  @override
  void initState() {
    super.initState();
    _view = widget.view;
  }

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
    final delta = widget.easiB - widget.easiA;
    final improved = delta < 0;
    final deltaColor =
        improved ? Colors.green : (delta > 0 ? Colors.red : Colors.grey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // View toggle
        Center(
          child: SegmentedButton<EczemaBodyView>(
            segments: const [
              ButtonSegment(value: EczemaBodyView.front, label: Text('Front')),
              ButtonSegment(value: EczemaBodyView.back,  label: Text('Back')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ),
        const SizedBox(height: 8),

        // Side-by-side body maps
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSide(widget.labelA, widget.easiA, widget.severityA, widget.scoresA, true),
              Container(width: 1, color: Colors.grey.shade300),
              _buildSide(widget.labelB, widget.easiB, widget.severityB, widget.scoresB, false),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Delta summary chip
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
              view: _view,
              regionScores: scores,
              readOnly: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaTable() {
    final allIds = {...widget.scoresA.keys, ...widget.scoresB.keys};
    final changes = <(String, double, double)>[];

    for (final id in allIds) {
      final a = widget.scoresA[id];
      final b = widget.scoresB[id];
      final easiA = a?.easiContribution(groupForRegion(id)) ?? 0;
      final easiB = b?.easiContribution(groupForRegion(id)) ?? 0;
      if ((easiA - easiB).abs() > 0.01) changes.add((id, easiA, easiB));
    }
    changes.sort(
        (x, y) => (y.$2 - y.$3).abs().compareTo((x.$2 - x.$3).abs()));

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
          final color =
              improved ? Colors.green.shade600 : Colors.red.shade600;
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
