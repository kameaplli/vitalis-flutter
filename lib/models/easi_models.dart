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
  // Hit-test geometry in 440×500 SVG canvas space.
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

  // Hit-test: returns true when [pt] (in 440×500 canvas space) is inside this zone.
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
// Coordinates match the body_map.svg (440×500 viewBox).
// FRONT: left half of SVG (x ≈ 63–157, centred at x=110).
// BACK:  right half of SVG (x ≈ 283–377, centred at x=330).
//
// Polygon points are traced directly from SVG element coordinates.

const kFrontRegions = <BodyRegion>[

  // ── HEAD ──────────────────────────────────────────────────────────────────
  // f_head: ellipse cx=110, cy=38, rx=22, ry=26 — split at midline x=110.

  BodyRegion(
    id: 'z1', label: 'R. Scalp', number: 1, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(88, 12), Offset(110, 12), Offset(110, 64),
      Offset(102, 62), Offset(92, 52), Offset(88, 28),
    ],
  ),

  BodyRegion(
    id: 'z2', label: 'L. Scalp', number: 2, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(110, 12), Offset(132, 12), Offset(132, 28),
      Offset(128, 52), Offset(118, 62), Offset(110, 64),
    ],
  ),

  // ── NECK ──────────────────────────────────────────────────────────────────
  // f_neck: rect x=102 y=63 w=16 h=12

  BodyRegion(
    id: 'z3', label: 'Neck', number: 3, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(102, 63), Offset(118, 63), Offset(118, 75), Offset(102, 75),
    ],
  ),

  // ── CHEST / SHOULDERS ─────────────────────────────────────────────────────
  // f_chest_r (M103,75 L118,75 L118,105 L103,105) + f_shoulder_r (cx=82,cy=80)
  // Combined bounding zone covering right shoulder + right chest.

  BodyRegion(
    id: 'z4', label: 'R. Chest', number: 4, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(69, 76), Offset(118, 76), Offset(118, 105), Offset(64, 105),
    ],
  ),

  BodyRegion(
    id: 'z5', label: 'L. Chest', number: 5, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(118, 76), Offset(151, 76), Offset(156, 105), Offset(118, 105),
    ],
  ),

  // ── UPPER ARMS ────────────────────────────────────────────────────────────
  // f_upper_arm_r: M70,76 L83,76 L85,120 L69,118

  BodyRegion(
    id: 'z6', label: 'R. Upper Arm', number: 6, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(70, 76), Offset(83, 76), Offset(85, 120), Offset(69, 118),
    ],
  ),

  // f_upper_arm_l: M137,76 L150,76 L151,118 L135,120

  BodyRegion(
    id: 'z7', label: 'L. Upper Arm', number: 7, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(137, 76), Offset(150, 76), Offset(151, 118), Offset(135, 120),
    ],
  ),

  // ── FOREARMS (incl. elbow) ────────────────────────────────────────────────
  // f_elbow_r: cx=77,cy=122; f_forearm_r: M69,127 L85,127 L87,168 L67,165

  BodyRegion(
    id: 'z8', label: 'R. Forearm', number: 8, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(69, 116), Offset(85, 116), Offset(87, 168), Offset(67, 165),
    ],
  ),

  // f_elbow_l: cx=143,cy=122; f_forearm_l: M135,127 L151,127 L153,165 L133,168

  BodyRegion(
    id: 'z9', label: 'L. Forearm', number: 9, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(133, 116), Offset(151, 116), Offset(153, 165), Offset(133, 168),
    ],
  ),

  // ── HANDS ─────────────────────────────────────────────────────────────────
  // f_hand_r: rect x=63 y=168 w=24 h=20

  BodyRegion(
    id: 'z10', label: 'R. Hand', number: 10, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(63, 168), Offset(87, 168), Offset(87, 188), Offset(63, 188),
    ],
  ),

  // f_hand_l: rect x=133 y=168 w=24 h=20

  BodyRegion(
    id: 'z11', label: 'L. Hand', number: 11, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(133, 168), Offset(157, 168), Offset(157, 188), Offset(133, 188),
    ],
  ),

  // ── UPPER ABDOMEN ─────────────────────────────────────────────────────────
  // f_abdomen_r: M104,105 L118,105 L118,138 L106,138

  BodyRegion(
    id: 'z12', label: 'R. Upper Abd.', number: 12, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(104, 105), Offset(118, 105), Offset(118, 138), Offset(106, 138),
    ],
  ),

  // f_abdomen_l: M118,105 L132,105 L130,138 L118,138

  BodyRegion(
    id: 'z13', label: 'L. Upper Abd.', number: 13, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(118, 105), Offset(132, 105), Offset(130, 138), Offset(118, 138),
    ],
  ),

  // ── LOWER ABDOMEN ─────────────────────────────────────────────────────────
  // f_lower_abd: M106,138 L130,138 L128,155 L108,155 — split at midline x=118.

  BodyRegion(
    id: 'z14', label: 'R. Lower Abd.', number: 14, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(106, 138), Offset(118, 138), Offset(118, 155), Offset(108, 155),
    ],
  ),

  BodyRegion(
    id: 'z15', label: 'L. Lower Abd.', number: 15, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(118, 138), Offset(130, 138), Offset(128, 155), Offset(118, 155),
    ],
  ),

  // Zone 16: groin / pubic area (below lower abdomen, between upper thighs).

  BodyRegion(
    id: 'z16', label: 'Groin', number: 16, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(108, 155), Offset(128, 155), Offset(127, 168), Offset(109, 168),
    ],
  ),

  // ── THIGHS ────────────────────────────────────────────────────────────────
  // f_thigh_r: M106,155 L118,155 L117,200 L104,200

  BodyRegion(
    id: 'z17', label: 'R. Thigh', number: 17, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(106, 155), Offset(118, 155), Offset(117, 200), Offset(104, 200),
    ],
  ),

  // f_thigh_l: M118,155 L130,155 L132,200 L119,200

  BodyRegion(
    id: 'z18', label: 'L. Thigh', number: 18, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(118, 155), Offset(130, 155), Offset(132, 200), Offset(119, 200),
    ],
  ),

  // ── KNEES ─────────────────────────────────────────────────────────────────
  // f_knee_r: ellipse cx=110, cy=206, rx=8, ry=8

  BodyRegion(
    id: 'z49', label: 'R. Knee', number: 49, isFront: true, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(102, 198, 16, 16),
  ),

  // f_knee_l: ellipse cx=126, cy=206, rx=8, ry=8

  BodyRegion(
    id: 'z50', label: 'L. Knee', number: 50, isFront: true, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(118, 198, 16, 16),
  ),

  // ── LOWER LEGS ────────────────────────────────────────────────────────────
  // f_shin_r: M102,214 L118,214 L116,260 L103,258

  BodyRegion(
    id: 'z19', label: 'R. Shin', number: 19, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(102, 214), Offset(118, 214), Offset(116, 260), Offset(103, 258),
    ],
  ),

  // f_shin_l: M118,214 L134,214 L133,258 L120,260

  BodyRegion(
    id: 'z20', label: 'L. Shin', number: 20, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(118, 214), Offset(134, 214), Offset(133, 258), Offset(120, 260),
    ],
  ),

  // ── FEET ──────────────────────────────────────────────────────────────────
  // f_foot_r: rect x=100 y=261 w=18 h=14

  BodyRegion(
    id: 'z21', label: 'R. Foot', number: 21, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(100, 261), Offset(118, 261), Offset(118, 275), Offset(100, 275),
    ],
  ),

  // f_foot_l: rect x=120 y=261 w=18 h=14

  BodyRegion(
    id: 'z22', label: 'L. Foot', number: 22, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(120, 261), Offset(138, 261), Offset(138, 275), Offset(120, 275),
    ],
  ),
];

// ─── BACK regions (zones 23–48) ───────────────────────────────────────────────
// Back body centred at x=330 in the SVG.

const kBackRegions = <BodyRegion>[

  // ── HEAD (BACK) ───────────────────────────────────────────────────────────
  // b_head: ellipse cx=330, cy=38, rx=22, ry=26 — split at midline x=330.

  BodyRegion(
    id: 'z23', label: 'R. Scalp (B)', number: 23, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(308, 12), Offset(330, 12), Offset(330, 64),
      Offset(322, 62), Offset(312, 52), Offset(308, 28),
    ],
  ),

  BodyRegion(
    id: 'z24', label: 'L. Scalp (B)', number: 24, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(330, 12), Offset(352, 12), Offset(352, 28),
      Offset(348, 52), Offset(338, 62), Offset(330, 64),
    ],
  ),

  // ── NAPE ──────────────────────────────────────────────────────────────────
  // b_neck: rect x=322 y=63 w=16 h=12

  BodyRegion(
    id: 'z25', label: 'Nape', number: 25, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(322, 63), Offset(338, 63), Offset(338, 75), Offset(322, 75),
    ],
  ),

  // ── UPPER BACK / SHOULDERS ────────────────────────────────────────────────
  // b_upper_back_r (M323,75 L338,75 L338,108 L323,108) + b_shoulder_r (cx=302,cy=80)

  BodyRegion(
    id: 'z26', label: 'L. Upper Back', number: 26, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(289, 76), Offset(338, 76), Offset(338, 108), Offset(302, 108), Offset(289, 88),
    ],
  ),

  // b_upper_back_l (M338,75 L353,75 L353,108 L338,108) + b_shoulder_l (cx=358,cy=80)

  BodyRegion(
    id: 'z27', label: 'R. Upper Back', number: 27, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(338, 76), Offset(371, 76), Offset(371, 88), Offset(358, 108), Offset(338, 108),
    ],
  ),

  // ── UPPER ARMS (BACK) ─────────────────────────────────────────────────────
  // b_upper_arm_r: M290,76 L303,76 L305,120 L289,118

  BodyRegion(
    id: 'z28', label: 'L. Upper Arm (B)', number: 28, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(290, 76), Offset(303, 76), Offset(305, 120), Offset(289, 118),
    ],
  ),

  // b_upper_arm_l: M357,76 L370,76 L371,118 L355,120

  BodyRegion(
    id: 'z29', label: 'R. Upper Arm (B)', number: 29, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(357, 76), Offset(370, 76), Offset(371, 118), Offset(355, 120),
    ],
  ),

  // ── FOREARMS (BACK, incl. elbow) ──────────────────────────────────────────
  // b_elbow_r: cx=297,cy=122; b_forearm_r: M289,127 L305,127 L307,168 L287,165

  BodyRegion(
    id: 'z30', label: 'L. Forearm (B)', number: 30, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(289, 116), Offset(305, 116), Offset(307, 168), Offset(287, 165),
    ],
  ),

  // b_elbow_l: cx=363,cy=122; b_forearm_l: M355,127 L371,127 L373,165 L353,168

  BodyRegion(
    id: 'z31', label: 'R. Forearm (B)', number: 31, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(355, 116), Offset(371, 116), Offset(373, 165), Offset(353, 168),
    ],
  ),

  // ── HANDS (BACK) ──────────────────────────────────────────────────────────
  // b_hand_r: rect x=283 y=168 w=24 h=20

  BodyRegion(
    id: 'z32', label: 'L. Hand (B)', number: 32, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(283, 168), Offset(307, 168), Offset(307, 188), Offset(283, 188),
    ],
  ),

  // b_hand_l: rect x=353 y=168 w=24 h=20

  BodyRegion(
    id: 'z33', label: 'R. Hand (B)', number: 33, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(353, 168), Offset(377, 168), Offset(377, 188), Offset(353, 188),
    ],
  ),

  // ── MID BACK ──────────────────────────────────────────────────────────────
  // b_mid_back_r: M323,108 L338,108 L338,138 L324,138

  BodyRegion(
    id: 'z34', label: 'L. Mid Back', number: 34, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(323, 108), Offset(338, 108), Offset(338, 138), Offset(324, 138),
    ],
  ),

  // b_mid_back_l: M338,108 L353,108 L352,138 L338,138

  BodyRegion(
    id: 'z35', label: 'R. Mid Back', number: 35, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(338, 108), Offset(353, 108), Offset(352, 138), Offset(338, 138),
    ],
  ),

  // ── LOWER BACK ────────────────────────────────────────────────────────────
  // b_lower_back: M324,138 L352,138 L350,155 L326,155 — split at midline x=338.

  BodyRegion(
    id: 'z36', label: 'L. Lower Back', number: 36, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(324, 138), Offset(338, 138), Offset(337, 155), Offset(325, 155),
    ],
  ),

  BodyRegion(
    id: 'z37', label: 'R. Lower Back', number: 37, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(338, 138), Offset(352, 138), Offset(350, 155), Offset(337, 155),
    ],
  ),

  // ── SACRUM ────────────────────────────────────────────────────────────────
  // Narrow zone between buttocks (centred at midline x=338).

  BodyRegion(
    id: 'z46', label: 'Sacrum', number: 46, isFront: false, group: EasiGroup.trunk,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(334, 155, 8, 24),
  ),

  // ── BUTTOCKS ──────────────────────────────────────────────────────────────
  // b_buttock_r: M325,155 L338,155 L337,185 L323,183

  BodyRegion(
    id: 'z38', label: 'L. Buttock', number: 38, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(325, 155), Offset(338, 155), Offset(337, 185), Offset(323, 183),
    ],
  ),

  // b_buttock_l: M338,155 L351,155 L353,183 L339,185

  BodyRegion(
    id: 'z39', label: 'R. Buttock', number: 39, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(338, 155), Offset(351, 155), Offset(353, 183), Offset(339, 185),
    ],
  ),

  // ── THIGHS (BACK / HAMSTRINGS) ────────────────────────────────────────────
  // b_thigh_r: M325,185 L338,185 L337,218 L323,218

  BodyRegion(
    id: 'z40', label: 'L. Thigh (B)', number: 40, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(325, 185), Offset(338, 185), Offset(337, 218), Offset(323, 218),
    ],
  ),

  // b_thigh_l: M338,185 L351,185 L353,218 L339,218

  BodyRegion(
    id: 'z41', label: 'R. Thigh (B)', number: 41, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(338, 185), Offset(351, 185), Offset(353, 218), Offset(339, 218),
    ],
  ),

  // ── POPLITEAL / BACK OF KNEE ──────────────────────────────────────────────
  // b_knee_r: ellipse cx=330, cy=224, rx=8, ry=8

  BodyRegion(
    id: 'z47', label: 'L. Back Knee', number: 47, isFront: false, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(322, 216, 16, 16),
  ),

  // b_knee_l: ellipse cx=346, cy=224, rx=8, ry=8

  BodyRegion(
    id: 'z48', label: 'R. Back Knee', number: 48, isFront: false, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(338, 216, 16, 16),
  ),

  // ── CALVES ────────────────────────────────────────────────────────────────
  // b_calf_r: M322,232 L338,232 L336,272 L323,270

  BodyRegion(
    id: 'z42', label: 'L. Calf', number: 42, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(322, 232), Offset(338, 232), Offset(336, 272), Offset(323, 270),
    ],
  ),

  // b_calf_l: M338,232 L354,232 L353,270 L340,272

  BodyRegion(
    id: 'z43', label: 'R. Calf', number: 43, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(338, 232), Offset(354, 232), Offset(353, 270), Offset(340, 272),
    ],
  ),

  // ── FEET (BACK / SOLE) ────────────────────────────────────────────────────
  // b_foot_r: rect x=320 y=273 w=18 h=14

  BodyRegion(
    id: 'z44', label: 'L. Foot (B)', number: 44, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(320, 273), Offset(338, 273), Offset(338, 287), Offset(320, 287),
    ],
  ),

  // b_foot_l: rect x=340 y=273 w=18 h=14

  BodyRegion(
    id: 'z45', label: 'R. Foot (B)', number: 45, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(340, 273), Offset(358, 273), Offset(358, 287), Offset(340, 287),
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
