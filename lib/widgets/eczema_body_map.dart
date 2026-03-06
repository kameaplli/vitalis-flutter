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
  // Proportions follow the Rule of Nines on a 220×500 logical canvas.
  // Segments are drawn back-to-front so joints overlap cleanly.

  void _drawClinicalSilhouette(Canvas canvas, double sw, double sh) {
    double x(double v) => _x(v, sw);
    double y(double v) => _y(v, sh);

    // FEET (drawn first — behind everything)
    _fill(canvas, Path()
      ..moveTo(x(60), y(452))
      ..lineTo(x(95), y(452))
      ..lineTo(x(97), y(474))
      ..quadraticBezierTo(x(78), y(478), x(62), y(473))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(160), y(452))
      ..lineTo(x(125), y(452))
      ..lineTo(x(123), y(474))
      ..quadraticBezierTo(x(142), y(478), x(158), y(473))
      ..close());

    // LOWER LEGS
    _fill(canvas, Path()
      ..moveTo(x(76), y(360))
      ..lineTo(x(95), y(360))
      ..lineTo(x(93), y(452))
      ..lineTo(x(77), y(452))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(144), y(360))
      ..lineTo(x(125), y(360))
      ..lineTo(x(127), y(452))
      ..lineTo(x(143), y(452))
      ..close());

    // THIGHS
    _fill(canvas, Path()
      ..moveTo(x(72), y(228))
      ..lineTo(x(97), y(228))
      ..quadraticBezierTo(x(96), y(290), x(95), y(356))
      ..lineTo(x(74), y(358))
      ..quadraticBezierTo(x(73), y(290), x(72), y(228))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(148), y(228))
      ..lineTo(x(123), y(228))
      ..quadraticBezierTo(x(124), y(290), x(125), y(356))
      ..lineTo(x(146), y(358))
      ..quadraticBezierTo(x(147), y(290), x(148), y(228))
      ..close());

    // HANDS
    _fill(canvas, Path()
      ..moveTo(x(42), y(218))
      ..lineTo(x(67), y(218))
      ..lineTo(x(68), y(242))
      ..lineTo(x(42), y(242))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(178), y(218))
      ..lineTo(x(153), y(218))
      ..lineTo(x(152), y(242))
      ..lineTo(x(178), y(242))
      ..close());

    // FOREARMS
    _fill(canvas, Path()
      ..moveTo(x(44), y(162))
      ..lineTo(x(65), y(160))
      ..lineTo(x(66), y(218))
      ..lineTo(x(43), y(218))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(176), y(162))
      ..lineTo(x(155), y(160))
      ..lineTo(x(154), y(218))
      ..lineTo(x(177), y(218))
      ..close());

    // UPPER ARMS
    _fill(canvas, Path()
      ..moveTo(x(44), y(82))
      ..lineTo(x(65), y(82))
      ..lineTo(x(65), y(148))
      ..quadraticBezierTo(x(64), y(158), x(65), y(163))
      ..lineTo(x(43), y(161))
      ..quadraticBezierTo(x(41), y(153), x(44), y(146))
      ..lineTo(x(44), y(82))
      ..close());
    _fill(canvas, Path()
      ..moveTo(x(176), y(82))
      ..lineTo(x(155), y(82))
      ..lineTo(x(155), y(148))
      ..quadraticBezierTo(x(156), y(158), x(155), y(163))
      ..lineTo(x(177), y(161))
      ..quadraticBezierTo(x(179), y(153), x(176), y(146))
      ..lineTo(x(176), y(82))
      ..close());

    // TORSO
    _fill(canvas, Path()
      ..moveTo(x(68), y(76))
      ..lineTo(x(100), y(76))
      ..lineTo(x(120), y(76))
      ..lineTo(x(152), y(76))
      ..quadraticBezierTo(x(162), y(77), x(164), y(90))
      ..quadraticBezierTo(x(163), y(104), x(156), y(112))
      ..lineTo(x(152), y(162))
      ..quadraticBezierTo(x(151), y(174), x(150), y(182))
      ..quadraticBezierTo(x(150), y(198), x(153), y(208))
      ..quadraticBezierTo(x(153), y(220), x(146), y(227))
      ..lineTo(x(122), y(230))
      ..quadraticBezierTo(x(116), y(232), x(110), y(232))
      ..quadraticBezierTo(x(104), y(232), x(98), y(230))
      ..lineTo(x(74), y(227))
      ..quadraticBezierTo(x(67), y(220), x(67), y(208))
      ..quadraticBezierTo(x(70), y(198), x(70), y(182))
      ..quadraticBezierTo(x(69), y(174), x(68), y(162))
      ..lineTo(x(64), y(112))
      ..quadraticBezierTo(x(57), y(104), x(56), y(90))
      ..quadraticBezierTo(x(58), y(77), x(68), y(76))
      ..close());

    // NECK
    _fill(canvas, Path()
      ..moveTo(x(102), y(57))
      ..lineTo(x(118), y(57))
      ..lineTo(x(120), y(76))
      ..lineTo(x(100), y(76))
      ..close());

    // HEAD
    _fillOval(canvas,
        Rect.fromCenter(center: Offset(x(110), y(31)), width: x(44), height: y(50)));

    // EARS (orientation cue)
    final earPaint = Paint()
      ..color = _kBodyStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(x(88), y(32)), width: x(5), height: y(9)),
        earPaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(x(132), y(32)), width: x(5), height: y(9)),
        earPaint);

    // CLAVICLE HINT (front view only)
    if (isFront) {
      final clav = Paint()
        ..color = _kBodyStroke.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;
      canvas.drawLine(Offset(x(100), y(76)), Offset(x(72), y(80)), clav);
      canvas.drawLine(Offset(x(120), y(76)), Offset(x(148), y(80)), clav);
    }
  }

  // ── Anatomical separator lines ─────────────────────────────────────────────
  // Thin lines at joint / zone-boundary levels so zones are visually distinct.

  void _drawAnatomicalSeparators(Canvas canvas, double sw, double sh) {
    double x(double v) => _x(v, sw);
    double y(double v) => _y(v, sh);
    final p = _sepPaint;

    // Midline through torso
    canvas.drawLine(Offset(x(110), y(57)), Offset(x(110), y(232)), p);

    // Wrist
    canvas.drawLine(Offset(x(42),  y(218)), Offset(x(68),  y(218)), p);
    canvas.drawLine(Offset(x(152), y(218)), Offset(x(178), y(218)), p);

    // Elbow
    canvas.drawLine(Offset(x(42),  y(161)), Offset(x(67),  y(161)), p);
    canvas.drawLine(Offset(x(153), y(161)), Offset(x(178), y(161)), p);

    // Axilla (arm / torso junction)
    canvas.drawLine(Offset(x(44),  y(82)), Offset(x(66),  y(82)), p);
    canvas.drawLine(Offset(x(154), y(82)), Offset(x(176), y(82)), p);

    // Chest / upper-abdomen boundary (y≈115)
    canvas.drawLine(Offset(x(68), y(115)), Offset(x(152), y(115)), p);

    // Upper- / lower-abdomen boundary (y≈162, front); also mid/lower-back boundary (back)
    canvas.drawLine(Offset(x(68), y(162)), Offset(x(152), y(162)), p);

    if (isFront) {
      // Lower abdomen / groin boundary
      canvas.drawLine(Offset(x(68), y(208)), Offset(x(152), y(208)), p);
    } else {
      // Additional back-view separators
      canvas.drawLine(Offset(x(68), y(155)), Offset(x(152), y(155)), p);
      canvas.drawLine(Offset(x(68), y(185)), Offset(x(152), y(185)), p);
    }

    // Knee band (two lines, one above one below the ellipse)
    canvas.drawLine(Offset(x(72),  y(358)), Offset(x(98),  y(358)), p);
    canvas.drawLine(Offset(x(122), y(358)), Offset(x(148), y(358)), p);
    canvas.drawLine(Offset(x(72),  y(364)), Offset(x(98),  y(364)), p);
    canvas.drawLine(Offset(x(122), y(364)), Offset(x(148), y(364)), p);

    // Ankle
    canvas.drawLine(Offset(x(76),  y(452)), Offset(x(95),  y(452)), p);
    canvas.drawLine(Offset(x(125), y(452)), Offset(x(144), y(452)), p);
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
