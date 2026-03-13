import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/medical_disclaimer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/eczema_provider.dart';
import '../providers/selected_person_provider.dart';
import '../providers/environment_provider.dart';
import '../providers/smart_correlation_provider.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/eczema_log.dart';
import '../models/easi_models.dart';
import '../models/environment_data.dart';
import '../models/smart_correlation_data.dart';
import '../widgets/eczema_body_map.dart';
import '../widgets/environment_card.dart' hide FlareRiskGauge;
import '../widgets/smart_correlation_card.dart';
import '../widgets/calendar_heatmap.dart';
import '../widgets/flare_risk_gauge.dart';
import '../widgets/trigger_radar_chart.dart';
import '../widgets/causation_chain.dart';
import '../widgets/what_if_simulator.dart';
import '../widgets/achievement_badges.dart';
import '../widgets/swipeable_insight_cards.dart';
import '../widgets/quick_log_sheet.dart';

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
  int _reportDays = 90;

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
    _tabs = TabController(length: 4, vsync: this);
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

      // Auto-capture environment data in the background
      _captureEnvironment();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
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

  /// Silently capture weather/air quality for the current location.
  Future<void> _captureEnvironment() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      // Fire-and-forget: store environment data server-side
      await apiClient.dio.get(
        ApiConstants.environmentCurrent,
        queryParameters: {'lat': pos.latitude, 'lon': pos.longitude},
      );
    } catch (_) {
      // Non-critical — silently ignore
    }
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

  void _showQuickLog() {
    // Gather frequent zones from recent logs
    final person = ref.read(selectedPersonProvider);
    final logsAsync = ref.read(eczemaProvider('$person:$_historyDays'));
    final logs = logsAsync.valueOrNull ?? [];
    final zoneCounts = <String, int>{};
    for (final log in logs) {
      for (final zone in log.parsedAreas.keys) {
        zoneCounts[zone] = (zoneCounts[zone] ?? 0) + 1;
      }
    }
    final frequentZones = (zoneCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .map((e) => e.key)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => QuickLogSheet(
        frequentZones: frequentZones,
        recentFoods: const ['Dairy', 'Eggs', 'Nuts', 'Wheat', 'Soy', 'Citrus'],
        onExpandToFull: () {
          _tabs.animateTo(0);
          _showFullFormSheet();
        },
        onSubmit: ({required severity, bodyZones, foodAssociations, notes}) async {
          final p = ref.read(selectedPersonProvider);
          final now = DateTime.now();
          final data = {
            'log_date': DateFormat('yyyy-MM-dd').format(now),
            'log_time': DateFormat('HH:mm').format(now),
            'itch_severity': severity.itchValue,
            'dairy_consumed': foodAssociations?.contains('Dairy') ?? false,
            'eggs_consumed': foodAssociations?.contains('Eggs') ?? false,
            'nuts_consumed': foodAssociations?.contains('Nuts') ?? false,
            'wheat_consumed': foodAssociations?.contains('Wheat') ?? false,
            'soy_consumed': foodAssociations?.contains('Soy') ?? false,
            'citrus_consumed': foodAssociations?.contains('Citrus') ?? false,
            'family_member_id': p == 'self' ? null : p,
          };
          if (bodyZones != null && bodyZones.isNotEmpty) {
            final zones = bodyZones.map((z) => {'area': z, 'level': severity.itchValue}).toList();
            data['affected_areas'] = jsonEncode({'zones': zones, 'patches': []});
          }
          try {
            await apiClient.dio.post(ApiConstants.eczema, data: data);
            if (!mounted) return;
            ref.invalidate(eczemaProvider('$p:$_historyDays'));
            ref.invalidate(eczemaHeatmapProvider('$p:$_heatmapDays'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quick log saved!')),
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Something went wrong. Please try again.')),
              );
            }
          }
        },
      ),
    );
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
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
            icon: const Icon(Icons.bolt),
            tooltip: 'Quick Log',
            onPressed: _showQuickLog,
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
            Tab(text: 'Report'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildLogTab(), _buildCompareTab(), _buildHeatmapTab(), _buildReportTab()],
            ),
          ),
          const MedicalDisclaimer(),
        ],
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


  // ── PDF colour helpers ──────────────────────────────────────────────────────
  static PdfColor _pdfItchColor(double avgItch) {
    if (avgItch <= 0) return PdfColors.grey;
    if (avgItch <= 2) return PdfColors.green400;
    if (avgItch <= 4) return PdfColors.yellow700;
    if (avgItch <= 6) return PdfColors.orange;
    if (avgItch <= 8) return PdfColors.deepOrange;
    return PdfColors.red900;
  }

  static String _pdfItchLabel(double avgItch) {
    if (avgItch <= 0) return 'None';
    if (avgItch <= 2) return 'Mild';
    if (avgItch <= 4) return 'Moderate';
    if (avgItch <= 6) return 'Significant';
    if (avgItch <= 8) return 'Severe';
    return 'Extreme';
  }

  static const _kAccent = PdfColor(0.16, 0.65, 0.60);       // teal 500
  static const _kAccentLight = PdfColor(0.88, 0.96, 0.95);  // teal 50
  static const _kDanger = PdfColor(0.76, 0.20, 0.20);       // red 800
  static const _kDangerLight = PdfColor(1, 0.92, 0.93);     // red 50
  static const _kSuccess = PdfColor(0.19, 0.55, 0.24);      // green 800
  static const _kSuccessLight = PdfColor(0.91, 0.96, 0.91); // green 50

  // ── PDF Export ─────────────────────────────────────────────────────────────
  Future<void> _exportPdf(List<EczemaLogSummary> logs, [FoodCorrelationData? foodCorrelation]) async {
    final doc = pw.Document();
    final days = _tabs.index == 3 ? _reportDays : _historyDays;
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
              color: _kAccent,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(children: [
              _PdfLogo(size: 36),
              pw.SizedBox(width: 12),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Eczema Assessment Report',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                pw.SizedBox(height: 2),
                pw.Text('Vitalis Health Tracker',
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
            metricCard('Assessments', '${logs.length}', _kAccent),
            pw.SizedBox(width: 6),
            metricCard('Avg Itch', '${avgItch.toStringAsFixed(1)}/10', _pdfItchColor(avgItch),
                sub: _pdfItchLabel(avgItch)),
            pw.SizedBox(width: 6),
            metricCard('Peak Itch', '$maxItch/10', _pdfItchColor(maxItch.toDouble())),
            pw.SizedBox(width: 6),
            metricCard('Avg EASI', avgEasi.toStringAsFixed(1), _kAccent,
                sub: _easiLabel(avgEasi)),
            pw.SizedBox(width: 6),
            metricCard('Flare Days', '$flareDays', _kDanger,
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
            child: _PdfBodyMap(width: pageW, heatIntensity: heatIntensity, zoneAvgItch: zoneAvgItch),
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
              final color = _pdfItchColor(avgI);
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
            _pdfPageHeader('Food-Itch Correlation Analysis', days),
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
                  color: _kAccentLight,
                  border: pw.Border.all(color: _kAccent, width: 0.5),
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
                  color: _kDangerLight,
                  border: pw.Border.all(color: _kDanger, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Row(children: [
                    pw.Container(width: 10, height: 10,
                        decoration: const pw.BoxDecoration(color: _kDanger, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 6),
                    pw.Text('Suspected Trigger Foods',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _kDanger)),
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
                        border: pw.Border.all(color: PdfColor(_kDanger.red, _kDanger.green, _kDanger.blue, 0.3), width: 0.5),
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
                                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _kDanger)),
                              pw.SizedBox(width: 12),
                              pw.Text('Without: ', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                              pw.Text('${f.avgItchWithout}/10',
                                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _kSuccess)),
                            ]),
                            pw.SizedBox(height: 3),
                            itchBar(f.avgItchWith, 10, _kDanger, 200),
                          ]),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: _kDangerLight,
                            border: pw.Border.all(color: _kDanger, width: 0.5),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                          ),
                          child: pw.Text('+${f.correlationScore}',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kDanger)),
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
                  color: _kSuccessLight,
                  border: pw.Border.all(color: _kSuccess, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Row(children: [
                    pw.Container(width: 10, height: 10,
                        decoration: const pw.BoxDecoration(color: _kSuccess, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 6),
                    pw.Text('Foods Associated with Lower Itch',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _kSuccess)),
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
                        border: pw.Border.all(color: PdfColor(_kSuccess.red, _kSuccess.green, _kSuccess.blue, 0.3), width: 0.5),
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
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _kSuccess)),
                            pw.SizedBox(width: 12),
                            pw.Text('Without: ', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                            pw.Text('${f.avgItchWithout}/10',
                                style: const pw.TextStyle(fontSize: 9)),
                          ]),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: _kSuccessLight,
                            border: pw.Border.all(color: _kSuccess, width: 0.5),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                          ),
                          child: pw.Text('${f.correlationScore}',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kSuccess)),
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
          _pdfPageHeader('Detailed Assessment Data', days),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (ctx) => pw.Row(children: [
        pw.Text('Vitalis Eczema Report',
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
            final color = _pdfItchColor(avgI);
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
                      child: pw.Text(_pdfItchLabel(avgI), style: pw.TextStyle(fontSize: 8, color: color))),
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
              decoration: const pw.BoxDecoration(color: _kAccentLight),
              children: ['Date / Time', 'EASI', 'Severity', 'Itch', 'Sleep', 'Affected Areas'].map((h) =>
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _kAccent)),
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
              final itchColor = _pdfItchColor((log.itchSeverity ?? 0).toDouble());
              return pw.TableRow(
                decoration: i.isOdd ? const pw.BoxDecoration(color: PdfColor(0.97, 0.97, 0.97)) : null,
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text('${log.logDate} ${log.logTime}', style: const pw.TextStyle(fontSize: 7))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(easi.toStringAsFixed(1),
                          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(_easiLabel(easi), style: const pw.TextStyle(fontSize: 7))),
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

  pw.Widget _pdfPageHeader(String title, int days) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      border: pw.Border(bottom: pw.BorderSide(color: _kAccent, width: 2)),
    ),
    child: pw.Row(children: [
      _PdfLogo(size: 20),
      pw.SizedBox(width: 8),
      pw.Text(title,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.Spacer(),
      pw.Text('Last $days days  |  Vitalis',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
    ]),
  );

  // ─── Compare Tab ────────────────────────────────────────────────────────────
  Widget _buildCompareTab() {
    final person = ref.watch(selectedPersonProvider);
    final logsAsync = ref.watch(eczemaProvider('$person:90'));
    return logsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Something went wrong. Pull to refresh.')),
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Column(
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
              const SizedBox(height: 8),

              // Body comparison (scrolls with everything else)
              EczemaBodyComparison(
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

              const SizedBox(height: 16),
              // Metrics table
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating mock data (~240 records)… please wait'), duration: Duration(seconds: 30)),
    );
    try {
      final res = await apiClient.dio.post(
        ApiConstants.eczemaMock,
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      final data = res.data as Map<String, dynamic>;
      final ec = data['eczema_entries'] ?? 0;
      final nc = data['nutrition_entries'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated $ec eczema + $nc nutrition mock entries (90 days)')),
      );
      _invalidateAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    }
  }

  Future<void> _deleteMockData() async {
    try {
      final res = await apiClient.dio.delete(ApiConstants.eczemaMock);
      if (!mounted) return;
      final data = res.data as Map<String, dynamic>;
      final ec = data['eczema_deleted'] ?? 0;
      final nc = data['nutrition_deleted'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $ec eczema + $nc nutrition mock entries')),
      );
      _invalidateAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
    }
  }

  void _invalidateAll() {
    final person = ref.read(selectedPersonProvider);
    ref.invalidate(eczemaHeatmapProvider('$person:$_heatmapDays'));
    ref.invalidate(eczemaHeatmapProvider('$person:$_reportDays'));
    ref.invalidate(eczemaProvider('$person:$_historyDays'));
    ref.invalidate(eczemaProvider('$person:90'));
    ref.invalidate(eczemaFoodCorrelationProvider('$person:$_reportDays'));
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
              tooltip: 'Generate mock data (90 days)',
              onPressed: _generateMockData,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              tooltip: 'Delete all mock data',
              onPressed: _deleteMockData,
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
            error: (e, _) => const Center(child: Text('Something went wrong. Pull to refresh.')),
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

  // ─── Report Tab ────────────────────────────────────────────────────────────
  Widget _buildReportTab() {
    final person = ref.watch(selectedPersonProvider);
    final heatAsync = ref.watch(eczemaHeatmapProvider('$person:$_reportDays'));
    final logsAsync = ref.watch(eczemaProvider('$person:$_reportDays'));
    final foodAsync = ref.watch(eczemaFoodCorrelationProvider('$person:$_reportDays'));

    // Phase 1: Environment correlation
    final envAsync = ref.watch(environmentCorrelationProvider((days: _reportDays, person: person)));
    // Phase 2: Smart food correlation
    final smartAsync = ref.watch(smartCorrelationProvider((days: _reportDays, person: person)));

    return Column(
      children: [
        // Period selector
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            Text('Report Period',
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
              ],
              selected: {_reportDays},
              onSelectionChanged: (s) => setState(() => _reportDays = s.first),
            ),
          ]),
        ),
        Expanded(
          child: heatAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const Center(child: Text('Something went wrong. Pull to refresh.')),
            data: (heatData) {
              return logsAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Center(child: Text('Something went wrong. Pull to refresh.')),
                data: (logs) {
                  if (logs.isEmpty) {
                    return const Center(
                      child: Text('No eczema data for this period',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return foodAsync.when(
                    skipLoadingOnReload: true,
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) {
                      return _ReportContent(
                        heatData: heatData,
                        logs: logs,
                        days: _reportDays,
                        foodCorrelation: null,
                        onExportPdf: () => _exportPdf(logs),
                        envCorrelation: envAsync.valueOrNull,
                        smartCorrelation: smartAsync.valueOrNull,
                      );
                    },
                    data: (foodData) {
                      return _ReportContent(
                        heatData: heatData,
                        logs: logs,
                        days: _reportDays,
                        foodCorrelation: foodData,
                        onExportPdf: () => _exportPdf(logs, foodData),
                        envCorrelation: envAsync.valueOrNull,
                        smartCorrelation: smartAsync.valueOrNull,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── PDF Logo (vector-drawn Vitalis "V" leaf mark) ──────────────────────────

class _PdfLogo extends pw.StatelessWidget {
  final double size;
  _PdfLogo({this.size = 32});

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

class _PdfBodyMap extends pw.StatelessWidget {
  final double width;
  final Map<String, double> heatIntensity; // zoneId → 0.0-1.0
  final Map<String, double> zoneAvgItch;   // zoneId → avg itch 0-10

  _PdfBodyMap({
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

// ─── Report content widget ────────────────────────────────────────────────────

class _ReportContent extends StatelessWidget {
  final EczemaHeatmapData heatData;
  final List<EczemaLogSummary> logs;
  final int days;
  final FoodCorrelationData? foodCorrelation;
  final VoidCallback onExportPdf;
  final EnvironmentCorrelation? envCorrelation;
  final SmartCorrelationResult? smartCorrelation;

  const _ReportContent({
    required this.heatData,
    required this.logs,
    required this.days,
    this.foodCorrelation,
    required this.onExportPdf,
    this.envCorrelation,
    this.smartCorrelation,
  });

  static Color _itchColor(double avgItch) {
    if (avgItch <= 0) return const Color(0xFF9E9E9E);
    if (avgItch <= 2) return const Color(0xFF66BB6A);
    if (avgItch <= 4) return const Color(0xFFFDD835);
    if (avgItch <= 6) return const Color(0xFFFF9800);
    if (avgItch <= 8) return const Color(0xFFF4511E);
    return const Color(0xFFB71C1C);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Compute stats
    final itchValues = logs
        .where((l) => l.itchSeverity != null)
        .map((l) => l.itchSeverity!)
        .toList();
    final avgItch = itchValues.isEmpty
        ? 0.0
        : itchValues.reduce((a, b) => a + b) / itchValues.length;
    final maxItch = itchValues.isEmpty
        ? 0
        : itchValues.reduce((a, b) => a > b ? a : b);
    final sleepDisrupted = logs.where((l) => l.sleepDisrupted == true).length;
    final easiScores = logs.map((l) => l.easiScore).toList();
    final avgEasi = easiScores.isEmpty
        ? 0.0
        : easiScores.reduce((a, b) => a + b) / easiScores.length;

    // Compute per-zone itch averages
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

    // Sort zones by avg itch descending
    final sortedZones = zoneAvgItch.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heatmap Body Map ──────────────────────────────────
          Card(
            clipBehavior: Clip.hardEdge,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(children: [
                    const SizedBox(width: 8),
                    Text('Itch Severity Heatmap',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text('Last $days days',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 8),
                  ]),
                  const SizedBox(height: 4),
                  EczemaBodyMap(
                    heatData: heatData.regionIntensity,
                    readOnly: true,
                  ),
                ],
              ),
            ),
          ),

          // ── Itch Severity Legend ─────────────────────────────
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Itch Severity Scale',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final entry in [
                        (0.0, 'None'),
                        (2.0, 'Mild'),
                        (4.0, 'Moderate'),
                        (6.0, 'Significant'),
                        (8.0, 'Severe'),
                        (10.0, 'Extreme'),
                      ])
                        Expanded(
                          child: Column(children: [
                            Container(
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: _itchColor(entry.$1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(entry.$2,
                                style: const TextStyle(fontSize: 8),
                                textAlign: TextAlign.center),
                          ]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Key Stats ──────────────────────────────────────
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatCard(
              label: 'Entries',
              value: '${logs.length}',
              color: cs.primary,
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
              label: 'Avg Itch',
              value: avgItch.toStringAsFixed(1),
              color: _itchColor(avgItch),
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
              label: 'Peak Itch',
              value: '$maxItch/10',
              color: _itchColor(maxItch.toDouble()),
            )),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(
              label: 'Sleep',
              value: '$sleepDisrupted',
              subtitle: 'disrupted',
              color: sleepDisrupted > 0 ? Colors.indigo : Colors.green,
            )),
          ]),

          // ── Avg EASI ────────────────────────────────────────
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Text('Avg EASI Score',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _easiColor(avgEasi).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _easiColor(avgEasi).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${avgEasi.toStringAsFixed(1)} — ${_easiLabel(avgEasi)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _easiColor(avgEasi),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Most Affected Areas (color-coded by itch) ──────
          if (sortedZones.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Most Affected Areas',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Color shows average itch severity for each zone',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            ...sortedZones.take(12).map((e) {
              final region = findRegion(e.key);
              final label = region?.label ?? e.key;
              final avgI = e.value;
              final count = zoneItchCount[e.key] ?? 0;
              final color = _itchColor(avgI);
              final pct = logs.isEmpty ? 0 : (count / logs.length * 100).round();

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  // Color indicator
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Text(label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  // Itch bar
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (avgI / 10.0).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: color.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 85,
                    child: Text(
                      '${avgI.toStringAsFixed(1)}/10 · $pct%',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              );
            }),
          ],

          // ── Food Correlation Insights ──────────────────────
          if (foodCorrelation != null && foodCorrelation!.badFoods.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.restaurant, size: 18, color: Colors.red),
                    const SizedBox(width: 6),
                    Text('Suspected Trigger Foods',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.red.shade700)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Foods correlated with higher itch scores (eaten 0–2 days before flares)',
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  ...foodCorrelation!.badFoods.take(3).map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.foodName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            'Avg itch ${f.avgItchWith}/10 when eaten vs ${f.avgItchWithout}/10 without  ·  ${f.timesEaten}× eaten',
                            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                          ),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text('+${f.correlationScore}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: Colors.red.shade700)),
                      ),
                    ]),
                  )),
                ]),
              ),
            ),

            if (foodCorrelation!.goodFoods.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.eco, size: 18, color: Colors.green),
                      const SizedBox(width: 6),
                      Text('Foods with Lower Itch',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.green.shade700)),
                    ]),
                    const SizedBox(height: 8),
                    ...foodCorrelation!.goodFoods.take(3).map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f.foodName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          '${f.avgItchWith}/10 vs ${f.avgItchWithout}/10',
                          style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                        ),
                      ]),
                    )),
                  ]),
                ),
              ),
          ],

          // ── Phase 1: Environmental Triggers ──────────────────
          const SizedBox(height: 16),
          if (envCorrelation != null)
            EnvironmentCorrelationCard(correlation: envCorrelation!)
          else
            _EmptyAnalysisCard(
              icon: Icons.cloud,
              title: 'Environmental Triggers',
              message: 'Save eczema logs to auto-capture weather data. '
                  'Location permission is needed to track temperature, '
                  'humidity, pollen, and air quality alongside your flares.',
            ),

          // ── Phase 2: Smart Food Correlation ──────────────────
          const SizedBox(height: 16),
          if (smartCorrelation != null)
            SmartCorrelationCard(result: smartCorrelation!)
          else
            _EmptyAnalysisCard(
              icon: Icons.psychology,
              title: 'Smart Food Analysis',
              message: 'Log both eczema and nutrition data to unlock '
                  'AI-powered food trigger analysis with Bayesian '
                  'probabilities, lag detection, and combination triggers.',
            ),

          // ── Phase 6: Calendar Heatmap ──────────────────────
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.calendar_month, size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('Severity Calendar',
                        style: Theme.of(context).textTheme.titleSmall),
                  ]),
                  const SizedBox(height: 4),
                  Text('Daily itch severity over the last $days days',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  CalendarHeatmap(
                    data: {
                      for (final log in logs)
                        if (log.itchSeverity != null)
                          log.logDate: log.itchSeverity!.toDouble(),
                    },
                    days: days,
                  ),
                ],
              ),
            ),
          ),

          // ── Phase 6: Flare Risk Gauge ──────────────────────
          if (envCorrelation != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text('Flare Risk Score',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Center(child: FlareRiskGauge(score: envCorrelation!.flareRiskScore)),
                  const SizedBox(height: 8),
                  if (envCorrelation!.topTrigger != null)
                    Text('Top trigger: ${envCorrelation!.topTrigger}',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
            ),
          ],

          // ── Phase 6: Trigger Profile Radar ─────────────────
          if (smartCorrelation != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Text('Trigger Profile',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('Which categories contribute most to your flares',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Center(child: TriggerRadarChart(
                    food: _triggerAxisValue(smartCorrelation!.categoryCorrelations),
                    environment: envCorrelation != null
                        ? (envCorrelation!.flareRiskScore / 100).clamp(0.0, 1.0)
                        : 0,
                    products: 0, // would need product correlation data
                    stress: _stressAxisValue(logs),
                    sleep: _sleepAxisValue(logs),
                  )),
                ]),
              ),
            ),
          ],

          // ── Phase 6: Causation Chain ────────────────────────
          if (logs.length >= 2 && foodCorrelation != null && foodCorrelation!.badFoods.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.timeline, size: 18, color: Colors.deepPurple),
                      const SizedBox(width: 6),
                      Text('Recent Causation Chain',
                          style: Theme.of(context).textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 4),
                    Text('Suspected food triggers leading to flares',
                        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    CausationChainTimeline(events: _buildCausationEvents(logs, foodCorrelation!)),
                  ],
                ),
              ),
            ),
          ],

          // ── Phase 6: What-If Simulator ─────────────────────
          if (smartCorrelation != null && smartCorrelation!.bayesianTriggers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.science, size: 18, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Text('What-If Simulator',
                          style: Theme.of(context).textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 4),
                    Text('See how avoiding triggers might help',
                        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    WhatIfSimulator(
                      currentAvgItch: avgItch,
                      scenarios: _buildWhatIfScenarios(smartCorrelation!, avgItch),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Phase 6: Swipeable Insight Cards ───────────────
          if (smartCorrelation != null || envCorrelation != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Insights', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SwipeableInsightCards(
                      insights: _buildSwipeInsights(
                        smartCorrelation, envCorrelation, avgItch, logs.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Export button ──────────────────────────────────
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export PDF Report'),
              onPressed: onExportPdf,
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 6 helper methods ──────────────────────────────────────────────────

  static double _triggerAxisValue(List<CategoryCorrelation> cats) {
    if (cats.isEmpty) return 0;
    final maxRisk = cats.map((c) => c.riskMultiplier).reduce((a, b) => a > b ? a : b);
    return (maxRisk / 3).clamp(0.0, 1.0); // normalize: 3x = full
  }

  static double _stressAxisValue(List<EczemaLogSummary> logs) {
    final stressLogs = logs.where((l) => l.stressLevel != null && l.stressLevel! > 0).toList();
    if (stressLogs.isEmpty) return 0;
    final avg = stressLogs.map((l) => l.stressLevel!).reduce((a, b) => a + b) / stressLogs.length;
    return (avg / 10).clamp(0.0, 1.0);
  }

  static double _sleepAxisValue(List<EczemaLogSummary> logs) {
    final disrupted = logs.where((l) => l.sleepDisrupted == true).length;
    if (logs.isEmpty) return 0;
    return (disrupted / logs.length).clamp(0.0, 1.0);
  }

  static List<CausationEvent> _buildCausationEvents(
      List<EczemaLogSummary> logs, FoodCorrelationData foodData) {
    final events = <CausationEvent>[];
    final badFoodNames = foodData.badFoods.take(3).map((f) => f.foodName).toSet();

    // Take last 5 logs and create a simplified chain
    final recent = logs.take(5).toList();
    for (final log in recent.reversed) {
      final date = DateTime.tryParse(log.logDate) ?? DateTime.now();
      final itch = log.itchSeverity ?? 0;
      final triggers = <String>[];
      if (log.dairyConsumed == true) triggers.add('DAIRY');
      if (log.eggsConsumed == true) triggers.add('EGGS');
      if (log.nutsConsumed == true) triggers.add('NUTS');
      if (log.wheatConsumed == true) triggers.add('WHEAT');

      if (triggers.isNotEmpty || itch >= 5) {
        events.add(CausationEvent(
          dateTime: date,
          title: itch >= 5 ? 'Flare: Itch $itch/10' : 'Triggers logged',
          subtitle: triggers.isEmpty ? 'No specific triggers flagged' : triggers.join(', '),
          tags: triggers,
          isFlare: itch >= 5,
          severity: itch.toDouble(),
        ));
      }
    }
    return events;
  }

  static List<WhatIfScenario> _buildWhatIfScenarios(
      SmartCorrelationResult smart, double currentAvg) {
    final scenarios = <WhatIfScenario>[];
    for (final trigger in smart.bayesianTriggers.take(4)) {
      if (trigger.posteriorProbability > 0.2) {
        final reduction = currentAvg * trigger.posteriorProbability * 0.5;
        scenarios.add(WhatIfScenario(
          label: 'Avoid ${trigger.displayName}',
          description: '${(trigger.posteriorProbability * 100).toInt()}% trigger probability',
          predictedItch: (currentAvg - reduction).clamp(0.0, 10.0),
          icon: Icons.no_food,
        ));
      }
    }
    // Add sleep/stress scenarios
    if (currentAvg > 3) {
      scenarios.add(WhatIfScenario(
        label: 'Improve sleep quality',
        description: 'Get 7+ hours consistently',
        predictedItch: (currentAvg * 0.85).clamp(0.0, 10.0),
        icon: Icons.bedtime,
      ));
    }
    return scenarios;
  }

  static List<SwipeableInsight> _buildSwipeInsights(
      SmartCorrelationResult? smart, EnvironmentCorrelation? env,
      double avgItch, int logCount) {
    final insights = <SwipeableInsight>[];

    if (smart != null) {
      for (final cat in smart.categoryCorrelations.where((c) => c.significant).take(3)) {
        insights.add(SwipeableInsight(
          title: '${cat.displayName} increases itch ${cat.riskMultiplier.toStringAsFixed(1)}x',
          body: 'Avg itch ${cat.avgItchWith.toStringAsFixed(1)}/10 with ${cat.displayName} '
              'vs ${cat.avgItchWithout.toStringAsFixed(1)}/10 without.',
          icon: Icons.restaurant,
          color: Colors.red,
        ));
      }
      for (final bt in smart.bayesianTriggers.where((b) => b.confidence == 'confirmed').take(2)) {
        insights.add(SwipeableInsight(
          title: '${bt.displayName}: confirmed trigger',
          body: '${(bt.posteriorProbability * 100).toInt()}% probability based on ${bt.timesConsumed} observations.',
          icon: Icons.verified,
          color: Colors.deepOrange,
        ));
      }
    }

    if (env != null) {
      for (final f in env.factors.where((f) => f.significant).take(2)) {
        insights.add(SwipeableInsight(
          title: '${f.factor} affects your skin ${f.riskMultiplier.toStringAsFixed(1)}x',
          body: 'Itch is ${f.avgItchBad.toStringAsFixed(1)}/10 in bad conditions '
              'vs ${f.avgItchNormal.toStringAsFixed(1)}/10 normally.',
          icon: Icons.cloud,
          color: Colors.blue,
        ));
      }
    }

    if (logCount >= 7) {
      insights.add(SwipeableInsight(
        title: '$logCount entries logged!',
        body: "Your data is getting powerful. Keep logging for more accurate insights.",
        icon: Icons.trending_up,
        color: Colors.green,
      ));
    }

    if (insights.isEmpty) {
      insights.add(const SwipeableInsight(
        title: 'Keep logging!',
        body: 'More data means better insights. Try to log daily for the best results.',
        icon: Icons.edit_note,
      ));
    }

    return insights;
  }
}

// ─── Stat card for report ───────────────────────────────────────────────────

class _EmptyAnalysisCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyAnalysisCard({required this.icon, required this.title, required this.message});

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
          children: [
            Row(
              children: [
                Icon(icon, color: cs.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ]),
      ),
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
          error: (e, _) => const Center(child: Text('Something went wrong. Pull to refresh.')),
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
