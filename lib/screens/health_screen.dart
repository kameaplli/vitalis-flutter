import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/health_provider.dart';
import '../providers/selected_person_provider.dart';
import '../widgets/person_selector.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../services/notification_service.dart';
import '../widgets/medical_disclaimer.dart';

// ─── Shared swipeable list ────────────────────────────────────────────────────

class _HealthList extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> logsAsync;
  final Widget Function(Map<String, dynamic>) itemBuilder;
  final void Function(BuildContext, WidgetRef) onAdd;
  final void Function(BuildContext, WidgetRef, Map<String, dynamic>)? onEdit;
  final Future<void> Function(WidgetRef, String) onDelete;
  final Widget Function()? headerBuilder;

  const _HealthList({
    required this.logsAsync,
    required this.itemBuilder,
    required this.onAdd,
    required this.onDelete,
    this.onEdit,
    this.headerBuilder,
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
        error: (e, _) => const Center(child: Text('Something went wrong. Pull to refresh.')),
        data: (entries) {
          if (entries.isEmpty && headerBuilder == null) {
            return const Center(
                child: Text('No entries yet. Tap + to add.'));
          }
          return CustomScrollView(
            slivers: [
              if (headerBuilder != null)
                SliverToBoxAdapter(child: headerBuilder!()),
              if (entries.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No entries yet. Tap + to add.')),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                    child: Row(children: [
                      Icon(Icons.swipe, size: 12, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(width: 4),
                      Text('Swipe right to edit · left to delete',
                          style: TextStyle(
                              fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                    ]),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final item = entries[i];
                      final id = item['id']?.toString() ?? '$i';
                      return Dismissible(
                        key: Key(id),
                        direction: DismissDirection.horizontal,
                        dismissThresholds: const {
                          DismissDirection.startToEnd: 0.3,
                          DismissDirection.endToStart: 0.3,
                        },
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
                    childCount: entries.length,
                  ),
                ),
              ],
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
  static const _days = 30;

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final key    = '$person:$_days';

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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(symptomsProvider);
            ref.invalidate(medicationsProvider);
            ref.invalidate(supplementsProvider);
            ref.invalidate(moodProvider);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: GridView.builder(
              itemCount: cards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, i) => _HealthCard(
                def: cards[i],
                index: i,
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
  final int index;
  final VoidCallback onTap;
  const _HealthCard({required this.def, required this.index, required this.onTap});

  @override
  State<_HealthCard> createState() => _HealthCardState();
}

class _HealthCardState extends State<_HealthCard>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    // Staggered entrance
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entryAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOutBack,
    );
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _entryCtrl.forward();
    });

    // Subtle breathing
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final def = widget.def;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final entryCount = def.logsAsync.whenOrNull(data: (list) => list.length);
    final badge = entryCount != null && entryCount > 0 ? '$entryCount' : null;

    return ScaleTransition(
      scale: _entryAnim,
      child: FadeTransition(
        opacity: _entryAnim,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            final p = _pulseAnim.value;

            return GestureDetector(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDark
                          ? cs.surface
                          : Colors.white,
                      def.color.withValues(alpha: 0.06 + p * 0.04),
                    ],
                  ),
                  border: Border.all(
                    color: def.color.withValues(alpha: 0.12 + p * 0.06),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: def.color.withValues(alpha: 0.08 + p * 0.04),
                      blurRadius: 10 + p * 4,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Accent dot top-right
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 6 + p * 2,
                        height: 6 + p * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: def.color.withValues(alpha: 0.25 + p * 0.15),
                        ),
                      ),
                    ),
                    // Badge
                    if (badge != null)
                      Positioned(
                        top: 8,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: def.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(badge,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: def.color)),
                        ),
                      ),
                    // Center content
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: 1.0 + p * 0.04,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      def.color.withValues(alpha: 0.18 + p * 0.08),
                                      def.color.withValues(alpha: 0.04),
                                    ],
                                    radius: 0.85,
                                  ),
                                ),
                                child: Icon(def.icon, color: def.color, size: 30),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              def.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? cs.onSurface : Colors.grey.shade800,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Insight widgets (computed from local data, no extra API calls) ───────────

class _InsightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InsightChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _SymptomInsights extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> logsAsync;
  const _SymptomInsights({required this.logsAsync});

  @override
  Widget build(BuildContext context) {
    final entries = logsAsync.valueOrNull ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    // Compute stats
    final total = entries.length;
    final severities = entries.map((e) => (e['severity'] as num?)?.toDouble() ?? 0).toList();
    final avgSeverity = severities.isEmpty ? 0.0 : severities.reduce((a, b) => a + b) / severities.length;

    // Most common symptom
    final freq = <String, int>{};
    for (final e in entries) {
      final t = (e['symptom_type'] ?? '') as String;
      if (t.isNotEmpty) freq[t] = (freq[t] ?? 0) + 1;
    }
    final sortedSymptoms = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topSymptom = sortedSymptoms.isNotEmpty ? sortedSymptoms.first.key : '—';

    // High severity count (>= 7)
    final highSev = severities.where((s) => s >= 7).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _InsightChip(
                icon: Icons.numbers, label: 'Total', value: '$total',
                color: const Color(0xFFE53935),
              )),
              const SizedBox(width: 8),
              Expanded(child: _InsightChip(
                icon: Icons.speed, label: 'Avg severity', value: avgSeverity.toStringAsFixed(1),
                color: const Color(0xFFFF9800),
              )),
              const SizedBox(width: 8),
              Expanded(child: _InsightChip(
                icon: Icons.warning_amber_rounded, label: 'Severe', value: '$highSev',
                color: const Color(0xFFD32F2F),
              )),
            ],
          ),
          if (sortedSymptoms.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: sortedSymptoms.take(5).map((e) => Chip(
                avatar: Text('${e.value}x', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                label: Text(e.key, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
          ] else if (topSymptom != '—') ...[
            const SizedBox(height: 6),
            Text('Most common: $topSymptom', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
          const Divider(height: 16),
        ],
      ),
    );
  }
}

class _MedicationInsights extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> logsAsync;
  const _MedicationInsights({required this.logsAsync});

  @override
  Widget build(BuildContext context) {
    final entries = logsAsync.valueOrNull ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    final active = entries.where((e) => e['is_active'] == true).length;
    final inactive = entries.length - active;

    // Group by frequency
    final freqMap = <String, int>{};
    for (final e in entries) {
      if (e['is_active'] == true) {
        final f = (e['frequency'] ?? 'unknown') as String;
        freqMap[f] = (freqMap[f] ?? 0) + 1;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _InsightChip(
                icon: Icons.check_circle, label: 'Active', value: '$active',
                color: const Color(0xFF43A047),
              )),
              const SizedBox(width: 8),
              Expanded(child: _InsightChip(
                icon: Icons.pause_circle, label: 'Stopped', value: '$inactive',
                color: const Color(0xFF9E9E9E),
              )),
              const SizedBox(width: 8),
              Expanded(child: _InsightChip(
                icon: Icons.medication_rounded, label: 'Total', value: '${entries.length}',
                color: const Color(0xFF1E88E5),
              )),
            ],
          ),
          if (freqMap.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: freqMap.entries.map((e) => Chip(
                avatar: Text('${e.value}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                label: Text(e.key, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
          ],
          const Divider(height: 16),
        ],
      ),
    );
  }
}

class _SupplementInsights extends ConsumerStatefulWidget {
  final String personKey;
  final Set<String> loggedThisSession;
  final void Function(String id) onLogged;
  const _SupplementInsights({
    required this.personKey,
    required this.loggedThisSession,
    required this.onLogged,
  });

  @override
  ConsumerState<_SupplementInsights> createState() => _SupplementInsightsState();
}

class _SupplementInsightsState extends ConsumerState<_SupplementInsights> {

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(supplementsProvider(widget.personKey)).valueOrNull ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    final active = entries.where((e) => e['is_active'] == true).toList();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // Merge backend state with local session state for immediate feedback
    final logged = widget.loggedThisSession;
    final takenToday = active.where((e) {
      final id = e['id']?.toString() ?? '';
      return e['last_intake_date'] == today || logged.contains(id);
    }).length;
    final remaining = active.where((e) {
      final id = e['id']?.toString() ?? '';
      return e['last_intake_date'] != today && !logged.contains(id);
    }).toList();
    final total = active.length;
    final allDone = total > 0 && takenToday >= total;

    // Calculate total remaining doses across all active supplements with end dates
    int? totalRemainingDoses;
    final todayDate = DateTime.now();
    for (final s in active) {
      final endStr = s['end_date'] as String?;
      if (endStr != null && endStr.isNotEmpty) {
        final end = DateTime.tryParse(endStr);
        if (end != null && end.isAfter(todayDate)) {
          totalRemainingDoses = (totalRemainingDoses ?? 0) + end.difference(todayDate).inDays;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Today score ────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                allDone ? Icons.check_circle : Icons.pending,
                color: allDone ? Colors.green : Colors.amber.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '$takenToday / $total taken today',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: allDone ? Colors.green.shade700 : Colors.amber.shade800,
                ),
              ),
              if (totalRemainingDoses != null) ...[
                const SizedBox(width: 8),
                Text(
                  '· $totalRemainingDoses doses left',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),

          // ── Remaining — tap to log ───────────────────────────────────
          if (remaining.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Tap to log:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: remaining.map((e) => ActionChip(
                avatar: Icon(Icons.add_circle_outline, size: 16, color: Colors.teal.shade700),
                label: Text(
                  e['supplement_name'] ?? '',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.teal.shade900),
                ),
                backgroundColor: Colors.teal.shade50,
                side: BorderSide(color: Colors.teal.shade300),
                onPressed: () => _logIntake(e),
              )).toList(),
            ),
          ],
          if (allDone && total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('All done for today!', style: TextStyle(fontSize: 12, color: Colors.green.shade600, fontWeight: FontWeight.w500)),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _logIntake(Map<String, dynamic> e) async {
    final id = e['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      final res = await apiClient.dio.post(
        ApiConstants.supplementLogIntake(id),
      );
      final data = res.data as Map<String, dynamic>;
      if (!mounted) return;

      final nutrients = data['nutrients_matched'] as int? ?? 0;
      final msg = data['already_logged'] == true
          ? '${e['supplement_name']} already logged today'
          : 'Logged ${e['supplement_name']} ($nutrients nutrients tracked)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700, duration: const Duration(seconds: 2)),
      );

      // Immediate local state update — chip disappears instantly
      widget.onLogged(id);

      // Also refresh provider for persistence / "not taken" text in the list below
      ref.invalidate(supplementsProvider(widget.personKey));
      ref.invalidate(supplementsCatalogProvider);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    }
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
    final logsAsync = ref.watch(symptomsProvider(personKey));
    return _HealthList(
      logsAsync: logsAsync,
      headerBuilder: () => _SymptomInsights(logsAsync: logsAsync),
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
    final logsAsync = ref.watch(medicationsProvider(personKey));
    return _HealthList(
      logsAsync: logsAsync,
      headerBuilder: () => _MedicationInsights(logsAsync: logsAsync),
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

class _SupplementsTab extends ConsumerStatefulWidget {
  final String personKey;
  const _SupplementsTab({super.key, required this.personKey});

  @override
  ConsumerState<_SupplementsTab> createState() => _SupplementsTabState();
}

class _SupplementsTabState extends ConsumerState<_SupplementsTab> {
  static const _forms = ['Tablet', 'Capsule', 'Liquid', 'Powder', 'Gummy', 'Softgel', 'Drops'];

  /// IDs logged this session — shared with _SupplementInsights for instant UI feedback
  final _loggedThisSession = <String>{};

  String get personKey => widget.personKey;

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(supplementsProvider(personKey));
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context, ref),
        child: const Icon(Icons.add),
      ),
      body: logsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Something went wrong. Pull to refresh.')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No supplements yet. Tap + to add.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
            children: [
              // ── Today score + quick-log ───────────────────────────────
              _SupplementInsights(
                personKey: personKey,
                loggedThisSession: _loggedThisSession,
                onLogged: (id) => setState(() => _loggedThisSession.add(id)),
              ),

              // ── All supplements list ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text('All Supplements', style: Theme.of(context).textTheme.titleSmall),
              ),
              ...entries.map((item) {
                final isActive = item['is_active'] == true;
                final itemId = item['id']?.toString() ?? '';
                final takenToday = item['last_intake_date'] == today || _loggedThisSession.contains(itemId);
                final name = item['supplement_name'] ?? '';
                final subtitle = [
                  if (item['dosage'] != null && (item['dosage'] as String).isNotEmpty) item['dosage'],
                  if (item['frequency'] != null && (item['frequency'] as String).isNotEmpty) item['frequency'],
                ].join(' · ');
                final id = item['id']?.toString() ?? '';

                return Dismissible(
                  key: Key(id),
                  direction: DismissDirection.horizontal,
                  dismissThresholds: const {
                    DismissDirection.startToEnd: 0.3,
                    DismissDirection.endToStart: 0.3,
                  },
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
                      _showForm(context, ref, item: item);
                      return false;
                    }
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete supplement?'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                        ],
                      ),
                    ) ?? false;
                  },
                  onDismissed: (dir) async {
                    if (dir == DismissDirection.endToStart) {
                      await apiClient.dio.delete('${ApiConstants.supplements}/$id');
                      ref.invalidate(supplementsProvider(personKey));
                      ref.invalidate(supplementsCatalogProvider);
                    }
                  },
                  child: ListTile(
                    leading: SizedBox(
                      width: 32, height: 32,
                      child: Checkbox(
                        value: isActive,
                        activeColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (_) async {
                          await apiClient.dio.put(
                              '${ApiConstants.supplements}/$id/toggle');
                          ref.invalidate(supplementsProvider(personKey));
                          ref.invalidate(supplementsCatalogProvider);
                        },
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isActive ? null : Colors.grey,
                        decoration: isActive ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: subtitle.isNotEmpty
                        ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                        : null,
                    trailing: isActive
                        ? (takenToday
                            ? Icon(Icons.check_circle, color: Colors.green.shade400, size: 22)
                            : Text('not taken', style: TextStyle(fontSize: 11, color: Colors.orange.shade400)))
                        : Text('off', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    onTap: () => _showForm(context, ref, item: item),
                  ),
                );
              }),

              // Swipe hint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Swipe right to edit · left to delete · tap checkbox to toggle tracking',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ],
          );
        },
      ),
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

  static const _courseDurations = <String, int?>{
    'No end date': null,
    '1 week': 7,
    '2 weeks': 14,
    '3 weeks': 21,
    '1 month': 30,
    '2 months': 60,
    '3 months': 90,
    '6 months': 180,
  };

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
    String? selectedCourse = source['end_date'] != null ? 'custom' : 'No end date';
    String? endDate = source['end_date'];
    bool enableReminder = source['reminder_enabled'] == true;
    String reminderTime = source['reminder_time'] ?? '09:00';

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
                const SizedBox(height: 8),
                // Course duration
                DropdownButtonFormField<String>(
                  value: selectedCourse,
                  decoration: const InputDecoration(labelText: 'Course duration'),
                  items: _courseDurations.keys.map((k) => DropdownMenuItem(
                      value: k, child: Text(k))).toList(),
                  onChanged: (v) {
                    ss(() {
                      selectedCourse = v;
                      final days = _courseDurations[v];
                      if (days != null) {
                        final end = DateTime.now().add(Duration(days: days));
                        endDate = end.toIso8601String().substring(0, 10);
                      } else {
                        endDate = null;
                      }
                    });
                  },
                ),
                if (endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Ends: $endDate',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
                const SizedBox(height: 8),
                // Reminder toggle
                SwitchListTile(
                  title: const Text('Daily reminder', style: TextStyle(fontSize: 14)),
                  subtitle: enableReminder
                      ? Text('At $reminderTime', style: const TextStyle(fontSize: 12))
                      : null,
                  value: enableReminder,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => ss(() => enableReminder = v),
                ),
                if (enableReminder)
                  InkWell(
                    onTap: () async {
                      final parts = reminderTime.split(':');
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                      );
                      if (picked != null) {
                        ss(() => reminderTime = _timeStr(picked));
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Reminder time',
                        isDense: true,
                        suffixIcon: Icon(Icons.access_time, size: 18),
                      ),
                      child: Text(reminderTime),
                    ),
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
                  'end_date': endDate,
                  'family_member_id': famId,
                  'reminder_enabled': enableReminder,
                  'reminder_time': enableReminder ? reminderTime : null,
                };
                if (isEdit) {
                  await apiClient.dio.put(
                      '${ApiConstants.supplements}/${item['id']}',
                      data: data);
                } else {
                  await apiClient.dio.post(
                      ApiConstants.supplements, data: data);
                }
                ref.invalidate(supplementsProvider(personKey));
                ref.invalidate(supplementsCatalogProvider);
                // Persist and schedule supplement reminder
                final supId = isEdit ? item['id'].toString() : nameCtrl.text;
                if (enableReminder) {
                  await NotificationPrefs.addSupplementReminder(
                    supplementId: supId,
                    name: nameCtrl.text,
                    time: reminderTime,
                    endDate: endDate,
                  );
                } else {
                  await NotificationPrefs.removeSupplementReminder(supId);
                }
                await NotificationService.scheduleAll();
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
    // Use the shared catalogue (all family members) for the search list
    final catalogAsync = ref.watch(supplementsCatalogProvider);
    final allSupplements = catalogAsync.valueOrNull ?? [];
    // Current person's supplements for quick-log
    final personSupsAsync = ref.watch(supplementsProvider(widget.personKey));
    final personSupplements = personSupsAsync.valueOrNull ?? [];

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
          // Quick-log: active supplements for this person not yet taken today
          Builder(builder: (_) {
            final today = DateTime.now().toIso8601String().substring(0, 10);
            final quickLog = personSupplements
                .where((s) => s['is_active'] == true && s['last_intake_date'] != today)
                .toList();
            if (quickLog.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quick log:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: quickLog.take(10).map((s) => ActionChip(
                      avatar: Icon(Icons.add_circle, size: 16, color: Colors.green.shade600),
                      label: Text(s['supplement_name'] ?? '', style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.green.shade50,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () async {
                        final id = s['id']?.toString() ?? '';
                        if (id.isEmpty) return;
                        try {
                          final res = await apiClient.dio.post(ApiConstants.supplementLogIntake(id));
                          final data = res.data as Map<String, dynamic>;
                          if (context.mounted) {
                            final nutrients = data['nutrients_matched'] as int? ?? 0;
                            final msg = data['already_logged'] == true
                                ? '${s['supplement_name']} already logged today'
                                : 'Logged ${s['supplement_name']} ($nutrients nutrients)';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700, duration: const Duration(seconds: 2)),
                            );
                            ref.invalidate(supplementsProvider(widget.personKey));
                            ref.invalidate(supplementsCatalogProvider);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Something went wrong. Please try again.')));
                          }
                        }
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                ],
              ),
            );
          }),
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
      ref.invalidate(supplementsCatalogProvider);
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
          const SnackBar(content: Text('Product not found. Try entering manually.'), duration: Duration(seconds: 3)),
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
      body: Column(
        children: [
          Expanded(child: body),
          const MedicalDisclaimer(),
        ],
      ),
    );
  }
}
