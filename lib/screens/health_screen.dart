import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/health_provider.dart';
import '../providers/selected_person_provider.dart';
import '../widgets/person_selector.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

// ─── Shared swipeable list ────────────────────────────────────────────────────

class _HealthList extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> logsAsync;
  final Widget Function(Map<String, dynamic>) itemBuilder;
  final void Function(BuildContext, WidgetRef) onAdd;
  final void Function(BuildContext, WidgetRef, Map<String, dynamic>)? onEdit;
  final Future<void> Function(WidgetRef, String) onDelete;

  const _HealthList({
    required this.logsAsync,
    required this.itemBuilder,
    required this.onAdd,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => onAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: logsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
                child: Text('No entries yet. Tap + to add.'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
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
                  itemCount: entries.length,
                  itemBuilder: (ctx, i) {
                    final item = entries[i];
                    final id = item['id']?.toString() ?? '$i';
                    return Dismissible(
                      key: Key(id),
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
                        child:
                            const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (dir) async {
                        if (dir == DismissDirection.startToEnd) {
                          onEdit?.call(ctx, ref, item);
                          return false;
                        }
                        return _confirmDelete(ctx);
                      },
                      onDismissed: (dir) {
                        if (dir == DismissDirection.endToStart) {
                          onDelete(ref, id);
                        }
                      },
                      child: itemBuilder(item),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext ctx) async =>
      await showDialog<bool>(
            context: ctx,
            builder: (c) => AlertDialog(
              title: const Text('Delete?'),
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
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});
  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final key    = '$person:$_days';

    // Card definitions: (route-category, label, icon, color, provider)
    final cards = [
      _CardDef('symptoms',    'Symptoms',    Icons.sick_outlined,            Colors.red,
          ref.watch(symptomsProvider(key))),
      _CardDef('medications', 'Medications', Icons.medication_outlined,      Colors.blue,
          ref.watch(medicationsProvider('$person:7'))),
      _CardDef('mood',        'Mood',        Icons.mood_outlined,            Colors.green,
          ref.watch(moodProvider(key))),
      _CardDef('weight',      'Weight',      Icons.monitor_weight_outlined,  Colors.purple,
          const AsyncValue.data([])),
      _CardDef('eczema',      'Eczema',      Icons.healing_outlined,         Colors.teal,
          const AsyncValue.data([])),
      _CardDef('skin-photos', 'Skin Photos', Icons.camera_alt_outlined,     Colors.brown,
          const AsyncValue.data([])),
      _CardDef('products',    'Products',    Icons.inventory_2_outlined,     Colors.indigo,
          const AsyncValue.data([])),
      _CardDef('insights',    'Insights',    Icons.psychology_outlined,      Colors.deepPurple,
          const AsyncValue.data([])),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7,  label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
              style: ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 6)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (context, i) => _HealthCard(
            def: cards[i],
            onTap: () {
              final cat = cards[i].category;
              final route = cat == 'weight' ? '/health/weight'
                  : cat == 'eczema' ? '/health/eczema'
                  : cat == 'skin-photos' ? '/skin-photos'
                  : cat == 'products' ? '/products'
                  : cat == 'insights' ? '/insights'
                  : '/health/$cat';
              context.push(route);
            },
          ),
        ),
      ),
    );
  }
}

// ─── Card definition ──────────────────────────────────────────────────────────

class _CardDef {
  final String category;
  final String label;
  final IconData icon;
  final Color color;
  final AsyncValue<List<Map<String, dynamic>>> logsAsync;

  const _CardDef(this.category, this.label, this.icon, this.color, this.logsAsync);
}

// ─── Health category card ──────────────────────────────────────────────────────

class _HealthCard extends StatelessWidget {
  final _CardDef def;
  final VoidCallback onTap;
  const _HealthCard({required this.def, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final entryCount = def.logsAsync.whenOrNull(data: (list) => list.length);
    final subtitle   = entryCount != null
        ? (entryCount == 0 ? 'No entries' : '$entryCount entr${entryCount == 1 ? 'y' : 'ies'}')
        : null;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: def.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(def.icon, color: def.color, size: 22),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                ],
              ),
              const Spacer(),
              Text(
                def.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                )
              else
                SizedBox(
                  height: 12,
                  width: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: def.color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────────

TimeOfDay _nowTime() => TimeOfDay.now();
String _todayStr() =>
    DateTime.now().toIso8601String().substring(0, 10);
String _timeStr(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// ─── Symptoms ─────────────────────────────────────────────────────────────────

class _SymptomsTab extends ConsumerWidget {
  final String personKey;
  const _SymptomsTab({super.key, required this.personKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _HealthList(
      logsAsync: ref.watch(symptomsProvider(personKey)),
      itemBuilder: (item) => ListTile(
        leading: const Icon(Icons.sick_outlined, color: Colors.orange),
        title: Text(item['symptom_type'] ?? ''),
        subtitle: Text('Severity: ${item['severity'] ?? '?'}/10'
            '${item['notes'] != null && item['notes'].isNotEmpty ? "  •  ${item['notes']}" : ""}'),
        trailing: Text(item['date'] ?? '',
            style: const TextStyle(fontSize: 11)),
      ),
      onAdd: (ctx, ref) => _showForm(ctx, ref),
      onEdit: (ctx, ref, item) => _showForm(ctx, ref, item: item),
      onDelete: (ref, id) async {
        await apiClient.dio
            .delete('${ApiConstants.symptoms}/$id');
        ref.invalidate(symptomsProvider);
      },
    );
  }

  static const _commonSymptoms = [
    'Headache', 'Fever', 'Nausea', 'Fatigue', 'Cough',
    'Sore throat', 'Runny nose', 'Stomach pain', 'Back pain',
    'Joint pain', 'Skin rash', 'Itching', 'Dizziness',
  ];

  void _showForm(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? item}) {
    final isEdit = item != null;
    final typeCtrl =
        TextEditingController(text: isEdit ? item['symptom_type'] : '');
    final notesCtrl =
        TextEditingController(text: isEdit ? (item['notes'] ?? '') : '');
    int severity = isEdit ? (item['severity'] as int? ?? 5) : 5;
    String selectedPerson =
        isEdit ? (item['family_member_id'] ?? 'self') : ref.read(selectedPersonProvider);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(isEdit ? 'Edit Symptom' : 'Log Symptom'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PersonSelector(
                  selectedId: selectedPerson,
                  onChanged: (v) => ss(() => selectedPerson = v ?? 'self'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _commonSymptoms
                      .map((s) => ActionChip(
                            label: Text(s,
                                style: const TextStyle(fontSize: 11)),
                            onPressed: () => ss(() => typeCtrl.text = s),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Symptom type')),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Severity: '),
                  Expanded(
                    child: Slider(
                      value: severity.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$severity',
                      onChanged: (v) => ss(() => severity = v.round()),
                    ),
                  ),
                  Text('$severity'),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Any additional details…'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final famId =
                    selectedPerson == 'self' ? null : selectedPerson;
                final notes = notesCtrl.text.trim().isEmpty
                    ? null
                    : notesCtrl.text.trim();
                if (isEdit) {
                  await apiClient.dio.put(
                      '${ApiConstants.symptoms}/${item['id']}',
                      data: {
                        'symptom_type': typeCtrl.text,
                        'severity': severity,
                        'notes': notes,
                        'family_member_id': famId,
                      });
                } else {
                  await apiClient.dio.post(ApiConstants.symptoms,
                      data: {
                        'symptom_type': typeCtrl.text,
                        'severity': severity,
                        'notes': notes,
                        'date': _todayStr(),
                        'time': _timeStr(_nowTime()),
                        'family_member_id': famId,
                      });
                }
                ref.invalidate(symptomsProvider);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Medications ──────────────────────────────────────────────────────────────

class _MedicationsTab extends ConsumerWidget {
  final String personKey;
  const _MedicationsTab({super.key, required this.personKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _HealthList(
      logsAsync: ref.watch(medicationsProvider(personKey)),
      itemBuilder: (item) => ListTile(
        leading:
            const Icon(Icons.medication_outlined, color: Colors.blue),
        title: Text(item['medication_name'] ?? ''),
        subtitle: Text(
            '${item['dosage'] ?? ''} • ${item['frequency'] ?? ''}'),
        trailing: Switch(
          value: item['is_active'] == true,
          onChanged: (_) async {
            await apiClient.dio.put(
                '${ApiConstants.medications}/${item['id']}/toggle');
            ref.invalidate(medicationsProvider);
          },
        ),
      ),
      onAdd: (ctx, ref) => _showForm(ctx, ref),
      onEdit: (ctx, ref, item) => _showForm(ctx, ref, item: item),
      onDelete: (ref, id) async {
        await apiClient.dio
            .delete('${ApiConstants.medications}/$id');
        ref.invalidate(medicationsProvider);
      },
    );
  }

  void _showForm(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? item}) {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(
        text: isEdit ? item['medication_name'] : '');
    final dosageCtrl =
        TextEditingController(text: isEdit ? (item['dosage'] ?? '') : '');
    final freqCtrl = TextEditingController(
        text: isEdit ? (item['frequency'] ?? '') : '');
    String selectedPerson =
        isEdit ? (item['family_member_id'] ?? 'self') : ref.read(selectedPersonProvider);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(isEdit ? 'Edit Medication' : 'Add Medication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonSelector(
                selectedId: selectedPerson,
                onChanged: (v) => ss(() => selectedPerson = v ?? 'self'),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Medication name')),
              const SizedBox(height: 8),
              TextField(
                  controller: dosageCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Dosage')),
              const SizedBox(height: 8),
              TextField(
                  controller: freqCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Frequency')),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final famId =
                    selectedPerson == 'self' ? null : selectedPerson;
                if (isEdit) {
                  await apiClient.dio.put(
                      '${ApiConstants.medications}/${item['id']}',
                      data: {
                        'medication_name': nameCtrl.text,
                        'dosage': dosageCtrl.text,
                        'frequency': freqCtrl.text,
                        'start_date': item['start_date'] ?? _todayStr(),
                        'family_member_id': famId,
                      });
                } else {
                  await apiClient.dio
                      .post(ApiConstants.medications, data: {
                    'medication_name': nameCtrl.text,
                    'dosage': dosageCtrl.text,
                    'frequency': freqCtrl.text,
                    'start_date': _todayStr(),
                    'family_member_id': famId,
                  });
                }
                ref.invalidate(medicationsProvider);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mood ─────────────────────────────────────────────────────────────────────

class _MoodTab extends ConsumerWidget {
  final String personKey;
  const _MoodTab({super.key, required this.personKey});

  static const _moods = [
    '😊 Happy',
    '😐 Neutral',
    '😔 Sad',
    '😰 Anxious',
    '😤 Stressed',
    '😴 Tired',
    '🤗 Excited',
    '😪 Sleepy',
    '😏 Horny',
    '😌 Calm',
    '😠 Irritated',
    '🧠 Focused',
    '😕 Confused',
    '🙏 Grateful',
    '😤 Overwhelmed',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _HealthList(
      logsAsync: ref.watch(moodProvider(personKey)),
      itemBuilder: (item) => ListTile(
        leading: const Icon(Icons.sentiment_satisfied_alt,
            color: Colors.amber),
        title: Text(item['mood'] ?? ''),
        subtitle: Text(
            'Score: ${item['score'] ?? '?'}/10  •  Energy: ${item['energy_level'] ?? '?'}'),
        trailing: Text(item['date'] ?? '',
            style: const TextStyle(fontSize: 11)),
      ),
      onAdd: (ctx, ref) => _showForm(ctx, ref),
      onEdit: (ctx, ref, item) => _showForm(ctx, ref, item: item),
      onDelete: (ref, id) async {
        await apiClient.dio.delete('${ApiConstants.mood}/$id');
        ref.invalidate(moodProvider);
      },
    );
  }

  void _showForm(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? item}) {
    final isEdit = item != null;
    String selectedMood =
        isEdit ? (item['mood'] ?? _moods[0]) : _moods[0];
    // ensure selectedMood is in the list
    if (!_moods.contains(selectedMood)) selectedMood = _moods[0];
    int score = isEdit ? (item['score'] as int? ?? 7) : 7;
    String selectedPerson = isEdit
        ? (item['family_member_id'] ?? 'self')
        : ref.read(selectedPersonProvider);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(isEdit ? 'Edit Mood' : 'Log Mood'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonSelector(
                selectedId: selectedPerson,
                onChanged: (v) => ss(() => selectedPerson = v ?? 'self'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedMood,
                items: _moods
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) =>
                    ss(() => selectedMood = v ?? _moods[0]),
                decoration:
                    const InputDecoration(labelText: 'Mood'),
              ),
              Row(children: [
                const Text('Score: '),
                Expanded(
                  child: Slider(
                    value: score.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$score',
                    onChanged: (v) => ss(() => score = v.round()),
                  ),
                ),
                Text('$score'),
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final famId =
                    selectedPerson == 'self' ? null : selectedPerson;
                final data = {
                  'mood': selectedMood,
                  'score': score,
                  'date': _todayStr(),
                  'time': _timeStr(_nowTime()),
                  'family_member_id': famId,
                };
                if (isEdit) {
                  await apiClient.dio.put(
                      '${ApiConstants.mood}/${item['id']}',
                      data: data);
                } else {
                  await apiClient.dio
                      .post(ApiConstants.mood, data: data);
                }
                ref.invalidate(moodProvider);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Health sub-screen — wraps individual category tab in a full Scaffold ───────
// Used by /health/* routes pushed from the Health card grid (Sprint 4).

class HealthSubScreen extends ConsumerStatefulWidget {
  final String category;
  const HealthSubScreen({super.key, required this.category});

  @override
  ConsumerState<HealthSubScreen> createState() => _HealthSubScreenState();
}

class _HealthSubScreenState extends ConsumerState<HealthSubScreen> {
  int _days = 30;

  String get _title {
    switch (widget.category) {
      case 'symptoms':    return 'Symptoms';
      case 'medications': return 'Medications';
      case 'mood':        return 'Mood';
      default:            return widget.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final key    = '$person:$_days';

    Widget body;
    switch (widget.category) {
      case 'symptoms':    body = _SymptomsTab(key: ValueKey(key), personKey: key); break;
      case 'medications': body = _MedicationsTab(key: ValueKey(key), personKey: key); break;
      case 'mood':        body = _MoodTab(key: ValueKey(key), personKey: key); break;
      default:            body = Center(child: Text('Unknown: ${widget.category}')); break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7,  label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
                ButtonSegment(value: 90, label: Text('90d')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
              style: ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 4)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}
