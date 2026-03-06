import 'package:flutter/material.dart';
import '../models/easi_models.dart';

// ─── Canvas dimensions ────────────────────────────────────────────────────────
const double _kW = 220.0;
const double _kH = 500.0;
const double _kAspect = _kH / _kW; // 2.272…

enum EczemaBodyView { front, back }

// ─── Clinical colour palette ──────────────────────────────────────────────────
const Color _kSkinFill   = Color(0xFFFDF9F5); // near-white, warm
const Color _kBodyStroke = Color(0xFF37474F); // dark blue-grey — like pencil on form
const Color _kSepLine    = Color(0xFF90A4AE); // subtle anatomical boundary

// ─── Severity color ramp (0.0 = clear → 1.0 = very severe) ──────────────────
Color severityColor(double t) {
  if (t <= 0.00) return const Color(0xFF9E9E9E); // clear = grey
  if (t <  0.17) return const Color(0xFF43A047); // almost clear
  if (t <  0.34) return const Color(0xFF8BC34A); // mild low
  if (t <  0.50) return const Color(0xFFFDD835); // mild high
  if (t <  0.67) return const Color(0xFFFF9800); // moderate
  if (t <  0.84) return const Color(0xFFF4511E); // severe
  return const Color(0xFFB71C1C);               // very severe
}

Color _levelColor(int level) => severityColor(level / 10.0);

// ─── EczemaBodyMap ────────────────────────────────────────────────────────────

class EczemaBodyMap extends StatelessWidget {
  final EczemaBodyView view;
  final Map<String, EasiRegionScore> regionScores;
  final Map<String, double>? heatData;  // heatmap mode: 0.0–1.0
  final String? activeZoneId;
  final void Function(BodyRegion)? onZoneTap;
  final bool readOnly;
  // When true, draws EASI-group outlines for the active body view
  final bool showGroupBoundaries;

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
    final svgPt = Offset(local.dx * _kW / size.width, local.dy * _kH / size.height);
    for (final r in _regions.reversed) {
      if (r.contains(svgPt)) { onZoneTap!(r); return; }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      final h = w * _kAspect;
      return SizedBox(
        width: w, height: h,
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
              showGroupBoundaries: showGroupBoundaries,
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
  final bool showGroupBoundaries;

  const _ClinicalBodyPainter({
    required this.regions,
    required this.regionScores,
    this.heatData,
    this.activeZoneId,
    required this.isFront,
    required this.showGroupBoundaries,
  });

  // Scaling helpers
  double _x(double v, double sw) => v * sw;
  double _y(double v, double sh) => v * sh;

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width / _kW;
    final sh = size.height / _kH;
    _drawClinicalSilhouette(canvas, sw, sh);
    if (showGroupBoundaries) { _drawGroupBoundaries(canvas, sw, sh); }
    _drawZoneOverlays(canvas, size);
    _drawAnatomicalSeparators(canvas, sw, sh);
  }

  // ── Paints ──────────────────────────────────────────────────────────────────

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
    ..strokeWidth = 0.6;

  void _fill(Canvas c, Path p) { c.drawPath(p, _fillPaint); c.drawPath(p, _strokePaint); }
  void _fillOval(Canvas c, Rect r) { c.drawOval(r, _fillPaint); c.drawOval(r, _strokePaint); }

  // ── Clinical Anatomical Silhouette ──────────────────────────────────────────
  // Proportions derived from Rule of Nines on a 220×500 logical canvas.
  // Each body segment drawn back-to-front so joints overlap cleanly.
  // COORDINATE SPACE: all values in logical units (0–220 width, 0–500 height).

  void _drawClinicalSilhouette(Canvas canvas, double sw, double sh) {
    double x(double v) => _x(v, sw);
    double y(double v) => _y(v, sh);

    // ── FEET (drawn first, behind everything) ────────────────────────────────
    // Left foot (anatomical L = viewer's right in front view)
    _fill(canvas, Path()
      ..moveTo(x(60), y(452)) // lateral (outer) top-left
      ..lineTo(x(95), y(452)) // medial (inner) top-right
      ..lineTo(x(97), y(474)) // medial bottom
      ..quadraticBezierTo(x(78), y(478), x(62), y(473)) // toe curve
      ..close());

    // Right foot (mirrored: x → 220-x)
    _fill(canvas, Path()
      ..moveTo(x(160), y(452))
      ..lineTo(x(125), y(452))
      ..lineTo(x(123), y(474))
      ..quadraticBezierTo(x(142), y(478), x(158), y(473))
      ..close());

    // ── LOWER LEGS ───────────────────────────────────────────────────────────
    // Left lower leg — slightly tapers, calf widest at ~1/3 from top (front view: shin)
    _fill(canvas, Path()
      ..moveTo(x(76), y(360))  // outer top
      ..lineTo(x(95), y(360))  // inner top
      ..lineTo(x(93), y(452))  // inner bottom (ankle)
      ..lineTo(x(77), y(452))  // outer bottom
      ..close());

    // Right lower leg
    _fill(canvas, Path()
      ..moveTo(x(144), y(360))
      ..lineTo(x(125), y(360))
      ..lineTo(x(127), y(452))
      ..lineTo(x(143), y(452))
      ..close());

    // ── THIGHS ───────────────────────────────────────────────────────────────
    // Left thigh — widest at top, tapers toward knee
    _fill(canvas, Path()
      ..moveTo(x(72), y(228))  // outer top
      ..lineTo(x(97), y(228))  // inner top
      ..quadraticBezierTo(x(96), y(290), x(95), y(356)) // inner side (slight taper)
      ..lineTo(x(74), y(358))  // outer bottom
      ..quadraticBezierTo(x(73), y(290), x(72), y(228)) // outer side
      ..close());

    // Right thigh
    _fill(canvas, Path()
      ..moveTo(x(148), y(228))
      ..lineTo(x(123), y(228))
      ..quadraticBezierTo(x(124), y(290), x(125), y(356))
      ..lineTo(x(146), y(358))
      ..quadraticBezierTo(x(147), y(290), x(148), y(228))
      ..close());

    // ── HANDS ────────────────────────────────────────────────────────────────
    // Left hand
    _fill(canvas, Path()
      ..moveTo(x(42), y(218))
      ..lineTo(x(67), y(218))
      ..lineTo(x(68), y(242))
      ..lineTo(x(42), y(242))
      ..close());

    // Right hand
    _fill(canvas, Path()
      ..moveTo(x(178), y(218))
      ..lineTo(x(153), y(218))
      ..lineTo(x(152), y(242))
      ..lineTo(x(178), y(242))
      ..close());

    // ── FOREARMS ─────────────────────────────────────────────────────────────
    // Left forearm — slight taper from elbow to wrist
    _fill(canvas, Path()
      ..moveTo(x(44), y(162))  // outer top
      ..lineTo(x(65), y(160))  // inner top
      ..lineTo(x(66), y(218))  // inner bottom
      ..lineTo(x(43), y(218))  // outer bottom
      ..close());

    // Right forearm
    _fill(canvas, Path()
      ..moveTo(x(176), y(162))
      ..lineTo(x(155), y(160))
      ..lineTo(x(154), y(218))
      ..lineTo(x(177), y(218))
      ..close());

    // ── UPPER ARMS ───────────────────────────────────────────────────────────
    // Left upper arm — slight outward taper at deltoid, elbow bump on outer
    _fill(canvas, Path()
      ..moveTo(x(44), y(82))   // outer top
      ..lineTo(x(65), y(82))   // inner top
      ..lineTo(x(65), y(148))  // inner elbow top
      ..quadraticBezierTo(x(64), y(158), x(65), y(163)) // inner elbow curve
      ..lineTo(x(43), y(161))  // outer elbow bottom
      ..quadraticBezierTo(x(41), y(153), x(44), y(146)) // outer elbow bump
      ..lineTo(x(44), y(82))   // back to top
      ..close());

    // Right upper arm (mirrored)
    _fill(canvas, Path()
      ..moveTo(x(176), y(82))
      ..lineTo(x(155), y(82))
      ..lineTo(x(155), y(148))
      ..quadraticBezierTo(x(156), y(158), x(155), y(163))
      ..lineTo(x(177), y(161))
      ..quadraticBezierTo(x(179), y(153), x(176), y(146))
      ..lineTo(x(176), y(82))
      ..close());

    // ── TORSO ────────────────────────────────────────────────────────────────
    // Front/back view share same silhouette. Anatomical position:
    // shoulders → shoulder-slope → axilla → chest → waist taper → hip flare → groin
    _fill(canvas, Path()
      // Left shoulder connection
      ..moveTo(x(68), y(76))
      ..lineTo(x(100), y(76)) // left neck base
      ..lineTo(x(120), y(76)) // right neck base
      ..lineTo(x(152), y(76)) // right shoulder connection
      // Right shoulder slope (acromion → deltoid→ axilla)
      ..quadraticBezierTo(x(162), y(77), x(164), y(90))
      ..quadraticBezierTo(x(163), y(104), x(156), y(112))
      // Right torso side — chest, waist, hip
      ..lineTo(x(152), y(162)) // chest level
      ..quadraticBezierTo(x(151), y(174), x(150), y(182)) // waist taper
      ..quadraticBezierTo(x(150), y(198), x(153), y(208)) // hip flare
      ..quadraticBezierTo(x(153), y(220), x(146), y(227)) // groin slope
      // Crotch
      ..lineTo(x(122), y(230))
      ..quadraticBezierTo(x(116), y(232), x(110), y(232))
      ..quadraticBezierTo(x(104), y(232), x(98), y(230))
      ..lineTo(x(74), y(227))
      // Left hip, waist, chest (mirror)
      ..quadraticBezierTo(x(67), y(220), x(67), y(208))
      ..quadraticBezierTo(x(70), y(198), x(70), y(182))
      ..quadraticBezierTo(x(69), y(174), x(68), y(162))
      ..lineTo(x(64), y(112))
      ..quadraticBezierTo(x(57), y(104), x(56), y(90))
      ..quadraticBezierTo(x(58), y(77), x(68), y(76))
      ..close());

    // ── NECK ─────────────────────────────────────────────────────────────────
    _fill(canvas, Path()
      ..moveTo(x(102), y(57))
      ..lineTo(x(118), y(57))
      ..lineTo(x(120), y(76))
      ..lineTo(x(100), y(76))
      ..close());

    // ── HEAD ─────────────────────────────────────────────────────────────────
    _fillOval(canvas,
        Rect.fromCenter(center: Offset(x(110), y(31)), width: x(44), height: y(50)));

    // ── EARS (tiny ellipses for orientation) ─────────────────────────────────
    final earPaint = Paint()
      ..color = _kBodyStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawOval(Rect.fromCenter(center: Offset(x(88), y(32)), width: x(5), height: y(9)), earPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(x(132), y(32)), width: x(5), height: y(9)), earPaint);

    // ── CLAVICLE HINT (front only) ───────────────────────────────────────────
    if (isFront) {
      final clav = Paint()
        ..color = _kBodyStroke.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;
      // Left clavicle: neck base to shoulder
      canvas.drawLine(Offset(x(100), y(76)), Offset(x(72), y(80)), clav);
      // Right clavicle
      canvas.drawLine(Offset(x(120), y(76)), Offset(x(148), y(80)), clav);
    }
  }

  // ── Anatomical separator lines ───────────────────────────────────────────────
  // Thin horizontal lines at joint/zone-boundary levels so users know
  // which zone they're tapping. No clinical zone is ambiguous.
  void _drawAnatomicalSeparators(Canvas canvas, double sw, double sh) {
    double x(double v) => _x(v, sw);
    double y(double v) => _y(v, sh);

    final p = _sepPaint;

    // Wrist level (forearm / hand boundary)
    canvas.drawLine(Offset(x(42), y(218)), Offset(x(68), y(218)), p);   // L
    canvas.drawLine(Offset(x(152), y(218)), Offset(x(178), y(218)), p); // R

    // Elbow level
    canvas.drawLine(Offset(x(42), y(161)), Offset(x(67), y(161)), p);
    canvas.drawLine(Offset(x(153), y(161)), Offset(x(178), y(161)), p);

    // Axilla / torso split (where arm diverges from torso)
    canvas.drawLine(Offset(x(44), y(82)), Offset(x(66), y(82)), p);
    canvas.drawLine(Offset(x(154), y(82)), Offset(x(176), y(82)), p);

    // Knee level
    canvas.drawLine(Offset(x(72), y(358)), Offset(x(97), y(358)), p);
    canvas.drawLine(Offset(x(123), y(358)), Offset(x(148), y(358)), p);

    // Ankle level
    canvas.drawLine(Offset(x(76), y(452)), Offset(x(95), y(452)), p);
    canvas.drawLine(Offset(x(125), y(452)), Offset(x(144), y(452)), p);

    // Waist (upper / lower torso split, y≈182)
    canvas.drawLine(Offset(x(68), y(182)), Offset(x(152), y(182)), p);
  }

  // ── EASI group boundary outlines (optional) ──────────────────────────────
  void _drawGroupBoundaries(Canvas canvas, double sw, double sh) {
    // Silhouette zone overlays handle group boundaries visually; no-op.
  }

  // ── Zone overlays ────────────────────────────────────────────────────────────
  void _drawZoneOverlays(Canvas canvas, Size size) {
    for (final region in regions) {
      final sr = _scaleRect(region.svgRect, size);
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
        final fp = Paint()..color = fill.withValues(alpha: 0.68);
        _zoneShape(canvas, sr, region.isEllipse, fp);
      }

      if (isActive) {
        final rp = Paint()
          ..color = fill ?? const Color(0xFF1565C0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        _zoneShape(canvas, sr, region.isEllipse, rp);

        // Pulse ring
        final rp2 = Paint()
          ..color = (fill ?? const Color(0xFF1565C0)).withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5;
        final expanded = sr.inflate(3);
        _zoneShape(canvas, expanded, region.isEllipse, rp2);
      }
    }
  }

  Rect _scaleRect(Rect r, Size size) => Rect.fromLTWH(
    r.left * size.width / _kW,
    r.top * size.height / _kH,
    r.width * size.width / _kW,
    r.height * size.height / _kH,
  );

  void _zoneShape(Canvas canvas, Rect r, bool ellipse, Paint p) {
    if (ellipse) {
      canvas.drawOval(r, p);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)), p);
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

// ─── Severity legend ──────────────────────────────────────────────────────────

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
          Text(b.$1,
              style: TextStyle(
                  fontSize: compact ? 9 : 10,
                  color: Colors.grey.shade700)),
        ]);
      }).toList(),
    );
  }
}

// ─── Visit comparison widget ──────────────────────────────────────────────────

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
    if (easi == 0) return const Color(0xFF9E9E9E);
    if (easi <= 1) return const Color(0xFF43A047);
    if (easi <= 7) return const Color(0xFFFDD835);
    if (easi <= 21) return const Color(0xFFFF9800);
    if (easi <= 50) return const Color(0xFFF4511E);
    return const Color(0xFFB71C1C);
  }

  @override
  Widget build(BuildContext context) {
    final delta = widget.easiB - widget.easiA;
    final improved = delta < 0;
    final deltaColor = improved ? Colors.green : (delta > 0 ? Colors.red : Colors.grey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // View toggle
        Center(
          child: SegmentedButton<EczemaBodyView>(
            segments: const [
              ButtonSegment(value: EczemaBodyView.front, label: Text('Front')),
              ButtonSegment(value: EczemaBodyView.back, label: Text('Back')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ),
        const SizedBox(height: 8),

        // Side-by-side maps
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

        // Delta row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: deltaColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: deltaColor.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(improved ? Icons.trending_down : (delta > 0 ? Icons.trending_up : Icons.trending_flat),
                color: deltaColor, size: 18),
            const SizedBox(width: 6),
            Text(
              delta == 0
                  ? 'No change in EASI score'
                  : 'EASI ${improved ? "improved" : "worsened"} by ${delta.abs().toStringAsFixed(1)} points',
              style: TextStyle(color: deltaColor, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ]),
        ),

        // Per-region change table (top changes only)
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
    // Find regions that changed
    final allIds = {...widget.scoresA.keys, ...widget.scoresB.keys};
    final changes = <(String, double, double)>[];

    for (final id in allIds) {
      final a = widget.scoresA[id];
      final b = widget.scoresB[id];
      final easiA = a?.easiContribution(groupForRegion(id)) ?? 0;
      final easiB = b?.easiContribution(groupForRegion(id)) ?? 0;
      if ((easiA - easiB).abs() > 0.01) changes.add((id, easiA, easiB));
    }
    changes.sort((x, y) => (y.$2 - y.$3).abs().compareTo((x.$2 - x.$3).abs()));

    if (changes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Region Changes', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
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
