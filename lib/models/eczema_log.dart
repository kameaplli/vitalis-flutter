import 'dart:convert';

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
    );
  }

  /// Returns Map<zoneId, itchLevel> handling both old (string list) and
  /// new (list of {area, level}) formats.
  Map<String, int> get parsedAreas {
    if (affectedAreas == null) return {};
    try {
      final List items = affectedAreas is String
          ? jsonDecode(affectedAreas as String) as List
          : affectedAreas as List;
      final result = <String, int>{};
      for (final item in items) {
        if (item is Map) {
          final area = item['area'] as String?;
          final level = (item['level'] as num?)?.toInt();
          if (area != null) result[area] = level ?? 5;
        } else if (item is String) {
          result[item] = 5; // legacy: no level info
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }
}
