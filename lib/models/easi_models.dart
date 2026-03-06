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
// Front body: left half (x ≈ 80–640, midline x≈360).
// Back body: right half (x ≈ 850–1460, midline x≈1155).
// Traced from the actual clinical medical diagram contours.
// Body-outline edges use 6–12 points to follow anatomical curves;
// internal zone boundaries (midlines, horizontal dividers) stay straighter.

const kFrontRegions = <BodyRegion>[

  // ── HEAD ──────────────────────────────────────────────────────────────────
  // The scalp is divided by the midline. Each half follows the skull curve.

  BodyRegion(
    id: 'z1', label: 'R. Scalp', number: 1, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(360, 25),   // top center (midline)
      Offset(332, 22),   // crown curves right
      Offset(310, 30),
      Offset(298, 48),
      Offset(292, 72),
      Offset(294, 98),
      Offset(304, 122),
      Offset(320, 140),
      Offset(340, 148),  // jawline meets neck
      Offset(360, 148),  // midline bottom
    ],
  ),

  BodyRegion(
    id: 'z2', label: 'L. Scalp', number: 2, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(360, 25),   // top center (midline)
      Offset(360, 148),  // midline bottom
      Offset(380, 148),  // jawline
      Offset(400, 140),
      Offset(416, 122),
      Offset(426, 98),
      Offset(428, 72),
      Offset(422, 48),
      Offset(410, 30),
      Offset(388, 22),
    ],
  ),

  // ── NECK ──────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z3', label: 'Neck', number: 3, isFront: true, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(330, 148), Offset(390, 148),
      Offset(395, 165), Offset(393, 183),
      Offset(327, 183), Offset(325, 165),
    ],
  ),

  // ── CHEST / SHOULDERS ─────────────────────────────────────────────────────
  // Outer edge follows the torso curve at armpit; inner edge is midline.

  BodyRegion(
    id: 'z4', label: 'R. Chest', number: 4, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(192, 190),  // armpit / shoulder junction
      Offset(240, 184),
      Offset(300, 183),
      Offset(360, 183),  // midline top
      Offset(360, 240),
      Offset(360, 297),  // midline bottom
      Offset(290, 298),
      Offset(220, 297),
      Offset(200, 258),
      Offset(192, 224),
    ],
  ),

  BodyRegion(
    id: 'z5', label: 'L. Chest', number: 5, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 183),  // midline top
      Offset(420, 183),
      Offset(480, 184),
      Offset(528, 190),  // armpit / shoulder junction
      Offset(528, 224),
      Offset(520, 258),
      Offset(500, 297),
      Offset(430, 298),
      Offset(360, 297),  // midline bottom
      Offset(360, 240),
    ],
  ),

  // ── UPPER ARMS ────────────────────────────────────────────────────────────
  // Arms taper slightly from shoulder to elbow. Outer edge follows silhouette.

  BodyRegion(
    id: 'z6', label: 'R. Upper Arm', number: 6, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(88, 195),   // outer shoulder
      Offset(140, 190),
      Offset(184, 195),  // inner shoulder (armpit side)
      Offset(186, 240),
      Offset(188, 300),
      Offset(188, 370),  // inner elbow
      Offset(140, 368),
      Offset(90, 362),   // outer elbow
      Offset(86, 300),
      Offset(84, 240),
    ],
  ),

  BodyRegion(
    id: 'z7', label: 'L. Upper Arm', number: 7, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(536, 195),  // inner shoulder (armpit side)
      Offset(580, 190),
      Offset(632, 195),  // outer shoulder
      Offset(636, 240),
      Offset(634, 300),
      Offset(630, 362),  // outer elbow
      Offset(580, 368),
      Offset(532, 370),  // inner elbow
      Offset(532, 300),
      Offset(534, 240),
    ],
  ),

  // ── FOREARMS ──────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z8', label: 'R. Forearm', number: 8, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(90, 374),   // outer elbow
      Offset(140, 374),
      Offset(188, 374),  // inner elbow
      Offset(190, 420),
      Offset(192, 470),
      Offset(192, 518),  // inner wrist
      Offset(140, 514),
      Offset(88, 506),   // outer wrist
      Offset(86, 460),
      Offset(86, 420),
    ],
  ),

  BodyRegion(
    id: 'z9', label: 'L. Forearm', number: 9, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(532, 374),  // inner elbow
      Offset(580, 374),
      Offset(630, 374),  // outer elbow
      Offset(632, 420),
      Offset(630, 460),
      Offset(628, 506),  // outer wrist
      Offset(580, 514),
      Offset(528, 518),  // inner wrist
      Offset(528, 470),
      Offset(530, 420),
    ],
  ),

  // ── HANDS ─────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z10', label: 'R. Hand', number: 10, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(76, 518),   // outer wrist
      Offset(140, 518),
      Offset(192, 518),  // inner wrist
      Offset(196, 555),
      Offset(198, 590),
      Offset(194, 617),  // fingertips inner
      Offset(140, 612),
      Offset(74, 604),   // fingertips outer
      Offset(72, 570),
    ],
  ),

  BodyRegion(
    id: 'z11', label: 'L. Hand', number: 11, isFront: true, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(528, 518),  // inner wrist
      Offset(580, 518),
      Offset(628, 518),  // outer wrist
      Offset(632, 570),
      Offset(630, 604),  // fingertips outer
      Offset(580, 612),
      Offset(526, 617),  // fingertips inner
      Offset(524, 590),
      Offset(524, 555),
    ],
  ),

  // ── UPPER ABDOMEN ─────────────────────────────────────────────────────────
  // Torso sides curve inward slightly at waist.

  BodyRegion(
    id: 'z12', label: 'R. Upper Abd.', number: 12, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(220, 297),  // outer top
      Offset(290, 298),
      Offset(360, 297),  // midline top
      Offset(360, 350),
      Offset(360, 412),  // midline bottom
      Offset(290, 413),
      Offset(225, 412),  // outer bottom
      Offset(216, 370),
      Offset(214, 330),
    ],
  ),

  BodyRegion(
    id: 'z13', label: 'L. Upper Abd.', number: 13, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 297),  // midline top
      Offset(430, 298),
      Offset(500, 297),  // outer top
      Offset(506, 330),
      Offset(504, 370),
      Offset(495, 412),  // outer bottom
      Offset(430, 413),
      Offset(360, 412),  // midline bottom
      Offset(360, 350),
    ],
  ),

  // ── LOWER ABDOMEN ─────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z14', label: 'R. Lower Abd.', number: 14, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(225, 412),  // outer top
      Offset(290, 413),
      Offset(360, 412),  // midline top
      Offset(360, 453),
      Offset(360, 494),  // midline bottom
      Offset(290, 496),
      Offset(234, 494),  // outer bottom (hip)
      Offset(228, 466),
      Offset(224, 438),
    ],
  ),

  BodyRegion(
    id: 'z15', label: 'L. Lower Abd.', number: 15, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 412),  // midline top
      Offset(430, 413),
      Offset(495, 412),  // outer top
      Offset(496, 438),
      Offset(492, 466),
      Offset(486, 494),  // outer bottom (hip)
      Offset(430, 496),
      Offset(360, 494),  // midline bottom
      Offset(360, 453),
    ],
  ),

  // ── GROIN ─────────────────────────────────────────────────────────────────
  // V-shaped zone between inner thighs.

  BodyRegion(
    id: 'z16', label: 'Groin', number: 16, isFront: true, group: EasiGroup.trunk,
    polyPoints: [
      Offset(310, 494),  // left hip
      Offset(340, 496),
      Offset(360, 498),  // center
      Offset(380, 496),
      Offset(410, 494),  // right hip
      Offset(406, 530),
      Offset(398, 558),  // inner thigh R
      Offset(360, 566),  // center bottom
      Offset(322, 558),  // inner thigh L
      Offset(314, 530),
    ],
  ),

  // ── THIGHS ────────────────────────────────────────────────────────────────
  // Thighs have curved outer edges following the body silhouette.
  // They taper from hip to knee.

  BodyRegion(
    id: 'z17', label: 'R. Thigh', number: 17, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(234, 558),  // outer hip
      Offset(270, 560),
      Offset(322, 558),  // inner groin
      Offset(338, 610),
      Offset(348, 660),
      Offset(350, 720),
      Offset(346, 768),  // inner knee
      Offset(290, 770),
      Offset(230, 768),  // outer knee
      Offset(218, 720),
      Offset(210, 660),
      Offset(212, 610),
    ],
  ),

  BodyRegion(
    id: 'z18', label: 'L. Thigh', number: 18, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(398, 558),  // inner groin
      Offset(450, 560),
      Offset(486, 558),  // outer hip
      Offset(508, 610),
      Offset(510, 660),
      Offset(502, 720),
      Offset(490, 768),  // outer knee
      Offset(430, 770),
      Offset(374, 768),  // inner knee
      Offset(370, 720),
      Offset(372, 660),
      Offset(382, 610),
    ],
  ),

  // ── KNEES (FRONT) ─────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z49', label: 'R. Knee', number: 49, isFront: true, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(216, 768, 134, 68),
  ),

  BodyRegion(
    id: 'z50', label: 'L. Knee', number: 50, isFront: true, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(370, 768, 134, 68),
  ),

  // ── SHINS ─────────────────────────────────────────────────────────────────
  // Shins taper from knee to ankle.

  BodyRegion(
    id: 'z19', label: 'R. Shin', number: 19, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(220, 836),  // outer top
      Offset(280, 838),
      Offset(342, 836),  // inner top
      Offset(340, 880),
      Offset(338, 930),
      Offset(334, 974),  // inner ankle
      Offset(278, 972),
      Offset(222, 968),  // outer ankle
      Offset(218, 930),
      Offset(216, 880),
    ],
  ),

  BodyRegion(
    id: 'z20', label: 'L. Shin', number: 20, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(378, 836),  // inner top
      Offset(430, 838),
      Offset(498, 836),  // outer top
      Offset(502, 880),
      Offset(500, 930),
      Offset(496, 968),  // outer ankle
      Offset(440, 972),
      Offset(382, 974),  // inner ankle
      Offset(380, 930),
      Offset(378, 880),
    ],
  ),

  // ── FEET ──────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z21', label: 'R. Foot', number: 21, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(210, 974),  // outer ankle
      Offset(270, 975),
      Offset(334, 974),  // inner ankle
      Offset(330, 1020),
      Offset(320, 1060),
      Offset(300, 1090),
      Offset(250, 1098),
      Offset(196, 1086),
      Offset(200, 1040),
    ],
  ),

  BodyRegion(
    id: 'z22', label: 'L. Foot', number: 22, isFront: true, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(382, 974),  // inner ankle
      Offset(440, 975),
      Offset(504, 974),  // outer ankle
      Offset(512, 1040),
      Offset(518, 1086),
      Offset(466, 1098),
      Offset(414, 1090),
      Offset(394, 1060),
      Offset(386, 1020),
    ],
  ),
];

// ─── BACK regions (zones 23–48) ───────────────────────────────────────────────

const kBackRegions = <BodyRegion>[

  // ── HEAD (BACK) ───────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z23', label: 'R. Scalp (B)', number: 23, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1155, 25),
      Offset(1128, 22),
      Offset(1106, 30),
      Offset(1094, 48),
      Offset(1088, 72),
      Offset(1090, 98),
      Offset(1100, 122),
      Offset(1116, 140),
      Offset(1136, 148),
      Offset(1155, 148),
    ],
  ),

  BodyRegion(
    id: 'z24', label: 'L. Scalp (B)', number: 24, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1155, 25),
      Offset(1155, 148),
      Offset(1174, 148),
      Offset(1194, 140),
      Offset(1210, 122),
      Offset(1220, 98),
      Offset(1222, 72),
      Offset(1216, 48),
      Offset(1204, 30),
      Offset(1182, 22),
    ],
  ),

  // ── NAPE ──────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z25', label: 'Nape', number: 25, isFront: false, group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1125, 148), Offset(1185, 148),
      Offset(1190, 165), Offset(1188, 183),
      Offset(1122, 183), Offset(1120, 165),
    ],
  ),

  // ── UPPER BACK / SHOULDERS ────────────────────────────────────────────────

  BodyRegion(
    id: 'z26', label: 'L. Upper Back', number: 26, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(962, 190),
      Offset(1020, 184),
      Offset(1090, 183),
      Offset(1155, 183),
      Offset(1155, 240),
      Offset(1155, 320),
      Offset(1080, 322),
      Offset(995, 320),
      Offset(975, 258),
      Offset(962, 224),
    ],
  ),

  BodyRegion(
    id: 'z27', label: 'R. Upper Back', number: 27, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 183),
      Offset(1220, 183),
      Offset(1290, 184),
      Offset(1348, 190),
      Offset(1348, 224),
      Offset(1335, 258),
      Offset(1315, 320),
      Offset(1230, 322),
      Offset(1155, 320),
      Offset(1155, 240),
    ],
  ),

  // ── UPPER ARMS (BACK) ─────────────────────────────────────────────────────

  BodyRegion(
    id: 'z28', label: 'L. Upper Arm (B)', number: 28, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(858, 195),
      Offset(908, 190),
      Offset(954, 195),
      Offset(956, 240),
      Offset(958, 300),
      Offset(958, 370),
      Offset(908, 368),
      Offset(860, 362),
      Offset(856, 300),
      Offset(854, 240),
    ],
  ),

  BodyRegion(
    id: 'z29', label: 'R. Upper Arm (B)', number: 29, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1356, 195),
      Offset(1402, 190),
      Offset(1452, 195),
      Offset(1456, 240),
      Offset(1454, 300),
      Offset(1450, 362),
      Offset(1402, 368),
      Offset(1352, 370),
      Offset(1352, 300),
      Offset(1354, 240),
    ],
  ),

  // ── FOREARMS (BACK) ───────────────────────────────────────────────────────

  BodyRegion(
    id: 'z30', label: 'L. Forearm (B)', number: 30, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(860, 374),
      Offset(908, 374),
      Offset(958, 374),
      Offset(960, 420),
      Offset(962, 470),
      Offset(962, 518),
      Offset(908, 514),
      Offset(858, 506),
      Offset(856, 460),
      Offset(856, 420),
    ],
  ),

  BodyRegion(
    id: 'z31', label: 'R. Forearm (B)', number: 31, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1352, 374),
      Offset(1402, 374),
      Offset(1450, 374),
      Offset(1452, 420),
      Offset(1454, 460),
      Offset(1452, 506),
      Offset(1402, 514),
      Offset(1348, 518),
      Offset(1348, 470),
      Offset(1350, 420),
    ],
  ),

  // ── HANDS (BACK) ──────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z32', label: 'L. Hand (B)', number: 32, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(846, 518),
      Offset(908, 518),
      Offset(962, 518),
      Offset(966, 555),
      Offset(968, 590),
      Offset(964, 617),
      Offset(908, 612),
      Offset(844, 604),
      Offset(842, 570),
    ],
  ),

  BodyRegion(
    id: 'z33', label: 'R. Hand (B)', number: 33, isFront: false, group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1348, 518),
      Offset(1402, 518),
      Offset(1452, 518),
      Offset(1456, 570),
      Offset(1454, 604),
      Offset(1402, 612),
      Offset(1346, 617),
      Offset(1342, 590),
      Offset(1344, 555),
    ],
  ),

  // ── MID BACK ──────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z34', label: 'L. Mid Back', number: 34, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(995, 320),
      Offset(1080, 322),
      Offset(1155, 320),
      Offset(1155, 375),
      Offset(1155, 438),
      Offset(1080, 440),
      Offset(1000, 438),
      Offset(992, 395),
      Offset(990, 355),
    ],
  ),

  BodyRegion(
    id: 'z35', label: 'R. Mid Back', number: 35, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 320),
      Offset(1230, 322),
      Offset(1315, 320),
      Offset(1320, 355),
      Offset(1318, 395),
      Offset(1310, 438),
      Offset(1230, 440),
      Offset(1155, 438),
      Offset(1155, 375),
    ],
  ),

  // ── LOWER BACK ────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z36', label: 'L. Lower Back', number: 36, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(1000, 438),
      Offset(1080, 440),
      Offset(1155, 438),
      Offset(1155, 480),
      Offset(1155, 522),
      Offset(1080, 524),
      Offset(1006, 522),
      Offset(998, 490),
      Offset(996, 460),
    ],
  ),

  BodyRegion(
    id: 'z37', label: 'R. Lower Back', number: 37, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 438),
      Offset(1230, 440),
      Offset(1310, 438),
      Offset(1314, 460),
      Offset(1312, 490),
      Offset(1304, 522),
      Offset(1230, 524),
      Offset(1155, 522),
      Offset(1155, 480),
    ],
  ),

  // ── SACRUM ────────────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z46', label: 'Sacrum', number: 46, isFront: false, group: EasiGroup.trunk,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(1118, 468, 74, 56),
  ),

  // ── BUTTOCKS ──────────────────────────────────────────────────────────────
  // Buttock zones have curved lower edges following the gluteal fold.

  BodyRegion(
    id: 'z38', label: 'L. Buttock', number: 38, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(970, 522),
      Offset(1040, 524),
      Offset(1118, 522),
      Offset(1116, 555),
      Offset(1108, 585),
      Offset(1090, 608),
      Offset(1060, 618),  // gluteal fold curve
      Offset(1010, 618),
      Offset(968, 612),
      Offset(960, 585),
      Offset(964, 555),
    ],
  ),

  BodyRegion(
    id: 'z39', label: 'R. Buttock', number: 39, isFront: false, group: EasiGroup.trunk,
    polyPoints: [
      Offset(1192, 522),
      Offset(1270, 524),
      Offset(1340, 522),
      Offset(1346, 555),
      Offset(1350, 585),
      Offset(1342, 612),
      Offset(1300, 618),
      Offset(1250, 618),  // gluteal fold curve
      Offset(1202, 608),
      Offset(1194, 585),
      Offset(1194, 555),
    ],
  ),

  // ── THIGHS (BACK) ─────────────────────────────────────────────────────────

  BodyRegion(
    id: 'z40', label: 'L. Thigh (B)', number: 40, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(960, 618),
      Offset(1020, 618),
      Offset(1090, 618),
      Offset(1148, 618),
      Offset(1150, 670),
      Offset(1148, 730),
      Offset(1142, 812),
      Offset(1060, 814),
      Offset(972, 812),
      Offset(960, 750),
      Offset(955, 680),
    ],
  ),

  BodyRegion(
    id: 'z41', label: 'R. Thigh (B)', number: 41, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1162, 618),
      Offset(1220, 618),
      Offset(1290, 618),
      Offset(1350, 618),
      Offset(1355, 680),
      Offset(1352, 750),
      Offset(1340, 812),
      Offset(1252, 814),
      Offset(1168, 812),
      Offset(1162, 730),
      Offset(1160, 670),
    ],
  ),

  // ── POPLITEAL / BACK OF KNEE ──────────────────────────────────────────────

  BodyRegion(
    id: 'z47', label: 'L. Back Knee', number: 47, isFront: false, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(960, 812, 130, 66),
  ),

  BodyRegion(
    id: 'z48', label: 'R. Back Knee', number: 48, isFront: false, group: EasiGroup.lowerExt,
    isEllipse: true,
    ellipseRect: Rect.fromLTWH(1160, 812, 130, 66),
  ),

  // ── CALVES ────────────────────────────────────────────────────────────────
  // Calves have a muscular bulge on the outer edge.

  BodyRegion(
    id: 'z42', label: 'L. Calf', number: 42, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(968, 878),
      Offset(1030, 880),
      Offset(1090, 878),
      Offset(1094, 920),
      Offset(1090, 960),
      Offset(1084, 1008),
      Offset(1030, 1006),
      Offset(968, 1008),
      Offset(964, 960),
      Offset(962, 920),
    ],
  ),

  BodyRegion(
    id: 'z43', label: 'R. Calf', number: 43, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1168, 878),
      Offset(1230, 880),
      Offset(1288, 878),
      Offset(1292, 920),
      Offset(1294, 960),
      Offset(1290, 1008),
      Offset(1230, 1006),
      Offset(1166, 1008),
      Offset(1162, 960),
      Offset(1164, 920),
    ],
  ),

  // ── FEET (BACK / SOLE) ────────────────────────────────────────────────────

  BodyRegion(
    id: 'z44', label: 'L. Foot (B)', number: 44, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(952, 1008),
      Offset(1020, 1010),
      Offset(1084, 1008),
      Offset(1082, 1050),
      Offset(1072, 1090),
      Offset(1010, 1115),
      Offset(940, 1108),
      Offset(942, 1060),
    ],
  ),

  BodyRegion(
    id: 'z45', label: 'R. Foot (B)', number: 45, isFront: false, group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1166, 1008),
      Offset(1240, 1010),
      Offset(1310, 1008),
      Offset(1316, 1060),
      Offset(1322, 1108),
      Offset(1252, 1115),
      Offset(1188, 1090),
      Offset(1178, 1050),
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
