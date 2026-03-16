import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/eczema_log.dart';
import '../../models/easi_models.dart';
import '../../providers/eczema_provider.dart';
import 'eczema_helpers.dart';

// ─── PDF colour helpers ──────────────────────────────────────────────────────

PdfColor pdfItchColor(double avgItch) {
  if (avgItch <= 0) return PdfColors.grey;
  if (avgItch <= 2) return PdfColors.green400;
  if (avgItch <= 4) return PdfColors.yellow700;
  if (avgItch <= 6) return PdfColors.orange;
  if (avgItch <= 8) return PdfColors.deepOrange;
  return PdfColors.red900;
}

String pdfItchLabel(double avgItch) {
  if (avgItch <= 0) return 'None';
  if (avgItch <= 2) return 'Mild';
  if (avgItch <= 4) return 'Moderate';
  if (avgItch <= 6) return 'Significant';
  if (avgItch <= 8) return 'Severe';
  return 'Extreme';
}

const kAccent = PdfColor(0.16, 0.65, 0.60);       // teal 500
const kAccentLight = PdfColor(0.88, 0.96, 0.95);  // teal 50
const kDanger = PdfColor(0.76, 0.20, 0.20);       // red 800
const kDangerLight = PdfColor(1, 0.92, 0.93);     // red 50
const kSuccess = PdfColor(0.19, 0.55, 0.24);      // green 800
const kSuccessLight = PdfColor(0.91, 0.96, 0.91); // green 50

// ─── PDF Logo (vector-drawn Qorhealth "V" leaf mark) ──────────────────────────

class PdfLogo extends pw.StatelessWidget {
  final double size;
  PdfLogo({this.size = 32});

  @override
  pw.Widget build(pw.Context context) {
    return pw.CustomPaint(
      size: PdfPoint(size, size),
      painter: (PdfGraphics gfx, PdfPoint sz) {
        final s = sz.x;
        final cx = s / 2;
        final cy = s / 2;
        final r = s / 2;

        // White circle background
        gfx.setFillColor(PdfColors.white);
        // Draw circle as 4 bezier curves
        const kappa = 0.5522848;
        final ox = r * kappa;
        final oy = r * kappa;
        gfx.moveTo(cx, cy - r);
        gfx.curveTo(cx + ox, cy - r, cx + r, cy - oy, cx + r, cy);
        gfx.curveTo(cx + r, cy + oy, cx + ox, cy + r, cx, cy + r);
        gfx.curveTo(cx - ox, cy + r, cx - r, cy + oy, cx - r, cy);
        gfx.curveTo(cx - r, cy - oy, cx - ox, cy - r, cx, cy - r);
        gfx.closePath();
        gfx.fillPath();

        // Teal "V" letter
        final vLeft = s * 0.22;
        final vRight = s * 0.78;
        final vTop = s * 0.22;
        final vBottom = s * 0.72;
        final vMid = s * 0.50;
        final strokeW = s * 0.09;

        gfx.setStrokeColor(const PdfColor(0.16, 0.65, 0.60));
        gfx.setLineWidth(strokeW);
        gfx.setLineCap(PdfLineCap.round);
        gfx.setLineJoin(PdfLineJoin.round);
        gfx.moveTo(vLeft, s - vTop);
        gfx.lineTo(vMid, s - vBottom);
        gfx.lineTo(vRight, s - vTop);
        gfx.strokePath();

        // Small leaf accent (top-right of V)
        gfx.setFillColor(const PdfColor(0.30, 0.78, 0.55)); // green accent
        final leafCx = vRight - s * 0.04;
        final leafCy = s - vTop + s * 0.06;
        final leafR = s * 0.06;
        gfx.moveTo(leafCx, leafCy - leafR);
        gfx.curveTo(leafCx + leafR * 1.2, leafCy - leafR * 0.5,
            leafCx + leafR * 1.2, leafCy + leafR * 0.5,
            leafCx, leafCy + leafR);
        gfx.curveTo(leafCx - leafR * 1.2, leafCy + leafR * 0.5,
            leafCx - leafR * 1.2, leafCy - leafR * 0.5,
            leafCx, leafCy - leafR);
        gfx.closePath();
        gfx.fillPath();
      },
    );
  }
}

// ─── PDF Body Map (draws zone polygons directly into PDF) ─────────────────────

class PdfBodyMap extends pw.StatelessWidget {
  final double width;
  final Map<String, double> heatIntensity; // zoneId → 0.0-1.0
  final Map<String, double> zoneAvgItch;   // zoneId → avg itch 0-10

  PdfBodyMap({
    required this.width,
    required this.heatIntensity,
    required this.zoneAvgItch,
  });

  // Zone coordinates are in 1548×1134 space
  static const double _srcW = 1548.0;
  static const double _srcH = 1134.0;

  static PdfColor _heatColor(double t) {
    if (t <= 0.00) return PdfColors.grey400;
    if (t <  0.20) return PdfColors.green400;
    if (t <  0.40) return PdfColors.yellow700;
    if (t <  0.60) return PdfColors.orange;
    if (t <  0.80) return PdfColors.deepOrange;
    return PdfColors.red900;
  }

  @override
  pw.Widget build(pw.Context context) {
    final h = width * (_srcH / _srcW);
    return pw.CustomPaint(
      size: PdfPoint(width, h),
      painter: (PdfGraphics gfx, PdfPoint size) {
        final sw = size.x / _srcW;
        final sh = size.y / _srcH;
        final allRegions = [...kFrontRegions, ...kBackRegions];

        // Draw a light border around the entire canvas
        gfx.setStrokeColor(PdfColors.grey300);
        gfx.setLineWidth(0.5);
        gfx.drawRect(0, 0, size.x, size.y);
        gfx.strokePath();

        // Draw "FRONT" and "BACK" labels using a divider line at midpoint
        final midX = size.x * (774.0 / _srcW); // approx midpoint between front/back
        gfx.setStrokeColor(PdfColors.grey300);
        gfx.setLineWidth(0.3);
        gfx.moveTo(midX, 0);
        gfx.lineTo(midX, size.y);
        gfx.strokePath();

        for (final region in allRegions) {
          final intensity = heatIntensity[region.id] ?? 0;
          final poly = region.polyPoints;
          if (poly.length < 3) continue;

          // Build polygon path — PDF y-axis is bottom-up, so flip
          gfx.saveContext();

          if (intensity > 0.01) {
            // Filled zone with heat color
            final color = _heatColor(intensity);
            gfx.setFillColor(PdfColor(color.red, color.green, color.blue, 0.35));
            gfx.moveTo(poly[0].dx * sw, size.y - poly[0].dy * sh);
            for (int i = 1; i < poly.length; i++) {
              gfx.lineTo(poly[i].dx * sw, size.y - poly[i].dy * sh);
            }
            gfx.closePath();
            gfx.fillPath();

            // Colored outline
            gfx.setStrokeColor(PdfColor(color.red, color.green, color.blue, 0.9));
            gfx.setLineWidth(1.2);
            gfx.moveTo(poly[0].dx * sw, size.y - poly[0].dy * sh);
            for (int i = 1; i < poly.length; i++) {
              gfx.lineTo(poly[i].dx * sw, size.y - poly[i].dy * sh);
            }
            gfx.closePath();
            gfx.strokePath();
          } else {
            // Grey outline only
            gfx.setStrokeColor(PdfColors.grey400);
            gfx.setLineWidth(0.5);
            gfx.moveTo(poly[0].dx * sw, size.y - poly[0].dy * sh);
            for (int i = 1; i < poly.length; i++) {
              gfx.lineTo(poly[i].dx * sw, size.y - poly[i].dy * sh);
            }
            gfx.closePath();
            gfx.strokePath();
          }

          gfx.restoreContext();
        }
      },
    );
  }
}

// ─── PDF page header ────────────────────────────────────────────────────────

pw.Widget pdfPageHeader(String title, int days) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
  decoration: pw.BoxDecoration(
    color: PdfColors.grey100,
    border: pw.Border(bottom: pw.BorderSide(color: kAccent, width: 2)),
  ),
  child: pw.Row(children: [
    PdfLogo(size: 20),
    pw.SizedBox(width: 8),
    pw.Text(title,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    pw.Spacer(),
    pw.Text('Last  days  |  Qorhealth',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
  ]),
);

// ─── PDF Export ─────────────────────────────────────────────────────────────

Future<void> exportEczemaPdf({
  required List<EczemaLogSummary> logs,
  required int days,
  FoodCorrelationData? foodCorrelation,
}) async {
  final doc = pw.Document();
  final now = DateTime.now();

  // ── Pre-compute stats ────────────────────────────────────
  final itchValues = logs.where((l) => l.itchSeverity != null).map((l) => l.itchSeverity!).toList();
  final avgItch = itchValues.isEmpty ? 0.0 : itchValues.reduce((a, b) => a + b) / itchValues.length;
  final maxItch = itchValues.isEmpty ? 0 : itchValues.reduce((a, b) => a > b ? a : b);
  final easiScores = logs.map((l) => l.easiScore).toList();
  final avgEasi = easiScores.isEmpty ? 0.0 : easiScores.reduce((a, b) => a + b) / easiScores.length;
  final maxEasi = easiScores.isEmpty ? 0.0 : easiScores.reduce((a, b) => a > b ? a : b);
  final sleepDisrupted = logs.where((l) => l.sleepDisrupted == true).length;
  final flareDays = logs.where((l) => (l.itchSeverity ?? 0) >= 6).length;

  final zoneItchSum = <String, double>{};
  final zoneItchCount = <String, int>{};
  for (final log in logs) {
    final itch = log.itchSeverity ?? 0;
    for (final zoneId in log.parsedAreas.keys) {
      zoneItchSum[zoneId] = (zoneItchSum[zoneId] ?? 0) + itch;
      zoneItchCount[zoneId] = (zoneItchCount[zoneId] ?? 0) + 1;
    }
  }
  final zoneAvgItch = <String, double>{};
  for (final id in zoneItchSum.keys) {
    zoneAvgItch[id] = zoneItchSum[id]! / zoneItchCount[id]!;
  }
  final sortedZones = zoneAvgItch.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final heatIntensity = <String, double>{};
  for (final e in zoneAvgItch.entries) {
    heatIntensity[e.key] = (e.value / 10.0).clamp(0.0, 1.0);
  }

  // Body group aggregation
  final groupData = <String, (double itchSum, int itchCount, int zoneCount)>{};
  for (final e in zoneAvgItch.entries) {
    final region = findRegion(e.key);
    final gName = region?.group.label ?? 'Unknown';
    final c = zoneItchCount[e.key] ?? 0;
    final cur = groupData[gName] ?? (0.0, 0, 0);
    groupData[gName] = (cur.$1 + e.value * c, cur.$2 + c, cur.$3 + 1);
  }
  final sortedGroups = groupData.entries.toList()
    ..sort((a, b) {
      final aa = a.value.$2 > 0 ? a.value.$1 / a.value.$2 : 0.0;
      final bb = b.value.$2 > 0 ? b.value.$1 / b.value.$2 : 0.0;
      return bb.compareTo(aa);
    });

  final pageW = PdfPageFormat.a4.availableWidth - 56;

  // ── Shared widgets ───────────────────────────────────────

  pw.Widget sectionTitle(String text, {PdfColor color = PdfColors.grey900}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
      );

  pw.Widget sectionSubtitle(String text) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      );

  pw.Widget metricCard(String label, String value, PdfColor accent, {String? sub}) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: pw.BoxDecoration(
            color: PdfColor(accent.red, accent.green, accent.blue, 0.06),
            border: pw.Border.all(color: PdfColor(accent.red, accent.green, accent.blue, 0.25), width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(children: [
            pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accent)),
            pw.SizedBox(height: 2),
            pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            if (sub != null) pw.Text(sub, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
          ]),
        ),
      );

  pw.Widget itchBar(double value, double maxVal, PdfColor color, double barWidth) =>
      pw.Container(
        width: barWidth,
        height: 8,
        decoration: pw.BoxDecoration(
          color: PdfColor(color.red, color.green, color.blue, 0.12),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Container(
            width: barWidth * (value / maxVal).clamp(0.0, 1.0),
            height: 8,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
          ),
        ),
      );

  pw.Widget dividerLine() => pw.Container(
    height: 0.5,
    color: PdfColors.grey300,
    margin: const pw.EdgeInsets.symmetric(vertical: 10),
  );

  // ══════════════════════════════════════════════════════════
  //  PAGE 1 — Cover + Key Metrics + Body Heatmap
  // ══════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Branded header with logo ──
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: pw.BoxDecoration(
            color: kAccent,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(children: [
            PdfLogo(size: 36),
            pw.SizedBox(width: 12),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Eczema Assessment Report',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.SizedBox(height: 2),
              pw.Text('Qorhealth Health Tracker',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColor(1, 1, 1, 0.75))),
            ]),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(DateFormat('dd MMMM yyyy').format(now),
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
              pw.Text('$days-day analysis period',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColor(1, 1, 1, 0.7))),
            ]),
          ]),
        ),
        pw.SizedBox(height: 14),

        // ── Key Metrics row ──
        pw.Row(children: [
          metricCard('Assessments', '${logs.length}', kAccent),
          pw.SizedBox(width: 6),
          metricCard('Avg Itch', '${avgItch.toStringAsFixed(1)}/10', pdfItchColor(avgItch),
              sub: pdfItchLabel(avgItch)),
          pw.SizedBox(width: 6),
          metricCard('Peak Itch', '$maxItch/10', pdfItchColor(maxItch.toDouble())),
          pw.SizedBox(width: 6),
          metricCard('Avg EASI', avgEasi.toStringAsFixed(1), kAccent,
              sub: easiLabel(avgEasi)),
          pw.SizedBox(width: 6),
          metricCard('Flare Days', '$flareDays', kDanger,
              sub: 'itch >= 6'),
          pw.SizedBox(width: 6),
          metricCard('Sleep Loss', '$sleepDisrupted', PdfColors.indigo,
              sub: 'nights'),
        ]),

        dividerLine(),

        // ── Body Heatmap ──
        sectionTitle('Itch Severity Heatmap'),
        // Legend
        pw.Row(children: [
          for (final e in [
            (PdfColors.grey400, 'None', 0.0),
            (PdfColors.green400, 'Mild', 2.0),
            (PdfColors.yellow700, 'Moderate', 4.0),
            (PdfColors.orange, 'Significant', 6.0),
            (PdfColors.deepOrange, 'Severe', 8.0),
            (PdfColors.red900, 'Extreme', 10.0),
          ]) ...[
            pw.Container(width: 8, height: 8,
                decoration: pw.BoxDecoration(color: e.$1, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)))),
            pw.SizedBox(width: 3),
            pw.Text(e.$2, style: const pw.TextStyle(fontSize: 7)),
            pw.SizedBox(width: 10),
          ],
        ]),
        pw.SizedBox(height: 6),
        pw.Center(
          child: PdfBodyMap(width: pageW, heatIntensity: heatIntensity, zoneAvgItch: zoneAvgItch),
        ),

        dividerLine(),

        // ── Most Affected Areas (with bars) ──
        if (sortedZones.isNotEmpty) ...[
          sectionTitle('Most Affected Areas'),
          sectionSubtitle('Top zones ranked by average itch severity over $days days'),
          ...sortedZones.take(8).map((e) {
            final region = findRegion(e.key);
            final lbl = region?.label ?? e.key;
            final avgI = e.value;
            final count = zoneItchCount[e.key] ?? 0;
            final pct = logs.isEmpty ? 0 : (count / logs.length * 100).round();
            final color = pdfItchColor(avgI);
            final group = region?.group.label ?? '';
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(children: [
                pw.Container(width: 8, height: 8,
                    decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle)),
                pw.SizedBox(width: 6),
                pw.SizedBox(width: 90,
                    child: pw.Text(lbl, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(width: 6),
                pw.Expanded(child: itchBar(avgI, 10, color, pageW * 0.35)),
                pw.SizedBox(width: 6),
                pw.SizedBox(width: 50,
                    child: pw.Text('${avgI.toStringAsFixed(1)}/10',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color))),
                pw.SizedBox(width: 40,
                    child: pw.Text('$pct% freq',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600))),
                pw.SizedBox(width: 55,
                    child: pw.Text(group,
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500))),
              ]),
            );
          }),
        ],
      ],
    ),
  ));

  // ══════════════════════════════════════════════════════════
  //  PAGE 2 — Food-Itch Correlation Analysis
  // ══════════════════════════════════════════════════════════
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) {
      final hasBad = foodCorrelation != null && foodCorrelation.badFoods.isNotEmpty;
      final hasGood = foodCorrelation != null && foodCorrelation.goodFoods.isNotEmpty;
      final hasFood = hasBad || hasGood;

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header bar
          pdfPageHeader('Food-Itch Correlation Analysis', days),
          pw.SizedBox(height: 12),

          if (!hasFood) ...[
            pw.Container(
              width: pageW,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(children: [
                pw.Text('No Food Correlation Data',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text('Insufficient nutrition data to compute food-itch correlations.\nLog meals consistently alongside eczema assessments for analysis.',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                    textAlign: pw.TextAlign.center),
              ]),
            ),
          ],

          if (hasFood) ...[
            pw.Container(
              width: pageW,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: kAccentLight,
                border: pw.Border.all(color: kAccent, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                'This analysis examines foods eaten 0-2 days before each eczema assessment and correlates them with itch severity scores. '
                'Foods with a positive impact score are associated with higher itch; negative scores suggest lower itch when consumed.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ),
            pw.SizedBox(height: 14),
          ],

          // ── Suspected Trigger Foods ──
          if (hasBad) ...[
            pw.Container(
              width: pageW,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: kDangerLight,
                border: pw.Border.all(color: kDanger, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [
                  pw.Container(width: 10, height: 10,
                      decoration: const pw.BoxDecoration(color: kDanger, shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 6),
                  pw.Text('Suspected Trigger Foods',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: kDanger)),
                ]),
                pw.SizedBox(height: 4),
                pw.Text('These foods are correlated with higher itch severity when consumed 0-2 days before an assessment.',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.SizedBox(height: 10),
                // Each food as a visual card
                ...foodCorrelation!.badFoods.map((f) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColor(kDanger.red, kDanger.green, kDanger.blue, 0.3), width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Row(children: [
                      pw.SizedBox(width: 100,
                          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                            pw.Text(f.foodName,
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Eaten ${f.timesEaten} times',
                                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                          ])),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          pw.Row(children: [
                            pw.Text('With food: ', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                            pw.Text('${f.avgItchWith}/10',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kDanger)),
                            pw.SizedBox(width: 12),
                            pw.Text('Without: ', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                            pw.Text('${f.avgItchWithout}/10',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kSuccess)),
                          ]),
                          pw.SizedBox(height: 3),
                          itchBar(f.avgItchWith, 10, kDanger, 200),
                        ]),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: kDangerLight,
                          border: pw.Border.all(color: kDanger, width: 0.5),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                        ),
                        child: pw.Text('+${f.correlationScore}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kDanger)),
                      ),
                    ]),
                  ),
                )),
              ]),
            ),
            pw.SizedBox(height: 14),
          ],

          // ── Foods with Lower Itch ──
          if (hasGood) ...[
            pw.Container(
              width: pageW,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: kSuccessLight,
                border: pw.Border.all(color: kSuccess, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [
                  pw.Container(width: 10, height: 10,
                      decoration: const pw.BoxDecoration(color: kSuccess, shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 6),
                  pw.Text('Foods Associated with Lower Itch',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: kSuccess)),
                ]),
                pw.SizedBox(height: 4),
                pw.Text('These foods are associated with lower itch scores when consumed before assessments.',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                pw.SizedBox(height: 10),
                ...foodCorrelation!.goodFoods.map((f) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColor(kSuccess.red, kSuccess.green, kSuccess.blue, 0.3), width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Row(children: [
                      pw.SizedBox(width: 100,
                          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                            pw.Text(f.foodName,
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Eaten ${f.timesEaten} times',
                                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                          ])),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: pw.Row(children: [
                          pw.Text('With food: ', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                          pw.Text('${f.avgItchWith}/10',
                              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: kSuccess)),
                          pw.SizedBox(width: 12),
                          pw.Text('Without: ', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                          pw.Text('${f.avgItchWithout}/10',
                              style: const pw.TextStyle(fontSize: 9)),
                        ]),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: kSuccessLight,
                          border: pw.Border.all(color: kSuccess, width: 0.5),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                        ),
                        child: pw.Text('${f.correlationScore}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kSuccess)),
                      ),
                    ]),
                  ),
                )),
              ]),
            ),
          ],

          pw.Spacer(),

          // ── Footer note ──
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              'Disclaimer: Food correlations are statistical observations and do not prove causation. '
              'Consult a dermatologist or allergist before making dietary changes based on these findings.',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ),
        ],
      );
    },
  ));

  // ══════════════════════════════════════════════════════════
  //  PAGE 3+ — Body Groups + Assessment History
  // ══════════════════════════════════════════════════════════
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pdfPageHeader('Detailed Assessment Data', days),
        pw.SizedBox(height: 8),
      ],
    ),
    footer: (ctx) => pw.Row(children: [
      pw.Text('Qorhealth Eczema Report',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
      pw.Spacer(),
      pw.Text('Page ${ctx.pageNumber}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
    ]),
    build: (ctx) => [
      // ── Body Group Summary ──
      sectionTitle('Body Group Summary'),
      sectionSubtitle('Aggregated itch severity by anatomical group'),
      if (sortedGroups.isNotEmpty) ...[
        ...sortedGroups.map((e) {
          final avgI = e.value.$2 > 0 ? e.value.$1 / e.value.$2 : 0.0;
          final color = pdfItchColor(avgI);
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: PdfColor(color.red, color.green, color.blue, 0.06),
                border: pw.Border.all(color: PdfColor(color.red, color.green, color.blue, 0.2), width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(children: [
                pw.Container(width: 8, height: 8,
                    decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle)),
                pw.SizedBox(width: 8),
                pw.SizedBox(width: 110,
                    child: pw.Text(e.key, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(child: itchBar(avgI, 10, color, pageW * 0.3)),
                pw.SizedBox(width: 8),
                pw.SizedBox(width: 50,
                    child: pw.Text('${avgI.toStringAsFixed(1)}/10',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color))),
                pw.SizedBox(width: 55,
                    child: pw.Text(pdfItchLabel(avgI), style: pw.TextStyle(fontSize: 8, color: color))),
                pw.Text('${e.value.$3} zones',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
              ]),
            ),
          );
        }),
      ],

      dividerLine(),

      // ── Assessment History ──
      sectionTitle('Assessment History'),
      sectionSubtitle('All ${ logs.length } entries logged over the past $days days'),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2.2),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1.3),
          3: const pw.FlexColumnWidth(0.8),
          4: const pw.FlexColumnWidth(0.8),
          5: const pw.FlexColumnWidth(3),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: kAccentLight),
            children: ['Date / Time', 'EASI', 'Severity', 'Itch', 'Sleep', 'Affected Areas'].map((h) =>
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: kAccent)),
              ),
            ).toList(),
          ),
          ...logs.asMap().entries.map((entry) {
            final i = entry.key;
            final log = entry.value;
            final easi = log.easiScore;
            final areas = log.parsedAreas.keys
                .take(3)
                .map((k) => findRegion(k)?.label ?? k)
                .join(', ');
            final moreAreas = log.parsedAreas.length > 3 ? ' +${log.parsedAreas.length - 3}' : '';
            final itchColor = pdfItchColor((log.itchSeverity ?? 0).toDouble());
            return pw.TableRow(
              decoration: i.isOdd ? const pw.BoxDecoration(color: PdfColor(0.97, 0.97, 0.97)) : null,
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('${log.logDate} ${log.logTime}', style: const pw.TextStyle(fontSize: 7))),
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(easi.toStringAsFixed(1),
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(easiLabel(easi), style: const pw.TextStyle(fontSize: 7))),
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('${log.itchSeverity ?? "-"}',
                        style: pw.TextStyle(fontSize: 7, color: itchColor, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                    child: pw.Text((log.sleepDisrupted == true) ? 'Yes' : '-', style: const pw.TextStyle(fontSize: 7))),
                pw.Padding(padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('$areas$moreAreas', style: const pw.TextStyle(fontSize: 7))),
              ],
            );
          }),
        ],
      ),
    ],
  ));

  await Printing.layoutPdf(onLayout: (format) => doc.save());
}
