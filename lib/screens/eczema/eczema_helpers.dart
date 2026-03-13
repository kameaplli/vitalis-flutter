import 'package:flutter/material.dart';
import '../../models/eczema_log.dart';
import '../../models/easi_models.dart';

// ─── EASI helpers ─────────────────────────────────────────────────────────────

double computeEasi(Map<String, EasiRegionScore> scores) {
  double t = 0;
  for (final e in scores.entries) {
    t += e.value.easiContribution(groupForRegion(e.key));
  }
  return t;
}

String easiLabel(double v) {
  if (v == 0)   return 'Clear';
  if (v <= 1)   return 'Almost Clear';
  if (v <= 7)   return 'Mild';
  if (v <= 21)  return 'Moderate';
  if (v <= 50)  return 'Severe';
  return 'Very Severe';
}

Color easiColor(double v) {
  if (v == 0)   return const Color(0xFF9E9E9E);
  if (v <= 1)   return const Color(0xFF43A047);
  if (v <= 7)   return const Color(0xFFFDD835);
  if (v <= 21)  return const Color(0xFFFF9800);
  if (v <= 50)  return const Color(0xFFF4511E);
  return const Color(0xFFB71C1C);
}

// Convert EczemaLogSummary.parsedEasiAreas → Map<regionId, EasiRegionScore>
Map<String, EasiRegionScore> logToScores(EczemaLogSummary log) {
  final result = <String, EasiRegionScore>{};
  for (final area in log.parsedEasiAreas) {
    final id = area['area'] as String;
    if (id.isEmpty) continue;
    result[id] = EasiRegionScore.fromJson(area);
  }
  return result;
}

// ─── Extension helpers ────────────────────────────────────────────────────────

extension ListX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) { if (test(e)) return e; }
    return null;
  }
}
