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
import '../core/timezone_util.dart';
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
  EczemaBodyView _bodyView = EczemaBodyView.front;
  final Map<String, EasiRegionScore> _regionScores = {};
  String? _activeZoneId;

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
      final areasJson = _regionScores.values.map((s) => s.toJson()).toList();
      final data = {
        'log_date': DateFormat('yyyy-MM-dd').format(_date),
        'log_time': _time.format(context),
        'itch_severity': _itchVas,
        'affected_areas': jsonEncode(areasJson),
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
      _tabs.animateTo(1);
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
      _bodyView = EczemaBodyView.front;
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
      _activeZoneId = null;
    });
    _tabs.animateTo(0);
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
    setState(() => _activeZoneId = region.id);
    _showEasiPanel(region);
  }

  void _showEasiPanel(BodyRegion region) {
    final current = _regionScores[region.id] ?? EasiRegionScore(regionId: region.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _EasiPanel(
        region: region,
        initial: current,
        allScores: _regionScores,
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
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Log'),
            Tab(text: 'History'),
            Tab(text: 'Compare'),
            Tab(text: 'Heatmap'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildLogTab(), _buildHistoryTab(), _buildCompareTab(), _buildHeatmapTab()],
      ),
    );
  }

  // ─── Log Tab ──────────────────────────────────────────────────────────────
  Widget _buildLogTab() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date / time
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 15),
                label: Text(DateFormat('dd MMM yyyy').format(_date)),
                onPressed: _pickDate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 15),
                label: Text('${_time.format(context)} ${localTimezone()}'),
                onPressed: _pickTime,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Body view toggle
          Center(
            child: SegmentedButton<EczemaBodyView>(
              segments: const [
                ButtonSegment(value: EczemaBodyView.front, label: Text('Front')),
                ButtonSegment(value: EczemaBodyView.back, label: Text('Back')),
              ],
              selected: {_bodyView},
              onSelectionChanged: (s) => setState(() => _bodyView = s.first),
            ),
          ),
          const SizedBox(height: 6),

          // Instruction
          Row(children: [
            Icon(Icons.touch_app_outlined, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('Tap body zone → score EASI attributes',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 4),

          // Body map
          Card(
            clipBehavior: Clip.hardEdge,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: EczemaBodyMap(
                view: _bodyView,
                regionScores: _regionScores,
                activeZoneId: _activeZoneId,
                onZoneTap: _onZoneTap,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const EczemaSeverityLegend(compact: true),

          // Scored zone chips
          if (_regionScores.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: _regionScores.entries.map((e) {
                final region = findRegion(e.key);
                final lbl = region?.label ?? e.key;
                final contribution = e.value.easiContribution(groupForRegion(e.key));
                final color = _easiColor(contribution * 3);
                return InputChip(
                  label: Text('$lbl  ${contribution.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 11)),
                  backgroundColor: color.withValues(alpha: 0.10),
                  side: BorderSide(color: color.withValues(alpha: 0.4)),
                  onDeleted: () => setState(() => _regionScores.remove(e.key)),
                  onPressed: () { if (region != null) _showEasiPanel(region); },
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 14),

          // EASI breakdown card
          _EasiBreakdownCard(scores: _regionScores),

          const SizedBox(height: 10),

          // Pruritus VAS
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Pruritus (Itch) VAS',
                      style: Theme.of(context).textTheme.titleSmall),
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
                  onChanged: (v) => setState(() => _itchVas = v.round()),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('None', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('Worst imaginable', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
              ]),
            ),
          ),

          const SizedBox(height: 8),

          // Sleep disruption
          Card(
            child: Column(children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('Sleep disrupted by itch', style: TextStyle(fontSize: 14)),
                value: _sleepDisrupted,
                onChanged: (v) => setState(() => _sleepDisrupted = v),
              ),
              if (_sleepDisrupted)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    Text('Hours lost: ${_sleepHoursLost.toStringAsFixed(1)}h',
                        style: const TextStyle(fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: _sleepHoursLost, min: 0, max: 8, divisions: 16,
                        onChanged: (v) => setState(() => _sleepHoursLost = v),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),

          const SizedBox(height: 8),

          // Triggers expansion
          Card(
            child: ExpansionTile(
              title: Row(children: [
                const Text('Triggers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (_trigCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$_trigCount selected',
                        style: const TextStyle(fontSize: 10, color: Colors.orange)),
                  ),
              ]),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _trigSection('Environmental', [
                      _TrigChip('New detergent', _trigNewDetergent, (v) => setState(() => _trigNewDetergent = v)),
                      _TrigChip('New fabric', _trigNewFabric, (v) => setState(() => _trigNewFabric = v)),
                      _TrigChip('Dust', _trigDust, (v) => setState(() => _trigDust = v)),
                      _TrigChip('Pet contact', _trigPet, (v) => setState(() => _trigPet = v)),
                      _TrigChip('Chlorine / pool', _trigChlorine, (v) => setState(() => _trigChlorine = v)),
                    ]),
                    _trigSection('Food', [
                      _TrigChip('Dairy', _trigDairy, (v) => setState(() => _trigDairy = v)),
                      _TrigChip('Eggs', _trigEggs, (v) => setState(() => _trigEggs = v)),
                      _TrigChip('Nuts', _trigNuts, (v) => setState(() => _trigNuts = v)),
                      _TrigChip('Wheat', _trigWheat, (v) => setState(() => _trigWheat = v)),
                      _TrigChip('Soy', _trigSoy, (v) => setState(() => _trigSoy = v)),
                      _TrigChip('Citrus', _trigCitrus, (v) => setState(() => _trigCitrus = v)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Text('Stress level: ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: _stressLevel.toDouble(), min: 0, max: 10, divisions: 10,
                          label: '$_stressLevel',
                          onChanged: (v) => setState(() => _stressLevel = v.round()),
                        ),
                      ),
                      Container(
                        width: 28,
                        alignment: Alignment.center,
                        child: Text('$_stressLevel',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ]),
                  ]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Treatment expansion
          Card(
            child: ExpansionTile(
              title: Row(children: [
                const Text('Treatment Today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (_txCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$_txCount applied',
                        style: const TextStyle(fontSize: 10, color: Colors.green)),
                  ),
              ]),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Moisturizer applied', style: TextStyle(fontSize: 13)),
                      value: _txMoisturizer,
                      onChanged: (v) => setState(() => _txMoisturizer = v ?? false),
                    ),
                    if (_txMoisturizer)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 6),
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Moisturizer type / brand',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => _txMoistType = v,
                        ),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Topical steroid cream', style: TextStyle(fontSize: 13)),
                      value: _txSteroid,
                      onChanged: (v) => setState(() => _txSteroid = v ?? false),
                    ),
                    if (_txSteroid)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 6),
                        child: Wrap(spacing: 6, children: ['mild', 'moderate', 'potent'].map((s) =>
                          ChoiceChip(
                            label: Text(s[0].toUpperCase() + s.substring(1),
                                style: const TextStyle(fontSize: 11)),
                            selected: _txSteroidStrength == s,
                            onSelected: (_) => setState(() => _txSteroidStrength = s),
                          ),
                        ).toList()),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Antihistamine', style: TextStyle(fontSize: 13)),
                      value: _txAntihistamine,
                      onChanged: (v) => setState(() => _txAntihistamine = v ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Wet wrap therapy', style: TextStyle(fontSize: 13)),
                      value: _txWetWrap,
                      onChanged: (v) => setState(() => _txWetWrap = v ?? false),
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
              labelText: 'Notes (optional — additional observations)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_editingId != null ? 'Update Log' : 'Save Assessment'),
              onPressed: _saving ? null : _submit,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  int get _trigCount => [
    _trigNewDetergent, _trigNewFabric, _trigDust, _trigPet, _trigChlorine,
    _trigDairy, _trigEggs, _trigNuts, _trigWheat, _trigSoy, _trigCitrus,
  ].where((b) => b).length;

  int get _txCount => [_txMoisturizer, _txSteroid, _txAntihistamine, _txWetWrap]
      .where((b) => b).length;

  Widget _trigSection(String title, List<Widget> chips) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600,
                fontWeight: FontWeight.w600)),
      ),
      Wrap(spacing: 6, runSpacing: 4, children: chips),
    ],
  );

  // ─── History Tab ────────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    final person = ref.watch(selectedPersonProvider);
    final logsAsync = ref.watch(eczemaProvider('$person:$_historyDays'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
              ],
              selected: {_historyDays},
              onSelectionChanged: (s) => setState(() => _historyDays = s.first),
            ),
            const Spacer(),
            logsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (logs) => logs.isEmpty
                  ? const SizedBox.shrink()
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('Export PDF'),
                      onPressed: () => _exportPdf(logs),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
            ),
          ]),
        ),
        Expanded(
          child: logsAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (logs) {
              if (logs.isEmpty) {
                return const Center(child: Text('No eczema logs yet'));
              }
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
                            _editLog(log);
                            return false;
                          }
                          return _confirmDelete(ctx);
                        },
                        onDismissed: (dir) async {
                          if (dir == DismissDirection.endToStart) await _deleteLog(log.id);
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
      ],
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

              // Comparison widget
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
  Widget _buildHeatmapTab() {
    final person = ref.watch(selectedPersonProvider);
    final heatAsync = ref.watch(eczemaHeatmapProvider('$person:$_heatmapDays'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
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
                    Center(
                      child: SegmentedButton<EczemaBodyView>(
                        segments: const [
                          ButtonSegment(value: EczemaBodyView.front, label: Text('Front')),
                          ButtonSegment(value: EczemaBodyView.back, label: Text('Back')),
                        ],
                        selected: {_bodyView},
                        onSelectionChanged: (s) => setState(() => _bodyView = s.first),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      clipBehavior: Clip.hardEdge,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: EczemaBodyMap(
                          view: _bodyView,
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
  final void Function(EasiRegionScore) onConfirm;
  final VoidCallback onRemove;
  final VoidCallback onDismiss;

  const _EasiPanel({
    required this.region,
    required this.initial,
    required this.allScores,
    required this.onConfirm,
    required this.onRemove,
    required this.onDismiss,
  });

  @override
  State<_EasiPanel> createState() => _EasiPanelState();
}

class _EasiPanelState extends State<_EasiPanel> {
  late int _erythema, _papulation, _excoriation, _lichenification, _areaScore;

  @override
  void initState() {
    super.initState();
    _erythema = widget.initial.erythema;
    _papulation = widget.initial.papulation;
    _excoriation = widget.initial.excoriation;
    _lichenification = widget.initial.lichenification;
    _areaScore = widget.initial.areaScore;
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

  static const _areaLabels = ['<1%', '1–9%', '10–29%', '30–49%', '50–69%', '≥70%'];
  static const _attrLabels = ['None', 'Slight', 'Moderate', 'Severe'];

  @override
  Widget build(BuildContext context) {
    final total = _totalEasi;
    final groupColor = _easiColor(_regional * 2);

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 4, height: 40,
                decoration: BoxDecoration(color: groupColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.region.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${widget.region.group.label}  ·  multiplier ×${widget.region.group.multiplier}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ])),
              IconButton(icon: const Icon(Icons.close), onPressed: () {
                Navigator.pop(context);
                widget.onDismiss();
              }),
            ]),
            const Divider(height: 16),

            // Area affected
            Text('Area Affected', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: List.generate(6, (i) {
              final val = i + 1;
              return ChoiceChip(
                label: Text(_areaLabels[i], style: const TextStyle(fontSize: 11)),
                selected: _areaScore == val,
                onSelected: (_) => setState(() => _areaScore = val),
              );
            })),
            const SizedBox(height: 14),

            // EASI attributes
            _AttributeRow(label: 'Erythema', hint: 'Redness / discolouration',
                value: _erythema, attrLabels: _attrLabels,
                onChanged: (v) => setState(() => _erythema = v)),
            _AttributeRow(label: 'Papulation', hint: 'Thickness / induration',
                value: _papulation, attrLabels: _attrLabels,
                onChanged: (v) => setState(() => _papulation = v)),
            _AttributeRow(label: 'Excoriation', hint: 'Scratch marks / erosion',
                value: _excoriation, attrLabels: _attrLabels,
                onChanged: (v) => setState(() => _excoriation = v)),
            _AttributeRow(label: 'Lichenification', hint: 'Skin thickening / leathering',
                value: _lichenification, attrLabels: _attrLabels,
                onChanged: (v) => setState(() => _lichenification = v)),

            const Divider(height: 12),

            // Running score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _easiColor(total).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Text('Region: ${_regional.toStringAsFixed(2)}',
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
                  ));
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Attribute row ────────────────────────────────────────────────────────────

class _AttributeRow extends StatelessWidget {
  final String label, hint;
  final int value;
  final List<String> attrLabels;
  final void Function(int) onChanged;

  const _AttributeRow({
    required this.label, required this.hint, required this.value,
    required this.attrLabels, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(hint, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 6, children: List.generate(4, (i) => ChoiceChip(
          label: Text(attrLabels[i], style: const TextStyle(fontSize: 11)),
          selected: value == i,
          onSelected: (_) => onChanged(i),
        ))),
      ]),
    );
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
