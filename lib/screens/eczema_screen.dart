import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/eczema_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/eczema_log.dart';
import '../models/easi_models.dart';
import '../widgets/eczema_body_map.dart';

// ─── EASI helpers ─────────────────────────────────────────────────────────────

double _computeEasi(Map<String, EasiRegionScore> scores) {
  double t = 0;
  for (final e in scores.entries) {
    t += e.value.easiContribution(groupForRegion(e.key));
  }
  return t;
}

String _easiLabel(double v) {
  if (v == 0)   return 'Clear';
  if (v <= 1)   return 'Almost Clear';
  if (v <= 7)   return 'Mild';
  if (v <= 21)  return 'Moderate';
  if (v <= 50)  return 'Severe';
  return 'Very Severe';
}

Color _easiColor(double v) {
  if (v == 0)   return const Color(0xFF9E9E9E);
  if (v <= 1)   return const Color(0xFF43A047);
  if (v <= 7)   return const Color(0xFFFDD835);
  if (v <= 21)  return const Color(0xFFFF9800);
  if (v <= 50)  return const Color(0xFFF4511E);
  return const Color(0xFFB71C1C);
}

// Convert EczemaLogSummary.parsedEasiAreas → Map<regionId, EasiRegionScore>
Map<String, EasiRegionScore> _logToScores(EczemaLogSummary log) {
  final result = <String, EasiRegionScore>{};
  for (final area in log.parsedEasiAreas) {
    final id = area['area'] as String;
    if (id.isEmpty) continue;
    result[id] = EasiRegionScore.fromJson(area);
  }
  return result;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class EczemaScreen extends ConsumerStatefulWidget {
  const EczemaScreen({super.key});

  @override
  ConsumerState<EczemaScreen> createState() => _EczemaScreenState();
}

class _EczemaScreenState extends ConsumerState<EczemaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // ── Period filters ───────────────────────────────────────────────────────
  int _historyDays = 30;
  int _heatmapDays = 30;

  // ── Edit tracking ────────────────────────────────────────────────────────
  String? _editingId;

  // ── Form state ───────────────────────────────────────────────────────────
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  final Map<String, EasiRegionScore> _regionScores = {};
  String? _activeZoneId;

  // ── Draw mode ────────────────────────────────────────────────────────────
  bool _drawMode = false;
  int  _drawSeverity = 1;         // 0-3: current draw colour
  final List<DrawnPatch> _drawnPatches = [];

  // EASI overall
  int _itchVas = 0;
  bool _sleepDisrupted = false;
  double _sleepHoursLost = 0;

  // Triggers
  bool _trigNewDetergent = false, _trigNewFabric = false;
  bool _trigDust = false, _trigPet = false, _trigChlorine = false;
  bool _trigDairy = false, _trigEggs = false, _trigNuts = false;
  bool _trigWheat = false, _trigSoy = false, _trigCitrus = false;
  int _stressLevel = 0;

  // Treatment
  bool _txMoisturizer = false, _txSteroid = false;
  bool _txAntihistamine = false, _txWetWrap = false;
  String _txSteroidStrength = 'mild';
  String _txMoistType = '';

  final _notesCtrl = TextEditingController();
  bool _saving = false;

  // ── Compare tab state ────────────────────────────────────────────────────
  String? _compareIdA;
  String? _compareIdB;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── EASI total ────────────────────────────────────────────────────────────
  double get _easiTotal => _computeEasi(_regionScores);

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final person = ref.read(selectedPersonProvider);
      final areasPayload = {
        'zones':   _regionScores.values.map((s) => s.toJson()).toList(),
        'patches': _drawnPatches.map((p) => p.toJson()).toList(),
      };
      final data = {
        'log_date': DateFormat('yyyy-MM-dd').format(_date),
        'log_time': _time.format(context),
        'itch_severity': _itchVas,
        'affected_areas': jsonEncode(areasPayload),
        'sleep_disrupted': _sleepDisrupted,
        'sleep_hours_lost': _sleepDisrupted ? _sleepHoursLost : null,
        'new_detergent': _trigNewDetergent,
        'new_fabric': _trigNewFabric,
        'dust_exposure': _trigDust,
        'pet_exposure': _trigPet,
        'chlorine_exposure': _trigChlorine,
        'dairy_consumed': _trigDairy,
        'eggs_consumed': _trigEggs,
        'nuts_consumed': _trigNuts,
        'wheat_consumed': _trigWheat,
        'soy_consumed': _trigSoy,
        'citrus_consumed': _trigCitrus,
        'stress_level': _stressLevel,
        'moisturizer_applied': _txMoisturizer,
        'moisturizer_type': _txMoistType.trim().isEmpty ? null : _txMoistType.trim(),
        'steroid_cream_used': _txSteroid,
        'steroid_cream_potency': _txSteroid ? _txSteroidStrength : null,
        'antihistamine_taken': _txAntihistamine,
        'wet_wrap_therapy': _txWetWrap,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'family_member_id': person == 'self' ? null : person,
      };
      final isEdit = _editingId != null;
      if (isEdit) {
        await apiClient.dio.put('${ApiConstants.eczema}/$_editingId', data: data);
      } else {
        await apiClient.dio.post(ApiConstants.eczema, data: data);
      }
      if (!mounted) return;
      _resetForm();
      final p = ref.read(selectedPersonProvider);
      ref.invalidate(eczemaProvider('$p:$_historyDays'));
      ref.invalidate(eczemaHeatmapProvider('$p:$_heatmapDays'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Log updated' : 'Log saved')),
      );
      _tabs.animateTo(0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _regionScores.clear();
      _activeZoneId = null;
      _drawMode = false;
      _drawSeverity = 1;
      _drawnPatches.clear();
      _itchVas = 0;
      _sleepDisrupted = false;
      _sleepHoursLost = 0;
      _stressLevel = 0;
      _trigNewDetergent = _trigNewFabric = _trigDust = false;
      _trigPet = _trigChlorine = false;
      _trigDairy = _trigEggs = _trigNuts = false;
      _trigWheat = _trigSoy = _trigCitrus = false;
      _txMoisturizer = _txSteroid = _txAntihistamine = _txWetWrap = false;
      _txSteroidStrength = 'mild';
      _txMoistType = '';
      _notesCtrl.clear();
      _date = DateTime.now();
      _time = TimeOfDay.now();
    });
  }

  void _editLog(EczemaLogSummary log) {
    setState(() {
      _editingId = log.id;
      _date = DateTime.tryParse(log.logDate) ?? DateTime.now();
      final parts = log.logTime.split(':');
      _time = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      );
      _itchVas = log.itchSeverity ?? 0;
      _sleepDisrupted = log.sleepDisrupted ?? false;
      _notesCtrl.text = log.notes ?? '';
      _regionScores..clear()..addAll(_logToScores(log));
      _drawnPatches..clear()..addAll(log.parsedPatches);
      _activeZoneId = null;
      _drawMode = false;
    });
    _tabs.animateTo(0); // Switch to Log tab
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _HistorySheet(
          scrollController: scrollController,
          historyDays: _historyDays,
          onDaysChanged: (d) => setState(() => _historyDays = d),
          onEdit: (log) { Navigator.pop(ctx); _editLog(log); },
          onDelete: (id) => _deleteLog(id),
          onConfirmDelete: (c) => _confirmDelete(c),
          onExportPdf: (logs) => _exportPdf(logs),
        ),
      ),
    );
  }

  Future<void> _deleteLog(String id) async {
    try {
      await apiClient.dio.delete('${ApiConstants.eczema}/$id');
      final p = ref.read(selectedPersonProvider);
      ref.invalidate(eczemaProvider('$p:$_historyDays'));
      ref.invalidate(eczemaHeatmapProvider('$p:$_heatmapDays'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<bool> _confirmDelete(BuildContext ctx) async =>
      await showDialog<bool>(
        context: ctx,
        builder: (c) => AlertDialog(
          title: const Text('Delete entry?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
          ],
        ),
      ) ??
      false;

  void _onZoneTap(BodyRegion region) {
    // Highlight the zone first (triggers pulse animation in body map),
    // then open the scoring panel after a short delay so the user sees
    // which zone they tapped.
    setState(() => _activeZoneId = region.id);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _showEasiPanel(region);
    });
  }

  void _onPatchDrawn(DrawnPatch patch, BodyRegion? zone) {
    setState(() => _drawnPatches.add(patch));
    // Auto-open EASI scoring panel for newly-touched zone if not yet scored.
    if (zone != null && !_regionScores.containsKey(zone.id)) {
      setState(() => _activeZoneId = zone.id);
      _showEasiPanel(zone);
    }
  }

  void _showEasiPanel(BodyRegion region) {
    final current = _regionScores[region.id] ?? EasiRegionScore(regionId: region.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _EasiPanel(
          region: region,
          initial: current,
          allScores: _regionScores,
          scrollController: scrollController,
          onConfirm: (score) => setState(() {
            _regionScores[region.id] = score;
            _activeZoneId = null;
          }),
          onRemove: () => setState(() {
            _regionScores.remove(region.id);
            _activeZoneId = null;
          }),
          onDismiss: () => setState(() => _activeZoneId = null),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final easi = _easiTotal;
    final color = _easiColor(easi);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId != null ? 'Edit Eczema Log' : 'Eczema Tracker'),
        actions: [
          if (_tabs.index == 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.6)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('EASI ${easi.toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(width: 5),
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(_easiLabel(easi), style: TextStyle(fontSize: 11, color: color)),
                  ]),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: _showHistorySheet,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Log'),
            Tab(text: 'Compare'),
            Tab(text: 'Heatmap'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        // Disable horizontal swipe to switch tabs — it conflicts with
        // pinch-zoom and zone taps on the body map. Tabs switch via tap only.
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildLogTab(), _buildCompareTab(), _buildHeatmapTab()],
      ),
    );
  }

  // ─── Log Tab ──────────────────────────────────────────────────────────────
  // Body map fills the entire tab. All form fields live in a separate 90%
  // height sheet triggered by a FAB ("Review & Save").
  Widget _buildLogTab() {
    final cs = Theme.of(context).colorScheme;
    final hasScores = _regionScores.isNotEmpty || _drawnPatches.isNotEmpty;

    return Stack(
      children: [
        // Full-height body map with thin toolbar
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Compact toolbar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(children: [
                // Draw mode UI hidden — kept in codebase for future use
                // _drawMode is always false; Zone mode is the default
                Icon(Icons.touch_app_outlined, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 3),
                Flexible(
                  child: Text('Tap zone to score  ·  Pinch to zoom',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),

            // ── Scored zone chips (compact bar) ───────────────────────────
            if (_regionScores.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _regionScores.entries.map((e) {
                      final region = findRegion(e.key);
                      final lbl = region?.label ?? e.key;
                      final contribution = e.value.easiContribution(groupForRegion(e.key));
                      final color = _easiColor(contribution * 3);
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ActionChip(
                          label: Text('$lbl ${contribution.toStringAsFixed(1)}',
                              style: TextStyle(fontSize: 10, color: color)),
                          backgroundColor: color.withValues(alpha: 0.08),
                          side: BorderSide(color: color.withValues(alpha: 0.3)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onPressed: () { if (region != null) _showEasiPanel(region); },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // ── Body map fills remaining space ──────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: EczemaBodyMap(
                  regionScores: _regionScores,
                  activeZoneId: _activeZoneId,
                  onZoneTap: _drawMode ? null : _onZoneTap,
                  drawMode: _drawMode,
                  drawSeverity: _drawSeverity,
                  drawnPatches: _drawnPatches,
                  onPatchDrawn: _onPatchDrawn,
                ),
              ),
            ),

            // ── Bottom legend bar ─────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: EczemaSeverityLegend(compact: true),
            ),
          ],
        ),

        // ── FAB: Review & Save ────────────────────────────────────────────
        Positioned(
          right: 16,
          bottom: 48,
          child: FloatingActionButton.extended(
            heroTag: 'eczema_save_fab',
            icon: const Icon(Icons.assignment),
            label: Text(hasScores
                ? 'Review & Save (${_regionScores.length})'
                : (_editingId != null ? 'Edit Details' : 'Log Details')),
            backgroundColor: hasScores ? cs.primary : cs.surfaceContainerHigh,
            foregroundColor: hasScores ? cs.onPrimary : cs.onSurface,
            onPressed: _showFullFormSheet,
          ),
        ),
      ],
    );
  }

  // ── Full form bottom sheet ─────────────────────────────────────────────────
  void _showFullFormSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            void update(VoidCallback fn) {
              fn();
              setState(() {});      // update parent
              setSheetState(() {}); // update sheet
            }

            final cs = Theme.of(sheetCtx).colorScheme;
            final easi = _computeEasi(_regionScores);
            final color = _easiColor(easi);

            return Column(children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  Text(_editingId != null ? 'Edit Assessment' : 'Log Assessment',
                      style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.6)),
                    ),
                    child: Text('EASI ${easi.toStringAsFixed(1)} - ${_easiLabel(easi)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  ),
                ]),
              ),
              const Divider(height: 1),
              // Scrollable form
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // Date / time
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 15),
                          label: Text(DateFormat('dd MMM yyyy').format(_date)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _pickDate();
                            if (mounted) _showFullFormSheet();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 15),
                          label: Text(_time.format(sheetCtx)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _pickTime();
                            if (mounted) _showFullFormSheet();
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Scored zones
                    if (_regionScores.isNotEmpty) ...[
                      Text('Scored Zones', style: Theme.of(sheetCtx).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: _regionScores.entries.map((e) {
                          final region = findRegion(e.key);
                          final lbl = region?.label ?? e.key;
                          final contribution = e.value.easiContribution(groupForRegion(e.key));
                          final c = _easiColor(contribution * 3);
                          return InputChip(
                            label: Text('$lbl ${contribution.toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 11)),
                            backgroundColor: c.withValues(alpha: 0.10),
                            side: BorderSide(color: c.withValues(alpha: 0.4)),
                            onDeleted: () => update(() => _regionScores.remove(e.key)),
                            onPressed: () {
                              if (region != null) {
                                Navigator.pop(ctx);
                                _showEasiPanel(region);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // EASI breakdown
                    _EasiBreakdownCard(scores: _regionScores),
                    const SizedBox(height: 10),

                    // Itch Intensity
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('Itch Intensity', style: Theme.of(sheetCtx).textTheme.titleSmall),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _easiColor(_itchVas.toDouble()).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('$_itchVas / 10',
                                  style: TextStyle(fontWeight: FontWeight.bold,
                                      color: _easiColor(_itchVas.toDouble()))),
                            ),
                          ]),
                          Slider(
                            value: _itchVas.toDouble(), min: 0, max: 10, divisions: 10,
                            activeColor: _easiColor(_itchVas.toDouble()),
                            onChanged: (v) => update(() => _itchVas = v.round()),
                          ),
                          const SizedBox(height: 4),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Sleep disruption
                    Card(
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: const Text('Sleep disrupted by itch', style: TextStyle(fontSize: 14)),
                        value: _sleepDisrupted,
                        onChanged: (v) => update(() => _sleepDisrupted = v),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Stress level
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('Stress Level', style: Theme.of(sheetCtx).textTheme.titleSmall),
                            const Spacer(),
                            Text('$_stressLevel / 10', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                          Slider(
                            value: _stressLevel.toDouble(), min: 0, max: 10, divisions: 10,
                            onChanged: (v) => update(() => _stressLevel = v.round()),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Triggers
                    Card(
                      child: ExpansionTile(
                        title: const Text('Triggers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Wrap(spacing: 6, runSpacing: 4, children: [
                              _TrigChip('Detergent', _trigNewDetergent, (v) => update(() => _trigNewDetergent = v)),
                              _TrigChip('Fabric', _trigNewFabric, (v) => update(() => _trigNewFabric = v)),
                              _TrigChip('Dust', _trigDust, (v) => update(() => _trigDust = v)),
                              _TrigChip('Pet', _trigPet, (v) => update(() => _trigPet = v)),
                              _TrigChip('Chlorine', _trigChlorine, (v) => update(() => _trigChlorine = v)),
                              _TrigChip('Dairy', _trigDairy, (v) => update(() => _trigDairy = v)),
                              _TrigChip('Eggs', _trigEggs, (v) => update(() => _trigEggs = v)),
                              _TrigChip('Nuts', _trigNuts, (v) => update(() => _trigNuts = v)),
                              _TrigChip('Wheat', _trigWheat, (v) => update(() => _trigWheat = v)),
                              _TrigChip('Soy', _trigSoy, (v) => update(() => _trigSoy = v)),
                              _TrigChip('Citrus', _trigCitrus, (v) => update(() => _trigCitrus = v)),
                            ]),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Treatment
                    Card(
                      child: ExpansionTile(
                        title: const Text('Treatment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Column(children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero, dense: true,
                                title: const Text('Moisturizer', style: TextStyle(fontSize: 13)),
                                value: _txMoisturizer,
                                onChanged: (v) => update(() => _txMoisturizer = v ?? false),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero, dense: true,
                                title: const Text('Steroid cream', style: TextStyle(fontSize: 13)),
                                value: _txSteroid,
                                onChanged: (v) => update(() => _txSteroid = v ?? false),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero, dense: true,
                                title: const Text('Antihistamine', style: TextStyle(fontSize: 13)),
                                value: _txAntihistamine,
                                onChanged: (v) => update(() => _txAntihistamine = v ?? false),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero, dense: true,
                                title: const Text('Wet wrap', style: TextStyle(fontSize: 13)),
                                value: _txWetWrap,
                                onChanged: (v) => update(() => _txWetWrap = v ?? false),
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Notes
                    TextField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(_editingId != null ? 'Update Log' : 'Save Assessment',
                            style: const TextStyle(fontSize: 16)),
                        onPressed: _saving ? null : () {
                          Navigator.pop(ctx);
                          _submit();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }


  // ── PDF export ──────────────────────────────────────────────────────────────
  Future<void> _exportPdf(List<EczemaLogSummary> logs) async {
    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Vitalis — Eczema Assessment Report',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Period: last $_historyDays days  ·  Generated: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.Divider(),
        ],
      ),
      build: (context) => [
        // Summary stats
        _pdfSummary(logs),
        pw.SizedBox(height: 16),
        // Log table
        pw.Text('Assessment History',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _pdfTable(logs),
        pw.SizedBox(height: 16),
        // Region frequency
        _pdfRegionFrequency(logs),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  pw.Widget _pdfSummary(List<EczemaLogSummary> logs) {
    final easiScores = logs.map((l) => l.easiScore).toList();
    final avgEasi = easiScores.isEmpty ? 0.0 : easiScores.reduce((a, b) => a + b) / easiScores.length;
    final maxEasi = easiScores.isEmpty ? 0.0 : easiScores.reduce((a, b) => a > b ? a : b);
    final sleepDisrupted = logs.where((l) => l.sleepDisrupted == true).length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _pdfStat('Entries', '${logs.length}'),
          _pdfStat('Avg EASI', avgEasi.toStringAsFixed(1)),
          _pdfStat('Peak EASI', maxEasi.toStringAsFixed(1)),
          _pdfStat('Sleep disrupted', '$sleepDisrupted nights'),
        ],
      ),
    );
  }

  pw.Widget _pdfStat(String label, String value) => pw.Column(
    children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
    ],
  );

  pw.Widget _pdfTable(List<EczemaLogSummary> logs) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: ['Date', 'EASI', 'Severity', 'Itch', 'Affected Areas'].map((h) =>
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            )
          ).toList(),
        ),
        ...logs.map((log) {
          final easi = log.easiScore;
          final areas = log.parsedAreas.keys
              .take(3)
              .map((k) => findRegion(k)?.label ?? k)
              .join(', ');
          return pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(4),
                child: pw.Text('${log.logDate} ${log.logTime}', style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(4),
                child: pw.Text(easi.toStringAsFixed(1), style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(4),
                child: pw.Text(_easiLabel(easi), style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(4),
                child: pw.Text('${log.itchSeverity ?? "-"}/10', style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                    areas + (log.parsedAreas.length > 3 ? ' +${log.parsedAreas.length - 3}' : ''),
                    style: const pw.TextStyle(fontSize: 8))),
          ]);
        }),
      ],
    );
  }

  pw.Widget _pdfRegionFrequency(List<EczemaLogSummary> logs) {
    final freq = <String, int>{};
    for (final log in logs) {
      for (final id in log.parsedAreas.keys) { freq[id] = (freq[id] ?? 0) + 1; }
    }
    final sorted = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Most Affected Regions',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        ...sorted.take(8).map((e) {
          final region = findRegion(e.key);
          final lbl = region?.label ?? e.key;
          final pct = (e.value / logs.length * 100).round();
          return pw.Row(children: [
            pw.SizedBox(width: 130, child: pw.Text(lbl, style: const pw.TextStyle(fontSize: 9))),
            pw.Text('$pct% of visits (${e.value}/${logs.length})',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ]);
        }),
      ],
    );
  }

  // ─── Compare Tab ────────────────────────────────────────────────────────────
  Widget _buildCompareTab() {
    final person = ref.watch(selectedPersonProvider);
    final logsAsync = ref.watch(eczemaProvider('$person:90'));
    return logsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (logs) {
        if (logs.length < 2) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Need at least 2 logged assessments to compare.\nLog more entries in the Log tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final logA = logs.firstWhereOrNull((l) => l.id == _compareIdA) ?? logs[0];
        final logB = logs.firstWhereOrNull((l) => l.id == _compareIdB) ?? logs[1];
        final scoresA = _logToScores(logA);
        final scoresB = _logToScores(logB);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selectors
              Row(children: [
                Expanded(child: _visitPicker('Visit A', logs, logA.id, (id) => setState(() {
                  _compareIdA = id;
                  if (_compareIdB == null) _compareIdB = logs.firstWhereOrNull((l) => l.id != id)?.id;
                }))),
                const SizedBox(width: 8),
                Expanded(child: _visitPicker('Visit B', logs, logB.id, (id) => setState(() => _compareIdB = id))),
              ]),
              const SizedBox(height: 12),

              // Comparison widget — give it 50% more height than default
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.75,
                child: EczemaBodyComparison(
                  view: EczemaBodyView.front,
                  scoresA: scoresA,
                  scoresB: scoresB,
                  labelA: '${logA.logDate}\n${logA.logTime}',
                  labelB: '${logB.logDate}\n${logB.logTime}',
                  easiA: logA.easiScore,
                  easiB: logB.easiScore,
                  severityA: _easiLabel(logA.easiScore),
                  severityB: _easiLabel(logB.easiScore),
                ),
              ),

              // Additional metrics table
              const SizedBox(height: 16),
              _CompareMetricsTable(logA: logA, logB: logB),
            ],
          ),
        );
      },
    );
  }

  Widget _visitPicker(String label, List<EczemaLogSummary> logs,
      String? selectedId, void Function(String) onChanged) {
    return DropdownButtonFormField<String>(
      value: selectedId,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: const OutlineInputBorder(),
      ),
      items: logs.map((l) {
        final easi = l.easiScore;
        return DropdownMenuItem(
          value: l.id,
          child: Text('${l.logDate}  EASI ${easi.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: (v) { if (v != null) onChanged(v); },
    );
  }

  // ─── Heatmap Tab ────────────────────────────────────────────────────────────
  Future<void> _generateMockData() async {
    try {
      await apiClient.dio.post(ApiConstants.eczemaMock);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generated 100 mock eczema logs')),
      );
      final person = ref.read(selectedPersonProvider);
      ref.invalidate(eczemaHeatmapProvider('$person:$_heatmapDays'));
      ref.invalidate(eczemaProvider('$person:60'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildHeatmapTab() {
    final person = ref.watch(selectedPersonProvider);
    final heatAsync = ref.watch(eczemaHeatmapProvider('$person:$_heatmapDays'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.science_outlined, size: 20),
              tooltip: 'Generate 100 mock logs',
              onPressed: _generateMockData,
            ),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
              ],
              selected: {_heatmapDays},
              onSelectionChanged: (s) => setState(() => _heatmapDays = s.first),
            ),
          ]),
        ),
        Expanded(
          child: heatAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) {
              if (data.regionIntensity.isEmpty) {
                return const Center(child: Text('No eczema data for this period'));
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      clipBehavior: Clip.hardEdge,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: EczemaBodyMap(
                          heatData: data.regionIntensity,
                          readOnly: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const EczemaSeverityLegend(),
                    if (data.topRegions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Most Affected Regions',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ...data.topRegions.take(10).map((r) => _TopRegionRow(
                            label: r.label,
                            frequency: r.frequency,
                            avgEasi: r.avgEasi,
                          )),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── EASI scoring panel (bottom sheet) ───────────────────────────────────────

class _EasiPanel extends StatefulWidget {
  final BodyRegion region;
  final EasiRegionScore initial;
  final Map<String, EasiRegionScore> allScores;
  final ScrollController? scrollController;
  final void Function(EasiRegionScore) onConfirm;
  final VoidCallback onRemove;
  final VoidCallback onDismiss;

  const _EasiPanel({
    required this.region,
    required this.initial,
    required this.allScores,
    this.scrollController,
    required this.onConfirm,
    required this.onRemove,
    required this.onDismiss,
  });

  @override
  State<_EasiPanel> createState() => _EasiPanelState();
}

class _EasiPanelState extends State<_EasiPanel> {
  late int _erythema, _papulation, _excoriation, _lichenification, _areaScore;
  late int _oozing, _dryness, _pigmentation;

  @override
  void initState() {
    super.initState();
    _erythema = widget.initial.erythema;
    _papulation = widget.initial.papulation;
    _excoriation = widget.initial.excoriation;
    _lichenification = widget.initial.lichenification;
    _areaScore = widget.initial.areaScore;
    _oozing = widget.initial.oozing;
    _dryness = widget.initial.dryness;
    _pigmentation = widget.initial.pigmentation;
  }

  double get _regional {
    return EasiRegionScore(
      regionId: widget.region.id, erythema: _erythema,
      papulation: _papulation, excoriation: _excoriation,
      lichenification: _lichenification, areaScore: _areaScore,
    ).easiContribution(widget.region.group);
  }

  double get _totalEasi {
    final updated = Map<String, EasiRegionScore>.from(widget.allScores);
    updated[widget.region.id] = EasiRegionScore(
      regionId: widget.region.id, erythema: _erythema,
      papulation: _papulation, excoriation: _excoriation,
      lichenification: _lichenification, areaScore: _areaScore,
    );
    return _computeEasi(updated);
  }

  static const _areaLabels = [
    'Tiny\n<1%', 'Small\n1–9%', 'Some\n10–29%',
    'Large\n30–49%', 'Mostly\n50–69%', 'All\n≥70%',
  ];

  @override
  Widget build(BuildContext context) {
    final total = _totalEasi;
    final groupColor = _easiColor(_regional * 2);

    return Column(
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: EdgeInsets.only(
              left: 16, right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 4, height: 40,
                decoration: BoxDecoration(color: groupColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.region.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(widget.region.group.label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ])),
              IconButton(icon: const Icon(Icons.close), onPressed: () {
                Navigator.pop(context);
                widget.onDismiss();
              }),
            ]),
            const Divider(height: 16),

            // ── Skin appearance ─────────────────────────────────────────────
            Text('How does the skin look?',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),

            _SkinParamRow(
              icon: '🔴', label: 'Redness',
              question: 'How red or dark is the skin?',
              value: _erythema,
              onChanged: (v) => setState(() => _erythema = v),
            ),
            _SkinParamRow(
              icon: '🫧', label: 'Bumps & Swelling',
              question: 'Raised bumps or puffiness?',
              value: _papulation,
              onChanged: (v) => setState(() => _papulation = v),
            ),
            _SkinParamRow(
              icon: '🩹', label: 'Scratch Marks',
              question: 'Scratch marks or broken skin?',
              value: _excoriation,
              onChanged: (v) => setState(() => _excoriation = v),
            ),
            _SkinParamRow(
              icon: '🪨', label: 'Skin Thickening',
              question: 'Thick, rough, or sandpaper-like texture?',
              value: _lichenification,
              onChanged: (v) => setState(() => _lichenification = v),
            ),
            _SkinParamRow(
              icon: '💧', label: 'Weeping / Crusting',
              question: 'Oozy, wet, or crusty patches?',
              value: _oozing,
              onChanged: (v) => setState(() => _oozing = v),
            ),
            _SkinParamRow(
              icon: '🌵', label: 'Dryness / Flaking',
              question: 'Dry, flaky, or scaly skin?',
              value: _dryness,
              onChanged: (v) => setState(() => _dryness = v),
            ),
            _SkinParamRow(
              icon: '🌑', label: 'Skin Darkening',
              question: 'Turned darker — brown or blackish patches?',
              value: _pigmentation,
              onChanged: (v) => setState(() => _pigmentation = v),
            ),

            const SizedBox(height: 6),
            const Divider(height: 8),
            const SizedBox(height: 4),

            // ── Area affected ───────────────────────────────────────────────
            Text('How much of this zone is affected?',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                final val = i + 1;
                final selected = _areaScore == val;
                final fillColor = selected
                    ? Color.lerp(
                        const Color(0xFF43A047), const Color(0xFFB71C1C), i / 5)!
                    : Colors.transparent;
                final borderColor = selected
                    ? Color.lerp(
                        const Color(0xFF43A047), const Color(0xFFB71C1C), i / 5)!
                    : Colors.grey.shade300;
                return GestureDetector(
                  onTap: () => setState(() => _areaScore = val),
                  child: Column(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Center(
                        child: Text('$val',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(_areaLabels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: selected ? borderColor : Colors.grey.shade400,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        height: 1.2,
                      ),
                    ),
                  ]),
                );
              }),
            ),

            const SizedBox(height: 10),
            const Divider(height: 8),

            // ── Running score ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _easiColor(total).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Text('Zone: ${_regional.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12)),
                const Text('  ·  ', style: TextStyle(color: Colors.grey)),
                Text('Total EASI: ${total.toStringAsFixed(1)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: _easiColor(total))),
                const Text('  ·  ', style: TextStyle(color: Colors.grey)),
                Text(_easiLabel(total),
                    style: TextStyle(fontSize: 11, color: _easiColor(total))),
              ]),
            ),
            const SizedBox(height: 10),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () { Navigator.pop(context); widget.onRemove(); },
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Confirm'),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onConfirm(EasiRegionScore(
                    regionId: widget.region.id,
                    erythema: _erythema, papulation: _papulation,
                    excoriation: _excoriation, lichenification: _lichenification,
                    areaScore: _areaScore,
                    oozing: _oozing, dryness: _dryness,
                    pigmentation: _pigmentation,
                  ));
                },
              ),
            ]),
          ],
        ),
      ),
    ],
    );
  }
}

// ─── Skin parameter row ───────────────────────────────────────────────────────
// Icon + plain-language label + 4-dot severity selector + text label.
// Used in the zone scoring panel to replace raw clinical terminology.

class _SkinParamRow extends StatelessWidget {
  final String icon;
  final String label;
  final String question;
  final int value; // 0–3
  final void Function(int) onChanged;

  const _SkinParamRow({
    required this.icon,
    required this.label,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  static const _dotColors = [
    Color(0xFF9E9E9E), // 0 None     — grey
    Color(0xFFFF9800), // 1 Mild     — amber
    Color(0xFFEF6C00), // 2 Moderate — deep orange
    Color(0xFFB71C1C), // 3 Severe   — deep red
  ];
  static const _textLabels = ['None', 'Mild', 'Moderate', 'Severe'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(children: [
        // Emoji icon
        SizedBox(width: 26, child: Text(icon, style: const TextStyle(fontSize: 17))),
        const SizedBox(width: 8),
        // Label + sub-question
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(question, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ]),
        ),
        const SizedBox(width: 10),
        // 4-dot selector
        Row(
          children: List.generate(4, (i) {
            final selected = value == i;
            final color = _dotColors[i];
            return GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : Colors.transparent,
                  border: Border.all(
                    color: selected ? color : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        // Severity text
        SizedBox(
          width: 58,
          child: Text(
            _textLabels[value],
            style: TextStyle(
              fontSize: 11,
              color: value == 0 ? Colors.grey.shade400 : _dotColors[value],
              fontWeight: value > 0 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── History sheet (shown from AppBar icon) ─────────────────────────────────

class _HistorySheet extends ConsumerWidget {
  final ScrollController scrollController;
  final int historyDays;
  final void Function(int) onDaysChanged;
  final void Function(EczemaLogSummary) onEdit;
  final Future<void> Function(String) onDelete;
  final Future<bool> Function(BuildContext) onConfirmDelete;
  final void Function(List<EczemaLogSummary>) onExportPdf;

  const _HistorySheet({
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
    final logsAsync = ref.watch(eczemaProvider('$person:$historyDays'));

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
          error: (e, _) => Center(child: Text('Error: $e')),
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
                      child: _HistoryCard(log: log),
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

// ─── EASI breakdown card ──────────────────────────────────────────────────────

class _EasiBreakdownCard extends StatefulWidget {
  final Map<String, EasiRegionScore> scores;
  const _EasiBreakdownCard({required this.scores});

  @override
  State<_EasiBreakdownCard> createState() => _EasiBreakdownCardState();
}

class _EasiBreakdownCardState extends State<_EasiBreakdownCard> {
  bool _expanded = false;

  Map<EasiGroup, double> get _groupScores {
    final m = <EasiGroup, double>{};
    for (final e in widget.scores.entries) {
      final g = groupForRegion(e.key);
      m[g] = (m[g] ?? 0) + e.value.easiContribution(g);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final total = _computeEasi(widget.scores);
    if (total == 0 && !_expanded) {
      return const SizedBox.shrink();
    }
    final color = _easiColor(total);
    final gs = _groupScores;

    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('EASI Auto-Calculator',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Text('${total.toStringAsFixed(1)} — ${_easiLabel(total)}',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
            ]),

            // EASI progress bar (0–72)
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (total / 72.0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
              Text('0  Clear', style: TextStyle(fontSize: 9, color: Colors.grey)),
              Text('7  Mild', style: TextStyle(fontSize: 9, color: Colors.grey)),
              Text('21  Mod.', style: TextStyle(fontSize: 9, color: Colors.grey)),
              Text('50  Severe', style: TextStyle(fontSize: 9, color: Colors.grey)),
              Text('72', style: TextStyle(fontSize: 9, color: Colors.grey)),
            ]),

            if (_expanded) ...[
              const Divider(height: 16),
              ...EasiGroup.values.map((g) {
                final score = gs[g] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    SizedBox(
                      width: 130,
                      child: Text(g.label, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    Text('×${g.multiplier}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (score / 18.0).clamp(0, 1),
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(_easiColor(score / 5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 36,
                      child: Text(score.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                );
              }),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─── Trigger chip ────────────────────────────────────────────────────────────

class _TrigChip extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _TrigChip(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: value,
      onSelected: onChanged,
      visualDensity: VisualDensity.compact,
      selectedColor: Colors.orange.withValues(alpha: 0.20),
    );
  }
}

// ─── History card ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatefulWidget {
  final EczemaLogSummary log;
  const _HistoryCard({required this.log});
  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final easi = log.easiScore;
    final color = _easiColor(easi);
    final label = _easiLabel(easi);
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
                  Text(label, style: TextStyle(fontSize: 10, color: color)),
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
                _InfoBadge('Itch ${log.itchSeverity}/10', Colors.purple),
              if (log.sleepDisrupted == true) ...[
                const SizedBox(width: 6),
                _InfoBadge('Sleep ↓', Colors.indigo),
              ],
              if (areas.isNotEmpty) ...[
                const SizedBox(width: 6),
                _InfoBadge('${areas.length} zone${areas.length > 1 ? "s" : ""}', Colors.teal),
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
                        style: const TextStyle(fontSize: 10)),
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
    final scores = _logToScores(log);
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
                valueColor: AlwaysStoppedAnimation<Color>(_easiColor(v / 5)),
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

class _InfoBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _InfoBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}

// ─── Visit comparison metrics table ───────────────────────────────────────────

class _CompareMetricsTable extends StatelessWidget {
  final EczemaLogSummary logA;
  final EczemaLogSummary logB;
  const _CompareMetricsTable({required this.logA, required this.logB});

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
      row('Severity', _easiLabel(easiA), _easiLabel(easiB)),
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

// ─── Top region row ────────────────────────────────────────────────────────────

class _TopRegionRow extends StatelessWidget {
  final String label;
  final double frequency;
  final double avgEasi;
  const _TopRegionRow({required this.label, required this.frequency, required this.avgEasi});

  @override
  Widget build(BuildContext context) {
    final color = _easiColor(avgEasi / 5.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frequency.clamp(0.0, 1.0), minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(frequency * 100).round()}%  EASI ${avgEasi.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}

// ─── Extension helpers ────────────────────────────────────────────────────────

extension _ListX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) { if (test(e)) return e; }
    return null;
  }
}
