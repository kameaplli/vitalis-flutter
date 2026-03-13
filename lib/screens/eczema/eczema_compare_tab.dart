import 'package:flutter/material.dart';
import '../../models/eczema_log.dart';
import 'eczema_helpers.dart';

// ─── Visit comparison metrics table ───────────────────────────────────────────

class CompareMetricsTable extends StatelessWidget {
  final EczemaLogSummary logA;
  final EczemaLogSummary logB;
  const CompareMetricsTable({super.key, required this.logA, required this.logB});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String a, String b, {bool improved = false, bool worsened = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(child: Center(child: Text(a, style: const TextStyle(fontSize: 12)))),
          Expanded(child: Center(child: Text(b,
              style: TextStyle(fontSize: 12,
                  color: improved ? Colors.green : (worsened ? Colors.red : null),
                  fontWeight: (improved || worsened) ? FontWeight.bold : FontWeight.normal)))),
        ]),
      );
    }

    final easiA = logA.easiScore;
    final easiB = logB.easiScore;
    final itchA = logA.itchSeverity ?? 0;
    final itchB = logB.itchSeverity ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Metric Comparison', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      // Header
      Row(children: const [
        SizedBox(width: 120),
        Expanded(child: Center(child: Text('Visit A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
        Expanded(child: Center(child: Text('Visit B', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))),
      ]),
      const Divider(height: 10),
      row('Date', logA.logDate, logB.logDate),
      row('EASI Score', easiA.toStringAsFixed(1), easiB.toStringAsFixed(1),
          improved: easiB < easiA, worsened: easiB > easiA),
      row('Severity', easiLabel(easiA), easiLabel(easiB)),
      row('Itch VAS', '$itchA / 10', '$itchB / 10',
          improved: itchB < itchA, worsened: itchB > itchA),
      row('Sleep', (logA.sleepDisrupted ?? false) ? 'Disrupted' : 'OK',
          (logB.sleepDisrupted ?? false) ? 'Disrupted' : 'OK',
          improved: (logA.sleepDisrupted ?? false) && !(logB.sleepDisrupted ?? false),
          worsened: !(logA.sleepDisrupted ?? false) && (logB.sleepDisrupted ?? false)),
      row('Zones affected', '${logA.parsedAreas.length}', '${logB.parsedAreas.length}',
          improved: logB.parsedAreas.length < logA.parsedAreas.length,
          worsened: logB.parsedAreas.length > logA.parsedAreas.length),
    ]);
  }
}
