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
  final bool isFront;
  final bool isEllipse;
  // Rect in single-view 220×500 logical canvas
  final Rect svgRect;
  final EasiGroup group;

  const BodyRegion({
    required this.id,
    required this.label,
    required this.isFront,
    required this.isEllipse,
    required this.svgRect,
    required this.group,
  });

  Offset get centroid => svgRect.center;

  bool contains(Offset pt) {
    if (isEllipse) {
      final dx = (pt.dx - centroid.dx) / (svgRect.width / 2);
      final dy = (pt.dy - centroid.dy) / (svgRect.height / 2);
      return dx * dx + dy * dy <= 1.0;
    }
    return svgRect.contains(pt);
  }
}

// ─── EASI Region Score ────────────────────────────────────────────────────────

class EasiRegionScore {
  final String regionId;
  final int erythema;       // 0-3
  final int papulation;     // 0-3
  final int excoriation;    // 0-3
  final int lichenification; // 0-3
  final int areaScore;      // 1-6

  const EasiRegionScore({
    required this.regionId,
    this.erythema = 0,
    this.papulation = 0,
    this.excoriation = 0,
    this.lichenification = 0,
    this.areaScore = 1,
  });

  int get attributeSum => erythema + papulation + excoriation + lichenification;

  /// Backward-compat 0-10 level for color display
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
    if (t == 0)   return 'Clear';
    if (t <= 1)   return 'Almost Clear';
    if (t <= 7)   return 'Mild';
    if (t <= 21)  return 'Moderate';
    if (t <= 50)  return 'Severe';
    return 'Very Severe';
  }

  Color get color {
    final t = total;
    if (t == 0)   return const Color(0xFF4CAF50);
    if (t <= 1)   return const Color(0xFF8BC34A);
    if (t <= 7)   return const Color(0xFFFFC107);
    if (t <= 21)  return const Color(0xFFFF9800);
    if (t <= 50)  return const Color(0xFFFF5722);
    return const Color(0xFFF44336);
  }
}

// ─── Zone coordinate data ─────────────────────────────────────────────────────
// All zones use a single 220×500 logical canvas (single-view).
// Front zones use coordinates directly from original _kZones (left half, 0-219).
// Back zones subtract 220 from left to normalize to 0-based canvas.

EasiGroup _groupFor(String id) {
  final s = id.replaceFirst(RegExp(r'^[fb]_'), '');
  if (s.startsWith('head') || s.startsWith('neck')) { return EasiGroup.headNeck; }
  if (s.startsWith('shoulder') || s.startsWith('upper_arm') ||
      s.startsWith('elbow') || s.startsWith('forearm') ||
      s.startsWith('hand')) { return EasiGroup.upperExt; }
  if (s.startsWith('chest') || s.startsWith('abdomen') ||
      s.startsWith('lower_abd') || s.startsWith('upper_back') ||
      s.startsWith('mid_back') || s.startsWith('lower_back') ||
      s.startsWith('buttock')) { return EasiGroup.trunk; }
  return EasiGroup.lowerExt;
}

EasiGroup groupForRegion(String regionId) => _groupFor(regionId);

// Front zones (id prefix 'f_') — coordinates from original SVG, already 0-based.
const kFrontRegions = <BodyRegion>[
  BodyRegion(id: 'f_head',        label: 'Head',           isFront: true,  isEllipse: true,  svgRect: Rect.fromLTWH(88,  12, 44, 52), group: EasiGroup.headNeck),
  BodyRegion(id: 'f_neck',        label: 'Neck',           isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(102, 63, 16, 12), group: EasiGroup.headNeck),
  BodyRegion(id: 'f_shoulder_r',  label: 'R. Shoulder',    isFront: true,  isEllipse: true,  svgRect: Rect.fromLTWH(69,  72, 26, 16), group: EasiGroup.upperExt),
  BodyRegion(id: 'f_shoulder_l',  label: 'L. Shoulder',    isFront: true,  isEllipse: true,  svgRect: Rect.fromLTWH(125, 72, 26, 16), group: EasiGroup.upperExt),
  BodyRegion(id: 'f_chest_r',     label: 'R. Chest',       isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(103, 75, 15, 30), group: EasiGroup.trunk),
  BodyRegion(id: 'f_chest_l',     label: 'L. Chest',       isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(118, 75, 15, 30), group: EasiGroup.trunk),
  BodyRegion(id: 'f_abdomen_r',   label: 'R. Abdomen',     isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(103,105, 15, 33), group: EasiGroup.trunk),
  BodyRegion(id: 'f_abdomen_l',   label: 'L. Abdomen',     isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(118,105, 15, 33), group: EasiGroup.trunk),
  BodyRegion(id: 'f_lower_abd',   label: 'Lower Abdomen',  isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(106,138, 24, 17), group: EasiGroup.trunk),
  BodyRegion(id: 'f_upper_arm_r', label: 'R. Upper Arm',   isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(68,  76, 15, 42), group: EasiGroup.upperExt),
  BodyRegion(id: 'f_upper_arm_l', label: 'L. Upper Arm',   isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(137, 76, 15, 42), group: EasiGroup.upperExt),
  BodyRegion(id: 'f_elbow_r',     label: 'R. Elbow',       isFront: true,  isEllipse: true,  svgRect: Rect.fromLTWH(69, 116, 16, 12), group: EasiGroup.upperExt),
  BodyRegion(id: 'f_elbow_l',     label: 'L. Elbow',       isFront: true,  isEllipse: true,  svgRect: Rect.fromLTWH(135,116, 16, 12), group: EasiGroup.upperExt),
  BodyRegion(id: 'f_forearm_r',   label: 'R. Forearm',     isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(67, 127, 18, 41), group: EasiGroup.upperExt),
  BodyRegion(id: 'f_forearm_l',   label: 'L. Forearm',     isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(133,127, 18, 41), group: EasiGroup.upperExt),
  BodyRegion(id: 'f_hand_r',      label: 'R. Hand',        isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(63, 168, 24, 20), group: EasiGroup.upperExt),
  BodyRegion(id: 'f_hand_l',      label: 'L. Hand',        isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(133,168, 24, 20), group: EasiGroup.upperExt),
  BodyRegion(id: 'f_thigh_r',     label: 'R. Thigh',       isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(103,155, 15, 45), group: EasiGroup.lowerExt),
  BodyRegion(id: 'f_thigh_l',     label: 'L. Thigh',       isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(119,155, 15, 45), group: EasiGroup.lowerExt),
  BodyRegion(id: 'f_knee_r',      label: 'R. Knee',        isFront: true,  isEllipse: true,  svgRect: Rect.fromLTWH(102,198, 16, 16), group: EasiGroup.lowerExt),
  BodyRegion(id: 'f_knee_l',      label: 'L. Knee',        isFront: true,  isEllipse: true,  svgRect: Rect.fromLTWH(118,198, 16, 16), group: EasiGroup.lowerExt),
  BodyRegion(id: 'f_shin_r',      label: 'R. Shin',        isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(101,214, 17, 46), group: EasiGroup.lowerExt),
  BodyRegion(id: 'f_shin_l',      label: 'L. Shin',        isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(118,214, 17, 46), group: EasiGroup.lowerExt),
  BodyRegion(id: 'f_foot_r',      label: 'R. Foot',        isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(100,261, 18, 14), group: EasiGroup.lowerExt),
  BodyRegion(id: 'f_foot_l',      label: 'L. Foot',        isFront: true,  isEllipse: false, svgRect: Rect.fromLTWH(120,261, 18, 14), group: EasiGroup.lowerExt),
];

// Back zones (id prefix 'b_') — original left coords had +220 offset; subtract 220 to normalize.
const kBackRegions = <BodyRegion>[
  BodyRegion(id: 'b_head',         label: 'Head (Back)',       isFront: false, isEllipse: true,  svgRect: Rect.fromLTWH(88,  12, 44, 52), group: EasiGroup.headNeck),
  BodyRegion(id: 'b_neck',         label: 'Neck (Back)',       isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(102, 63, 16, 12), group: EasiGroup.headNeck),
  BodyRegion(id: 'b_shoulder_r',   label: 'R. Shoulder (B)',   isFront: false, isEllipse: true,  svgRect: Rect.fromLTWH(69,  72, 26, 16), group: EasiGroup.upperExt),
  BodyRegion(id: 'b_shoulder_l',   label: 'L. Shoulder (B)',   isFront: false, isEllipse: true,  svgRect: Rect.fromLTWH(125, 72, 26, 16), group: EasiGroup.upperExt),
  BodyRegion(id: 'b_upper_back_r', label: 'R. Upper Back',     isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(103, 75, 15, 33), group: EasiGroup.trunk),
  BodyRegion(id: 'b_upper_back_l', label: 'L. Upper Back',     isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(118, 75, 15, 33), group: EasiGroup.trunk),
  BodyRegion(id: 'b_mid_back_r',   label: 'R. Mid Back',       isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(103,108, 15, 30), group: EasiGroup.trunk),
  BodyRegion(id: 'b_mid_back_l',   label: 'L. Mid Back',       isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(118,108, 15, 30), group: EasiGroup.trunk),
  BodyRegion(id: 'b_lower_back',   label: 'Lower Back',        isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(103,138, 28, 17), group: EasiGroup.trunk),
  BodyRegion(id: 'b_buttock_r',    label: 'R. Buttock',        isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(103,155, 15, 30), group: EasiGroup.trunk),
  BodyRegion(id: 'b_buttock_l',    label: 'L. Buttock',        isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(118,155, 15, 30), group: EasiGroup.trunk),
  BodyRegion(id: 'b_upper_arm_r',  label: 'R. Upper Arm (B)',  isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(69,  76, 14, 44), group: EasiGroup.upperExt),
  BodyRegion(id: 'b_upper_arm_l',  label: 'L. Upper Arm (B)',  isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(137, 76, 14, 44), group: EasiGroup.upperExt),
  BodyRegion(id: 'b_elbow_r',      label: 'R. Elbow (B)',      isFront: false, isEllipse: true,  svgRect: Rect.fromLTWH(69, 116, 16, 12), group: EasiGroup.upperExt),
  BodyRegion(id: 'b_elbow_l',      label: 'L. Elbow (B)',      isFront: false, isEllipse: true,  svgRect: Rect.fromLTWH(135,116, 16, 12), group: EasiGroup.upperExt),
  BodyRegion(id: 'b_forearm_r',    label: 'R. Forearm (B)',    isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(67, 127, 18, 41), group: EasiGroup.upperExt),
  BodyRegion(id: 'b_forearm_l',    label: 'L. Forearm (B)',    isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(133,127, 18, 41), group: EasiGroup.upperExt),
  BodyRegion(id: 'b_hand_r',       label: 'R. Hand (B)',       isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(63, 168, 24, 20), group: EasiGroup.upperExt),
  BodyRegion(id: 'b_hand_l',       label: 'L. Hand (B)',       isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(133,168, 24, 20), group: EasiGroup.upperExt),
  BodyRegion(id: 'b_thigh_r',      label: 'R. Thigh (B)',      isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(103,185, 15, 33), group: EasiGroup.lowerExt),
  BodyRegion(id: 'b_thigh_l',      label: 'L. Thigh (B)',      isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(118,185, 15, 33), group: EasiGroup.lowerExt),
  BodyRegion(id: 'b_knee_r',       label: 'R. Knee (B)',       isFront: false, isEllipse: true,  svgRect: Rect.fromLTWH(102,216, 16, 16), group: EasiGroup.lowerExt),
  BodyRegion(id: 'b_knee_l',       label: 'L. Knee (B)',       isFront: false, isEllipse: true,  svgRect: Rect.fromLTWH(118,216, 16, 16), group: EasiGroup.lowerExt),
  BodyRegion(id: 'b_calf_r',       label: 'R. Calf',           isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(101,232, 17, 40), group: EasiGroup.lowerExt),
  BodyRegion(id: 'b_calf_l',       label: 'L. Calf',           isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(118,232, 17, 40), group: EasiGroup.lowerExt),
  BodyRegion(id: 'b_foot_r',       label: 'R. Foot (B)',       isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(100,273, 18, 14), group: EasiGroup.lowerExt),
  BodyRegion(id: 'b_foot_l',       label: 'L. Foot (B)',       isFront: false, isEllipse: false, svgRect: Rect.fromLTWH(120,273, 18, 14), group: EasiGroup.lowerExt),
];

BodyRegion? findRegion(String id) {
  try {
    return [...kFrontRegions, ...kBackRegions].firstWhere((r) => r.id == id);
  } catch (_) {
    return null;
  }
}
