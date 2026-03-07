/// Phase 1: Environmental Intelligence — data models

class EnvironmentData {
  final double? temperatureC;
  final double? humidityPct;
  final double? uvIndex;
  final double? windSpeedKph;
  final int? weatherCode;
  final String? weatherDesc;
  final int? aqi;
  final double? pm25;
  final double? pm10;
  final int? pollenTree;
  final int? pollenGrass;
  final int? pollenWeed;
  final double? latitude;
  final double? longitude;
  final String? fetchedAt;

  EnvironmentData({
    this.temperatureC,
    this.humidityPct,
    this.uvIndex,
    this.windSpeedKph,
    this.weatherCode,
    this.weatherDesc,
    this.aqi,
    this.pm25,
    this.pm10,
    this.pollenTree,
    this.pollenGrass,
    this.pollenWeed,
    this.latitude,
    this.longitude,
    this.fetchedAt,
  });

  factory EnvironmentData.fromJson(Map<String, dynamic> json) {
    return EnvironmentData(
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      humidityPct: (json['humidity_pct'] as num?)?.toDouble(),
      uvIndex: (json['uv_index'] as num?)?.toDouble(),
      windSpeedKph: (json['wind_speed_kph'] as num?)?.toDouble(),
      weatherCode: json['weather_code'] as int?,
      weatherDesc: json['weather_desc'] as String?,
      aqi: json['aqi'] as int?,
      pm25: (json['pm25'] as num?)?.toDouble(),
      pm10: (json['pm10'] as num?)?.toDouble(),
      pollenTree: json['pollen_tree'] as int?,
      pollenGrass: json['pollen_grass'] as int?,
      pollenWeed: json['pollen_weed'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      fetchedAt: json['fetched_at'] as String?,
    );
  }
}

class EnvironmentCorrelation {
  final List<EnvironmentFactor> factors;
  final int flareRiskScore;
  final String? topTrigger;
  final String dataQuality;
  final int periodDays;
  final int eczemaEntries;
  final int environmentEntries;

  EnvironmentCorrelation({
    required this.factors,
    required this.flareRiskScore,
    this.topTrigger,
    required this.dataQuality,
    required this.periodDays,
    required this.eczemaEntries,
    required this.environmentEntries,
  });

  factory EnvironmentCorrelation.fromJson(Map<String, dynamic> json) {
    return EnvironmentCorrelation(
      factors: (json['factors'] as List<dynamic>? ?? [])
          .map((f) => EnvironmentFactor.fromJson(f as Map<String, dynamic>))
          .toList(),
      flareRiskScore: json['flare_risk_score'] as int? ?? 0,
      topTrigger: json['top_trigger'] as String?,
      dataQuality: json['data_quality'] as String? ?? 'insufficient',
      periodDays: json['period_days'] as int? ?? 0,
      eczemaEntries: json['eczema_entries'] as int? ?? 0,
      environmentEntries: json['environment_entries'] as int? ?? 0,
    );
  }
}

class EnvironmentFactor {
  final String factor;
  final double correlation;
  final double? threshold;
  final String? thresholdDirection;
  final double avgItchBad;
  final double avgItchNormal;
  final double riskMultiplier;
  final int dataPoints;
  final bool significant;

  EnvironmentFactor({
    required this.factor,
    required this.correlation,
    this.threshold,
    this.thresholdDirection,
    required this.avgItchBad,
    required this.avgItchNormal,
    required this.riskMultiplier,
    required this.dataPoints,
    required this.significant,
  });

  factory EnvironmentFactor.fromJson(Map<String, dynamic> json) {
    return EnvironmentFactor(
      factor: json['factor'] as String? ?? '',
      correlation: (json['correlation'] as num?)?.toDouble() ?? 0,
      threshold: (json['threshold'] as num?)?.toDouble(),
      thresholdDirection: json['threshold_direction'] as String?,
      avgItchBad: (json['avg_itch_bad'] as num?)?.toDouble() ?? 0,
      avgItchNormal: (json['avg_itch_normal'] as num?)?.toDouble() ?? 0,
      riskMultiplier: (json['risk_multiplier'] as num?)?.toDouble() ?? 0,
      dataPoints: json['data_points'] as int? ?? 0,
      significant: json['significant'] as bool? ?? false,
    );
  }
}

class FlareRisk {
  final int score;
  final List<FlareRiskFactor> factors;
  final EnvironmentData? currentConditions;

  FlareRisk({
    required this.score,
    required this.factors,
    this.currentConditions,
  });

  factory FlareRisk.fromJson(Map<String, dynamic> json) {
    return FlareRisk(
      score: json['score'] as int? ?? 0,
      factors: (json['factors'] as List<dynamic>? ?? [])
          .map((f) => FlareRiskFactor.fromJson(f as Map<String, dynamic>))
          .toList(),
      currentConditions: json['current_conditions'] != null
          ? EnvironmentData.fromJson(json['current_conditions'] as Map<String, dynamic>)
          : null,
    );
  }
}

class FlareRiskFactor {
  final String factor;
  final int contribution;
  final String detail;

  FlareRiskFactor({
    required this.factor,
    required this.contribution,
    required this.detail,
  });

  factory FlareRiskFactor.fromJson(Map<String, dynamic> json) {
    return FlareRiskFactor(
      factor: json['factor'] as String? ?? '',
      contribution: json['contribution'] as int? ?? 0,
      detail: json['detail'] as String? ?? '',
    );
  }
}
