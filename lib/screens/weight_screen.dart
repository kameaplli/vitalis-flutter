import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/weight_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/weight_log.dart';
import '../widgets/weight_chart_widget.dart';
import '../widgets/medical_disclaimer.dart';
import '../widgets/friendly_error.dart';
import '../widgets/days_slider.dart';

/// Standalone route screen — wraps WeightContent in a Scaffold.
class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weight Tracker')),
      body: const WeightContent(),
    );
  }
}

/// Reusable widget used both by WeightScreen and the Weight tab in HealthScreen.
class WeightContent extends ConsumerStatefulWidget {
  const WeightContent({super.key});
  @override
  ConsumerState<WeightContent> createState() => _WeightContentState();
}

class _WeightContentState extends ConsumerState<WeightContent> {
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
    final histAsync = ref.watch(weightHistoryProvider('${person}_$_days'));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(weightHistoryProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            // ── Chart ────────────────────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('History',
                              style: Theme.of(context).textTheme.titleSmall),
                          DaysSlider(
                            value: _days,
                            onChanged: (d) => setState(() => _days = d),
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                histAsync.when(
                  skipLoadingOnReload: true,
                  loading: () => const SizedBox(
                    height: 280,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SizedBox(
                    height: 280,
                    child: FriendlyError(error: e, context: 'weight history'),
                  ),
                  data: (history) {
                    // BMI badge
                    final latest = history.entries.isNotEmpty ? history.entries.last : null;
                    final idealMin = history.idealMin;
                    final idealMax = history.idealMax;
                    String? bmiLabel;
                    if (latest != null && idealMin != null && idealMax != null) {
                      final w = latest.weight;
                      if (w < idealMin) {
                        bmiLabel = '${(idealMin - w).toStringAsFixed(1)} kg below ideal';
                      } else if (w > idealMax) {
                        bmiLabel = '${(w - idealMax).toStringAsFixed(1)} kg above ideal';
                      } else {
                        bmiLabel = 'In healthy weight range';
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WeightChartWidget(history: history),
                        if (bmiLabel != null) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: (latest!.weight >= (idealMin ?? 0) && latest.weight <= (idealMax ?? 999))
                                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5)
                                    : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (latest.weight >= (idealMin ?? 0) && latest.weight <= (idealMax ?? 999))
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                              child: Text(
                                bmiLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: (latest.weight >= (idealMin ?? 0) && latest.weight <= (idealMax ?? 999))
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Log weight ───────────────────────────────────────────────────
            _WeightInputCard(
              weightCtrl: _weightCtrl,
              notesCtrl: _notesCtrl,
              isSaving: _isSaving,
              onLog: _logWeight,
              idealWeight: histAsync.valueOrNull?.idealWeight,
            ),

            const SizedBox(height: 16),

            // ── Entry list with edit/delete ──────────────────────────────────
            histAsync.when(
              skipLoadingOnReload: true,
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (history) {
                if (history.entries.isEmpty) return const SizedBox.shrink();
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
                              color: Theme.of(context).colorScheme.outline)),
                    ]),
                    const SizedBox(height: 8),
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: history.entries.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, indent: 16),
                        itemBuilder: (ctx, i) {
                          final log = history.entries[i];
                          return Dismissible(
                            key: Key(log.id),
                            direction: DismissDirection.horizontal,
                            dismissThresholds: const {
                              DismissDirection.startToEnd: 0.3,
                              DismissDirection.endToStart: 0.3,
                            },
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
                              leading: Icon(
                                  Icons.monitor_weight_outlined,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary),
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
                                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            const MedicalDisclaimer(),
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
                        SnackBar(content: Text(friendlyErrorMessage(e, context: 'weight'))));
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
      final person = ref.read(selectedPersonProvider);
      final famId = person == 'self' ? null : person;
      await apiClient.dio.post(ApiConstants.weightLog, data: {
        'weight': double.parse(_weightCtrl.text),
        'notes': _notesCtrl.text,
        if (famId != null) 'family_member_id': famId,
      });
      _weightCtrl.clear();
      _notesCtrl.clear();
      ref.invalidate(weightHistoryProvider);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Weight logged!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, context: 'weight'))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _WeightInputCard extends StatefulWidget {
  final TextEditingController weightCtrl;
  final TextEditingController notesCtrl;
  final bool isSaving;
  final VoidCallback onLog;
  final double? idealWeight;

  const _WeightInputCard({
    required this.weightCtrl,
    required this.notesCtrl,
    required this.isSaving,
    required this.onLog,
    this.idealWeight,
  });

  @override
  State<_WeightInputCard> createState() => _WeightInputCardState();
}

class _WeightInputCardState extends State<_WeightInputCard> {
  // Weight stored as integer grams for precision (e.g. 70050 = 70.05 kg)
  late int _wholeKg;
  late int _grams; // 0, 50, 100, ..., 950
  late FixedExtentScrollController _kgController;
  late FixedExtentScrollController _gController;
  bool _initialized = false;

  static const _minKg = 20;
  static const _maxKg = 250;
  // 50g steps: 0, 50, 100, 150, ..., 950 → 20 items
  static const _gramSteps = 20;

  @override
  void initState() {
    super.initState();
    _wholeKg = 70;
    _grams = 0;
    _kgController = FixedExtentScrollController(initialItem: _wholeKg - _minKg);
    _gController = FixedExtentScrollController(initialItem: 0);
  }

  @override
  void dispose() {
    _kgController.dispose();
    _gController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_WeightInputCard old) {
    super.didUpdateWidget(old);
    _tryInit();
  }

  void _tryInit() {
    if (!_initialized && widget.idealWeight != null) {
      final w = widget.idealWeight!;
      _wholeKg = w.truncate();
      _grams = ((w - _wholeKg) * 1000).round();
      // Snap grams to nearest 50
      _grams = ((_grams / 50).round() * 50).clamp(0, 950);
      _kgController.jumpToItem(_wholeKg - _minKg);
      _gController.jumpToItem(_grams ~/ 50);
      _syncText();
      _initialized = true;
    }
  }

  void _syncText() {
    final weight = _wholeKg + _grams / 1000.0;
    widget.weightCtrl.text = weight.toStringAsFixed(
        _grams % 100 == 0 ? 1 : 2);
  }

  double get _weight => _wholeKg + _grams / 1000.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    _tryInit();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          children: [
            // Title
            Row(
              children: [
                Icon(Icons.monitor_weight_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Log Weight', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),

            // Scroll wheel picker
            SizedBox(
              height: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Kg wheel
                  SizedBox(
                    width: 80,
                    child: ListWheelScrollView.useDelegate(
                      controller: _kgController,
                      itemExtent: 44,
                      perspective: 0.003,
                      diameterRatio: 1.5,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) {
                        setState(() => _wholeKg = _minKg + i);
                        _syncText();
                        HapticFeedback.selectionClick();
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _maxKg - _minKg + 1,
                        builder: (ctx, i) {
                          final kg = _minKg + i;
                          final selected = kg == _wholeKg;
                          return Center(
                            child: Text(
                              '$kg',
                              style: TextStyle(
                                fontSize: selected ? 32 : 20,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w300,
                                color: selected
                                    ? cs.onSurface
                                    : cs.onSurface.withValues(alpha: 0.25),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  // Decimal separator
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('.', style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w700, color: cs.onSurface,
                    )),
                  ),
                  // Grams wheel (50g steps)
                  SizedBox(
                    width: 80,
                    child: ListWheelScrollView.useDelegate(
                      controller: _gController,
                      itemExtent: 44,
                      perspective: 0.003,
                      diameterRatio: 1.5,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) {
                        setState(() => _grams = i * 50);
                        _syncText();
                        HapticFeedback.selectionClick();
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _gramSteps,
                        builder: (ctx, i) {
                          final g = i * 50;
                          final selected = g == _grams;
                          // Display as fractional: 0→.0, 50→.05, 100→.1, ..., 950→.95
                          final label = g < 100
                              ? '${(g ~/ 10).toString().padLeft(2, '0')}'
                              : '${(g ~/ 10)}';
                          return Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: selected ? 32 : 20,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w300,
                                color: selected
                                    ? cs.onSurface
                                    : cs.onSurface.withValues(alpha: 0.25),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Unit
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('kg', style: TextStyle(
                      fontSize: 18, color: cs.onSurfaceVariant,
                    )),
                  ),
                ],
              ),
            ),

            // Selection indicator line
            Container(
              width: 180,
              height: 2,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),

            const SizedBox(height: 12),
            // Notes
            TextFormField(
              controller: widget.notesCtrl,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            // Submit
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: widget.isSaving ? null : widget.onLog,
                icon: widget.isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text('Log ${_weight.toStringAsFixed(1)} kg'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
