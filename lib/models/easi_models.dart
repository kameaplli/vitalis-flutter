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
  // All fields are public so the painter can access them without reflection.
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

  // Ray-casting polygon hit-test (static so it can be called without an instance).
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

  // 0–10 level for colour display.
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
  // Extract numeric portion of the zone id (e.g. 'z12' → 12).
  final numStr = id.replaceAll(RegExp(r'[^0-9]'), '');
  final num = int.tryParse(numStr) ?? 0;
  // Head & Neck: 1, 2, 3, 23, 24, 25
  if ([1, 2, 3, 23, 24, 25].contains(num)) return EasiGroup.headNeck;
  // Upper Extremities: upper arms, forearms, hands
  if ([6, 7, 8, 9, 10, 11, 28, 29, 30, 31, 32, 33].contains(num)) return EasiGroup.upperExt;
  // Trunk: chest, abdomen, back, groin, buttocks, sacrum
  if ([4, 5, 12, 13, 14, 15, 16, 26, 27, 34, 35, 36, 37, 38, 39, 46].contains(num)) {
    return EasiGroup.trunk;
  }
  // Lower Extremities: thighs, knees, legs, ankles, feet
  return EasiGroup.lowerExt;
}

EasiGroup groupForRegion(String regionId) => _groupFor(regionId);

// ─── Zone data — 220×500 canvas ───────────────────────────────────────────────
//
// All coordinates are in the 220×500 logical canvas used by the body painter.
// "Viewer's left" = person's right (for front view, where person faces you).
// "Viewer's left" = person's left  (for back view, where person faces away).
//
// Polygon vertices are listed roughly clockwise from top-left.

const kFrontRegions = <BodyRegion>[

  // ── HEAD ──────────────────────────────────────────────────────────────────

  // Zone 1: Person's right scalp (viewer's left half of head)
  BodyRegion(
    id: 'z1', label: 'R. Scalp', number: 1, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(88, 6), Offset(110, 6), Offset(110, 56),
      Offset(100, 57), Offset(96, 52), Offset(90, 42), Offset(88, 32),
    ],
  ),

  // Zone 2: Person's left scalp (viewer's right half of head)
  BodyRegion(
    id: 'z2', label: 'L. Scalp', number: 2, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(110, 6), Offset(132, 6), Offset(132, 32),
      Offset(130, 42), Offset(124, 52), Offset(120, 57), Offset(110, 56),
    ],
  ),

  // Zone 3: Neck / throat (front)
  BodyRegion(
    id: 'z3', label: 'Neck', number: 3, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(102, 57), Offset(118, 57), Offset(120, 76), Offset(100, 76),
    ],
  ),

  // ── CHEST ─────────────────────────────────────────────────────────────────

  // Zone 4: Person's right chest / pec (viewer's left)
  BodyRegion(
    id: 'z4', label: 'R. Chest', number: 4, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(68, 76), Offset(110, 76), Offset(110, 115), Offset(68, 115),
    ],
  ),

  // Zone 5: Person's left chest / pec (viewer's right)
  BodyRegion(
    id: 'z5', label: 'L. Chest', number: 5, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 76), Offset(152, 76), Offset(152, 115), Offset(110, 115),
    ],
  ),

  // ── UPPER ARMS ────────────────────────────────────────────────────────────

  // Zone 6: Person's right upper arm (viewer's left arm)
  BodyRegion(
    id: 'z6', label: 'R. Upper Arm', number: 6, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(44, 82), Offset(68, 82), Offset(68, 161), Offset(44, 161),
    ],
  ),

  // Zone 7: Person's left upper arm (viewer's right arm)
  BodyRegion(
    id: 'z7', label: 'L. Upper Arm', number: 7, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(152, 82), Offset(176, 82), Offset(176, 161), Offset(152, 161),
    ],
  ),

  // ── FOREARMS ──────────────────────────────────────────────────────────────

  // Zone 8: Person's right forearm
  BodyRegion(
    id: 'z8', label: 'R. Forearm', number: 8, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(43, 162), Offset(67, 162), Offset(67, 218), Offset(43, 218),
    ],
  ),

  // Zone 9: Person's left forearm
  BodyRegion(
    id: 'z9', label: 'L. Forearm', number: 9, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(153, 162), Offset(177, 162), Offset(177, 218), Offset(153, 218),
    ],
  ),

  // ── HANDS ─────────────────────────────────────────────────────────────────

  // Zone 10: Person's right hand (front / palm)
  BodyRegion(
    id: 'z10', label: 'R. Hand', number: 10, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(42, 218), Offset(68, 218), Offset(68, 242), Offset(42, 242),
    ],
  ),

  // Zone 11: Person's left hand (front / palm)
  BodyRegion(
    id: 'z11', label: 'L. Hand', number: 11, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(152, 218), Offset(178, 218), Offset(178, 242), Offset(152, 242),
    ],
  ),

  // ── UPPER ABDOMEN ─────────────────────────────────────────────────────────

  // Zone 12: Person's right upper abdomen (viewer's left)
  BodyRegion(
    id: 'z12', label: 'R. Upper Abd.', number: 12, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(68, 115), Offset(110, 115), Offset(110, 162), Offset(68, 162),
    ],
  ),

  // Zone 13: Person's left upper abdomen (viewer's right)
  BodyRegion(
    id: 'z13', label: 'L. Upper Abd.', number: 13, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 115), Offset(152, 115), Offset(152, 162), Offset(110, 162),
    ],
  ),

  // ── LOWER ABDOMEN ─────────────────────────────────────────────────────────

  // Zone 14: Person's right lower abdomen
  BodyRegion(
    id: 'z14', label: 'R. Lower Abd.', number: 14, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(68, 162), Offset(110, 162), Offset(110, 208), Offset(68, 208),
    ],
  ),

  // Zone 15: Person's left lower abdomen
  BodyRegion(
    id: 'z15', label: 'L. Lower Abd.', number: 15, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 162), Offset(152, 162), Offset(152, 208), Offset(110, 208),
    ],
  ),

  // Zone 16: Groin / pubic area (centre)
  BodyRegion(
    id: 'z16', label: 'Groin', number: 16, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(98, 208), Offset(122, 208), Offset(122, 230), Offset(98, 230),
    ],
  ),

  // ── THIGHS ────────────────────────────────────────────────────────────────

  // Zone 17: Person's right thigh (front)
  BodyRegion(
    id: 'z17', label: 'R. Thigh', number: 17, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(72, 228), Offset(98, 228), Offset(98, 350), Offset(72, 350),
    ],
  ),

  // Zone 18: Person's left thigh (front)
  BodyRegion(
    id: 'z18', label: 'L. Thigh', number: 18, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(122, 228), Offset(148, 228), Offset(148, 350), Offset(122, 350),
    ],
  ),

  // ── KNEES ─────────────────────────────────────────────────────────────────

  // Zone 49: Person's right knee (front) — ellipse
  BodyRegion(
    id: 'z49', label: 'R. Knee', number: 49, isFront: true, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(72, 350, 26, 14),
  ),

  // Zone 50: Person's left knee (front) — ellipse
  BodyRegion(
    id: 'z50', label: 'L. Knee', number: 50, isFront: true, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(122, 350, 26, 14),
  ),

  // ── LOWER LEGS ────────────────────────────────────────────────────────────

  // Zone 19: Person's right shin / lower leg (front)
  BodyRegion(
    id: 'z19', label: 'R. Shin', number: 19, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(76, 364), Offset(95, 364), Offset(95, 452), Offset(76, 452),
    ],
  ),

  // Zone 20: Person's left shin / lower leg (front)
  BodyRegion(
    id: 'z20', label: 'L. Shin', number: 20, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(125, 364), Offset(144, 364), Offset(144, 452), Offset(125, 452),
    ],
  ),

  // ── FEET ──────────────────────────────────────────────────────────────────

  // Zone 21: Person's right foot (front / dorsal)
  BodyRegion(
    id: 'z21', label: 'R. Foot', number: 21, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(60, 452), Offset(97, 452), Offset(97, 474),
      Offset(78, 478), Offset(62, 473),
    ],
  ),

  // Zone 22: Person's left foot (front / dorsal)
  BodyRegion(
    id: 'z22', label: 'L. Foot', number: 22, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(123, 452), Offset(160, 452), Offset(158, 473),
      Offset(142, 478), Offset(123, 474),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// BACK regions (zones 23–48)
// In the back view the person is facing away, so "viewer's left" = person's left.
// ─────────────────────────────────────────────────────────────────────────────

const kBackRegions = <BodyRegion>[

  // ── HEAD (BACK) ───────────────────────────────────────────────────────────

  // Zone 23: Person's right scalp / occiput (viewer's left)
  BodyRegion(
    id: 'z23', label: 'R. Scalp (B)', number: 23, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(88, 6), Offset(110, 6), Offset(110, 56),
      Offset(100, 57), Offset(96, 52), Offset(90, 42), Offset(88, 32),
    ],
  ),

  // Zone 24: Person's left scalp / occiput (viewer's right)
  BodyRegion(
    id: 'z24', label: 'L. Scalp (B)', number: 24, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(110, 6), Offset(132, 6), Offset(132, 32),
      Offset(130, 42), Offset(124, 52), Offset(120, 57), Offset(110, 56),
    ],
  ),

  // Zone 25: Nape / back of neck
  BodyRegion(
    id: 'z25', label: 'Nape', number: 25, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(102, 57), Offset(118, 57), Offset(120, 76), Offset(100, 76),
    ],
  ),

  // ── UPPER BACK ────────────────────────────────────────────────────────────

  // Zone 26: Person's right upper back / shoulder (viewer's left)
  BodyRegion(
    id: 'z26', label: 'R. Upper Back', number: 26, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(68, 76), Offset(110, 76), Offset(110, 115), Offset(68, 115),
    ],
  ),

  // Zone 27: Person's left upper back / shoulder (viewer's right)
  BodyRegion(
    id: 'z27', label: 'L. Upper Back', number: 27, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 76), Offset(152, 76), Offset(152, 115), Offset(110, 115),
    ],
  ),

  // ── UPPER ARMS (BACK) ─────────────────────────────────────────────────────

  // Zone 28: Person's right upper arm (back)
  BodyRegion(
    id: 'z28', label: 'R. Upper Arm (B)', number: 28, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(44, 82), Offset(68, 82), Offset(68, 161), Offset(44, 161),
    ],
  ),

  // Zone 29: Person's left upper arm (back)
  BodyRegion(
    id: 'z29', label: 'L. Upper Arm (B)', number: 29, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(152, 82), Offset(176, 82), Offset(176, 161), Offset(152, 161),
    ],
  ),

  // ── FOREARMS (BACK) ───────────────────────────────────────────────────────

  // Zone 30: Person's right forearm (back)
  BodyRegion(
    id: 'z30', label: 'R. Forearm (B)', number: 30, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(43, 162), Offset(67, 162), Offset(67, 218), Offset(43, 218),
    ],
  ),

  // Zone 31: Person's left forearm (back)
  BodyRegion(
    id: 'z31', label: 'L. Forearm (B)', number: 31, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(153, 162), Offset(177, 162), Offset(177, 218), Offset(153, 218),
    ],
  ),

  // ── HANDS (BACK) ──────────────────────────────────────────────────────────

  // Zone 32: Person's right hand (back / dorsum)
  BodyRegion(
    id: 'z32', label: 'R. Hand (B)', number: 32, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(42, 218), Offset(68, 218), Offset(68, 242), Offset(42, 242),
    ],
  ),

  // Zone 33: Person's left hand (back / dorsum)
  BodyRegion(
    id: 'z33', label: 'L. Hand (B)', number: 33, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(152, 218), Offset(178, 218), Offset(178, 242), Offset(152, 242),
    ],
  ),

  // ── MID BACK ──────────────────────────────────────────────────────────────

  // Zone 34: Person's right mid back (trapezius / lats, viewer's left)
  BodyRegion(
    id: 'z34', label: 'R. Mid Back', number: 34, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(68, 115), Offset(110, 115), Offset(110, 155), Offset(68, 155),
    ],
  ),

  // Zone 35: Person's left mid back (viewer's right)
  BodyRegion(
    id: 'z35', label: 'L. Mid Back', number: 35, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 115), Offset(152, 115), Offset(152, 155), Offset(110, 155),
    ],
  ),

  // ── LOWER BACK ────────────────────────────────────────────────────────────

  // Zone 36: Person's right lower back / lumbar (viewer's left)
  BodyRegion(
    id: 'z36', label: 'R. Lower Back', number: 36, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(68, 155), Offset(110, 155), Offset(110, 185), Offset(68, 185),
    ],
  ),

  // Zone 37: Person's left lower back / lumbar (viewer's right)
  BodyRegion(
    id: 'z37', label: 'L. Lower Back', number: 37, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(110, 155), Offset(152, 155), Offset(152, 185), Offset(110, 185),
    ],
  ),

  // ── BUTTOCKS ──────────────────────────────────────────────────────────────

  // Zone 38: Person's right buttock (viewer's left)
  BodyRegion(
    id: 'z38', label: 'R. Buttock', number: 38, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(72, 185), Offset(101, 185), Offset(101, 232), Offset(72, 232),
    ],
  ),

  // Zone 39: Person's left buttock (viewer's right)
  BodyRegion(
    id: 'z39', label: 'L. Buttock', number: 39, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(119, 185), Offset(148, 185), Offset(148, 232), Offset(119, 232),
    ],
  ),

  // Zone 46: Sacrum (small oval, centre between buttocks)
  BodyRegion(
    id: 'z46', label: 'Sacrum', number: 46, isFront: false, group: EasiGroup.trunk,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(101, 185, 18, 47),
  ),

  // ── THIGHS (BACK / HAMSTRINGS) ────────────────────────────────────────────

  // Zone 40: Person's right thigh (back)
  BodyRegion(
    id: 'z40', label: 'R. Thigh (B)', number: 40, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(72, 232), Offset(98, 232), Offset(98, 350), Offset(72, 350),
    ],
  ),

  // Zone 41: Person's left thigh (back)
  BodyRegion(
    id: 'z41', label: 'L. Thigh (B)', number: 41, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(122, 232), Offset(148, 232), Offset(148, 350), Offset(122, 350),
    ],
  ),

  // ── ANKLES / HEELS ────────────────────────────────────────────────────────

  // Zone 47: Person's right ankle / heel — ellipse straddling the knee separator
  BodyRegion(
    id: 'z47', label: 'R. Ankle', number: 47, isFront: false, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(74, 350, 22, 14),
  ),

  // Zone 48: Person's left ankle / heel
  BodyRegion(
    id: 'z48', label: 'L. Ankle', number: 48, isFront: false, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(124, 350, 22, 14),
  ),

  // ── CALVES ────────────────────────────────────────────────────────────────

  // Zone 42: Person's right calf (back)
  BodyRegion(
    id: 'z42', label: 'R. Calf', number: 42, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(76, 364), Offset(95, 364), Offset(95, 452), Offset(76, 452),
    ],
  ),

  // Zone 43: Person's left calf (back)
  BodyRegion(
    id: 'z43', label: 'L. Calf', number: 43, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(125, 364), Offset(144, 364), Offset(144, 452), Offset(125, 452),
    ],
  ),

  // ── FEET (BACK / HEEL / SOLE) ─────────────────────────────────────────────

  // Zone 44: Person's right foot (back / sole)
  BodyRegion(
    id: 'z44', label: 'R. Foot (B)', number: 44, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(60, 452), Offset(97, 452), Offset(97, 474),
      Offset(78, 478), Offset(62, 473),
    ],
  ),

  // Zone 45: Person's left foot (back / sole)
  BodyRegion(
    id: 'z45', label: 'L. Foot (B)', number: 45, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(123, 452), Offset(160, 452), Offset(158, 473),
      Offset(142, 478), Offset(123, 474),
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
