import 'package:flutter/material.dart';

// ─── EASI Group ───────────────────────────────────────────────────────────────

enum EasiGroup { headNeck, upperExt, trunk, lowerExt }

extension EasiGroupX on EasiGroup {
  double get multiplier => const [0.1, 0.2, 0.3, 0.4][index];
  String get label =>
      const ['Head & Neck', 'Upper Extremities', 'Trunk', 'Lower Extremities'][index];
}

// ─── Body Region ──────────────────────────────────────────────────────────────

class BodyRegion {
  final String id;
  final String label;
  final int number;       // clinical diagram number (1–50)
  final bool isFront;
  final EasiGroup group;
  // Hit-test geometry in 220×500 logical canvas space.
  final List<Offset> polyPoints;  // polygon vertices (empty when isEllipse=true)
  final bool isEllipse;
  final Rect ellipseRect;         // only meaningful when isEllipse=true

  const BodyRegion({
    required this.id,
    required this.label,
    required this.number,
    required this.isFront,
    required this.group,
    this.polyPoints = const [],
    this.isEllipse = false,
    this.ellipseRect = Rect.zero,
  });

  // Bounding rect — used by legacy callers.
  Rect get svgRect {
    if (isEllipse) return ellipseRect;
    if (polyPoints.isEmpty) return Rect.zero;
    double minX = polyPoints[0].dx, maxX = polyPoints[0].dx;
    double minY = polyPoints[0].dy, maxY = polyPoints[0].dy;
    for (final p in polyPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  // Centroid of the zone (used for number-label placement).
  Offset get centroid {
    if (isEllipse) return ellipseRect.center;
    if (polyPoints.isEmpty) return Offset.zero;
    double sx = 0, sy = 0;
    for (final p in polyPoints) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / polyPoints.length, sy / polyPoints.length);
  }

  // Hit-test: returns true when [pt] (in 220×500 canvas space) is inside this zone.
  bool contains(Offset pt) {
    if (isEllipse) {
      final c = ellipseRect.center;
      final rx = ellipseRect.width / 2;
      final ry = ellipseRect.height / 2;
      if (rx <= 0 || ry <= 0) return false;
      final dx = (pt.dx - c.dx) / rx;
      final dy = (pt.dy - c.dy) / ry;
      return dx * dx + dy * dy <= 1.0;
    }
    return _pointInPolygon(pt, polyPoints);
  }

  static bool _pointInPolygon(Offset pt, List<Offset> poly) {
    if (poly.length < 3) return false;
    bool inside = false;
    int j = poly.length - 1;
    for (int i = 0; i < poly.length; i++) {
      final xi = poly[i].dx, yi = poly[i].dy;
      final xj = poly[j].dx, yj = poly[j].dy;
      if (((yi > pt.dy) != (yj > pt.dy)) &&
          (pt.dx < (xj - xi) * (pt.dy - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }
}

// ─── EASI Region Score ────────────────────────────────────────────────────────

class EasiRegionScore {
  final String regionId;
  final int erythema;         // 0–3
  final int papulation;       // 0–3
  final int excoriation;      // 0–3
  final int lichenification;  // 0–3
  final int areaScore;        // 1–6

  const EasiRegionScore({
    required this.regionId,
    this.erythema = 0,
    this.papulation = 0,
    this.excoriation = 0,
    this.lichenification = 0,
    this.areaScore = 1,
  });

  int get attributeSum => erythema + papulation + excoriation + lichenification;

  int get level => (attributeSum / 12.0 * 10).round();

  double easiContribution(EasiGroup group) =>
      attributeSum * areaScore * group.multiplier;

  Map<String, dynamic> toJson() => {
    'area': regionId,
    'erythema': erythema,
    'papulation': papulation,
    'excoriation': excoriation,
    'lichenification': lichenification,
    'area_score': areaScore,
    'level': level,
  };

  factory EasiRegionScore.fromJson(Map<String, dynamic> json) {
    return EasiRegionScore(
      regionId: json['area'] as String? ?? '',
      erythema: (json['erythema'] as num?)?.toInt() ?? 0,
      papulation: (json['papulation'] as num?)?.toInt() ?? 0,
      excoriation: (json['excoriation'] as num?)?.toInt() ?? 0,
      lichenification: (json['lichenification'] as num?)?.toInt() ?? 0,
      areaScore: (json['area_score'] as num?)?.toInt() ?? 1,
    );
  }
}

// ─── EASI Score ───────────────────────────────────────────────────────────────

class EasiScore {
  final List<EasiRegionScore> scores;
  const EasiScore(this.scores);

  double get total {
    double sum = 0;
    for (final s in scores) {
      sum += s.easiContribution(groupForRegion(s.regionId));
    }
    return sum;
  }

  String get severityLabel {
    final t = total;
    if (t == 0)  return 'Clear';
    if (t <= 1)  return 'Almost Clear';
    if (t <= 7)  return 'Mild';
    if (t <= 21) return 'Moderate';
    if (t <= 50) return 'Severe';
    return 'Very Severe';
  }

  Color get color {
    final t = total;
    if (t == 0)  return const Color(0xFF4CAF50);
    if (t <= 1)  return const Color(0xFF8BC34A);
    if (t <= 7)  return const Color(0xFFFFC107);
    if (t <= 21) return const Color(0xFFFF9800);
    if (t <= 50) return const Color(0xFFFF5722);
    return const Color(0xFFF44336);
  }
}

// ─── Group lookup ─────────────────────────────────────────────────────────────

EasiGroup _groupFor(String id) {
  final numStr = id.replaceAll(RegExp(r'[^0-9]'), '');
  final num = int.tryParse(numStr) ?? 0;
  if ([1, 2, 3, 23, 24, 25].contains(num)) return EasiGroup.headNeck;
  if ([6, 7, 8, 9, 10, 11, 28, 29, 30, 31, 32, 33].contains(num)) return EasiGroup.upperExt;
  if ([4, 5, 12, 13, 14, 15, 16, 26, 27, 34, 35, 36, 37, 38, 39, 46].contains(num)) {
    return EasiGroup.trunk;
  }
  return EasiGroup.lowerExt;
}

EasiGroup groupForRegion(String regionId) => _groupFor(regionId);

// ─── Zone data ────────────────────────────────────────────────────────────────
//
// Coordinates are in the 220×500 logical canvas.
// FRONT: person faces viewer → viewer's left = person's right.
// BACK:  person faces away   → viewer's left = person's left.
//
// These polygons trace the medical diagram provided.

const kFrontRegions = <BodyRegion>[

  // ── HEAD ──────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z1', label: 'R. Scalp', number: 1, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(89, 6), Offset(110, 6), Offset(110, 54),
      Offset(101, 52), Offset(92, 42), Offset(89, 28),
    ],
  ),

  BodyRegion(
    id: 'z2', label: 'L. Scalp', number: 2, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(110, 6), Offset(131, 6), Offset(131, 28),
      Offset(128, 42), Offset(119, 52), Offset(110, 54),
    ],
  ),

  // ── NECK ──────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z3', label: 'Neck', number: 3, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(101, 54), Offset(119, 54), Offset(121, 76), Offset(99, 76),
    ],
  ),

  // ── CHEST / SHOULDERS ─────────────────────────────────────────────────────

  // Zone 4: right chest & shoulder (viewer's left)
  BodyRegion(
    id: 'z4', label: 'R. Chest', number: 4, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(58, 76), Offset(110, 76), Offset(110, 122), Offset(64, 122),
    ],
  ),

  // Zone 5: left chest & shoulder (viewer's right)
  BodyRegion(
    id: 'z5', label: 'L. Chest', number: 5, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 76), Offset(162, 76), Offset(156, 122), Offset(110, 122),
    ],
  ),

  // ── UPPER ARMS ────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z6', label: 'R. Upper Arm', number: 6, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(24, 80), Offset(56, 80), Offset(54, 168), Offset(22, 168),
    ],
  ),

  BodyRegion(
    id: 'z7', label: 'L. Upper Arm', number: 7, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(164, 80), Offset(196, 80), Offset(198, 168), Offset(166, 168),
    ],
  ),

  // ── FOREARMS ──────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z8', label: 'R. Forearm', number: 8, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(20, 168), Offset(54, 168), Offset(52, 220), Offset(18, 220),
    ],
  ),

  BodyRegion(
    id: 'z9', label: 'L. Forearm', number: 9, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(166, 168), Offset(200, 168), Offset(202, 220), Offset(168, 220),
    ],
  ),

  // ── HANDS ─────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z10', label: 'R. Hand', number: 10, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(14, 220), Offset(54, 220), Offset(56, 252), Offset(12, 248),
    ],
  ),

  BodyRegion(
    id: 'z11', label: 'L. Hand', number: 11, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(166, 220), Offset(206, 220), Offset(208, 248), Offset(164, 252),
    ],
  ),

  // ── UPPER ABDOMEN ─────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z12', label: 'R. Upper Abd.', number: 12, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(64, 122), Offset(110, 122), Offset(110, 168), Offset(68, 168),
    ],
  ),

  BodyRegion(
    id: 'z13', label: 'L. Upper Abd.', number: 13, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 122), Offset(156, 122), Offset(152, 168), Offset(110, 168),
    ],
  ),

  // ── LOWER ABDOMEN ─────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z14', label: 'R. Lower Abd.', number: 14, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(68, 168), Offset(110, 168), Offset(110, 215), Offset(72, 215),
    ],
  ),

  BodyRegion(
    id: 'z15', label: 'L. Lower Abd.', number: 15, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 168), Offset(152, 168), Offset(148, 215), Offset(110, 215),
    ],
  ),

  // Zone 16: groin / pubic area
  BodyRegion(
    id: 'z16', label: 'Groin', number: 16, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(97, 215), Offset(123, 215), Offset(122, 240), Offset(98, 240),
    ],
  ),

  // ── THIGHS ────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z17', label: 'R. Thigh', number: 17, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(68, 240), Offset(105, 240), Offset(101, 370), Offset(70, 370),
    ],
  ),

  BodyRegion(
    id: 'z18', label: 'L. Thigh', number: 18, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(115, 240), Offset(152, 240), Offset(150, 370), Offset(119, 370),
    ],
  ),

  // ── KNEES ─────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z49', label: 'R. Knee', number: 49, isFront: true, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(70, 370, 30, 22),
  ),

  BodyRegion(
    id: 'z50', label: 'L. Knee', number: 50, isFront: true, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(120, 370, 30, 22),
  ),

  // ── LOWER LEGS ────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z19', label: 'R. Shin', number: 19, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(73, 392), Offset(100, 392), Offset(97, 462), Offset(74, 462),
    ],
  ),

  BodyRegion(
    id: 'z20', label: 'L. Shin', number: 20, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(120, 392), Offset(147, 392), Offset(146, 462), Offset(123, 462),
    ],
  ),

  // ── FEET ──────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z21', label: 'R. Foot', number: 21, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(58, 462), Offset(100, 462), Offset(97, 484),
      Offset(70, 490), Offset(55, 480),
    ],
  ),

  BodyRegion(
    id: 'z22', label: 'L. Foot', number: 22, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(120, 462), Offset(162, 462), Offset(165, 480),
      Offset(150, 490), Offset(123, 484),
    ],
  ),
];

// ─── BACK regions (zones 23–48) ───────────────────────────────────────────────

const kBackRegions = <BodyRegion>[

  // ── HEAD (BACK) ───────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z23', label: 'R. Scalp (B)', number: 23, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(89, 6), Offset(110, 6), Offset(110, 54),
      Offset(101, 52), Offset(92, 42), Offset(89, 28),
    ],
  ),

  BodyRegion(
    id: 'z24', label: 'L. Scalp (B)', number: 24, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(110, 6), Offset(131, 6), Offset(131, 28),
      Offset(128, 42), Offset(119, 52), Offset(110, 54),
    ],
  ),

  BodyRegion(
    id: 'z25', label: 'Nape', number: 25, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(101, 54), Offset(119, 54), Offset(121, 76), Offset(99, 76),
    ],
  ),

  // ── UPPER BACK / SHOULDERS ────────────────────────────────────────────────

  // Zone 26: left upper back (viewer's left = person's left from behind)
  BodyRegion(
    id: 'z26', label: 'L. Upper Back', number: 26, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(58, 76), Offset(110, 76), Offset(110, 118), Offset(64, 118),
    ],
  ),

  // Zone 27: right upper back (viewer's right = person's right from behind)
  BodyRegion(
    id: 'z27', label: 'R. Upper Back', number: 27, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 76), Offset(162, 76), Offset(156, 118), Offset(110, 118),
    ],
  ),

  // ── UPPER ARMS (BACK) ─────────────────────────────────────────────────────

  BodyRegion(
    id: 'z28', label: 'L. Upper Arm (B)', number: 28, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(24, 80), Offset(56, 80), Offset(54, 168), Offset(22, 168),
    ],
  ),

  BodyRegion(
    id: 'z29', label: 'R. Upper Arm (B)', number: 29, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(164, 80), Offset(196, 80), Offset(198, 168), Offset(166, 168),
    ],
  ),

  // ── FOREARMS (BACK) ───────────────────────────────────────────────────────

  BodyRegion(
    id: 'z30', label: 'L. Forearm (B)', number: 30, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(20, 168), Offset(54, 168), Offset(52, 220), Offset(18, 220),
    ],
  ),

  BodyRegion(
    id: 'z31', label: 'R. Forearm (B)', number: 31, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(166, 168), Offset(200, 168), Offset(202, 220), Offset(168, 220),
    ],
  ),

  // ── HANDS (BACK) ──────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z32', label: 'L. Hand (B)', number: 32, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(14, 220), Offset(54, 220), Offset(56, 252), Offset(12, 248),
    ],
  ),

  BodyRegion(
    id: 'z33', label: 'R. Hand (B)', number: 33, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(166, 220), Offset(206, 220), Offset(208, 248), Offset(164, 252),
    ],
  ),

  // ── SCAPULAR / MID BACK ───────────────────────────────────────────────────

  // Zone 34: left scapular (viewer's left)
  BodyRegion(
    id: 'z34', label: 'L. Mid Back', number: 34, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(64, 118), Offset(110, 118), Offset(110, 168), Offset(68, 168),
    ],
  ),

  // Zone 35: right scapular (viewer's right)
  BodyRegion(
    id: 'z35', label: 'R. Mid Back', number: 35, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 118), Offset(156, 118), Offset(152, 168), Offset(110, 168),
    ],
  ),

  // ── LOWER BACK ────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z36', label: 'L. Lower Back', number: 36, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(68, 168), Offset(110, 168), Offset(110, 215), Offset(72, 215),
    ],
  ),

  BodyRegion(
    id: 'z37', label: 'R. Lower Back', number: 37, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 168), Offset(152, 168), Offset(148, 215), Offset(110, 215),
    ],
  ),

  // ── SACRUM ────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z46', label: 'Sacrum', number: 46, isFront: false, group: EasiGroup.trunk,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(103, 218, 14, 34),
  ),

  // ── BUTTOCKS ──────────────────────────────────────────────────────────────

  // Zone 38: left buttock (viewer's left = person's left from behind)
  BodyRegion(
    id: 'z38', label: 'L. Buttock', number: 38, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(70, 215), Offset(103, 215), Offset(107, 252),
      Offset(98, 270), Offset(74, 268), Offset(66, 250),
    ],
  ),

  // Zone 39: right buttock (viewer's right = person's right from behind)
  BodyRegion(
    id: 'z39', label: 'R. Buttock', number: 39, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(117, 215), Offset(150, 215), Offset(154, 250),
      Offset(146, 268), Offset(122, 270), Offset(113, 252),
    ],
  ),

  // ── THIGHS (BACK / HAMSTRINGS) ────────────────────────────────────────────

  BodyRegion(
    id: 'z40', label: 'L. Thigh (B)', number: 40, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(70, 270), Offset(104, 270), Offset(101, 370), Offset(70, 370),
    ],
  ),

  BodyRegion(
    id: 'z41', label: 'R. Thigh (B)', number: 41, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(116, 270), Offset(150, 270), Offset(150, 370), Offset(119, 370),
    ],
  ),

  // ── POPLITEAL / BACK OF KNEE ──────────────────────────────────────────────

  BodyRegion(
    id: 'z47', label: 'L. Back Knee', number: 47, isFront: false, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(70, 370, 30, 22),
  ),

  BodyRegion(
    id: 'z48', label: 'R. Back Knee', number: 48, isFront: false, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(120, 370, 30, 22),
  ),

  // ── CALVES ────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z42', label: 'L. Calf', number: 42, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(73, 392), Offset(100, 392), Offset(97, 462), Offset(74, 462),
    ],
  ),

  BodyRegion(
    id: 'z43', label: 'R. Calf', number: 43, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(120, 392), Offset(147, 392), Offset(146, 462), Offset(123, 462),
    ],
  ),

  // ── FEET (BACK / SOLE) ────────────────────────────────────────────────────

  BodyRegion(
    id: 'z44', label: 'L. Foot (B)', number: 44, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(58, 462), Offset(100, 462), Offset(97, 484),
      Offset(70, 490), Offset(55, 480),
    ],
  ),

  BodyRegion(
    id: 'z45', label: 'R. Foot (B)', number: 45, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(120, 462), Offset(162, 462), Offset(165, 480),
      Offset(150, 490), Offset(123, 484),
    ],
  ),
];

// ─── Convenience lookup ───────────────────────────────────────────────────────

BodyRegion? findRegion(String id) {
  try {
    return [...kFrontRegions, ...kBackRegions].firstWhere((r) => r.id == id);
  } catch (_) {
    return null;
  }
}
