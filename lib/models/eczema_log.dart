import 'dart:convert';
import 'easi_models.dart';

class EczemaLogSummary {
  final String id;
  final String logDate;
  final String logTime;
  final int? itchSeverity;
  final int? rednessSeverity;
  final String? flareIntensity;
  final dynamic affectedAreas;
  final bool? sleepDisrupted;
  final String? notes;
  final int? stressLevel;
  final bool? dairyConsumed;
  final bool? eggsConsumed;
  final bool? nutsConsumed;
  final bool? wheatConsumed;

  EczemaLogSummary({
    required this.id,
    required this.logDate,
    required this.logTime,
    this.itchSeverity,
    this.rednessSeverity,
    this.flareIntensity,
    this.affectedAreas,
    this.sleepDisrupted,
    this.notes,
    this.stressLevel,
    this.dairyConsumed,
    this.eggsConsumed,
    this.nutsConsumed,
    this.wheatConsumed,
  });

  factory EczemaLogSummary.fromJson(Map<String, dynamic> json) {
    return EczemaLogSummary(
      id: json['id'] ?? '',
      logDate: json['log_date'] ?? '',
      logTime: json['log_time'] ?? '',
      itchSeverity: json['itch_severity'],
      rednessSeverity: json['redness_severity'],
      flareIntensity: json['flare_intensity'],
      affectedAreas: json['affected_areas'],
      sleepDisrupted: json['sleep_disrupted'],
      notes: json['notes'],
      stressLevel: json['stress_level'],
      dairyConsumed: json['dairy_consumed'],
      eggsConsumed: json['eggs_consumed'],
      nutsConsumed: json['nuts_consumed'],
      wheatConsumed: json['wheat_consumed'],
    );
  }

  /// Unwrap the affected_areas field, which may be:
  ///   legacy:  [zoneObj, ...]
  ///   current: {"zones": [...], "patches": [...]}
  static List _unwrapZones(dynamic raw) {
    if (raw == null) return [];
    final decoded = raw is String ? jsonDecode(raw as String) : raw;
    if (decoded is Map) return (decoded['zones'] as List? ?? []);
    if (decoded is List) return decoded;
    return [];
  }

  static List _unwrapPatches(dynamic raw) {
    if (raw == null) return [];
    final decoded = raw is String ? jsonDecode(raw as String) : raw;
    if (decoded is Map) return (decoded['patches'] as List? ?? []);
    return [];
  }

  /// Returns Map<zoneId, itchLevel> handling both old (string list) and
  /// new (list of {area, level}) formats.
  Map<String, int> get parsedAreas {
    if (affectedAreas == null) return {};
    try {
      final List items = _unwrapZones(affectedAreas);
      final result = <String, int>{};
      for (final item in items) {
        if (item is Map) {
          final area = item['area'] as String?;
          if (area == null) continue;
          // New EASI format: compute a 0-10 level from attributes
          if (item.containsKey('erythema')) {
            final e = (item['erythema'] as num?)?.toInt() ?? 0;
            final p = (item['papulation'] as num?)?.toInt() ?? 0;
            final ex = (item['excoriation'] as num?)?.toInt() ?? 0;
            final l = (item['lichenification'] as num?)?.toInt() ?? 0;
            result[area] = ((e + p + ex + l) / 12.0 * 10).round();
          } else {
            result[area] = (item['level'] as num?)?.toInt() ?? 5;
          }
        } else if (item is String) {
          result[item] = 5; // legacy: no level info
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Drawn patches from this log entry (if any).
  List<DrawnPatch> get parsedPatches {
    try {
      return _unwrapPatches(affectedAreas)
          .whereType<Map>()
          .map((m) => DrawnPatch.fromJson(Map<String, dynamic>.from(m)))
          .where((p) => p.points.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns raw EASI area data — list of maps with full EASI attributes.
  /// Each entry: {area, erythema, papulation, excoriation, lichenification, area_score, level}
  List<Map<String, dynamic>> get parsedEasiAreas {
    if (affectedAreas == null) return [];
    try {
      final List items = _unwrapZones(affectedAreas);
      return items.whereType<Map>().map((item) {
        final area = item['area'] as String? ?? '';
        if (item.containsKey('erythema')) {
          return {
            'area': area,
            'erythema': (item['erythema'] as num?)?.toInt() ?? 0,
            'papulation': (item['papulation'] as num?)?.toInt() ?? 0,
            'excoriation': (item['excoriation'] as num?)?.toInt() ?? 0,
            'lichenification': (item['lichenification'] as num?)?.toInt() ?? 0,
            'area_score': (item['area_score'] as num?)?.toInt() ?? 1,
            'level': (item['level'] as num?)?.toInt(),
          };
        } else {
          // Legacy format — convert to EASI-shaped map
          final level = (item['level'] as num?)?.toInt() ?? 5;
          final attrs = (level / 10.0 * 3).round().clamp(0, 3);
          return {
            'area': area,
            'erythema': attrs,
            'papulation': attrs,
            'excoriation': 0,
            'lichenification': 0,
            'area_score': 1,
            'level': level,
          };
        }
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Computed EASI total from parsedEasiAreas (0–72).
  double get easiScore {
    const multipliers = {
      'head': 0.1, 'neck': 0.1,
      'shoulder': 0.2, 'upper_arm': 0.2, 'elbow': 0.2,
      'forearm': 0.2, 'hand': 0.2,
      'chest': 0.3, 'abdomen': 0.3, 'lower_abd': 0.3,
      'upper_back': 0.3, 'mid_back': 0.3, 'lower_back': 0.3, 'buttock': 0.3,
    };
    double total = 0.0;
    for (final area in parsedEasiAreas) {
      final id = (area['area'] as String? ?? '');
      // Strip prefix (f_ or b_) and find multiplier by keyword match
      final stripped = id.replaceFirst(RegExp(r'^[fb]_'), '');
      double mult = 0.4; // default: lower extremities
      for (final key in multipliers.keys) {
        if (stripped.startsWith(key)) { mult = multipliers[key]!; break; }
      }
      final e = (area['erythema'] as int? ?? 0);
      final p = (area['papulation'] as int? ?? 0);
      final ex = (area['excoriation'] as int? ?? 0);
      final l = (area['lichenification'] as int? ?? 0);
      final areaScore = (area['area_score'] as int? ?? 1);
      total += (e + p + ex + l) * areaScore * mult;
    }
    return total;
  }
}
