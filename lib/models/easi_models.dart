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
// Coordinates in body_map_clinical.png pixel space (1548 x 1134).
// Front body midline x~360.  Back body midline x~1155.
// Many polygons extracted via flood-fill contour tracing from the actual image.
// Remaining zones traced by hand from the clinical diagram.
//
// FRONT: zones 1-22, 49-50
// BACK:  zones 23-48

const kFrontRegions = <BodyRegion>[

  // z1 -- R. Scalp
  BodyRegion(
    id: 'z1', label: 'R. Scalp', number: 1, isFront: true,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(360, 18),
      Offset(350, 17), Offset(340, 18), Offset(330, 22), Offset(322, 28),
      Offset(314, 36), Offset(307, 48), Offset(302, 60), Offset(298, 74),
      Offset(296, 88), Offset(296, 100), Offset(300, 112), Offset(306, 122),
      Offset(314, 130), Offset(324, 136), Offset(336, 140), Offset(348, 142),
      Offset(360, 142),
    ],
  ),

  // z2 -- L. Scalp
  BodyRegion(
    id: 'z2', label: 'L. Scalp', number: 2, isFront: true,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(360, 18),
      Offset(360, 142),
      Offset(372, 142), Offset(384, 140), Offset(396, 136), Offset(406, 130),
      Offset(414, 122), Offset(420, 112), Offset(424, 100), Offset(424, 88),
      Offset(422, 74), Offset(418, 60), Offset(413, 48), Offset(406, 36),
      Offset(398, 28), Offset(390, 22), Offset(380, 18), Offset(370, 17),
    ],
  ),

  // z3 -- Neck
  BodyRegion(
    id: 'z3', label: 'Neck', number: 3, isFront: true,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(324, 136), Offset(336, 142), Offset(360, 142),
      Offset(384, 142), Offset(396, 136),
      Offset(400, 148), Offset(406, 160), Offset(415, 172),
      Offset(430, 182), Offset(448, 192),
      Offset(360, 192),
      Offset(272, 192),
      Offset(290, 182), Offset(305, 172),
      Offset(314, 160), Offset(320, 148),
    ],
  ),

  // z4 -- R. Chest (from automated extraction)
  BodyRegion(
    id: 'z4', label: 'R. Chest', number: 4, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(272, 192), Offset(312, 200), Offset(340, 200), Offset(360, 204),
      Offset(360, 290),
      Offset(270, 290), Offset(265, 280), Offset(255, 268),
      Offset(240, 256), Offset(220, 244),
      Offset(228, 220), Offset(238, 208), Offset(252, 198),
    ],
  ),

  // z5 -- L. Chest
  BodyRegion(
    id: 'z5', label: 'L. Chest', number: 5, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 204), Offset(380, 200), Offset(408, 200), Offset(448, 192),
      Offset(470, 198), Offset(484, 208), Offset(496, 222),
      Offset(504, 240), Offset(500, 260), Offset(490, 274), Offset(478, 284),
      Offset(460, 290),
      Offset(360, 290),
    ],
  ),

  // z6 -- R. Upper Arm
  BodyRegion(
    id: 'z6', label: 'R. Upper Arm', number: 6, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(220, 244), Offset(240, 256), Offset(255, 268), Offset(265, 280),
      Offset(270, 290),
      Offset(270, 310), Offset(260, 328), Offset(248, 342), Offset(232, 354),
      Offset(214, 363),
      Offset(197, 370), Offset(173, 378), Offset(156, 363),
      Offset(150, 350), Offset(148, 334), Offset(150, 316),
      Offset(155, 300), Offset(164, 284), Offset(176, 270),
      Offset(190, 258), Offset(206, 250),
    ],
  ),

  // z7 -- L. Upper Arm
  BodyRegion(
    id: 'z7', label: 'L. Upper Arm', number: 7, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(500, 240), Offset(510, 252), Offset(522, 264),
      Offset(536, 276), Offset(552, 286), Offset(566, 296),
      Offset(574, 310), Offset(578, 326), Offset(578, 340),
      Offset(575, 354), Offset(567, 365),
      Offset(551, 378), Offset(540, 370),
      Offset(488, 342), Offset(478, 328), Offset(470, 312),
      Offset(462, 296), Offset(460, 290),
      Offset(478, 284), Offset(490, 274),
    ],
  ),

  // z8 -- R. Forearm (from automated extraction)
  BodyRegion(
    id: 'z8', label: 'R. Forearm', number: 8, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(156, 363), Offset(173, 378), Offset(197, 387),
      Offset(191, 402), Offset(169, 435), Offset(137, 466),
      Offset(113, 493), Offset(104, 507), Offset(88, 506),
      Offset(78, 497), Offset(88, 487), Offset(104, 460),
      Offset(137, 385),
    ],
  ),

  // z9 -- L. Forearm (from automated extraction)
  BodyRegion(
    id: 'z9', label: 'L. Forearm', number: 9, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(567, 365), Offset(589, 359), Offset(610, 382),
      Offset(629, 424), Offset(659, 471), Offset(673, 487),
      Offset(659, 493), Offset(648, 502),
      Offset(614, 464), Offset(581, 433), Offset(566, 412),
      Offset(551, 381),
    ],
  ),

  // z10 -- R. Hand
  BodyRegion(
    id: 'z10', label: 'R. Hand', number: 10, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(104, 507), Offset(88, 506), Offset(78, 497),
      Offset(72, 510), Offset(66, 528), Offset(62, 548),
      Offset(60, 568), Offset(64, 588), Offset(72, 600),
      Offset(84, 596), Offset(92, 588), Offset(98, 576),
      Offset(106, 564), Offset(118, 548), Offset(130, 534),
      Offset(140, 520),
    ],
  ),

  // z11 -- L. Hand
  BodyRegion(
    id: 'z11', label: 'L. Hand', number: 11, isFront: true,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(648, 502), Offset(659, 493), Offset(673, 487),
      Offset(682, 500), Offset(688, 518), Offset(690, 538),
      Offset(688, 558), Offset(682, 576), Offset(672, 590),
      Offset(660, 600), Offset(650, 594), Offset(642, 582),
      Offset(636, 568), Offset(626, 548), Offset(616, 530),
      Offset(608, 518),
    ],
  ),

  // z12 -- R. Upper Abd. (from automated extraction)
  BodyRegion(
    id: 'z12', label: 'R. Upper Abd.', number: 12, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(271, 293), Offset(360, 293),
      Offset(360, 313), Offset(349, 320), Offset(343, 329),
      Offset(327, 371), Offset(318, 385),
      Offset(302, 403), Offset(291, 414), Offset(285, 415),
      Offset(285, 377), Offset(282, 347), Offset(278, 322),
    ],
  ),

  // z13 -- L. Upper Abd. (from automated extraction)
  BodyRegion(
    id: 'z13', label: 'L. Upper Abd.', number: 13, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(377, 293), Offset(474, 293),
      Offset(470, 318), Offset(452, 379), Offset(453, 411),
      Offset(436, 402), Offset(425, 389),
      Offset(412, 363), Offset(405, 338), Offset(398, 324),
      Offset(391, 316), Offset(377, 310),
    ],
  ),

  // z14 -- R. Lower Abd. (from automated extraction)
  BodyRegion(
    id: 'z14', label: 'R. Lower Abd.', number: 14, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(360, 323), Offset(360, 511),
      Offset(331, 512), Offset(301, 486), Offset(286, 468),
      Offset(281, 455), Offset(284, 425),
      Offset(297, 420), Offset(327, 387), Offset(340, 364),
      Offset(351, 333),
    ],
  ),

  // z15 -- L. Lower Abd. (from automated extraction)
  BodyRegion(
    id: 'z15', label: 'L. Lower Abd.', number: 15, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(377, 319), Offset(383, 321), Offset(389, 327),
      Offset(394, 336), Offset(405, 371),
      Offset(420, 398), Offset(434, 412), Offset(455, 421),
      Offset(460, 470), Offset(418, 511),
      Offset(374, 511), Offset(374, 406), Offset(376, 391),
    ],
  ),

  // z16 -- Groin
  BodyRegion(
    id: 'z16', label: 'Groin', number: 16, isFront: true,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(331, 512), Offset(360, 512), Offset(374, 511), Offset(418, 511),
      Offset(410, 522), Offset(400, 536), Offset(392, 548),
      Offset(385, 560), Offset(378, 570),
      Offset(370, 572), Offset(360, 570), Offset(350, 572),
      Offset(342, 570), Offset(335, 560), Offset(328, 548),
      Offset(320, 536), Offset(312, 522),
    ],
  ),

  // z17 -- R. Thigh (from automated extraction)
  BodyRegion(
    id: 'z17', label: 'R. Thigh', number: 17, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(276, 467), Offset(312, 522), Offset(332, 526),
      Offset(369, 579), Offset(361, 713),
      Offset(356, 744), Offset(344, 749), Offset(319, 749),
      Offset(296, 734), Offset(276, 676),
      Offset(265, 585), Offset(266, 517),
    ],
  ),

  // z18 -- L. Thigh (from automated extraction)
  BodyRegion(
    id: 'z18', label: 'L. Thigh', number: 18, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(463, 478), Offset(476, 565), Offset(466, 667),
      Offset(452, 721), Offset(443, 734), Offset(423, 744),
      Offset(400, 745), Offset(390, 740),
      Offset(385, 660), Offset(378, 622), Offset(378, 581),
      Offset(399, 544), Offset(462, 479),
    ],
  ),

  // z49 -- R. Knee (from automated extraction)
  BodyRegion(
    id: 'z49', label: 'R. Knee', number: 49, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(296, 747), Offset(311, 756), Offset(328, 759),
      Offset(343, 758), Offset(358, 753),
      Offset(359, 767), Offset(352, 815),
      Offset(330, 807), Offset(313, 807), Offset(296, 814),
      Offset(297, 799), Offset(294, 782),
    ],
  ),

  // z50 -- L. Knee (from automated extraction)
  BodyRegion(
    id: 'z50', label: 'L. Knee', number: 50, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(390, 740), Offset(397, 755), Offset(422, 755),
      Offset(439, 749), Offset(446, 744),
      Offset(445, 749), Offset(442, 776),
      Offset(444, 806), Offset(433, 803), Offset(412, 803),
      Offset(399, 805), Offset(389, 809),
      Offset(391, 753),
    ],
  ),

  // z19 -- R. Shin (from automated extraction)
  BodyRegion(
    id: 'z19', label: 'R. Shin', number: 19, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(296, 814), Offset(312, 816), Offset(343, 820),
      Offset(352, 825), Offset(354, 833),
      Offset(359, 882), Offset(343, 982), Offset(347, 1029),
      Offset(309, 1028), Offset(309, 965),
      Offset(290, 845), Offset(292, 829),
    ],
  ),

  // z20 -- L. Shin (from automated extraction)
  BodyRegion(
    id: 'z20', label: 'L. Shin', number: 20, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(389, 809), Offset(415, 812), Offset(438, 814),
      Offset(447, 819), Offset(450, 861),
      Offset(439, 939), Offset(427, 987), Offset(431, 1026),
      Offset(391, 1030), Offset(398, 998),
      Offset(398, 951), Offset(384, 895), Offset(382, 849),
      Offset(388, 821),
    ],
  ),

  // z21 -- R. Foot
  BodyRegion(
    id: 'z21', label: 'R. Foot', number: 21, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(309, 1028), Offset(347, 1029),
      Offset(350, 1040), Offset(348, 1058), Offset(342, 1072),
      Offset(332, 1084), Offset(318, 1092), Offset(302, 1098),
      Offset(284, 1100), Offset(268, 1098),
      Offset(254, 1092), Offset(244, 1082), Offset(240, 1070),
      Offset(242, 1058), Offset(250, 1046),
      Offset(262, 1038), Offset(278, 1032),
    ],
  ),

  // z22 -- L. Foot (hand-traced smooth oval matching image contour)
  BodyRegion(
    id: 'z22', label: 'L. Foot', number: 22, isFront: true,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(391, 1030), Offset(410, 1026), Offset(432, 1026),
      Offset(454, 1030), Offset(472, 1040), Offset(484, 1054),
      Offset(490, 1072), Offset(488, 1088), Offset(478, 1098),
      Offset(462, 1104), Offset(442, 1108), Offset(422, 1106),
      Offset(404, 1100), Offset(392, 1090), Offset(386, 1076),
      Offset(384, 1058), Offset(386, 1042),
    ],
  ),
];

const kBackRegions = <BodyRegion>[

  // z23 -- R. Scalp (B) — keep (head zones align correctly)
  BodyRegion(
    id: 'z23', label: 'R. Scalp (B)', number: 23, isFront: false,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1155, 18),
      Offset(1143, 17), Offset(1131, 20), Offset(1120, 26),
      Offset(1111, 34), Offset(1104, 44), Offset(1099, 56),
      Offset(1096, 70), Offset(1095, 86), Offset(1096, 100),
      Offset(1100, 112), Offset(1106, 122), Offset(1114, 130),
      Offset(1124, 136), Offset(1136, 140), Offset(1148, 142),
      Offset(1155, 142),
    ],
  ),

  // z24 -- L. Scalp (B)
  BodyRegion(
    id: 'z24', label: 'L. Scalp (B)', number: 24, isFront: false,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1155, 18),
      Offset(1155, 142),
      Offset(1162, 142), Offset(1174, 140), Offset(1186, 136),
      Offset(1196, 130), Offset(1204, 122), Offset(1210, 112),
      Offset(1214, 100), Offset(1215, 86), Offset(1214, 70),
      Offset(1211, 56), Offset(1206, 44), Offset(1199, 34),
      Offset(1190, 26), Offset(1179, 20), Offset(1167, 17),
    ],
  ),

  // z25 -- Nape
  BodyRegion(
    id: 'z25', label: 'Nape', number: 25, isFront: false,
    group: EasiGroup.headNeck,
    polyPoints: [
      Offset(1114, 130), Offset(1124, 136), Offset(1148, 142),
      Offset(1155, 142), Offset(1162, 142), Offset(1186, 136),
      Offset(1196, 130),
      Offset(1210, 145), Offset(1225, 160), Offset(1244, 176),
      Offset(1265, 190),
      Offset(1155, 192),
      Offset(1045, 190),
      Offset(1066, 176), Offset(1086, 160), Offset(1100, 145),
    ],
  ),

  // ── TORSO ZONES (all retraced to match image body outline) ────────────
  // Back body midline: x ≈ 1155
  // Body edges at shoulder: ~1045 (L) to ~1265 (R)
  // Body edges at waist:    ~1055 (L) to ~1255 (R)

  // z26 -- L. Upper Back
  BodyRegion(
    id: 'z26', label: 'L. Upper Back', number: 26, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1048, 192), Offset(1100, 194), Offset(1155, 198),
      Offset(1155, 270),
      Offset(1115, 275), Offset(1080, 278), Offset(1050, 275),
      Offset(1042, 258), Offset(1038, 238), Offset(1042, 215),
    ],
  ),

  // z27 -- R. Upper Back
  BodyRegion(
    id: 'z27', label: 'R. Upper Back', number: 27, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 198), Offset(1210, 194), Offset(1262, 192),
      Offset(1268, 215), Offset(1272, 238), Offset(1268, 258),
      Offset(1260, 275), Offset(1230, 278), Offset(1195, 275),
      Offset(1155, 270),
    ],
  ),

  // z28 -- L. Upper Arm (B)
  BodyRegion(
    id: 'z28', label: 'L. Upper Arm (B)', number: 28, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1042, 215), Offset(1038, 238), Offset(1042, 258),
      Offset(1050, 275),
      Offset(1040, 298), Offset(1032, 318), Offset(1026, 340),
      Offset(1020, 360),
      Offset(1005, 352), Offset(990, 362), Offset(975, 370),
      Offset(962, 368), Offset(948, 360),
      Offset(938, 340), Offset(932, 318), Offset(930, 296),
      Offset(934, 274), Offset(942, 256), Offset(954, 242),
      Offset(970, 234), Offset(988, 234), Offset(1005, 240),
      Offset(1020, 250), Offset(1032, 264),
    ],
  ),

  // z29 -- R. Upper Arm (B)
  BodyRegion(
    id: 'z29', label: 'R. Upper Arm (B)', number: 29, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1268, 215), Offset(1272, 238), Offset(1268, 258),
      Offset(1260, 275),
      Offset(1270, 298), Offset(1278, 318), Offset(1284, 340),
      Offset(1290, 360),
      Offset(1305, 352), Offset(1320, 362), Offset(1335, 370),
      Offset(1348, 368), Offset(1362, 360),
      Offset(1372, 340), Offset(1378, 318), Offset(1380, 296),
      Offset(1376, 274), Offset(1368, 256), Offset(1356, 242),
      Offset(1340, 234), Offset(1322, 234), Offset(1305, 240),
      Offset(1290, 250), Offset(1278, 264),
    ],
  ),

  // z30 -- L. Forearm (B)
  BodyRegion(
    id: 'z30', label: 'L. Forearm (B)', number: 30, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(948, 360), Offset(962, 368), Offset(975, 370),
      Offset(966, 390), Offset(954, 414), Offset(940, 438),
      Offset(926, 460), Offset(912, 482), Offset(902, 498),
      Offset(888, 494), Offset(876, 488),
      Offset(886, 466), Offset(900, 440), Offset(914, 414),
      Offset(928, 390), Offset(938, 374),
    ],
  ),

  // z31 -- R. Forearm (B)
  BodyRegion(
    id: 'z31', label: 'R. Forearm (B)', number: 31, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1362, 360), Offset(1348, 368), Offset(1335, 370),
      Offset(1344, 390), Offset(1356, 414), Offset(1370, 438),
      Offset(1384, 460), Offset(1398, 482), Offset(1408, 498),
      Offset(1422, 494), Offset(1434, 488),
      Offset(1424, 466), Offset(1410, 440), Offset(1396, 414),
      Offset(1382, 390), Offset(1372, 374),
    ],
  ),

  // z32 -- L. Hand (B)
  BodyRegion(
    id: 'z32', label: 'L. Hand (B)', number: 32, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(902, 498), Offset(888, 494), Offset(876, 488),
      Offset(866, 500), Offset(858, 516), Offset(854, 534),
      Offset(854, 554), Offset(858, 572), Offset(866, 586),
      Offset(878, 596), Offset(892, 600), Offset(906, 596),
      Offset(916, 586), Offset(922, 570), Offset(924, 552),
      Offset(922, 534), Offset(916, 518), Offset(910, 506),
    ],
  ),

  // z33 -- R. Hand (B)
  BodyRegion(
    id: 'z33', label: 'R. Hand (B)', number: 33, isFront: false,
    group: EasiGroup.upperExt,
    polyPoints: [
      Offset(1408, 498), Offset(1422, 494), Offset(1434, 488),
      Offset(1444, 500), Offset(1452, 516), Offset(1456, 534),
      Offset(1456, 554), Offset(1452, 572), Offset(1444, 586),
      Offset(1432, 596), Offset(1418, 600), Offset(1404, 596),
      Offset(1394, 586), Offset(1388, 570), Offset(1386, 552),
      Offset(1388, 534), Offset(1394, 518), Offset(1400, 506),
    ],
  ),

  // z34 -- L. Mid Back
  BodyRegion(
    id: 'z34', label: 'L. Mid Back', number: 34, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1050, 275), Offset(1080, 278), Offset(1115, 275),
      Offset(1155, 270),
      Offset(1155, 368),
      Offset(1115, 372), Offset(1082, 374), Offset(1056, 370),
      Offset(1048, 348), Offset(1046, 322), Offset(1048, 298),
    ],
  ),

  // z35 -- R. Mid Back
  BodyRegion(
    id: 'z35', label: 'R. Mid Back', number: 35, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 270), Offset(1195, 275), Offset(1230, 278),
      Offset(1260, 275),
      Offset(1262, 298), Offset(1264, 322), Offset(1262, 348),
      Offset(1254, 370), Offset(1228, 374), Offset(1195, 372),
      Offset(1155, 368),
    ],
  ),

  // z36 -- L. Lower Back
  BodyRegion(
    id: 'z36', label: 'L. Lower Back', number: 36, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1056, 370), Offset(1082, 374), Offset(1115, 372),
      Offset(1155, 368),
      Offset(1155, 452),
      Offset(1115, 456), Offset(1085, 458), Offset(1062, 454),
      Offset(1052, 438), Offset(1050, 418), Offset(1052, 394),
    ],
  ),

  // z37 -- R. Lower Back
  BodyRegion(
    id: 'z37', label: 'R. Lower Back', number: 37, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1155, 368), Offset(1195, 372), Offset(1228, 374),
      Offset(1254, 370),
      Offset(1258, 394), Offset(1260, 418), Offset(1258, 438),
      Offset(1248, 454), Offset(1225, 458), Offset(1195, 456),
      Offset(1155, 452),
    ],
  ),

  // z46 -- Sacrum
  BodyRegion(
    id: 'z46', label: 'Sacrum', number: 46, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1115, 456), Offset(1155, 452), Offset(1195, 456),
      Offset(1205, 472), Offset(1198, 504), Offset(1185, 535),
      Offset(1170, 558), Offset(1155, 570),
      Offset(1140, 558), Offset(1125, 535), Offset(1112, 504),
      Offset(1105, 472),
    ],
  ),

  // z38 -- L. Buttock
  BodyRegion(
    id: 'z38', label: 'L. Buttock', number: 38, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1062, 454), Offset(1085, 458), Offset(1115, 456),
      Offset(1105, 472), Offset(1112, 504), Offset(1125, 535),
      Offset(1140, 558), Offset(1155, 570),
      Offset(1130, 585), Offset(1105, 592),
      Offset(1078, 590), Offset(1055, 580), Offset(1038, 564),
      Offset(1030, 542), Offset(1030, 518), Offset(1036, 496),
      Offset(1046, 476),
    ],
  ),

  // z39 -- R. Buttock
  BodyRegion(
    id: 'z39', label: 'R. Buttock', number: 39, isFront: false,
    group: EasiGroup.trunk,
    polyPoints: [
      Offset(1248, 454), Offset(1225, 458), Offset(1195, 456),
      Offset(1205, 472), Offset(1198, 504), Offset(1185, 535),
      Offset(1170, 558), Offset(1155, 570),
      Offset(1180, 585), Offset(1205, 592),
      Offset(1232, 590), Offset(1255, 580), Offset(1272, 564),
      Offset(1280, 542), Offset(1280, 518), Offset(1274, 496),
      Offset(1264, 476),
    ],
  ),

  // ── LOWER EXTREMITY ZONES (retraced) ──────────────────────────────────

  // z40 -- L. Thigh (B)
  BodyRegion(
    id: 'z40', label: 'L. Thigh (B)', number: 40, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1038, 564), Offset(1055, 580), Offset(1078, 590),
      Offset(1105, 592), Offset(1130, 585),
      Offset(1120, 635), Offset(1108, 690), Offset(1096, 740),
      Offset(1085, 780), Offset(1078, 810),
      Offset(1024, 812),
      Offset(1018, 780), Offset(1014, 740), Offset(1014, 690),
      Offset(1018, 640), Offset(1025, 600),
    ],
  ),

  // z41 -- R. Thigh (B)
  BodyRegion(
    id: 'z41', label: 'R. Thigh (B)', number: 41, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1272, 564), Offset(1255, 580), Offset(1232, 590),
      Offset(1205, 592), Offset(1180, 585),
      Offset(1190, 635), Offset(1202, 690), Offset(1214, 740),
      Offset(1225, 780), Offset(1232, 810),
      Offset(1270, 812),
      Offset(1278, 780), Offset(1284, 740), Offset(1288, 690),
      Offset(1286, 640), Offset(1280, 600),
    ],
  ),

  // z47 -- L. Back Knee
  BodyRegion(
    id: 'z47', label: 'L. Back Knee', number: 47, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1024, 812), Offset(1078, 810),
      Offset(1080, 840), Offset(1078, 870), Offset(1072, 900),
      Offset(1064, 920),
      Offset(1034, 922), Offset(1008, 920),
      Offset(1002, 900), Offset(1004, 870), Offset(1010, 840),
    ],
  ),

  // z48 -- R. Back Knee
  BodyRegion(
    id: 'z48', label: 'R. Back Knee', number: 48, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1232, 810), Offset(1270, 812),
      Offset(1272, 840), Offset(1272, 870), Offset(1268, 900),
      Offset(1260, 920),
      Offset(1238, 922), Offset(1216, 920),
      Offset(1212, 900), Offset(1214, 870), Offset(1218, 840),
    ],
  ),

  // z42 -- L. Calf
  BodyRegion(
    id: 'z42', label: 'L. Calf', number: 42, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1008, 920), Offset(1034, 922), Offset(1064, 920),
      Offset(1060, 950), Offset(1054, 980),
      Offset(1046, 1008), Offset(1042, 1028),
      Offset(1000, 1030),
      Offset(994, 1008), Offset(990, 980), Offset(992, 950),
    ],
  ),

  // z43 -- R. Calf
  BodyRegion(
    id: 'z43', label: 'R. Calf', number: 43, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1216, 920), Offset(1238, 922), Offset(1260, 920),
      Offset(1264, 950), Offset(1264, 980), Offset(1258, 1008),
      Offset(1252, 1028),
      Offset(1222, 1030),
      Offset(1216, 1008), Offset(1212, 980), Offset(1212, 950),
    ],
  ),

  // z44 -- L. Foot (B)
  BodyRegion(
    id: 'z44', label: 'L. Foot (B)', number: 44, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1000, 1030), Offset(1042, 1028),
      Offset(1046, 1044), Offset(1046, 1062),
      Offset(1040, 1078), Offset(1028, 1090),
      Offset(1012, 1098), Offset(992, 1102),
      Offset(972, 1100), Offset(954, 1094),
      Offset(942, 1084), Offset(938, 1070),
      Offset(940, 1056), Offset(948, 1044),
      Offset(962, 1036), Offset(980, 1032),
    ],
  ),

  // z45 -- R. Foot (B)
  BodyRegion(
    id: 'z45', label: 'R. Foot (B)', number: 45, isFront: false,
    group: EasiGroup.lowerExt,
    polyPoints: [
      Offset(1222, 1030), Offset(1252, 1028),
      Offset(1260, 1044), Offset(1268, 1058), Offset(1270, 1074),
      Offset(1266, 1088), Offset(1256, 1098), Offset(1240, 1104),
      Offset(1222, 1106), Offset(1206, 1102), Offset(1194, 1094),
      Offset(1186, 1082), Offset(1184, 1066), Offset(1188, 1050),
      Offset(1198, 1040), Offset(1210, 1034),
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
