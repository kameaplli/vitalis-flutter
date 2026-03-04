import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../providers/eczema_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/eczema_log.dart';
import '../core/timezone_util.dart';

// ─── SVG viewport ─────────────────────────────────────────────────────────────
const double _svgW = 440.0;
const double _svgH = 500.0;

// ─── Zone data ────────────────────────────────────────────────────────────────

class _ZoneData {
  final String id;
  final String label;
  final Rect rect; // in SVG coordinate space
  final bool isEllipse;

  const _ZoneData(this.id, this.label, this.rect, {this.isEllipse = false});

  Offset get centroid => rect.center;

  bool contains(Offset svgPt) {
    if (isEllipse) {
      final dx = (svgPt.dx - centroid.dx) / (rect.width / 2);
      final dy = (svgPt.dy - centroid.dy) / (rect.height / 2);
      return dx * dx + dy * dy <= 1.0;
    }
    return rect.contains(svgPt);
  }
}

// Zone rectangles mirror the SVG element positions in body_map.svg
const _kZones = <_ZoneData>[
  // ── FRONT ──────────────────────────────────────────────────────────────────
  _ZoneData('f_head',        'Head (Front)',      Rect.fromLTWH(88,  12, 44, 52), isEllipse: true),
  _ZoneData('f_neck',        'Neck (Front)',      Rect.fromLTWH(102, 63, 16, 12)),
  _ZoneData('f_shoulder_r',  'R. Shoulder (F)',   Rect.fromLTWH(69,  72, 26, 16), isEllipse: true),
  _ZoneData('f_shoulder_l',  'L. Shoulder (F)',   Rect.fromLTWH(125, 72, 26, 16), isEllipse: true),
  _ZoneData('f_chest_r',     'R. Chest',          Rect.fromLTWH(103, 75, 15, 30)),
  _ZoneData('f_chest_l',     'L. Chest',          Rect.fromLTWH(118, 75, 15, 30)),
  _ZoneData('f_abdomen_r',   'R. Abdomen',        Rect.fromLTWH(103,105, 15, 33)),
  _ZoneData('f_abdomen_l',   'L. Abdomen',        Rect.fromLTWH(118,105, 15, 33)),
  _ZoneData('f_lower_abd',   'Lower Abdomen',     Rect.fromLTWH(106,138, 24, 17)),
  _ZoneData('f_upper_arm_r', 'R. Upper Arm',      Rect.fromLTWH(68,  76, 15, 42)),
  _ZoneData('f_upper_arm_l', 'L. Upper Arm',      Rect.fromLTWH(137, 76, 15, 42)),
  _ZoneData('f_elbow_r',     'R. Elbow (F)',      Rect.fromLTWH(69, 116, 16, 12), isEllipse: true),
  _ZoneData('f_elbow_l',     'L. Elbow (F)',      Rect.fromLTWH(135,116, 16, 12), isEllipse: true),
  _ZoneData('f_forearm_r',   'R. Forearm',        Rect.fromLTWH(67, 127, 18, 41)),
  _ZoneData('f_forearm_l',   'L. Forearm',        Rect.fromLTWH(133,127, 18, 41)),
  _ZoneData('f_hand_r',      'R. Hand (Front)',   Rect.fromLTWH(63, 168, 24, 20)),
  _ZoneData('f_hand_l',      'L. Hand (Front)',   Rect.fromLTWH(133,168, 24, 20)),
  _ZoneData('f_thigh_r',     'R. Thigh (Front)',  Rect.fromLTWH(103,155, 15, 45)),
  _ZoneData('f_thigh_l',     'L. Thigh (Front)',  Rect.fromLTWH(119,155, 15, 45)),
  _ZoneData('f_knee_r',      'R. Knee (Front)',   Rect.fromLTWH(102,198, 16, 16), isEllipse: true),
  _ZoneData('f_knee_l',      'L. Knee (Front)',   Rect.fromLTWH(118,198, 16, 16), isEllipse: true),
  _ZoneData('f_shin_r',      'R. Shin',           Rect.fromLTWH(101,214, 17, 46)),
  _ZoneData('f_shin_l',      'L. Shin',           Rect.fromLTWH(118,214, 17, 46)),
  _ZoneData('f_foot_r',      'R. Foot (Front)',   Rect.fromLTWH(100,261, 18, 14)),
  _ZoneData('f_foot_l',      'L. Foot (Front)',   Rect.fromLTWH(120,261, 18, 14)),

  // ── BACK ───────────────────────────────────────────────────────────────────
  _ZoneData('b_head',         'Head (Back)',       Rect.fromLTWH(308, 12, 44, 52), isEllipse: true),
  _ZoneData('b_neck',         'Neck (Back)',       Rect.fromLTWH(322, 63, 16, 12)),
  _ZoneData('b_shoulder_r',   'R. Shoulder (B)',   Rect.fromLTWH(289, 72, 26, 16), isEllipse: true),
  _ZoneData('b_shoulder_l',   'L. Shoulder (B)',   Rect.fromLTWH(345, 72, 26, 16), isEllipse: true),
  _ZoneData('b_upper_back_r', 'R. Upper Back',     Rect.fromLTWH(323, 75, 15, 33)),
  _ZoneData('b_upper_back_l', 'L. Upper Back',     Rect.fromLTWH(338, 75, 15, 33)),
  _ZoneData('b_mid_back_r',   'R. Mid Back',       Rect.fromLTWH(323,108, 15, 30)),
  _ZoneData('b_mid_back_l',   'L. Mid Back',       Rect.fromLTWH(338,108, 15, 30)),
  _ZoneData('b_lower_back',   'Lower Back',        Rect.fromLTWH(323,138, 28, 17)),
  _ZoneData('b_buttock_r',    'R. Buttock',        Rect.fromLTWH(323,155, 15, 30)),
  _ZoneData('b_buttock_l',    'L. Buttock',        Rect.fromLTWH(338,155, 15, 30)),
  _ZoneData('b_upper_arm_r',  'R. Upper Arm (B)',  Rect.fromLTWH(289, 76, 14, 44)),
  _ZoneData('b_upper_arm_l',  'L. Upper Arm (B)',  Rect.fromLTWH(357, 76, 14, 44)),
  _ZoneData('b_elbow_r',      'R. Elbow (B)',      Rect.fromLTWH(289,116, 16, 12), isEllipse: true),
  _ZoneData('b_elbow_l',      'L. Elbow (B)',      Rect.fromLTWH(355,116, 16, 12), isEllipse: true),
  _ZoneData('b_forearm_r',    'R. Forearm (B)',    Rect.fromLTWH(287,127, 18, 41)),
  _ZoneData('b_forearm_l',    'L. Forearm (B)',    Rect.fromLTWH(353,127, 18, 41)),
  _ZoneData('b_hand_r',       'R. Hand (Back)',    Rect.fromLTWH(283,168, 24, 20)),
  _ZoneData('b_hand_l',       'L. Hand (Back)',    Rect.fromLTWH(353,168, 24, 20)),
  _ZoneData('b_thigh_r',      'R. Thigh (Back)',   Rect.fromLTWH(323,185, 15, 33)),
  _ZoneData('b_thigh_l',      'L. Thigh (Back)',   Rect.fromLTWH(338,185, 15, 33)),
  _ZoneData('b_knee_r',       'R. Knee (Back)',    Rect.fromLTWH(322,216, 16, 16), isEllipse: true),
  _ZoneData('b_knee_l',       'L. Knee (Back)',    Rect.fromLTWH(338,216, 16, 16), isEllipse: true),
  _ZoneData('b_calf_r',       'R. Calf',           Rect.fromLTWH(321,232, 17, 40)),
  _ZoneData('b_calf_l',       'L. Calf',           Rect.fromLTWH(338,232, 17, 40)),
  _ZoneData('b_foot_r',       'R. Foot (Back)',    Rect.fromLTWH(320,273, 18, 14)),
  _ZoneData('b_foot_l',       'L. Foot (Back)',    Rect.fromLTWH(340,273, 18, 14)),
];

_ZoneData? _findZone(String id) {
  try {
    return _kZones.firstWhere((z) => z.id == id);
  } catch (_) {
    return null;
  }
}

// ─── Colour helper ────────────────────────────────────────────────────────────

Color _heatColor(int level) {
  if (level <= 2) return const Color(0xFF4CAF50);
  if (level <= 4) return const Color(0xFF8BC34A);
  if (level <= 6) return const Color(0xFFFFC107);
  if (level <= 8) return const Color(0xFFFF5722);
  return const Color(0xFFF44336);
}

// ─── Heat-map overlay painter ─────────────────────────────────────────────────

class _HeatPainter extends CustomPainter {
  final Map<String, int> areas;
  final String? activeId;

  const _HeatPainter(this.areas, this.activeId);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _svgW;
    final sy = size.height / _svgH;

    for (final zone in _kZones) {
      final level = areas[zone.id];
      final isActive = zone.id == activeId;
      if (level == null && !isActive) continue;

      final zoneRect = Rect.fromLTWH(
        zone.rect.left * sx,
        zone.rect.top * sy,
        zone.rect.width * sx,
        zone.rect.height * sy,
      );

      if (level != null) {
        final color = _heatColor(level);
        final fill = Paint()..color = color.withValues(alpha: 0.62);
        if (zone.isEllipse) {
          canvas.drawOval(zoneRect, fill);
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(zoneRect, const Radius.circular(3)),
            fill,
          );
        }
      }

      if (isActive) {
        final ringColor = level != null ? _heatColor(level) : Colors.blue;
        final ring = Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        if (zone.isEllipse) {
          canvas.drawOval(zoneRect, ring);
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(zoneRect, const Radius.circular(3)),
            ring,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeatPainter old) =>
      old.areas != areas || old.activeId != activeId;
}

// ─── Interactive body map ─────────────────────────────────────────────────────

class _BodyMap extends StatelessWidget {
  final Map<String, int> areas;
  final String? activeId;
  final void Function(String id, String label) onTap;

  const _BodyMap({
    required this.areas,
    required this.activeId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      final h = w * (_svgH / _svgW);
      return SizedBox(
        width: w,
        height: h,
        child: GestureDetector(
          onTapDown: (det) {
            final svgX = det.localPosition.dx * (_svgW / w);
            final svgY = det.localPosition.dy * (_svgH / h);
            final pt = Offset(svgX, svgY);
            _ZoneData? hit;
            for (final zone in _kZones.reversed) {
              if (zone.contains(pt)) {
                hit = zone;
                break;
              }
            }
            if (hit != null) onTap(hit.id, hit.label);
          },
          child: Stack(children: [
            SvgPicture.asset(
              'assets/body_map.svg',
              width: w,
              height: h,
              fit: BoxFit.fill,
            ),
            CustomPaint(
              size: Size(w, h),
              painter: _HeatPainter(areas, activeId),
            ),
          ]),
        ),
      );
    });
  }
}

// ─── Zone severity panel ──────────────────────────────────────────────────────

class _ZonePanel extends StatefulWidget {
  final String id;
  final String label;
  final int initialLevel;
  final void Function(int level) onConfirm;
  final VoidCallback onRemove;
  final VoidCallback onDismiss;

  const _ZonePanel({
    super.key,
    required this.id,
    required this.label,
    required this.initialLevel,
    required this.onConfirm,
    required this.onRemove,
    required this.onDismiss,
  });

  @override
  State<_ZonePanel> createState() => _ZonePanelState();
}

class _ZonePanelState extends State<_ZonePanel> {
  late int _level;

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel > 0 ? widget.initialLevel : 5;
  }

  @override
  void didUpdateWidget(_ZonePanel old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _level = widget.initialLevel > 0 ? widget.initialLevel : 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _heatColor(_level);
    return Card(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      color: color.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onDismiss,
                visualDensity: VisualDensity.compact,
              ),
            ]),
            Row(children: [
              const Text('Itch level:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(10)),
                child: Text('$_level',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
            ]),
            Slider(
              value: _level.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: color,
              onChanged: (v) => setState(() => _level = v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.initialLevel > 0)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: widget.onRemove,
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: () => widget.onConfirm(_level),
                  child:
                      Text(widget.initialLevel > 0 ? 'Update' : 'Mark Area'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Main screen ──────────────────────────────────────────────────────────────

class EczemaScreen extends ConsumerStatefulWidget {
  const EczemaScreen({super.key});

  @override
  ConsumerState<EczemaScreen> createState() => _EczemaScreenState();
}

class _EczemaScreenState extends ConsumerState<EczemaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // History filter
  int _historyDays = 30;

  // Edit tracking (null = new entry)
  String? _editingId;

  // Form state
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  int _itchSeverity = 5;
  int _redness = 5;
  String _flare = 'mild';
  bool _sleepDisrupted = false;
  final _notesCtrl = TextEditingController();

  // Body map state
  final Map<String, int> _areas = {};
  String? _activeZoneId;
  String? _activeZoneLabel;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Submit (create or update) ─────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final person = ref.read(selectedPersonProvider);
      final areasJson =
          _areas.entries.map((e) => {'area': e.key, 'level': e.value}).toList();
      final data = {
        'log_date': DateFormat('yyyy-MM-dd').format(_date),
        'log_time': _time.format(context),
        'itch_severity': _itchSeverity,
        'redness_severity': _redness,
        'flare_intensity': _flare,
        'affected_areas': jsonEncode(areasJson),
        'sleep_disrupted': _sleepDisrupted,
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
      setState(() {
        _editingId = null;
        _areas.clear();
        _activeZoneId = null;
        _activeZoneLabel = null;
        _itchSeverity = 5;
        _redness = 5;
        _flare = 'mild';
        _sleepDisrupted = false;
        _notesCtrl.clear();
        _date = DateTime.now();
        _time = TimeOfDay.now();
      });
      ref.invalidate(eczemaProvider('${ref.read(selectedPersonProvider)}:$_historyDays'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Eczema log updated' : 'Eczema log saved')),
      );
      _tabs.animateTo(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  // ── Edit log (pre-populate form and switch to Log tab) ────────────────────

  void _editLog(EczemaLogSummary log) {
    setState(() {
      _editingId = log.id;
      _date = DateTime.tryParse(log.logDate) ?? DateTime.now();
      final timeParts = (log.logTime).split(':');
      _time = TimeOfDay(
        hour: int.tryParse(timeParts[0]) ?? 0,
        minute: int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0,
      );
      _itchSeverity = log.itchSeverity ?? 5;
      _redness = log.rednessSeverity ?? 5;
      _flare = log.flareIntensity ?? 'mild';
      _sleepDisrupted = log.sleepDisrupted ?? false;
      _notesCtrl.text = log.notes ?? '';
      _areas.clear();
      _areas.addAll(log.parsedAreas);
      _activeZoneId = null;
      _activeZoneLabel = null;
    });
    _tabs.animateTo(0);
  }

  // ── Delete log ────────────────────────────────────────────────────────────

  Future<void> _deleteLog(String id) async {
    try {
      await apiClient.dio.delete('${ApiConstants.eczema}/$id');
      ref.invalidate(eczemaProvider('${ref.read(selectedPersonProvider)}:$_historyDays'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Confirm delete dialog ─────────────────────────────────────────────────

  Future<bool> _confirmDelete(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete entry?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete')),
          ],
        ),
      ) ??
      false;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId != null ? 'Edit Eczema Log' : 'Eczema Tracker'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Log'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildLogTab(), _buildHistoryTab()],
      ),
    );
  }

  // ── Log tab ───────────────────────────────────────────────────────────────

  Widget _buildLogTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date/time row
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(DateFormat('dd MMM yyyy').format(_date)),
                onPressed: _pickDate,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 16),
                label: Text('${_time.format(context)} ${localTimezone()}'),
                onPressed: _pickTime,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Body map ────────────────────────────────────────────────────
          Text(
            'Tap to mark affected areas',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Card(
            clipBehavior: Clip.hardEdge,
            child: _BodyMap(
              areas: _areas,
              activeId: _activeZoneId,
              onTap: (id, label) =>
                  setState(() {
                    _activeZoneId = id;
                    _activeZoneLabel = label;
                  }),
            ),
          ),

          // Zone panel (slides in when a zone is active)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _activeZoneId != null
                ? _ZonePanel(
                    key: ValueKey(_activeZoneId),
                    id: _activeZoneId!,
                    label: _activeZoneLabel ?? _activeZoneId!,
                    initialLevel: _areas[_activeZoneId!] ?? 0,
                    onConfirm: (level) => setState(() {
                      _areas[_activeZoneId!] = level;
                      _activeZoneId = null;
                      _activeZoneLabel = null;
                    }),
                    onRemove: () => setState(() {
                      _areas.remove(_activeZoneId!);
                      _activeZoneId = null;
                      _activeZoneLabel = null;
                    }),
                    onDismiss: () => setState(() {
                      _activeZoneId = null;
                      _activeZoneLabel = null;
                    }),
                  )
                : const SizedBox.shrink(),
          ),

          // Marked areas chips
          if (_areas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _areas.entries.map((e) {
                final color = _heatColor(e.value);
                final label = _findZone(e.key)?.label ?? e.key;
                return InputChip(
                  label: Text('$label  ${e.value}/10',
                      style: const TextStyle(fontSize: 11)),
                  backgroundColor: color.withValues(alpha: 0.15),
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  onDeleted: () => setState(() => _areas.remove(e.key)),
                  onPressed: () => setState(() {
                    _activeZoneId = e.key;
                    _activeZoneLabel = label;
                  }),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),

          // ── Overall severity ─────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Severity',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  _SeverityRow(
                    label: 'Itch',
                    value: _itchSeverity,
                    onChanged: (v) => setState(() => _itchSeverity = v),
                  ),
                  const SizedBox(height: 4),
                  _SeverityRow(
                    label: 'Redness',
                    value: _redness,
                    onChanged: (v) => setState(() => _redness = v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Flare intensity + sleep ───────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Flare & Sleep',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: ['none', 'mild', 'moderate', 'severe'].map((v) {
                      return ChoiceChip(
                        label:
                            Text(v[0].toUpperCase() + v.substring(1)),
                        selected: _flare == v,
                        onSelected: (_) => setState(() => _flare = v),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sleep disrupted by itch',
                        style: TextStyle(fontSize: 14)),
                    value: _sleepDisrupted,
                    onChanged: (v) => setState(() => _sleepDisrupted = v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Notes ─────────────────────────────────────────────────────────
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (triggers, treatments…)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),

          const SizedBox(height: 16),

          // ── Submit ────────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_editingId != null ? 'Update Log' : 'Save Log'),
              onPressed: _saving ? null : _submit,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── History tab ───────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    final person = ref.watch(selectedPersonProvider);
    final logsAsync = ref.watch(eczemaProvider('$person:$_historyDays'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
              ],
              selected: {_historyDays},
              onSelectionChanged: (s) =>
                  setState(() => _historyDays = s.first),
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
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(children: [
                      Icon(Icons.swipe, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text('Swipe right to edit · left to delete',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400)),
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
                            color: Colors.blue,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 16),
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
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
                            if (dir == DismissDirection.endToStart) {
                              await _deleteLog(log.id);
                            }
                          },
                          child: _HistoryCard(log: log),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Severity row widget ──────────────────────────────────────────────────────

class _SeverityRow extends StatelessWidget {
  final String label;
  final int value;
  final void Function(int) onChanged;

  const _SeverityRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = _heatColor(value);
    return Row(children: [
      SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 13))),
      Expanded(
        child: Slider(
          value: value.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: color,
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
      Container(
        width: 32,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Text('$value',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ),
    ]);
  }
}

// ─── History card ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final EczemaLogSummary log;

  const _HistoryCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final areas = log.parsedAreas;
    final flare = log.flareIntensity ?? '—';
    final flareColor = flare == 'severe'
        ? Colors.red
        : flare == 'moderate'
            ? Colors.orange
            : flare == 'mild'
                ? Colors.amber
                : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text('${log.logDate}  ${log.logTime}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: flareColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: flareColor.withValues(alpha: 0.5)),
                ),
                child: Text(flare,
                    style: TextStyle(fontSize: 11, color: flareColor)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _SeverityBadge('Itch', log.itchSeverity),
              const SizedBox(width: 8),
              _SeverityBadge('Redness', log.rednessSeverity),
              if (log.sleepDisrupted == true) ...[
                const SizedBox(width: 8),
                const Chip(
                  label: Text('Sleep disrupted',
                      style: TextStyle(fontSize: 10)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Color(0xFFFFF3E0),
                ),
              ],
            ]),
            if (areas.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: areas.entries.map((e) {
                  final color = _heatColor(e.value);
                  return Chip(
                    label: Text(
                        '${_findZone(e.key)?.label ?? e.key}  ${e.value}/10',
                        style: const TextStyle(fontSize: 10)),
                    backgroundColor: color.withValues(alpha: 0.15),
                    side: BorderSide(color: color.withValues(alpha: 0.4)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
            if (log.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(log.notes!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String label;
  final int? value;

  const _SeverityBadge(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    final color = _heatColor(value!);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label:',
          style: const TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(width: 3),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Text('$value',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ),
    ]);
  }
}
