import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/medical_disclaimer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
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
import '../widgets/environment_card.dart';
import '../widgets/friendly_error.dart';
import '../widgets/days_slider.dart';
import '../widgets/eczema_body_map.dart';
import '../widgets/help_tooltip.dart';

// ── Extracted widgets ────────────────────────────────────────────────────────
import 'eczema/eczema_helpers.dart';
import 'eczema/easi_panel.dart';
import 'eczema/easi_breakdown_card.dart';
import 'eczema/eczema_form_widgets.dart';
import 'eczema/eczema_compare_tab.dart';
import 'eczema/eczema_heatmap_tab.dart';
import 'eczema/eczema_report_tab.dart';
import 'eczema/eczema_pdf_export.dart';
import 'package:hugeicons/hugeicons.dart';

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
  final int _historyDays = 30;
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

  // ── Auto-captured environment ──────────────────────────────────────────
  EnvironmentData? _currentEnvironment;
  bool _envLoading = false;

  // ── Compare tab state ────────────────────────────────────────────────────
  String? _compareIdA;
  String? _compareIdB;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _fetchEnvironment();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── EASI total ────────────────────────────────────────────────────────────
  double get _easiTotal => computeEasi(_regionScores);

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
      ref.invalidate(eczemaProvider('${p}_$_historyDays'));
      ref.invalidate(eczemaHeatmapProvider('${p}_$_heatmapDays'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Log updated' : 'Log saved')),
      );
      _tabs.animateTo(0);

      // Auto-capture environment data in the background
      _captureEnvironment();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, context: 'eczema'))));
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
          perm == LocationPermission.deniedForever) {
        return;
      }

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

  /// Auto-fetch current environment on screen load for display.
  Future<void> _fetchEnvironment() async {
    if (_envLoading) return;
    setState(() => _envLoading = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      final res = await apiClient.dio.get(
        ApiConstants.environmentCurrent,
        queryParameters: {'lat': pos.latitude, 'lon': pos.longitude},
      );
      if (mounted) {
        setState(() {
          _currentEnvironment = EnvironmentData.fromJson(res.data as Map<String, dynamic>);
        });
      }
    } catch (_) {
      // Non-critical
    } finally {
      if (mounted) setState(() => _envLoading = false);
    }
  }

  void _onZoneTap(BodyRegion region) {
    setState(() => _activeZoneId = region.id);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _showEasiPanel(region);
    });
  }

  void _onPatchDrawn(DrawnPatch patch, BodyRegion? zone) {
    setState(() => _drawnPatches.add(patch));
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
        builder: (_, scrollController) => EasiPanel(
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

  // ── PDF Export (delegates to extracted module) ────────────────────────────
  Future<void> _exportPdf(List<EczemaLogSummary> logs, [FoodCorrelationData? foodCorrelation]) async {
    final days = _tabs.index == 3 ? _reportDays : _historyDays;
    await exportEczemaPdf(
      logs: logs,
      days: days,
      foodCorrelation: foodCorrelation,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final easi = _easiTotal;
    final color = easiColor(easi);
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
                    Text(easiLabel(easi), style: TextStyle(fontSize: 11, color: color)),
                    const HelpTooltip(
                      message: 'EASI (Eczema Area and Severity Index) measures eczema severity from 0-72. Tap body zones to score each affected area for redness, thickness, scratching, and skin thickening.',
                      iconSize: 14,
                    ),
                  ]),
                ),
              ),
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
                HugeIcon(icon: HugeIcons.strokeRoundedTouch01, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 3),
                Flexible(
                  child: Text('Tap zone to score  ·  Pinch to zoom',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
                      final color = easiColor(contribution * 3);
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ActionChip(
                          label: Text('$lbl ${contribution.toStringAsFixed(1)}',
                              style: TextStyle(fontSize: 11, color: color)),
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
            icon: HugeIcon(icon: HugeIcons.strokeRoundedTask01),
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
            final easi = computeEasi(_regionScores);
            final color = easiColor(easi);

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
                    child: Text('EASI ${easi.toStringAsFixed(1)} - ${easiLabel(easi)}',
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
                          icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 15),
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
                          icon: HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 15),
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

                    // Auto-captured environment
                    if (_currentEnvironment != null)
                      EnvironmentCard(data: _currentEnvironment!)
                    else if (_envLoading)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 12),
                              Text('Fetching environment data...', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        child: ListTile(
                          leading: HugeIcon(icon: HugeIcons.strokeRoundedCloud, size: 20),
                          title: const Text('Environment data unavailable', style: TextStyle(fontSize: 13)),
                          subtitle: const Text('Enable location to auto-capture weather', style: TextStyle(fontSize: 11)),
                          dense: true,
                          onTap: _fetchEnvironment,
                          trailing: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 18),
                        ),
                      ),
                    const SizedBox(height: 8),

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
                          final c = easiColor(contribution * 3);
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
                    EasiBreakdownCard(scores: _regionScores),
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
                                color: easiColor(_itchVas.toDouble()).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('$_itchVas / 10',
                                  style: TextStyle(fontWeight: FontWeight.bold,
                                      color: easiColor(_itchVas.toDouble()))),
                            ),
                          ]),
                          Slider(
                            value: _itchVas.toDouble(), min: 0, max: 10, divisions: 10,
                            activeColor: easiColor(_itchVas.toDouble()),
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
                              TrigChip('Detergent', _trigNewDetergent, (v) => update(() => _trigNewDetergent = v)),
                              TrigChip('Fabric', _trigNewFabric, (v) => update(() => _trigNewFabric = v)),
                              TrigChip('Dust', _trigDust, (v) => update(() => _trigDust = v)),
                              TrigChip('Pet', _trigPet, (v) => update(() => _trigPet = v)),
                              TrigChip('Chlorine', _trigChlorine, (v) => update(() => _trigChlorine = v)),
                              TrigChip('Dairy', _trigDairy, (v) => update(() => _trigDairy = v)),
                              TrigChip('Eggs', _trigEggs, (v) => update(() => _trigEggs = v)),
                              TrigChip('Nuts', _trigNuts, (v) => update(() => _trigNuts = v)),
                              TrigChip('Wheat', _trigWheat, (v) => update(() => _trigWheat = v)),
                              TrigChip('Soy', _trigSoy, (v) => update(() => _trigSoy = v)),
                              TrigChip('Citrus', _trigCitrus, (v) => update(() => _trigCitrus = v)),
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
                            : HugeIcon(icon: HugeIcons.strokeRoundedFloppyDisk),
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

  // ─── Compare Tab ────────────────────────────────────────────────────────────
  Widget _buildCompareTab() {
    final person = ref.watch(selectedPersonProvider);
    final logsAsync = ref.watch(eczemaProvider('${person}_90'));
    return logsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FriendlyError(error: e, context: 'eczema comparison'),
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
        final scoresA = logToScores(logA);
        final scoresB = logToScores(logB);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Column(
            children: [
              // Selectors
              Row(children: [
                Expanded(child: _visitPicker('Visit A', logs, logA.id, (id) => setState(() {
                  _compareIdA = id;
                  _compareIdB ??= logs.firstWhereOrNull((l) => l.id != id)?.id;
                }))),
                const SizedBox(width: 8),
                Expanded(child: _visitPicker('Visit B', logs, logB.id, (id) => setState(() => _compareIdB = id))),
              ]),
              const SizedBox(height: 8),

              // Body comparison
              EczemaBodyComparison(
                view: EczemaBodyView.front,
                scoresA: scoresA,
                scoresB: scoresB,
                labelA: '${logA.logDate}\n${logA.logTime}',
                labelB: '${logB.logDate}\n${logB.logTime}',
                easiA: logA.easiScore,
                easiB: logB.easiScore,
                severityA: easiLabel(logA.easiScore),
                severityB: easiLabel(logB.easiScore),
              ),

              const SizedBox(height: 16),
              // Metrics table
              CompareMetricsTable(logA: logA, logB: logB),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, context: 'mock data'))));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, context: 'mock data'))));
    }
  }

  void _invalidateAll() {
    final person = ref.read(selectedPersonProvider);
    ref.invalidate(eczemaHeatmapProvider('${person}_$_heatmapDays'));
    ref.invalidate(eczemaHeatmapProvider('${person}_$_reportDays'));
    ref.invalidate(eczemaProvider('${person}_$_historyDays'));
    ref.invalidate(eczemaProvider('${person}_90'));
    ref.invalidate(eczemaFoodCorrelationProvider('${person}_$_reportDays'));
  }

  Widget _buildHeatmapTab() {
    final person = ref.watch(selectedPersonProvider);
    final heatAsync = ref.watch(eczemaHeatmapProvider('${person}_$_heatmapDays'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            IconButton(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedTestTube01, size: 20),
              tooltip: 'Generate mock data (90 days)',
              onPressed: _generateMockData,
            ),
            IconButton(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedDelete01, size: 20),
              tooltip: 'Delete all mock data',
              onPressed: _deleteMockData,
            ),
            const Spacer(),
            DaysSlider(
              value: _heatmapDays,
              onChanged: (d) => setState(() => _heatmapDays = d),
              compact: true,
            ),
          ]),
        ),
        Expanded(
          child: heatAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FriendlyError(error: e, context: 'eczema heatmap'),
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
                      ...data.topRegions.take(10).map((r) => TopRegionRow(
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
    final heatAsync = ref.watch(eczemaHeatmapProvider('${person}_$_reportDays'));
    final logsAsync = ref.watch(eczemaProvider('${person}_$_reportDays'));
    final foodAsync = ref.watch(eczemaFoodCorrelationProvider('${person}_$_reportDays'));

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
            DaysSlider(
              value: _reportDays,
              onChanged: (d) => setState(() => _reportDays = d),
              compact: true,
            ),
          ]),
        ),
        Expanded(
          child: heatAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FriendlyError(error: e, context: 'eczema report'),
            data: (heatData) {
              return logsAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => FriendlyError(error: e, context: 'eczema report'),
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
                      return ReportContent(
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
                      return ReportContent(
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
