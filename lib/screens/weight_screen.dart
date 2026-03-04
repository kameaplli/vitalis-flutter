import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/weight_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/weight_log.dart';
import '../widgets/line_chart_widget.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});
  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  int _days = 30;
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final histAsync = ref.watch(weightHistoryProvider('$person:$_days'));

    return Scaffold(
      appBar: AppBar(title: const Text('Weight Tracker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            // ── Chart ────────────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('History',
                            style: Theme.of(context).textTheme.titleSmall),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 7, label: Text('7d')),
                            ButtonSegment(value: 30, label: Text('30d')),
                            ButtonSegment(value: 90, label: Text('90d')),
                          ],
                          selected: {_days},
                          onSelectionChanged: (s) =>
                              setState(() => _days = s.first),
                          style: ButtonStyle(
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                    horizontal: 8)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: histAsync.when(
                        skipLoadingOnReload: true,
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('$e')),
                        data: (logs) {
                          if (logs.isEmpty) {
                            return const Center(
                                child: Text('No weight entries yet'));
                          }
                          final spots = logs.asMap().entries.map((e) {
                            return FlSpot(
                                e.key.toDouble(), e.value.weight);
                          }).toList();
                          final dates =
                              logs.map((l) => l.date).toList();
                          return LineChartWidget(
                              spots: spots,
                              xDates: dates,
                              yLabel: 'kg');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Log form ─────────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Log Weight',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _weightCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Weight (kg)', suffixText: 'kg'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Notes (optional)'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _logWeight,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Text('Log Weight'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Entry list with edit/delete ──────────────────────────────────
            histAsync.when(
              skipLoadingOnReload: true,
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (logs) {
                if (logs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Entries',
                          style:
                              Theme.of(context).textTheme.titleSmall),
                      const SizedBox(width: 8),
                      Text('Swipe right to edit · left to delete',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                    ]),
                    const SizedBox(height: 8),
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, indent: 16),
                        itemBuilder: (ctx, i) {
                          final log = logs[i];
                          return Dismissible(
                            key: Key(log.id),
                            direction: DismissDirection.horizontal,
                            background: Container(
                              color: Colors.blue,
                              alignment: Alignment.centerLeft,
                              padding:
                                  const EdgeInsets.only(left: 16),
                              child: const Icon(Icons.edit,
                                  color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(right: 16),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),
                            confirmDismiss: (dir) async {
                              if (dir ==
                                  DismissDirection.startToEnd) {
                                _showEditDialog(ctx, log);
                                return false;
                              }
                              return _confirmDelete(ctx);
                            },
                            onDismissed: (dir) async {
                              if (dir ==
                                  DismissDirection.endToStart) {
                                await apiClient.dio.delete(
                                    '${ApiConstants.weightLog}/${log.id}');
                                ref.invalidate(
                                    weightHistoryProvider);
                              }
                            },
                            child: ListTile(
                              leading: const Icon(
                                  Icons.monitor_weight_outlined,
                                  size: 20,
                                  color: Colors.purple),
                              title: Text(
                                '${log.weight.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                  '${log.date}${(log.notes?.isNotEmpty == true) ? '  •  ${log.notes}' : ''}'),
                              trailing: Text(log.person,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit dialog ──────────────────────────────────────────────────────────

  void _showEditDialog(BuildContext context, WeightLog log) {
    final ctrl = TextEditingController(
        text: log.weight.toStringAsFixed(1));
    final notesCtrl = TextEditingController(text: log.notes);
    DateTime date = DateTime.tryParse(log.date) ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Weight Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: ctrl,
                decoration: const InputDecoration(
                    labelText: 'Weight (kg)', suffixText: 'kg'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, size: 18),
                title: Text(DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(fontSize: 14)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) ss(() => date = d);
                },
              ),
              TextFormField(
                controller: notesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final w = double.tryParse(ctrl.text);
                if (w == null) return;
                try {
                  await apiClient.dio.put(
                    '${ApiConstants.weightLog}/${log.id}',
                    data: {
                      'weight': w,
                      'date': DateFormat('yyyy-MM-dd').format(date),
                      'notes': notesCtrl.text,
                    },
                  );
                  ref.invalidate(weightHistoryProvider);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete entry?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _logWeight() async {
    if (_weightCtrl.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await apiClient.dio.post(ApiConstants.weightLog, data: {
        'weight': double.parse(_weightCtrl.text),
        'notes': _notesCtrl.text,
      });
      _weightCtrl.clear();
      _notesCtrl.clear();
      ref.invalidate(weightHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Weight logged!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
