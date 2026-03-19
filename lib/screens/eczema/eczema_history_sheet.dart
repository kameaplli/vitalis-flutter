import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/eczema_log.dart';
import '../../models/easi_models.dart';
import '../../providers/eczema_provider.dart';
import '../../providers/selected_person_provider.dart';
import 'eczema_helpers.dart';
import '../../widgets/friendly_error.dart';

// ─── History sheet (shown from AppBar icon) ─────────────────────────────────

class HistorySheet extends ConsumerWidget {
  final ScrollController scrollController;
  final int historyDays;
  final void Function(int) onDaysChanged;
  final void Function(EczemaLogSummary) onEdit;
  final Future<void> Function(String) onDelete;
  final Future<bool> Function(BuildContext) onConfirmDelete;
  final void Function(List<EczemaLogSummary>) onExportPdf;

  const HistorySheet({
    super.key,
    required this.scrollController,
    required this.historyDays,
    required this.onDaysChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onConfirmDelete,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final logsAsync = ref.watch(eczemaProvider('${person}_$historyDays'));

    return Column(children: [
      // Drag handle
      Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 40, height: 4,
        decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          Text('History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          logsAsync.whenOrNull(
            data: (logs) => logs.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    tooltip: 'Export PDF',
                    onPressed: () => onExportPdf(logs),
                  ),
          ) ?? const SizedBox.shrink(),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: logsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => FriendlyError(error: e, context: 'eczema history'),
          data: (logs) {
            if (logs.isEmpty) return const Center(child: Text('No eczema logs yet'));
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                child: Row(children: [
                  Icon(Icons.swipe, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('Swipe right to edit · left to delete',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: logs.length,
                  itemBuilder: (ctx, i) {
                    final log = logs[i];
                    return Dismissible(
                      key: Key(log.id),
                      direction: DismissDirection.horizontal,
                      dismissThresholds: const {
                        DismissDirection.startToEnd: 0.3,
                        DismissDirection.endToStart: 0.3,
                      },
                      background: Container(
                        color: Colors.blue, alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(Icons.edit, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red, alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (dir) async {
                        if (dir == DismissDirection.startToEnd) {
                          onEdit(log);
                          return false;
                        }
                        return onConfirmDelete(ctx);
                      },
                      onDismissed: (dir) async {
                        if (dir == DismissDirection.endToStart) await onDelete(log.id);
                      },
                      child: HistoryCard(log: log),
                    );
                  },
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }
}

// ─── History card ─────────────────────────────────────────────────────────────

class HistoryCard extends StatefulWidget {
  final EczemaLogSummary log;
  const HistoryCard({super.key, required this.log});
  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final easi = log.easiScore;
    final color = easiColor(easi);
    final label = easiLabel(easi);
    final areas = log.parsedAreas;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header row
            Row(children: [
              Text('${log.logDate}  ${log.logTime}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('EASI ${easi.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(width: 4),
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 11, color: color)),
                ]),
              ),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: Colors.grey),
            ]),

            const SizedBox(height: 6),

            // Quick info
            Row(children: [
              if (log.itchSeverity != null)
                InfoBadge('Itch ${log.itchSeverity}/10', Colors.purple),
              if (log.sleepDisrupted == true) ...[
                const SizedBox(width: 6),
                const InfoBadge('Sleep ↓', Colors.indigo),
              ],
              if (areas.isNotEmpty) ...[
                const SizedBox(width: 6),
                InfoBadge('${areas.length} zone${areas.length > 1 ? "s" : ""}', Colors.teal),
              ],
            ]),

            // Expanded detail
            if (_expanded) ...[
              const SizedBox(height: 10),
              // Area chips
              if (areas.isNotEmpty)
                Wrap(spacing: 4, runSpacing: 4, children: areas.entries.map((e) {
                  final region = findRegion(e.key);
                  return Chip(
                    label: Text(region?.label ?? e.key,
                        style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList()),

              // EASI group breakdown
              const SizedBox(height: 8),
              ..._buildBreakdown(log),

              if (log.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(log.notes!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ]),
        ),
      ),
    );
  }

  List<Widget> _buildBreakdown(EczemaLogSummary log) {
    final scores = logToScores(log);
    final gs = <EasiGroup, double>{};
    for (final e in scores.entries) {
      final g = groupForRegion(e.key);
      gs[g] = (gs[g] ?? 0) + e.value.easiContribution(g);
    }
    return EasiGroup.values.where((g) => (gs[g] ?? 0) > 0).map((g) {
      final v = gs[g]!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(children: [
          SizedBox(width: 110, child: Text(g.label, style: const TextStyle(fontSize: 11))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (v / 18.0).clamp(0, 1), minHeight: 5,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(easiColor(v / 5)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(v.toStringAsFixed(2), style: const TextStyle(fontSize: 11)),
        ]),
      );
    }).toList();
  }
}

// ─── Info badge ──────────────────────────────────────────────────────────────

class InfoBadge extends StatelessWidget {
  final String text;
  final Color color;
  const InfoBadge(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
