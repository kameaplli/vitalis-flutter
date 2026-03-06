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
  // Hit-test geometry in 1548×1134 image pixel space.
  final List<Offset> polyPoints;
  final bool isEllipse;
  final Rect ellipseRect;

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
  // ── EASI core (affect score) ─────────────────────────────────────────────
  final int erythema;        // Redness
  final int papulation;      // Bumps & Swelling
  final int excoriation;     // Scratch Marks
  final int lichenification; // Skin Thickening
  final int areaScore;
  // ── Supplementary (stored, not in EASI calc) ─────────────────────────────
  final int oozing;          // Weeping / Crusting            (SCORAD)
  final int dryness;         // Dryness / Flaking             (POEM/SCORAD)
  final int pigmentation;    // Skin Darkening / PIH          (research)

  const EasiRegionScore({
    required this.regionId,
    this.erythema = 0,
    this.papulation = 0,
    this.excoriation = 0,
    this.lichenification = 0,
    this.areaScore = 1,
    this.oozing = 0,
    this.dryness = 0,
    this.pigmentation = 0,
  });

  // EASI uses only the 4 core attributes; oozing/dryness are supplementary.
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
    'oozing': oozing,
    'dryness': dryness,
    'pigmentation': pigmentation,
  };

  factory EasiRegionScore.fromJson(Map<String, dynamic> json) {
    return EasiRegionScore(
      regionId: json['area'] as String? ?? '',
      erythema: (json['erythema'] as num?)?.toInt() ?? 0,
      papulation: (json['papulation'] as num?)?.toInt() ?? 0,
      excoriation: (json['excoriation'] as num?)?.toInt() ?? 0,
      lichenification: (json['lichenification'] as num?)?.toInt() ?? 0,
      areaScore: (json['area_score'] as num?)?.toInt() ?? 1,
      oozing: (json['oozing'] as num?)?.toInt() ?? 0,
      dryness: (json['dryness'] as num?)?.toInt() ?? 0,
      pigmentation: (json['pigmentation'] as num?)?.toInt() ?? 0,
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
// Coordinates match body_map_clinical.png (1548×1134 pixels).
// Front body: left half (x ≈ 90–640, midline x=360).
// Back body: right half (x ≈ 860–1450, midline x=1155).
// Traced from grid analysis of the actual clinical medical diagram.

const kFrontRegions = <BodyRegion>[

  // ── HEAD ──────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z1', label: 'R. Scalp', number: 1, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(306, 28), Offset(360, 28), Offset(360, 148),
      Offset(340, 143), Offset(318, 126), Offset(306, 88),
    ],
  ),

  BodyRegion(
    id: 'z2', label: 'L. Scalp', number: 2, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(360, 28), Offset(414, 28), Offset(414, 88),
      Offset(402, 126), Offset(380, 143), Offset(360, 148),
    ],
  ),

  // ── NECK ──────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z3', label: 'Neck', number: 3, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(330, 148), Offset(390, 148), Offset(393, 183), Offset(327, 183),
    ],
  ),

  // ── CHEST / SHOULDERS ─────────────────────────────────────────────────────

  BodyRegion(
    id: 'z4', label: 'R. Chest', number: 4, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(185, 183), Offset(360, 183), Offset(360, 297),
      Offset(218, 297), Offset(185, 235),
    ],
  ),

  BodyRegion(
    id: 'z5', label: 'L. Chest', number: 5, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 183), Offset(535, 183), Offset(535, 235),
      Offset(502, 297), Offset(360, 297),
    ],
  ),

  // ── UPPER ARMS ────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z6', label: 'R. Upper Arm', number: 6, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(90, 195), Offset(182, 195), Offset(187, 374), Offset(92, 362),
    ],
  ),

  BodyRegion(
    id: 'z7', label: 'L. Upper Arm', number: 7, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(538, 195), Offset(630, 195), Offset(628, 362), Offset(533, 374),
    ],
  ),

  // ── FOREARMS ──────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z8', label: 'R. Forearm', number: 8, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(92, 374), Offset(187, 374), Offset(191, 518), Offset(90, 506),
    ],
  ),

  BodyRegion(
    id: 'z9', label: 'L. Forearm', number: 9, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(533, 362), Offset(628, 374), Offset(626, 506), Offset(529, 518),
    ],
  ),

  // ── HANDS ─────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z10', label: 'R. Hand', number: 10, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(78, 518), Offset(191, 518), Offset(194, 617), Offset(76, 604),
    ],
  ),

  BodyRegion(
    id: 'z11', label: 'L. Hand', number: 11, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(529, 506), Offset(626, 518), Offset(628, 604), Offset(524, 617),
    ],
  ),

  // ── UPPER ABDOMEN ─────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z12', label: 'R. Upper Abd.', number: 12, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(218, 297), Offset(360, 297), Offset(360, 412), Offset(225, 412),
    ],
  ),

  BodyRegion(
    id: 'z13', label: 'L. Upper Abd.', number: 13, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 297), Offset(502, 297), Offset(495, 412), Offset(360, 412),
    ],
  ),

  // ── LOWER ABDOMEN ─────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z14', label: 'R. Lower Abd.', number: 14, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(225, 412), Offset(360, 412), Offset(360, 494), Offset(232, 494),
    ],
  ),

  BodyRegion(
    id: 'z15', label: 'L. Lower Abd.', number: 15, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 412), Offset(495, 412), Offset(488, 494), Offset(360, 494),
    ],
  ),

  // ── GROIN ─────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z16', label: 'Groin', number: 16, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(310, 494), Offset(410, 494), Offset(406, 562), Offset(314, 562),
    ],
  ),

  // ── THIGHS ────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z17', label: 'R. Thigh', number: 17, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(234, 562), Offset(354, 562), Offset(346, 768), Offset(228, 768),
    ],
  ),

  BodyRegion(
    id: 'z18', label: 'L. Thigh', number: 18, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(366, 562), Offset(486, 562), Offset(482, 768), Offset(358, 768),
    ],
  ),

  // ── KNEES (FRONT) ─────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z49', label: 'R. Knee', number: 49, isFront: true, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(222, 768, 116, 68),
  ),

  BodyRegion(
    id: 'z50', label: 'L. Knee', number: 50, isFront: true, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(364, 768, 116, 68),
  ),

  // ── SHINS ─────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z19', label: 'R. Shin', number: 19, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(226, 836), Offset(342, 836), Offset(336, 974), Offset(224, 974),
    ],
  ),

  BodyRegion(
    id: 'z20', label: 'L. Shin', number: 20, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(366, 836), Offset(482, 836), Offset(476, 974), Offset(362, 974),
    ],
  ),

  // ── FEET ──────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z21', label: 'R. Foot', number: 21, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(204, 974), Offset(342, 974), Offset(335, 1098),
      Offset(190, 1086),
    ],
  ),

  BodyRegion(
    id: 'z22', label: 'L. Foot', number: 22, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(366, 974), Offset(504, 974), Offset(516, 1086),
      Offset(366, 1098),
    ],
  ),
];

// ─── BACK regions (zones 23–48) ───────────────────────────────────────────────

const kBackRegions = <BodyRegion>[

  // ── HEAD (BACK) ───────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z23', label: 'R. Scalp (B)', number: 23, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1095, 28), Offset(1155, 28), Offset(1155, 148),
      Offset(1135, 143), Offset(1115, 126), Offset(1095, 88),
    ],
  ),

  BodyRegion(
    id: 'z24', label: 'L. Scalp (B)', number: 24, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1155, 28), Offset(1215, 28), Offset(1215, 88),
      Offset(1195, 126), Offset(1175, 143), Offset(1155, 148),
    ],
  ),

  // ── NAPE ──────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z25', label: 'Nape', number: 25, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1120, 148), Offset(1190, 148), Offset(1193, 183), Offset(1117, 183),
    ],
  ),

  // ── UPPER BACK / SHOULDERS ────────────────────────────────────────────────

  BodyRegion(
    id: 'z26', label: 'L. Upper Back', number: 26, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(958, 183), Offset(1155, 183), Offset(1155, 320),
      Offset(990, 320), Offset(958, 235),
    ],
  ),

  BodyRegion(
    id: 'z27', label: 'R. Upper Back', number: 27, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 183), Offset(1352, 183), Offset(1352, 235),
      Offset(1320, 320), Offset(1155, 320),
    ],
  ),

  // ── UPPER ARMS (BACK) ─────────────────────────────────────────────────────

  BodyRegion(
    id: 'z28', label: 'L. Upper Arm (B)', number: 28, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(860, 195), Offset(952, 195), Offset(957, 374), Offset(862, 362),
    ],
  ),

  BodyRegion(
    id: 'z29', label: 'R. Upper Arm (B)', number: 29, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1358, 195), Offset(1450, 195), Offset(1448, 362), Offset(1353, 374),
    ],
  ),

  // ── FOREARMS (BACK) ───────────────────────────────────────────────────────

  BodyRegion(
    id: 'z30', label: 'L. Forearm (B)', number: 30, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(862, 374), Offset(957, 374), Offset(962, 518), Offset(860, 506),
    ],
  ),

  BodyRegion(
    id: 'z31', label: 'R. Forearm (B)', number: 31, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1353, 362), Offset(1448, 374), Offset(1450, 506), Offset(1348, 518),
    ],
  ),

  // ── HANDS (BACK) ──────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z32', label: 'L. Hand (B)', number: 32, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(848, 518), Offset(962, 518), Offset(965, 617), Offset(846, 604),
    ],
  ),

  BodyRegion(
    id: 'z33', label: 'R. Hand (B)', number: 33, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1348, 506), Offset(1450, 518), Offset(1452, 604), Offset(1344, 617),
    ],
  ),

  // ── MID BACK ──────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z34', label: 'L. Mid Back', number: 34, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(990, 320), Offset(1155, 320), Offset(1155, 438), Offset(997, 438),
    ],
  ),

  BodyRegion(
    id: 'z35', label: 'R. Mid Back', number: 35, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 320), Offset(1320, 320), Offset(1313, 438), Offset(1155, 438),
    ],
  ),

  // ── LOWER BACK ────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z36', label: 'L. Lower Back', number: 36, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(997, 438), Offset(1155, 438), Offset(1155, 522), Offset(1004, 522),
    ],
  ),

  BodyRegion(
    id: 'z37', label: 'R. Lower Back', number: 37, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 438), Offset(1313, 438), Offset(1306, 522), Offset(1155, 522),
    ],
  ),

  // ── SACRUM ────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z46', label: 'Sacrum', number: 46, isFront: false, group: EasiGroup.trunk,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(1118, 468, 74, 56),
  ),

  // ── BUTTOCKS ──────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z38', label: 'L. Buttock', number: 38, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(968, 522), Offset(1118, 522), Offset(1115, 614), Offset(960, 614),
    ],
  ),

  BodyRegion(
    id: 'z39', label: 'R. Buttock', number: 39, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(1192, 522), Offset(1342, 522), Offset(1350, 614), Offset(1195, 614),
    ],
  ),

  // ── THIGHS (BACK) ─────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z40', label: 'L. Thigh (B)', number: 40, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(960, 614), Offset(1148, 614), Offset(1141, 812), Offset(962, 812),
    ],
  ),

  BodyRegion(
    id: 'z41', label: 'R. Thigh (B)', number: 41, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1162, 614), Offset(1350, 614), Offset(1352, 812), Offset(1164, 812),
    ],
  ),

  // ── POPLITEAL / BACK OF KNEE ──────────────────────────────────────────────

  BodyRegion(
    id: 'z47', label: 'L. Back Knee', number: 47, isFront: false, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(966, 812, 118, 66),
  ),

  BodyRegion(
    id: 'z48', label: 'R. Back Knee', number: 48, isFront: false, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(1164, 812, 118, 66),
  ),

  // ── CALVES ────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z42', label: 'L. Calf', number: 42, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(970, 878), Offset(1090, 878), Offset(1084, 1008), Offset(968, 1008),
    ],
  ),

  BodyRegion(
    id: 'z43', label: 'R. Calf', number: 43, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1164, 878), Offset(1284, 878), Offset(1288, 1008), Offset(1166, 1008),
    ],
  ),

  // ── FEET (BACK / SOLE) ────────────────────────────────────────────────────

  BodyRegion(
    id: 'z44', label: 'L. Foot (B)', number: 44, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(950, 1008), Offset(1090, 1008), Offset(1082, 1120),
      Offset(934, 1108),
    ],
  ),

  BodyRegion(
    id: 'z45', label: 'R. Foot (B)', number: 45, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1166, 1008), Offset(1306, 1008), Offset(1320, 1108),
      Offset(1168, 1120),
    ],
  ),
];

// ─── Drawn Patch ──────────────────────────────────────────────────────────────
// Represents one freehand stroke drawn on the body map.
// Coordinates are in 1548×1134 image pixel space.

class DrawnPatch {
  final String zoneId;       // auto-detected zone this patch belongs to
  final List<Offset> points; // stroke points in image pixel space
  final int severity;        // 0-3

  const DrawnPatch({
    required this.zoneId,
    required this.points,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
    'zone_id': zoneId,
    'severity': severity,
    // Store as rounded int pairs to keep payload small
    'pts': points.map((p) => [p.dx.round(), p.dy.round()]).toList(),
  };

  factory DrawnPatch.fromJson(Map<String, dynamic> json) {
    return DrawnPatch(
      zoneId: json['zone_id'] as String? ?? '',
      severity: (json['severity'] as num?)?.toInt() ?? 1,
      points: (json['pts'] as List? ?? []).expand((p) {
        if (p is List && p.length >= 2) {
          return [Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())];
        }
        return <Offset>[];
      }).toList(),
    );
  }
}

// ─── Convenience lookup ───────────────────────────────────────────────────────

BodyRegion? findRegion(String id) {
  try {
    return [...kFrontRegions, ...kBackRegions].firstWhere((r) => r.id == id);
  } catch (_) {
    return null;
  }
}
