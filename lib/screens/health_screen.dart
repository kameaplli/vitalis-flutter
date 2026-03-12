import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
      _CardDef('symptoms',    'Symptoms',    Icons.thermostat_rounded,       const Color(0xFFE53935),
          ref.watch(symptomsProvider(key))),
      _CardDef('medications', 'Medications', Icons.medical_services_rounded, const Color(0xFF1E88E5),
          ref.watch(medicationsProvider('$person:7'))),
      _CardDef('supplements', 'Supplements', Icons.science_rounded,         const Color(0xFFF9A825),
          ref.watch(supplementsProvider('$person:7'))),
      _CardDef('mood',        'Mood',        Icons.self_improvement_rounded, const Color(0xFF43A047),
          ref.watch(moodProvider(key))),
      _CardDef('weight',      'Weight',      Icons.fitness_center_rounded,   const Color(0xFF8E24AA),
          const AsyncValue.data([])),
      _CardDef('eczema',      'Eczema',      Icons.dry_rounded,             const Color(0xFF00897B),
          const AsyncValue.data([])),
      _CardDef('skin-photos', 'Skin Photos', Icons.photo_camera_rounded,    const Color(0xFF6D4C41),
          const AsyncValue.data([])),
      _CardDef('products',    'Products',    Icons.local_pharmacy_rounded,   const Color(0xFF3949AB),
          const AsyncValue.data([])),
      _CardDef('insights',    'Insights',    Icons.auto_awesome_rounded,     const Color(0xFF5E35B1),
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

class _HealthCard extends StatefulWidget {
  final _CardDef def;
  final VoidCallback onTap;
  const _HealthCard({required this.def, required this.onTap});

  @override
  State<_HealthCard> createState() => _HealthCardState();
}

class _HealthCardState extends State<_HealthCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final def = widget.def;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final entryCount = def.logsAsync.whenOrNull(data: (list) => list.length);
    final subtitle = entryCount != null
        ? (entryCount == 0
            ? 'No entries'
            : '$entryCount entr${entryCount == 1 ? 'y' : 'ies'}')
        : null;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        final pulse = _pulseAnim.value;
        final glowOpacity = 0.08 + (pulse * 0.07);
        final iconScale = 1.0 + (pulse * 0.06);

        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          elevation: 1 + (pulse * 1.5),
          shadowColor: def.color.withValues(alpha: 0.3),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark ? cs.surface : Colors.white,
                  def.color.withValues(alpha: glowOpacity),
                ],
              ),
            ),
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: iconScale,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              def.color.withValues(alpha: 0.20 + pulse * 0.1),
                              def.color.withValues(alpha: 0.08),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: def.color.withValues(alpha: 0.18 + pulse * 0.12),
                              blurRadius: 12 + (pulse * 6),
                              spreadRadius: pulse * 2,
                            ),
                          ],
                        ),
                        child: Icon(def.icon, color: def.color, size: 36),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      def.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
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
          ),
        );
      },
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

// ─── Supplements ─────────────────────────────────────────────────────────────

class _SupplementsTab extends ConsumerWidget {
  final String personKey;
  const _SupplementsTab({super.key, required this.personKey});

  static const _forms = ['Tablet', 'Capsule', 'Liquid', 'Powder', 'Gummy', 'Softgel', 'Drops'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _HealthList(
      logsAsync: ref.watch(supplementsProvider(personKey)),
      itemBuilder: (item) => ListTile(
        leading: const Icon(Icons.spa_rounded, color: Colors.amber),
        title: Text(item['supplement_name'] ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text([
              if (item['brand'] != null && (item['brand'] as String).isNotEmpty) item['brand'],
              if (item['dosage'] != null && (item['dosage'] as String).isNotEmpty) item['dosage'],
              if (item['frequency'] != null && (item['frequency'] as String).isNotEmpty) item['frequency'],
            ].join(' · ')),
            if (item['last_intake_date'] != null || (item['intake_count'] ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    if (item['last_intake_date'] != null) 'Last: ${item['last_intake_date']}',
                    if ((item['intake_count'] ?? 0) > 0) '${item['intake_count']}x taken',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
              tooltip: 'Log intake today',
              onPressed: () async {
                final id = item['id']?.toString() ?? '';
                if (id.isEmpty) return;
                try {
                  final res = await apiClient.dio.post(
                    ApiConstants.supplementLogIntake(id),
                  );
                  final data = res.data as Map<String, dynamic>;
                  if (context.mounted) {
                    final nutrients = data['nutrients_matched'] as int? ?? 0;
                    final msg = data['already_logged'] == true
                        ? '${item['supplement_name']} already logged today'
                        : 'Logged ${item['supplement_name']} intake ($nutrients nutrients tracked)';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    // Refresh supplement list to show updated intake count
                    ref.invalidate(supplementsProvider(personKey));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              },
            ),
            Switch(
              value: item['is_active'] == true,
              onChanged: (_) async {
                await apiClient.dio.put(
                    '${ApiConstants.supplements}/${item['id']}/toggle');
                ref.invalidate(supplementsProvider);
              },
            ),
          ],
        ),
      ),
      onAdd: (ctx, ref) => _showAddOptions(ctx, ref),
      onEdit: (ctx, ref, item) => _showForm(ctx, ref, item: item),
      onDelete: (ref, id) async {
        await apiClient.dio.delete('${ApiConstants.supplements}/$id');
        ref.invalidate(supplementsProvider);
      },
    );
  }

  void _showAddOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SupplementSearchSheet(
        personKey: personKey,
        onSelect: (prefill) => _showForm(context, ref, prefill: prefill),
        onBarcode: () => _showBarcodeScanner(context, ref),
        onManual: () => _showForm(context, ref),
      ),
    );
  }

  void _showBarcodeScanner(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: _SupplementBarcodeScanner(
          onScanned: (barcode, productName, brand, {String? servingSize}) {
            Navigator.pop(ctx);
            _showForm(context, ref, prefill: {
              'supplement_name': productName ?? '',
              'brand': brand ?? '',
              'barcode': barcode,
              if (servingSize != null) 'dosage': servingSize,
            });
          },
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? item, Map<String, dynamic>? prefill}) {
    final isEdit = item != null;
    final source = prefill ?? item ?? {};
    final nameCtrl = TextEditingController(
        text: source['supplement_name'] ?? '');
    final brandCtrl = TextEditingController(
        text: source['brand'] ?? '');
    final dosageCtrl = TextEditingController(
        text: source['dosage'] ?? '');
    final freqCtrl = TextEditingController(
        text: source['frequency'] ?? '');
    String selectedForm = source['form'] ?? '';
    String selectedPerson = isEdit
        ? (item['family_member_id'] ?? 'self')
        : ref.read(selectedPersonProvider);
    final barcode = source['barcode'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(isEdit ? 'Edit Supplement' : 'Add Supplement'),
          content: SingleChildScrollView(
            child: Column(
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
                        labelText: 'Supplement name')),
                const SizedBox(height: 8),
                TextField(
                    controller: brandCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Brand (optional)')),
                const SizedBox(height: 8),
                TextField(
                    controller: dosageCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Dosage (e.g. 1000mg)')),
                const SizedBox(height: 8),
                TextField(
                    controller: freqCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Frequency (e.g. Once daily)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedForm.isEmpty ? null : selectedForm,
                  decoration: const InputDecoration(labelText: 'Form'),
                  items: _forms.map((f) => DropdownMenuItem(
                      value: f.toLowerCase(), child: Text(f))).toList(),
                  onChanged: (v) => ss(() => selectedForm = v ?? ''),
                ),
                if (barcode.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Barcode: $barcode',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
                final data = {
                  'supplement_name': nameCtrl.text,
                  'brand': brandCtrl.text,
                  'dosage': dosageCtrl.text,
                  'frequency': freqCtrl.text,
                  'form': selectedForm,
                  'barcode': barcode,
                  'start_date': isEdit
                      ? (item['start_date'] ?? _todayStr())
                      : _todayStr(),
                  'family_member_id': famId,
                };
                if (isEdit) {
                  await apiClient.dio.put(
                      '${ApiConstants.supplements}/${item['id']}',
                      data: data);
                } else {
                  await apiClient.dio.post(
                      ApiConstants.supplements, data: data);
                }
                ref.invalidate(supplementsProvider);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Supplement search sheet (searches previously logged supplements) ─────────

class _SupplementSearchSheet extends ConsumerStatefulWidget {
  final String personKey;
  final void Function(Map<String, dynamic> prefill) onSelect;
  final VoidCallback onBarcode;
  final VoidCallback onManual;
  const _SupplementSearchSheet({
    required this.personKey,
    required this.onSelect,
    required this.onBarcode,
    required this.onManual,
  });
  @override
  ConsumerState<_SupplementSearchSheet> createState() => _SupplementSearchSheetState();
}

class _SupplementSearchSheetState extends ConsumerState<_SupplementSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final supplementsAsync = ref.watch(supplementsProvider(widget.personKey));
    final allSupplements = supplementsAsync.valueOrNull ?? [];

    // Deduplicate by supplement_name (case-insensitive) — show unique supplements
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final s in allSupplements) {
      final key = (s['supplement_name'] as String? ?? '').toLowerCase();
      if (key.isNotEmpty && seen.add(key)) unique.add(s);
    }

    // Filter by query
    final filtered = _query.isEmpty ? unique : unique.where((s) {
      final name = (s['supplement_name'] as String? ?? '').toLowerCase();
      final brand = (s['brand'] as String? ?? '').toLowerCase();
      return name.contains(_query) || brand.contains(_query);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search supplements...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          // Quick actions row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () { Navigator.pop(context); widget.onBarcode(); },
                  icon: const Icon(Icons.qr_code_scanner, size: 16),
                  label: const Text('Scan Barcode', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  onPressed: () { Navigator.pop(context); widget.onManual(); },
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Enter Manually', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showImportBrand(context),
                  icon: const Icon(Icons.cloud_download_outlined, size: 16),
                  label: const Text('Import Brand', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: unique.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.spa_outlined, size: 48, color: cs.primary.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text('No supplements logged yet',
                            style: TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        Text('Scan a barcode or add manually to get started',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('No match for "$_query"',
                                style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          final name = s['supplement_name'] as String? ?? '';
                          final brand = s['brand'] as String? ?? '';
                          final dosage = s['dosage'] as String? ?? '';
                          final form = s['form'] as String? ?? '';
                          final subtitle = [brand, dosage, form].where((e) => e.isNotEmpty).join(' · ');
                          return ListTile(
                            leading: const Icon(Icons.spa_outlined, color: Colors.amber),
                            title: Text(name),
                            subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
                            trailing: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelect({
                                'supplement_name': name,
                                'brand': brand,
                                'dosage': dosage,
                                'frequency': s['frequency'] ?? '',
                                'form': form,
                                'barcode': s['barcode'] ?? '',
                              });
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showImportBrand(BuildContext context) {
    final brandCtrl = TextEditingController();
    final majorBrands = [
      'Nature Made', 'NOW Foods', "Nature's Bounty", 'Garden of Life',
      'Centrum', 'One A Day', 'Kirkland Signature', 'Nordic Naturals',
      'Solgar', 'MegaFood', 'Thorne', 'Pure Encapsulations',
      'Life Extension', 'Jarrow Formulas', "Doctor's Best", 'Swanson',
      'GNC', 'Spring Valley', 'Natrol',
    ];
    String? selectedBrand;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Import Supplements'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import all common supplements from a brand. '
                    'Uses AI to find supplement facts online.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: brandCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Brand name',
                      hintText: 'e.g. Nature Made',
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (v) => ss(() => selectedBrand = null),
                  ),
                  const SizedBox(height: 12),
                  const Text('Or select a major brand:',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: majorBrands.map((b) => ChoiceChip(
                      label: Text(b, style: const TextStyle(fontSize: 11)),
                      selected: selectedBrand == b,
                      onSelected: (sel) {
                        ss(() {
                          selectedBrand = sel ? b : null;
                          brandCtrl.text = sel ? b : '';
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final brand = brandCtrl.text.trim();
                if (brand.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a brand name')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _runBrandImport(brand);
              },
              icon: const Icon(Icons.cloud_download, size: 18),
              label: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runBrandImport(String brand) async {
    // Show non-blocking snackbar so user can navigate away
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Text('Importing $brand supplements in background...')),
          ],
        ),
        duration: const Duration(seconds: 60),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Close the bottom sheet so user can use the app
    if (context.mounted) Navigator.of(context).pop();

    try {
      final res = await apiClient.dio.post(
        ApiConstants.supplementImportBrand,
        data: {'brand': brand},
      );

      messenger.hideCurrentSnackBar();

      final data = res.data as Map<String, dynamic>;

      if (data['success'] == false) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Import failed for $brand'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      final imported = data['imported'] ?? 0;
      final existing = data['existing'] ?? 0;
      final found = data['found'] ?? 0;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$brand: $found found, $imported imported, $existing already in DB',
          ),
          backgroundColor: imported > 0 ? Colors.green.shade700 : null,
          duration: const Duration(seconds: 4),
        ),
      );

      // Refresh supplement list
      ref.invalidate(supplementsProvider);
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Import failed: $e'), duration: const Duration(seconds: 3)),
      );
    }
  }
}

class _SupplementBarcodeScanner extends ConsumerStatefulWidget {
  final void Function(String barcode, String? productName, String? brand, {String? servingSize}) onScanned;
  const _SupplementBarcodeScanner({required this.onScanned});
  @override
  ConsumerState<_SupplementBarcodeScanner> createState() => _SupplementBarcodeScannerState();
}

class _SupplementBarcodeScannerState extends ConsumerState<_SupplementBarcodeScanner> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _processing = false;
  String _status = 'Point camera at a barcode';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _lookupBarcode(code);
  }

  Future<void> _lookupBarcode(String code) async {
    if (_processing) return;
    setState(() { _processing = true; _status = 'Looking up product...'; });
    _ctrl.stop();

    // Try Open Food Facts with UPC-A/EAN-13 variants
    final variants = <String>[code];
    if (code.length == 12) variants.add('0$code');
    if (code.length == 13 && code.startsWith('0')) variants.add(code.substring(1));

    String? productName;
    String? brand;
    bool found = false;

    for (final variant in variants) {
      try {
        final dio = Dio();
        dio.options.headers['User-Agent'] = 'Vitalis/3.0 (vitalis-health-app)';
        final res = await dio.get(
          'https://world.openfoodfacts.org/api/v2/product/$variant',
        );
        final data = res.data as Map<String, dynamic>;
        if (data['status'] == 'product_found' || data['status'] == 1) {
          final p = data['product'] as Map<String, dynamic>?;
          productName = p?['product_name'] as String?;
          brand = p?['brands'] as String?;
          found = true;
          break;
        }
      } catch (_) {}
    }

    if (found && mounted) {
      widget.onScanned(code, productName, brand);
    } else if (mounted) {
      // Product not found in OpenFoodFacts — offer online AI search
      _showNotFoundOptions(code);
    }
  }

  void _showNotFoundOptions(String barcode) {
    setState(() { _processing = false; _status = 'Point camera at a barcode'; });
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: $barcode', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            const Text('Not found in product databases. How would you like to proceed?', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _ctrl.start();
            },
            child: const Text('Scan Again'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onScanned(barcode, null, null);
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Enter Manually'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showSupplementWebLookup(barcode);
            },
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search Online'),
          ),
        ],
      ),
    );
  }

  void _showSupplementWebLookup(String barcode) {
    final nameCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Supplement Online'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: $barcode', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            const Text('Enter the supplement details to search:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Supplement name *',
                hintText: 'e.g. Multivitamin, Vitamin D3 5000 IU',
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: brandCtrl,
              decoration: const InputDecoration(
                labelText: 'Brand (optional)',
                hintText: 'e.g. Nature Made, NOW Foods',
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _ctrl.start(); },
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a supplement name')),
                );
                return;
              }
              Navigator.pop(ctx);
              _performSupplementLookup(
                name: name,
                brand: brandCtrl.text.trim().isNotEmpty ? brandCtrl.text.trim() : null,
                barcode: barcode,
              );
            },
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSupplementLookup({
    required String name,
    String? brand,
    String? barcode,
  }) async {
    setState(() { _processing = true; _status = 'Searching online for supplement info...'; });

    try {
      final res = await apiClient.dio.post(ApiConstants.supplementLookup, data: {
        'name': name,
        'brand': brand,
        'barcode': barcode,
      });

      final data = res.data as Map<String, dynamic>;

      if (data['success'] != true) {
        if (mounted) {
          setState(() { _processing = false; _status = 'Point camera at a barcode'; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Supplement not found'), duration: const Duration(seconds: 3)),
          );
          widget.onScanned(barcode ?? '', null, null);
        }
        return;
      }

      if (mounted) {
        setState(() { _processing = false; _status = 'Point camera at a barcode'; });
        _showSupplementConfirmation(data, barcode);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _processing = false; _status = 'Point camera at a barcode'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: ${e.toString().length > 80 ? '${e.toString().substring(0, 80)}...' : e}'), duration: const Duration(seconds: 3)),
        );
        widget.onScanned(barcode ?? '', null, null);
      }
    }
  }

  void _showSupplementConfirmation(Map<String, dynamic> data, String? barcode) {
    final ingredients = (data['ingredients'] as List<dynamic>?) ?? [];
    final supplementName = data['supplement_name'] ?? 'Unknown Supplement';
    final brandName = data['brand'] ?? '';
    final servingSize = data['serving_size'] ?? '1 serving';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(supplementName, style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (brandName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Brand: $brandName', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  ),
                Text('Serving: $servingSize', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                const Text('Supplement Facts:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Divider(height: 12),
                if (ingredients.isEmpty)
                  const Text('No ingredients found', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ...ingredients.map<Widget>((ing) {
                  final ingMap = ing as Map<String, dynamic>;
                  final ingName = ingMap['name'] ?? '';
                  final amount = ingMap['amount'];
                  final unit = ingMap['unit'] ?? '';
                  final dv = ingMap['daily_value_percent'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(ingName, style: const TextStyle(fontSize: 13))),
                        if (amount != null)
                          Text('$amount $unit', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        if (dv != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text('${dv.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ),
                      ],
                    ),
                  );
                }),
                if (data['other_ingredients'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Other: ${data['other_ingredients']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              // Save the supplement to DB first so nutrients are stored
              try {
                await apiClient.dio.post(ApiConstants.supplementSave, data: data);
              } catch (_) {}
              // Pass the AI-found data back to supplement form with serving info
              widget.onScanned(
                barcode ?? '',
                data['supplement_name'] as String?,
                data['brand'] as String?,
                servingSize: data['serving_size'] as String?,
              );
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Use This'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (_processing)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              if (_processing) const SizedBox(width: 8),
              Text(_processing ? _status : 'Scan Supplement Barcode',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        Expanded(
          child: _processing
              ? const Center(child: CircularProgressIndicator())
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    controller: _ctrl,
                    onDetect: _onDetect,
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextButton.icon(
            onPressed: () {
              _showManualBarcode();
            },
            icon: const Icon(Icons.keyboard),
            label: const Text('Enter barcode manually'),
          ),
        ),
      ],
    );
  }

  void _showManualBarcode() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Barcode'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Barcode number'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (ctrl.text.isNotEmpty) {
                _lookupBarcode(ctrl.text);
              }
            },
            child: const Text('Look up'),
          ),
        ],
      ),
    );
  }
}

// ─── Mood ─────────────────────────────────────────────────────────────────────

class _MoodTab extends ConsumerWidget {
  final String personKey;
  const _MoodTab({super.key, required this.personKey});

  static const _moods = [
    // Positive / energized
    '😊 Happy',
    '🤩 Excited',
    '🔥 Pumped Up',
    '💪 Motivated',
    '🙏 Grateful',
    '💕 Loved',
    '😌 Calm',
    '🧘 Peaceful',
    // Neutral / mixed
    '😐 Neutral',
    '🤔 Confused',
    '😬 Nervous',
    '🧠 Focused',
    '😏 Horny',
    // Low energy / rest
    '😴 Sleepy',
    '🥱 Tired',
    '😮‍💨 Exhausted',
    // Negative / stressed
    '😔 Sad',
    '😰 Anxious',
    '😤 Stressed',
    '😠 Irritated',
    '🤯 Overwhelmed',
    '😞 Lonely',
    '😡 Angry',
    '😢 Frustrated',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _HealthList(
      logsAsync: ref.watch(moodProvider(personKey)),
      itemBuilder: (item) {
        // Display all moods if available, fallback to single mood
        final moodsList = item['moods'] as List<dynamic>?;
        final moodDisplay = moodsList != null && moodsList.isNotEmpty
            ? moodsList.join(', ')
            : (item['mood'] ?? '');
        return ListTile(
          leading: const Icon(Icons.sentiment_satisfied_alt,
              color: Colors.amber),
          title: Text(moodDisplay,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              'Score: ${item['score'] ?? '?'}/10  •  Energy: ${item['energy_level'] ?? '?'}'),
          trailing: Text(item['date'] ?? '',
              style: const TextStyle(fontSize: 11)),
        );
      },
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
    // Multi-mood support: initialize from moods array or fallback to single mood
    final Set<String> selectedMoods = {};
    if (isEdit) {
      final existingMoods = item['moods'] as List<dynamic>?;
      if (existingMoods != null && existingMoods.isNotEmpty) {
        for (final m in existingMoods) {
          final s = m.toString();
          if (_moods.contains(s)) selectedMoods.add(s);
        }
      }
      if (selectedMoods.isEmpty) {
        final single = item['mood'] ?? _moods[0];
        if (_moods.contains(single)) selectedMoods.add(single);
      }
    }
    if (selectedMoods.isEmpty) selectedMoods.add(_moods[0]);

    int score = isEdit ? (item['score'] as int? ?? 7) : 7;
    String selectedPerson = isEdit
        ? (item['family_member_id'] ?? 'self')
        : ref.read(selectedPersonProvider);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(isEdit ? 'Edit Mood' : 'How are you feeling?'),
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
                Text('Select all that apply:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _moods.map((m) {
                    final selected = selectedMoods.contains(m);
                    return FilterChip(
                      label: Text(m, style: const TextStyle(fontSize: 13)),
                      selected: selected,
                      onSelected: (val) {
                        ss(() {
                          if (val) {
                            selectedMoods.add(m);
                          } else if (selectedMoods.length > 1) {
                            selectedMoods.remove(m);
                          }
                        });
                      },
                      selectedColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      checkmarkColor: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
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
                final moodsList = selectedMoods.toList();
                final primaryMood = moodsList.first;
                final data = {
                  'mood': primaryMood,
                  'moods': moodsList,
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
      case 'supplements': return 'Supplements';
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
      case 'supplements': body = _SupplementsTab(key: ValueKey(key), personKey: key); break;
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
