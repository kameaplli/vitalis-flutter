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
  final int number;
  final bool isFront;
  final EasiGroup group;
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
    for (final p in polyPoints) { sx += p.dx; sy += p.dy; }
    return Offset(sx / polyPoints.length, sy / polyPoints.length);
  }

  bool contains(Offset pt) {
    if (isEllipse) {
      final c = ellipseRect.center;
      final rx = ellipseRect.width / 2, ry = ellipseRect.height / 2;
      if (rx <= 0 || ry <= 0) return false;
      final dx = (pt.dx - c.dx) / rx, dy = (pt.dy - c.dy) / ry;
      return dx * dx + dy * dy <= 1.0;
    }
    return _pip(pt, polyPoints);
  }

  static bool _pip(Offset pt, List<Offset> poly) {
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
  final int erythema;
  final int papulation;
  final int excoriation;
  final int lichenification;
  final int areaScore;
  final int oozing;
  final int dryness;
  final int pigmentation;

  const EasiRegionScore({
    required this.regionId,
    this.erythema = 0, this.papulation = 0,
    this.excoriation = 0, this.lichenification = 0,
    this.areaScore = 1,
    this.oozing = 0, this.dryness = 0, this.pigmentation = 0,
  });

  int get attributeSum => erythema + papulation + excoriation + lichenification;
  int get level => (attributeSum / 12.0 * 10).round();
  double easiContribution(EasiGroup group) =>
      attributeSum * areaScore * group.multiplier;

  Map<String, dynamic> toJson() => {
    'area': regionId, 'erythema': erythema, 'papulation': papulation,
    'excoriation': excoriation, 'lichenification': lichenification,
    'area_score': areaScore, 'level': level,
    'oozing': oozing, 'dryness': dryness, 'pigmentation': pigmentation,
  };

  factory EasiRegionScore.fromJson(Map<String, dynamic> j) => EasiRegionScore(
    regionId: j['area'] as String? ?? '',
    erythema: (j['erythema'] as num?)?.toInt() ?? 0,
    papulation: (j['papulation'] as num?)?.toInt() ?? 0,
    excoriation: (j['excoriation'] as num?)?.toInt() ?? 0,
    lichenification: (j['lichenification'] as num?)?.toInt() ?? 0,
    areaScore: (j['area_score'] as num?)?.toInt() ?? 1,
    oozing: (j['oozing'] as num?)?.toInt() ?? 0,
    dryness: (j['dryness'] as num?)?.toInt() ?? 0,
    pigmentation: (j['pigmentation'] as num?)?.toInt() ?? 0,
  );
}

// ─── EASI Score ───────────────────────────────────────────────────────────────

class EasiScore {
  final List<EasiRegionScore> scores;
  const EasiScore(this.scores);

  double get total {
    double s = 0;
    for (final sc in scores) s += sc.easiContribution(groupForRegion(sc.regionId));
    return s;
  }

  String get severityLabel {
    final t = total;
    if (t == 0) return 'Clear'; if (t <= 1) return 'Almost Clear';
    if (t <= 7) return 'Mild';  if (t <= 21) return 'Moderate';
    if (t <= 50) return 'Severe'; return 'Very Severe';
  }

  Color get color {
    final t = total;
    if (t == 0) return const Color(0xFF4CAF50); if (t <= 1) return const Color(0xFF8BC34A);
    if (t <= 7) return const Color(0xFFFFC107); if (t <= 21) return const Color(0xFFFF9800);
    if (t <= 50) return const Color(0xFFFF5722); return const Color(0xFFF44336);
  }
}

// ─── Group lookup ─────────────────────────────────────────────────────────────

EasiGroup groupForRegion(String regionId) {
  final n = int.tryParse(regionId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  if ([1,2,3,23,24,25].contains(n)) return EasiGroup.headNeck;
  if ([6,7,8,9,10,11,28,29,30,31,32,33].contains(n)) return EasiGroup.upperExt;
  if ([4,5,12,13,14,15,16,26,27,34,35,36,37,38,39,46].contains(n)) return EasiGroup.trunk;
  return EasiGroup.lowerExt;
}

// ─── Zone data ────────────────────────────────────────────────────────────────
// Coordinates in body_map_clinical.png pixel space (1548 × 1134).
// Front body midline x=360.  Back body midline x=1155.
// Silhouette edges traced with 15-50 pts per zone for smooth curves.
// Internal zone dividers use fewer points (mostly straight lines).
//
// FRONT: zones 1-22, 49-50
// BACK:  zones 23-48

const kFrontRegions = <BodyRegion>[

  // ════════════════════════════════════════════════════════════════════════════
  // HEAD & NECK
  // ════════════════════════════════════════════════════════════════════════════

  // z1 — R. Scalp (right half of head, clockwise from top-center)
  BodyRegion(
    id: 'z1', label: 'R. Scalp', number: 1, isFront: true,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(360, 20),  // top center
      Offset(350, 18), Offset(340, 17), Offset(330, 18), Offset(322, 22),
      Offset(314, 28), Offset(307, 36), Offset(301, 46), Offset(297, 58),
      Offset(294, 70), Offset(292, 84), Offset(291, 98), Offset(292, 112),
      Offset(295, 124), Offset(300, 134), Offset(308, 142), Offset(318, 148),
      Offset(330, 152), Offset(345, 153), Offset(360, 153), // jaw → midline
    ],
  ),

  // z2 — L. Scalp (left half of head, clockwise from top-center)
  BodyRegion(
    id: 'z2', label: 'L. Scalp', number: 2, isFront: true,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(360, 20),  // top center
      Offset(360, 153), // midline bottom
      Offset(375, 153), Offset(390, 152), Offset(402, 148), Offset(412, 142),
      Offset(420, 134), Offset(425, 124), Offset(428, 112), Offset(429, 98),
      Offset(428, 84), Offset(426, 70), Offset(423, 58), Offset(419, 46),
      Offset(413, 36), Offset(406, 28), Offset(398, 22), Offset(390, 18),
      Offset(380, 17), Offset(370, 18),
    ],
  ),

  // z3 — Neck
  BodyRegion(
    id: 'z3', label: 'Neck', number: 3, isFront: true,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(330, 153), Offset(345, 153), Offset(360, 153),
      Offset(375, 153), Offset(390, 153),
      Offset(392, 160), Offset(394, 168), Offset(396, 176), Offset(396, 183),
      Offset(360, 183),
      Offset(324, 183), Offset(324, 176), Offset(326, 168), Offset(328, 160),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // CHEST & SHOULDERS
  // ════════════════════════════════════════════════════════════════════════════

  // z4 — R. Chest (clockwise: midline-top → shoulder → torso-side → bottom → midline)
  BodyRegion(
    id: 'z4', label: 'R. Chest', number: 4, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      // top edge (shoulder line, midline → armpit)
      Offset(360, 183), Offset(340, 183), Offset(320, 184), Offset(300, 186),
      Offset(280, 188), Offset(260, 190), Offset(240, 192), Offset(220, 194),
      Offset(204, 196), Offset(192, 198),
      // right edge (torso lateral, shoulder → chest line)
      Offset(194, 210), Offset(197, 225), Offset(200, 240), Offset(204, 255),
      Offset(208, 270), Offset(212, 285), Offset(218, 298),
      // bottom edge (chest line → midline)
      Offset(240, 299), Offset(260, 299), Offset(280, 298), Offset(300, 298),
      Offset(320, 297), Offset(340, 297), Offset(360, 297),
    ],
  ),

  // z5 — L. Chest (mirror of z4)
  BodyRegion(
    id: 'z5', label: 'L. Chest', number: 5, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 183), Offset(360, 297),
      Offset(380, 297), Offset(400, 297), Offset(420, 298), Offset(440, 298),
      Offset(460, 299), Offset(480, 299), Offset(502, 298),
      Offset(508, 285), Offset(512, 270), Offset(516, 255), Offset(520, 240),
      Offset(523, 225), Offset(526, 210), Offset(528, 198),
      Offset(516, 196), Offset(500, 194), Offset(480, 192), Offset(460, 190),
      Offset(440, 188), Offset(420, 186), Offset(400, 184), Offset(380, 183),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // UPPER ARMS
  // ════════════════════════════════════════════════════════════════════════════

  // z6 — R. Upper Arm (clockwise: outer-shoulder → outer-elbow → inner-elbow → inner-shoulder)
  BodyRegion(
    id: 'z6', label: 'R. Upper Arm', number: 6, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      // outer edge (shoulder → elbow)
      Offset(88, 198), Offset(87, 215), Offset(86, 232), Offset(85, 250),
      Offset(84, 268), Offset(83, 286), Offset(82, 304), Offset(81, 322),
      Offset(80, 340), Offset(80, 356), Offset(82, 370), Offset(84, 374),
      // bottom (elbow line)
      Offset(110, 374), Offset(140, 374), Offset(168, 374), Offset(190, 374),
      // inner edge (elbow → shoulder)
      Offset(190, 358), Offset(189, 342), Offset(189, 326), Offset(189, 310),
      Offset(189, 294), Offset(189, 278), Offset(189, 262), Offset(189, 246),
      Offset(190, 230), Offset(190, 214), Offset(192, 198),
      // top (shoulder line)
      Offset(168, 197), Offset(140, 196), Offset(112, 197),
    ],
  ),

  // z7 — L. Upper Arm (mirror of z6)
  BodyRegion(
    id: 'z7', label: 'L. Upper Arm', number: 7, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(528, 198), Offset(530, 214), Offset(530, 230), Offset(531, 246),
      Offset(531, 262), Offset(531, 278), Offset(531, 294), Offset(531, 310),
      Offset(531, 326), Offset(531, 342), Offset(530, 358), Offset(530, 374),
      Offset(552, 374), Offset(580, 374), Offset(610, 374), Offset(636, 374),
      Offset(638, 370), Offset(640, 356), Offset(640, 340), Offset(639, 322),
      Offset(638, 304), Offset(637, 286), Offset(636, 268), Offset(635, 250),
      Offset(634, 232), Offset(633, 215), Offset(632, 198),
      Offset(608, 197), Offset(580, 196), Offset(552, 197),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // FOREARMS
  // ════════════════════════════════════════════════════════════════════════════

  // z8 — R. Forearm
  BodyRegion(
    id: 'z8', label: 'R. Forearm', number: 8, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(84, 374), Offset(83, 392), Offset(81, 410), Offset(80, 428),
      Offset(79, 446), Offset(78, 464), Offset(77, 482), Offset(78, 500),
      Offset(78, 510),
      Offset(110, 510), Offset(145, 510), Offset(178, 510), Offset(196, 510),
      Offset(196, 496), Offset(195, 478), Offset(195, 460), Offset(194, 442),
      Offset(194, 424), Offset(193, 406), Offset(192, 388), Offset(190, 374),
      Offset(168, 374), Offset(140, 374), Offset(110, 374),
    ],
  ),

  // z9 — L. Forearm (mirror)
  BodyRegion(
    id: 'z9', label: 'L. Forearm', number: 9, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(530, 374), Offset(528, 388), Offset(527, 406), Offset(526, 424),
      Offset(526, 442), Offset(525, 460), Offset(525, 478), Offset(524, 496),
      Offset(524, 510),
      Offset(542, 510), Offset(575, 510), Offset(610, 510), Offset(642, 510),
      Offset(642, 500), Offset(643, 482), Offset(641, 464), Offset(641, 446),
      Offset(640, 428), Offset(639, 410), Offset(637, 392), Offset(636, 374),
      Offset(610, 374), Offset(580, 374), Offset(552, 374),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // HANDS
  // ════════════════════════════════════════════════════════════════════════════

  // z10 — R. Hand
  BodyRegion(
    id: 'z10', label: 'R. Hand', number: 10, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(78, 510), Offset(76, 528), Offset(74, 546), Offset(72, 564),
      Offset(71, 582), Offset(72, 600), Offset(74, 615),
      Offset(95, 616), Offset(120, 616), Offset(148, 616), Offset(175, 616),
      Offset(196, 614),
      Offset(198, 598), Offset(198, 580), Offset(198, 562), Offset(198, 544),
      Offset(196, 526), Offset(196, 510),
      Offset(178, 510), Offset(145, 510), Offset(110, 510),
    ],
  ),

  // z11 — L. Hand (mirror)
  BodyRegion(
    id: 'z11', label: 'L. Hand', number: 11, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(524, 510), Offset(524, 526), Offset(522, 544), Offset(522, 562),
      Offset(522, 580), Offset(522, 598), Offset(524, 614),
      Offset(545, 616), Offset(572, 616), Offset(600, 616), Offset(625, 616),
      Offset(646, 615),
      Offset(648, 600), Offset(649, 582), Offset(648, 564), Offset(646, 546),
      Offset(644, 528), Offset(642, 510),
      Offset(610, 510), Offset(575, 510), Offset(542, 510),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // UPPER ABDOMEN
  // ════════════════════════════════════════════════════════════════════════════

  // z12 — R. Upper Abd.
  BodyRegion(
    id: 'z12', label: 'R. Upper Abd.', number: 12, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(218, 298), Offset(222, 314), Offset(224, 332), Offset(226, 350),
      Offset(228, 368), Offset(228, 386), Offset(228, 400), Offset(228, 412),
      Offset(250, 412), Offset(280, 412), Offset(310, 412), Offset(340, 412),
      Offset(360, 412), Offset(360, 380), Offset(360, 350), Offset(360, 320),
      Offset(360, 297),
      Offset(340, 297), Offset(320, 297), Offset(300, 298), Offset(280, 298),
      Offset(260, 299), Offset(240, 299),
    ],
  ),

  // z13 — L. Upper Abd. (mirror)
  BodyRegion(
    id: 'z13', label: 'L. Upper Abd.', number: 13, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 297), Offset(360, 320), Offset(360, 350), Offset(360, 380),
      Offset(360, 412),
      Offset(380, 412), Offset(410, 412), Offset(440, 412), Offset(470, 412),
      Offset(492, 412),
      Offset(492, 400), Offset(492, 386), Offset(492, 368), Offset(494, 350),
      Offset(496, 332), Offset(498, 314), Offset(502, 298),
      Offset(480, 299), Offset(460, 299), Offset(440, 298), Offset(420, 298),
      Offset(400, 297), Offset(380, 297),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // LOWER ABDOMEN
  // ════════════════════════════════════════════════════════════════════════════

  // z14 — R. Lower Abd.
  BodyRegion(
    id: 'z14', label: 'R. Lower Abd.', number: 14, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(228, 412), Offset(226, 428), Offset(225, 444), Offset(224, 460),
      Offset(224, 476), Offset(224, 492), Offset(224, 498),
      Offset(250, 498), Offset(280, 498), Offset(312, 498),
      Offset(340, 498), Offset(360, 498),
      Offset(360, 470), Offset(360, 440), Offset(360, 412),
      Offset(340, 412), Offset(310, 412), Offset(280, 412), Offset(250, 412),
    ],
  ),

  // z15 — L. Lower Abd. (mirror)
  BodyRegion(
    id: 'z15', label: 'L. Lower Abd.', number: 15, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 412), Offset(360, 440), Offset(360, 470), Offset(360, 498),
      Offset(380, 498), Offset(408, 498),
      Offset(440, 498), Offset(470, 498), Offset(496, 498),
      Offset(496, 492), Offset(496, 476), Offset(496, 460), Offset(495, 444),
      Offset(494, 428), Offset(492, 412),
      Offset(470, 412), Offset(440, 412), Offset(410, 412), Offset(380, 412),
    ],
  ),

  // z16 — Groin (V-shaped)
  BodyRegion(
    id: 'z16', label: 'Groin', number: 16, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(312, 498), Offset(325, 498), Offset(340, 498), Offset(360, 498),
      Offset(380, 498), Offset(395, 498), Offset(408, 498),
      Offset(404, 512), Offset(398, 524), Offset(392, 536), Offset(384, 546),
      Offset(376, 554), Offset(368, 558), Offset(360, 560),
      Offset(352, 558), Offset(344, 554), Offset(336, 546), Offset(328, 536),
      Offset(322, 524), Offset(316, 512),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // THIGHS  (largest zones — many silhouette points)
  // ════════════════════════════════════════════════════════════════════════════

  // z17 — R. Thigh (clockwise: outer-hip → outer-knee → inner-knee → inner-groin → groin-boundary)
  BodyRegion(
    id: 'z17', label: 'R. Thigh', number: 17, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      // top edge (hip → groin boundary)
      Offset(224, 498), Offset(220, 508), Offset(216, 518),
      Offset(312, 498),
      // groin boundary (shared with z16, going down-right)
      Offset(316, 512), Offset(322, 524), Offset(328, 536), Offset(336, 546),
      Offset(344, 554), Offset(352, 558),
      // inner thigh edge (groin → knee, going down)
      Offset(354, 572), Offset(354, 590), Offset(354, 608), Offset(354, 626),
      Offset(354, 644), Offset(354, 662), Offset(353, 680), Offset(352, 698),
      Offset(350, 716), Offset(348, 734), Offset(346, 752), Offset(344, 768),
      Offset(342, 782),
      // bottom (knee top line)
      Offset(320, 782), Offset(300, 782), Offset(280, 782), Offset(260, 782),
      Offset(240, 782), Offset(228, 782),
      // outer thigh edge (knee → hip, going up — body silhouette)
      Offset(224, 770), Offset(220, 756), Offset(216, 742), Offset(213, 728),
      Offset(210, 714), Offset(207, 700), Offset(205, 686), Offset(203, 672),
      Offset(202, 658), Offset(201, 644), Offset(201, 630), Offset(202, 616),
      Offset(203, 602), Offset(205, 588), Offset(207, 574), Offset(210, 560),
      Offset(212, 546), Offset(214, 532),
    ],
  ),

  // z18 — L. Thigh (mirror of z17)
  BodyRegion(
    id: 'z18', label: 'L. Thigh', number: 18, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(408, 498), Offset(504, 518), Offset(500, 508), Offset(496, 498),
      Offset(506, 532), Offset(508, 546), Offset(510, 560), Offset(512, 574),
      Offset(515, 588), Offset(517, 602), Offset(518, 616), Offset(519, 630),
      Offset(519, 644), Offset(518, 658), Offset(517, 672), Offset(515, 686),
      Offset(513, 700), Offset(510, 714), Offset(507, 728), Offset(504, 742),
      Offset(500, 756), Offset(496, 770), Offset(492, 782),
      Offset(480, 782), Offset(460, 782), Offset(440, 782), Offset(420, 782),
      Offset(400, 782), Offset(378, 782),
      Offset(376, 768), Offset(374, 752), Offset(372, 734), Offset(370, 716),
      Offset(368, 698), Offset(367, 680), Offset(366, 662), Offset(366, 644),
      Offset(366, 626), Offset(366, 608), Offset(366, 590), Offset(366, 572),
      Offset(368, 558),
      Offset(376, 554), Offset(384, 546), Offset(392, 536), Offset(398, 524),
      Offset(404, 512),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // KNEES (ellipses)
  // ════════════════════════════════════════════════════════════════════════════

  BodyRegion(
    id: 'z49', label: 'R. Knee', number: 49, isFront: true,
    group: EasiGroup.lowerExt,
    isEllipse: true, ellipseRect: Rect.fromLTWH(218, 780, 132, 64),
  ),

  BodyRegion(
    id: 'z50', label: 'L. Knee', number: 50, isFront: true,
    group: EasiGroup.lowerExt,
    isEllipse: true, ellipseRect: Rect.fromLTWH(370, 780, 132, 64),
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // SHINS
  // ════════════════════════════════════════════════════════════════════════════

  // z19 — R. Shin
  BodyRegion(
    id: 'z19', label: 'R. Shin', number: 19, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      // outer edge (below knee → ankle)
      Offset(228, 844), Offset(226, 858), Offset(224, 874), Offset(222, 890),
      Offset(220, 906), Offset(218, 922), Offset(216, 938), Offset(216, 954),
      Offset(218, 968), Offset(220, 978),
      // bottom (ankle line)
      Offset(240, 978), Offset(260, 978), Offset(280, 978), Offset(300, 978),
      Offset(320, 978), Offset(336, 978),
      // inner edge (ankle → below knee)
      Offset(338, 968), Offset(340, 954), Offset(342, 938), Offset(342, 922),
      Offset(342, 906), Offset(344, 890), Offset(344, 874), Offset(344, 858),
      Offset(342, 844),
      // top (below knee line)
      Offset(320, 844), Offset(300, 844), Offset(280, 844), Offset(260, 844),
      Offset(240, 844),
    ],
  ),

  // z20 — L. Shin (mirror)
  BodyRegion(
    id: 'z20', label: 'L. Shin', number: 20, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(378, 844), Offset(376, 858), Offset(376, 874), Offset(376, 890),
      Offset(378, 906), Offset(378, 922), Offset(378, 938), Offset(380, 954),
      Offset(382, 968), Offset(384, 978),
      Offset(400, 978), Offset(420, 978), Offset(440, 978), Offset(460, 978),
      Offset(480, 978), Offset(500, 978),
      Offset(502, 968), Offset(504, 954), Offset(504, 938), Offset(502, 922),
      Offset(500, 906), Offset(498, 890), Offset(496, 874), Offset(494, 858),
      Offset(492, 844),
      Offset(480, 844), Offset(460, 844), Offset(440, 844), Offset(420, 844),
      Offset(400, 844),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // FEET
  // ════════════════════════════════════════════════════════════════════════════

  // z21 — R. Foot
  BodyRegion(
    id: 'z21', label: 'R. Foot', number: 21, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(220, 978), Offset(218, 992), Offset(214, 1008), Offset(210, 1024),
      Offset(206, 1040), Offset(202, 1056), Offset(198, 1072), Offset(196, 1086),
      Offset(194, 1096),
      Offset(210, 1100), Offset(230, 1102), Offset(250, 1100), Offset(270, 1096),
      Offset(290, 1090), Offset(306, 1082), Offset(320, 1072), Offset(330, 1060),
      Offset(334, 1044), Offset(336, 1028), Offset(336, 1010), Offset(336, 992),
      Offset(336, 978),
      Offset(320, 978), Offset(300, 978), Offset(280, 978), Offset(260, 978),
      Offset(240, 978),
    ],
  ),

  // z22 — L. Foot (mirror)
  BodyRegion(
    id: 'z22', label: 'L. Foot', number: 22, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(384, 978), Offset(384, 992), Offset(384, 1010), Offset(384, 1028),
      Offset(386, 1044), Offset(390, 1060), Offset(400, 1072), Offset(414, 1082),
      Offset(430, 1090), Offset(450, 1096), Offset(470, 1100), Offset(490, 1102),
      Offset(510, 1100), Offset(526, 1096),
      Offset(524, 1086), Offset(522, 1072), Offset(518, 1056), Offset(514, 1040),
      Offset(510, 1024), Offset(506, 1008), Offset(502, 992), Offset(500, 978),
      Offset(480, 978), Offset(460, 978), Offset(440, 978), Offset(420, 978),
      Offset(400, 978),
    ],
  ),
];

// ─── BACK regions (zones 23–48) ───────────────────────────────────────────────
// Back midline x=1155. Patient's R side = viewer's R side (x > 1155).
// Mirror formula: back_x = 1155 + (360 - front_x)  (flips L/R for back view).

const kBackRegions = <BodyRegion>[

  // ════════════════════════════════════════════════════════════════════════════
  // HEAD & NECK (BACK)
  // ════════════════════════════════════════════════════════════════════════════

  // z23 — R. Scalp (B) — on viewer's RIGHT of back figure
  BodyRegion(
    id: 'z23', label: 'R. Scalp (B)', number: 23, isFront: false,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1155, 20),
      Offset(1165, 18), Offset(1175, 17), Offset(1185, 18), Offset(1193, 22),
      Offset(1201, 28), Offset(1208, 36), Offset(1214, 46), Offset(1218, 58),
      Offset(1221, 70), Offset(1223, 84), Offset(1224, 98), Offset(1223, 112),
      Offset(1220, 124), Offset(1215, 134), Offset(1207, 142), Offset(1197, 148),
      Offset(1185, 152), Offset(1170, 153), Offset(1155, 153),
    ],
  ),

  // z24 — L. Scalp (B) — on viewer's LEFT
  BodyRegion(
    id: 'z24', label: 'L. Scalp (B)', number: 24, isFront: false,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1155, 20),
      Offset(1155, 153),
      Offset(1140, 153), Offset(1125, 152), Offset(1113, 148), Offset(1103, 142),
      Offset(1095, 134), Offset(1090, 124), Offset(1087, 112), Offset(1086, 98),
      Offset(1087, 84), Offset(1089, 70), Offset(1092, 58), Offset(1096, 46),
      Offset(1102, 36), Offset(1109, 28), Offset(1117, 22), Offset(1125, 18),
      Offset(1135, 17), Offset(1145, 18),
    ],
  ),

  // z25 — Nape
  BodyRegion(
    id: 'z25', label: 'Nape', number: 25, isFront: false,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1125, 153), Offset(1140, 153), Offset(1155, 153),
      Offset(1170, 153), Offset(1185, 153),
      Offset(1187, 160), Offset(1189, 168), Offset(1191, 176), Offset(1191, 183),
      Offset(1155, 183),
      Offset(1119, 183), Offset(1119, 176), Offset(1121, 168), Offset(1123, 160),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // UPPER BACK / SHOULDERS
  // ════════════════════════════════════════════════════════════════════════════

  // z26 — L. Upper Back (viewer's LEFT of back figure)
  BodyRegion(
    id: 'z26', label: 'L. Upper Back', number: 26, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 183), Offset(1135, 183), Offset(1115, 184), Offset(1095, 186),
      Offset(1075, 188), Offset(1055, 190), Offset(1035, 192), Offset(1015, 194),
      Offset(999, 196), Offset(983, 198),
      Offset(985, 210), Offset(988, 225), Offset(991, 240), Offset(995, 255),
      Offset(999, 270), Offset(1003, 285), Offset(1007, 298),
      Offset(1030, 299), Offset(1055, 299), Offset(1080, 298), Offset(1105, 298),
      Offset(1130, 297), Offset(1155, 297),
    ],
  ),

  // z27 — R. Upper Back (viewer's RIGHT)
  BodyRegion(
    id: 'z27', label: 'R. Upper Back', number: 27, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 183), Offset(1155, 297),
      Offset(1180, 297), Offset(1205, 298), Offset(1230, 298), Offset(1255, 299),
      Offset(1280, 299), Offset(1303, 298),
      Offset(1307, 285), Offset(1311, 270), Offset(1315, 255), Offset(1319, 240),
      Offset(1322, 225), Offset(1325, 210), Offset(1327, 198),
      Offset(1311, 196), Offset(1295, 194), Offset(1275, 192), Offset(1255, 190),
      Offset(1235, 188), Offset(1215, 186), Offset(1195, 184), Offset(1175, 183),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // UPPER ARMS (BACK)
  // ════════════════════════════════════════════════════════════════════════════

  // z28 — L. Upper Arm (B) (viewer's LEFT)
  BodyRegion(
    id: 'z28', label: 'L. Upper Arm (B)', number: 28, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(883, 198), Offset(882, 215), Offset(881, 232), Offset(880, 250),
      Offset(879, 268), Offset(878, 286), Offset(877, 304), Offset(876, 322),
      Offset(875, 340), Offset(875, 356), Offset(877, 370), Offset(879, 374),
      Offset(905, 374), Offset(935, 374), Offset(963, 374), Offset(985, 374),
      Offset(985, 358), Offset(984, 342), Offset(984, 326), Offset(984, 310),
      Offset(984, 294), Offset(984, 278), Offset(984, 262), Offset(984, 246),
      Offset(985, 230), Offset(985, 214), Offset(983, 198),
      Offset(963, 197), Offset(935, 196), Offset(907, 197),
    ],
  ),

  // z29 — R. Upper Arm (B) (viewer's RIGHT)
  BodyRegion(
    id: 'z29', label: 'R. Upper Arm (B)', number: 29, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1327, 198), Offset(1329, 214), Offset(1329, 230), Offset(1330, 246),
      Offset(1330, 262), Offset(1330, 278), Offset(1330, 294), Offset(1330, 310),
      Offset(1330, 326), Offset(1330, 342), Offset(1329, 358), Offset(1329, 374),
      Offset(1351, 374), Offset(1379, 374), Offset(1409, 374), Offset(1435, 374),
      Offset(1437, 370), Offset(1439, 356), Offset(1439, 340), Offset(1438, 322),
      Offset(1437, 304), Offset(1436, 286), Offset(1435, 268), Offset(1434, 250),
      Offset(1433, 232), Offset(1432, 215), Offset(1431, 198),
      Offset(1407, 197), Offset(1379, 196), Offset(1351, 197),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // FOREARMS (BACK)
  // ════════════════════════════════════════════════════════════════════════════

  // z30 — L. Forearm (B)
  BodyRegion(
    id: 'z30', label: 'L. Forearm (B)', number: 30, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(879, 374), Offset(878, 392), Offset(876, 410), Offset(875, 428),
      Offset(874, 446), Offset(873, 464), Offset(872, 482), Offset(873, 500),
      Offset(873, 510),
      Offset(905, 510), Offset(940, 510), Offset(973, 510), Offset(991, 510),
      Offset(991, 496), Offset(990, 478), Offset(990, 460), Offset(989, 442),
      Offset(989, 424), Offset(988, 406), Offset(987, 388), Offset(985, 374),
      Offset(963, 374), Offset(935, 374), Offset(905, 374),
    ],
  ),

  // z31 — R. Forearm (B)
  BodyRegion(
    id: 'z31', label: 'R. Forearm (B)', number: 31, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1329, 374), Offset(1327, 388), Offset(1326, 406), Offset(1325, 424),
      Offset(1325, 442), Offset(1324, 460), Offset(1324, 478), Offset(1323, 496),
      Offset(1323, 510),
      Offset(1341, 510), Offset(1374, 510), Offset(1409, 510), Offset(1441, 510),
      Offset(1441, 500), Offset(1442, 482), Offset(1440, 464), Offset(1440, 446),
      Offset(1439, 428), Offset(1438, 410), Offset(1436, 392), Offset(1435, 374),
      Offset(1409, 374), Offset(1379, 374), Offset(1351, 374),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // HANDS (BACK)
  // ════════════════════════════════════════════════════════════════════════════

  // z32 — L. Hand (B)
  BodyRegion(
    id: 'z32', label: 'L. Hand (B)', number: 32, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(873, 510), Offset(871, 528), Offset(869, 546), Offset(867, 564),
      Offset(866, 582), Offset(867, 600), Offset(869, 615),
      Offset(890, 616), Offset(915, 616), Offset(943, 616), Offset(970, 616),
      Offset(991, 614),
      Offset(993, 598), Offset(993, 580), Offset(993, 562), Offset(993, 544),
      Offset(991, 526), Offset(991, 510),
      Offset(973, 510), Offset(940, 510), Offset(905, 510),
    ],
  ),

  // z33 — R. Hand (B)
  BodyRegion(
    id: 'z33', label: 'R. Hand (B)', number: 33, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1323, 510), Offset(1323, 526), Offset(1321, 544), Offset(1321, 562),
      Offset(1321, 580), Offset(1321, 598), Offset(1323, 614),
      Offset(1344, 616), Offset(1371, 616), Offset(1399, 616), Offset(1424, 616),
      Offset(1445, 615),
      Offset(1447, 600), Offset(1448, 582), Offset(1447, 564), Offset(1445, 546),
      Offset(1443, 528), Offset(1441, 510),
      Offset(1409, 510), Offset(1374, 510), Offset(1341, 510),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // MID BACK
  // ════════════════════════════════════════════════════════════════════════════

  // z34 — L. Mid Back
  BodyRegion(
    id: 'z34', label: 'L. Mid Back', number: 34, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1007, 298), Offset(1011, 314), Offset(1013, 332), Offset(1015, 350),
      Offset(1015, 368), Offset(1015, 386), Offset(1014, 400), Offset(1012, 412),
      Offset(1040, 412), Offset(1070, 412), Offset(1100, 412), Offset(1130, 412),
      Offset(1155, 412), Offset(1155, 380), Offset(1155, 350), Offset(1155, 320),
      Offset(1155, 297),
      Offset(1130, 297), Offset(1105, 298), Offset(1080, 298), Offset(1055, 299),
      Offset(1030, 299),
    ],
  ),

  // z35 — R. Mid Back
  BodyRegion(
    id: 'z35', label: 'R. Mid Back', number: 35, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 297), Offset(1155, 320), Offset(1155, 350), Offset(1155, 380),
      Offset(1155, 412),
      Offset(1180, 412), Offset(1210, 412), Offset(1240, 412), Offset(1270, 412),
      Offset(1298, 412),
      Offset(1296, 400), Offset(1295, 386), Offset(1295, 368), Offset(1297, 350),
      Offset(1299, 332), Offset(1301, 314), Offset(1303, 298),
      Offset(1280, 299), Offset(1255, 299), Offset(1230, 298), Offset(1205, 298),
      Offset(1180, 297),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // LOWER BACK
  // ════════════════════════════════════════════════════════════════════════════

  // z36 — L. Lower Back
  BodyRegion(
    id: 'z36', label: 'L. Lower Back', number: 36, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1012, 412), Offset(1010, 428), Offset(1008, 444), Offset(1006, 460),
      Offset(1006, 476), Offset(1006, 492), Offset(1006, 522),
      Offset(1040, 522), Offset(1070, 522), Offset(1100, 522), Offset(1120, 522),
      Offset(1155, 522), Offset(1155, 470), Offset(1155, 440), Offset(1155, 412),
      Offset(1130, 412), Offset(1100, 412), Offset(1070, 412), Offset(1040, 412),
    ],
  ),

  // z37 — R. Lower Back
  BodyRegion(
    id: 'z37', label: 'R. Lower Back', number: 37, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 412), Offset(1155, 440), Offset(1155, 470), Offset(1155, 522),
      Offset(1190, 522), Offset(1210, 522), Offset(1240, 522), Offset(1270, 522),
      Offset(1304, 522),
      Offset(1304, 492), Offset(1304, 476), Offset(1304, 460), Offset(1302, 444),
      Offset(1300, 428), Offset(1298, 412),
      Offset(1270, 412), Offset(1240, 412), Offset(1210, 412), Offset(1180, 412),
    ],
  ),

  // z46 — Sacrum (ellipse)
  BodyRegion(
    id: 'z46', label: 'Sacrum', number: 46, isFront: false,
    group: EasiGroup.trunk,
    isEllipse: true, ellipseRect: Rect.fromLTWH(1118, 468, 74, 56),
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // BUTTOCKS (rounded lower edge — gluteal fold)
  // ════════════════════════════════════════════════════════════════════════════

  // z38 — L. Buttock
  BodyRegion(
    id: 'z38', label: 'L. Buttock', number: 38, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1006, 522), Offset(1030, 522), Offset(1060, 522), Offset(1090, 522),
      Offset(1120, 522),
      Offset(1118, 540), Offset(1114, 558), Offset(1108, 574), Offset(1098, 590),
      Offset(1086, 604), Offset(1070, 614), Offset(1050, 620), Offset(1028, 622),
      Offset(1006, 620), Offset(988, 614), Offset(974, 604), Offset(966, 590),
      Offset(962, 574), Offset(960, 558), Offset(960, 540), Offset(962, 526),
    ],
  ),

  // z39 — R. Buttock
  BodyRegion(
    id: 'z39', label: 'R. Buttock', number: 39, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1190, 522), Offset(1220, 522), Offset(1250, 522), Offset(1280, 522),
      Offset(1304, 522),
      Offset(1348, 526), Offset(1350, 540), Offset(1350, 558), Offset(1348, 574),
      Offset(1344, 590), Offset(1336, 604), Offset(1322, 614), Offset(1304, 620),
      Offset(1282, 622), Offset(1260, 620), Offset(1240, 614), Offset(1224, 604),
      Offset(1212, 590), Offset(1202, 574), Offset(1196, 558), Offset(1192, 540),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // THIGHS (BACK)
  // ════════════════════════════════════════════════════════════════════════════

  // z40 — L. Thigh (B)
  BodyRegion(
    id: 'z40', label: 'L. Thigh (B)', number: 40, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(960, 622), Offset(988, 622), Offset(1020, 622), Offset(1050, 622),
      Offset(1080, 622), Offset(1110, 622), Offset(1140, 622),
      Offset(1142, 644), Offset(1142, 666), Offset(1142, 688), Offset(1140, 710),
      Offset(1138, 732), Offset(1134, 754), Offset(1130, 776), Offset(1126, 790),
      Offset(1100, 790), Offset(1070, 790), Offset(1040, 790), Offset(1010, 790),
      Offset(980, 790),
      Offset(976, 776), Offset(972, 754), Offset(968, 732), Offset(966, 710),
      Offset(964, 688), Offset(962, 666), Offset(960, 644),
    ],
  ),

  // z41 — R. Thigh (B)
  BodyRegion(
    id: 'z41', label: 'R. Thigh (B)', number: 41, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1170, 622), Offset(1200, 622), Offset(1230, 622), Offset(1260, 622),
      Offset(1290, 622), Offset(1322, 622), Offset(1350, 622),
      Offset(1352, 644), Offset(1352, 666), Offset(1350, 688), Offset(1348, 710),
      Offset(1344, 732), Offset(1340, 754), Offset(1336, 776), Offset(1332, 790),
      Offset(1300, 790), Offset(1270, 790), Offset(1240, 790), Offset(1210, 790),
      Offset(1180, 790),
      Offset(1176, 776), Offset(1172, 754), Offset(1170, 732), Offset(1170, 710),
      Offset(1170, 688), Offset(1170, 666), Offset(1170, 644),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // BACK OF KNEE (ellipses)
  // ════════════════════════════════════════════════════════════════════════════

  BodyRegion(
    id: 'z47', label: 'L. Back Knee', number: 47, isFront: false,
    group: EasiGroup.lowerExt,
    isEllipse: true, ellipseRect: Rect.fromLTWH(966, 788, 130, 66),
  ),

  BodyRegion(
    id: 'z48', label: 'R. Back Knee', number: 48, isFront: false,
    group: EasiGroup.lowerExt,
    isEllipse: true, ellipseRect: Rect.fromLTWH(1168, 788, 130, 66),
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // CALVES
  // ════════════════════════════════════════════════════════════════════════════

  // z42 — L. Calf
  BodyRegion(
    id: 'z42', label: 'L. Calf', number: 42, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(974, 854), Offset(972, 870), Offset(970, 888), Offset(968, 906),
      Offset(966, 924), Offset(966, 942), Offset(968, 960), Offset(970, 978),
      Offset(990, 978), Offset(1010, 978), Offset(1030, 978), Offset(1050, 978),
      Offset(1070, 978), Offset(1088, 978),
      Offset(1090, 960), Offset(1092, 942), Offset(1092, 924), Offset(1090, 906),
      Offset(1088, 888), Offset(1086, 870), Offset(1084, 854),
      Offset(1060, 854), Offset(1040, 854), Offset(1020, 854), Offset(1000, 854),
    ],
  ),

  // z43 — R. Calf
  BodyRegion(
    id: 'z43', label: 'R. Calf', number: 43, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1176, 854), Offset(1174, 870), Offset(1172, 888), Offset(1170, 906),
      Offset(1168, 924), Offset(1168, 942), Offset(1170, 960), Offset(1172, 978),
      Offset(1192, 978), Offset(1212, 978), Offset(1232, 978), Offset(1252, 978),
      Offset(1272, 978), Offset(1290, 978),
      Offset(1292, 960), Offset(1294, 942), Offset(1294, 924), Offset(1292, 906),
      Offset(1290, 888), Offset(1288, 870), Offset(1286, 854),
      Offset(1262, 854), Offset(1242, 854), Offset(1222, 854), Offset(1202, 854),
    ],
  ),

  // ════════════════════════════════════════════════════════════════════════════
  // FEET (BACK)
  // ════════════════════════════════════════════════════════════════════════════

  // z44 — L. Foot (B)
  BodyRegion(
    id: 'z44', label: 'L. Foot (B)', number: 44, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(970, 978), Offset(968, 992), Offset(964, 1008), Offset(960, 1024),
      Offset(956, 1040), Offset(952, 1056), Offset(948, 1072), Offset(946, 1086),
      Offset(944, 1096),
      Offset(960, 1100), Offset(980, 1102), Offset(1000, 1100), Offset(1020, 1096),
      Offset(1038, 1090), Offset(1054, 1082), Offset(1068, 1072), Offset(1078, 1060),
      Offset(1082, 1044), Offset(1084, 1028), Offset(1084, 1010), Offset(1084, 992),
      Offset(1088, 978),
      Offset(1070, 978), Offset(1050, 978), Offset(1030, 978), Offset(1010, 978),
      Offset(990, 978),
    ],
  ),

  // z45 — R. Foot (B)
  BodyRegion(
    id: 'z45', label: 'R. Foot (B)', number: 45, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1172, 978), Offset(1172, 992), Offset(1172, 1010), Offset(1172, 1028),
      Offset(1174, 1044), Offset(1178, 1060), Offset(1188, 1072), Offset(1202, 1082),
      Offset(1218, 1090), Offset(1238, 1096), Offset(1258, 1100), Offset(1278, 1102),
      Offset(1298, 1100), Offset(1314, 1096),
      Offset(1312, 1086), Offset(1310, 1072), Offset(1306, 1056), Offset(1302, 1040),
      Offset(1298, 1024), Offset(1294, 1008), Offset(1290, 992), Offset(1288, 978),
      Offset(1272, 978), Offset(1252, 978), Offset(1232, 978), Offset(1212, 978),
      Offset(1192, 978),
    ],
  ),
];

// ─── Drawn Patch ──────────────────────────────────────────────────────────────

class DrawnPatch {
  final String zoneId;
  final List<Offset> points;
  final int severity;

  const DrawnPatch({required this.zoneId, required this.points, required this.severity});

  Map<String, dynamic> toJson() => {
    'zone_id': zoneId, 'severity': severity,
    'pts': points.map((p) => [p.dx.round(), p.dy.round()]).toList(),
  };

  factory DrawnPatch.fromJson(Map<String, dynamic> j) => DrawnPatch(
    zoneId: j['zone_id'] as String? ?? '',
    severity: (j['severity'] as num?)?.toInt() ?? 1,
    points: (j['pts'] as List? ?? []).expand((p) {
      if (p is List && p.length >= 2) {
        return [Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())];
      }
      return <Offset>[];
    }).toList(),
  );
}

// ─── Convenience lookup ───────────────────────────────────────────────────────

BodyRegion? findRegion(String id) {
  try {
    return [...kFrontRegions, ...kBackRegions].firstWhere((r) => r.id == id);
  } catch (_) {
    return null;
  }
}
