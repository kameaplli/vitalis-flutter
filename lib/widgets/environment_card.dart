import 'package:flutter/material.dart';
import '../models/environment_data.dart';
import 'package:hugeicons/hugeicons.dart';

/// Displays current weather, air quality, and pollen conditions.
class EnvironmentCard extends StatelessWidget {
  final EnvironmentData data;
  const EnvironmentCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedCloud, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Environment', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (data.weatherDesc != null)
                  Text(data.weatherDesc!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            // Weather row
            Row(
              children: [
                _MetricChip(
                  icon: HugeIcons.strokeRoundedThermometer,
                  label: '${data.temperatureC?.toStringAsFixed(0) ?? '--'}C',
                  color: _tempColor(data.temperatureC),
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  icon: HugeIcons.strokeRoundedDroplet,
                  label: '${data.humidityPct?.toStringAsFixed(0) ?? '--'}%',
                  color: _humidityColor(data.humidityPct),
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  icon: HugeIcons.strokeRoundedSun01,
                  label: 'UV ${data.uvIndex?.toStringAsFixed(0) ?? '--'}',
                  color: _uvColor(data.uvIndex),
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  icon: HugeIcons.strokeRoundedFastWind,
                  label: '${data.windSpeedKph?.toStringAsFixed(0) ?? '--'} kph',
                  color: Colors.blueGrey,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Air quality row
            Row(
              children: [
                _MetricChip(
                  icon: HugeIcons.strokeRoundedCircle,
                  label: 'AQI ${data.aqi ?? '--'}',
                  color: _aqiColor(data.aqi),
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  icon: HugeIcons.strokeRoundedCorn,
                  label: 'PM2.5: ${data.pm25?.toStringAsFixed(0) ?? '--'}',
                  color: _pm25Color(data.pm25),
                ),
              ],
            ),
            // Pollen row
            if ((data.pollenTree ?? 0) > 0 || (data.pollenGrass ?? 0) > 0 || (data.pollenWeed ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if ((data.pollenTree ?? 0) > 0)
                    _PollenBar(label: 'Tree', level: data.pollenTree!),
                  if ((data.pollenGrass ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _PollenBar(label: 'Grass', level: data.pollenGrass!),
                    ),
                  if ((data.pollenWeed ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: _PollenBar(label: 'Weed', level: data.pollenWeed!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _tempColor(double? t) {
    if (t == null) return Colors.grey;
    if (t < 5) return Colors.blue;
    if (t > 30) return Colors.red;
    return Colors.green;
  }

  Color _humidityColor(double? h) {
    if (h == null) return Colors.grey;
    if (h < 30) return Colors.red;
    if (h < 40) return Colors.orange;
    return Colors.green;
  }

  Color _uvColor(double? uv) {
    if (uv == null) return Colors.grey;
    if (uv > 8) return Colors.red;
    if (uv > 6) return Colors.orange;
    return Colors.green;
  }

  Color _aqiColor(int? aqi) {
    if (aqi == null) return Colors.grey;
    if (aqi > 100) return Colors.red;
    if (aqi > 50) return Colors.orange;
    return Colors.green;
  }

  Color _pm25Color(double? pm) {
    if (pm == null) return Colors.grey;
    if (pm > 35) return Colors.red;
    if (pm > 25) return Colors.orange;
    return Colors.green;
  }
}

class _MetricChip extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final Color color;
  const _MetricChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollenBar extends StatelessWidget {
  final String label;
  final int level; // 0-5
  const _PollenBar({required this.label, required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level >= 4 ? Colors.red : (level >= 2 ? Colors.orange : Colors.green);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: HugeIcons.strokeRoundedLeaf01, size: 12, color: color),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(fontSize: 11)),
        ...List.generate(5, (i) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: i < level ? color : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        )),
      ],
    );
  }
}

/// Flare risk gauge widget — circular risk score 0-100.
class FlareRiskGauge extends StatelessWidget {
  final FlareRisk risk;
  const FlareRiskGauge({super.key, required this.risk});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = risk.score >= 60
        ? Colors.red
        : (risk.score >= 30 ? Colors.orange : Colors.green);
    final label = risk.score >= 60
        ? 'High Risk'
        : (risk.score >= 30 ? 'Moderate' : 'Low Risk');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedShield01, color: color, size: 20),
                const SizedBox(width: 8),
                Text('Flare Risk', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: risk.score / 100,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${risk.score}',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
                      ),
                      Text(label, style: TextStyle(fontSize: 11, color: color)),
                    ],
                  ),
                ],
              ),
            ),
            if (risk.factors.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...risk.factors.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text('+${f.contribution}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f.detail, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Displays environment-eczema correlation results.
class EnvironmentCorrelationCard extends StatelessWidget {
  final EnvironmentCorrelation correlation;
  const EnvironmentCorrelationCard({super.key, required this.correlation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final significant = correlation.factors.where((f) => f.significant).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedChartLineData01, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Environmental Triggers', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${correlation.environmentEntries} data points over ${correlation.periodDays} days',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (correlation.topTrigger != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Top trigger: ${correlation.topTrigger}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (significant.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...significant.map((f) => _FactorRow(factor: f)),
            ],
            if (significant.isEmpty && correlation.environmentEntries > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'No significant environmental triggers found yet. Keep logging!',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            if (correlation.environmentEntries == 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'No environment data. Enable location to auto-capture weather with each log.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  final EnvironmentFactor factor;
  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final isBad = factor.riskMultiplier >= 1.5;
    final color = isBad ? Colors.red : Colors.orange;
    final direction = factor.thresholdDirection == 'below' ? '<' : '>';
    final threshStr = factor.threshold != null
        ? ' ($direction ${factor.threshold!.toStringAsFixed(0)})'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_factorLabel(factor.factor)}$threshStr',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${factor.riskMultiplier.toStringAsFixed(1)}x risk',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  String _factorLabel(String f) {
    const labels = {
      'humidity': 'Low Humidity',
      'pm25': 'PM2.5',
      'temperature_low': 'Cold Temperature',
      'temperature_high': 'Hot Temperature',
      'uv_index': 'High UV',
      'pollen_tree': 'Tree Pollen',
      'pollen_grass': 'Grass Pollen',
      'pollen_weed': 'Weed Pollen',
      'aqi': 'Poor Air Quality',
    };
    return labels[f] ?? f;
  }
}
