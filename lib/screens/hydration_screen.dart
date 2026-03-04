import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hydration_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../widgets/circular_progress_ring.dart';
import '../core/timezone_util.dart';

const double _dailyGoalMl = 2500;

class HydrationScreen extends ConsumerStatefulWidget {
  const HydrationScreen({super.key});
  @override
  ConsumerState<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends ConsumerState<HydrationScreen> {
  bool _isSaving = false;
  final _quantityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedBeverage = 'water';
  TimeOfDay _selectedTime = TimeOfDay.now();

  String _timeStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final todayAsync = ref.watch(todayHydrationProvider(person));
    final presetsAsync = ref.watch(beveragePresetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Hydration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Progress ring
            todayAsync.when(
              skipLoadingOnReload: true,
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox(),
              data: (total) => Center(
                child: CircularProgressRing(
                  progress: (total / _dailyGoalMl).clamp(0, 1),
                  value: '${(total / 1000).toStringAsFixed(1)} L',
                  label: 'of ${(_dailyGoalMl / 1000).toStringAsFixed(1)} L goal',
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Quick-add presets
            presetsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (presets) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((p) => ActionChip(
                  avatar: Text(p.emoji),
                  label: Text('${p.name} (${p.defaultQuantity.toInt()} ml)'),
                  onPressed: () => _quickAdd(p.id, p.defaultQuantity),
                )).toList(),
              ),
            ),
            const SizedBox(height: 24),
            // Manual entry
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manual Entry', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedBeverage,
                      decoration: const InputDecoration(labelText: 'Beverage', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'water', child: Text('💧 Water')),
                        DropdownMenuItem(value: 'coffee', child: Text('☕ Coffee')),
                        DropdownMenuItem(value: 'tea', child: Text('🍵 Tea')),
                        DropdownMenuItem(value: 'milk', child: Text('🥛 Milk')),
                        DropdownMenuItem(value: 'juice', child: Text('🧃 Juice')),
                        DropdownMenuItem(value: 'other', child: Text('🥤 Other')),
                      ],
                      onChanged: (v) => setState(() => _selectedBeverage = v ?? 'water'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text('${_selectedTime.format(context)} ${localTimezone()}'),
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: context, initialTime: _selectedTime);
                        if (t != null) setState(() => _selectedTime = t);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _quantityCtrl,
                      decoration: const InputDecoration(labelText: 'Amount (ml)', suffixText: 'ml'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _logHydration,
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Log Hydration'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAdd(String beverage, double quantity) async {
    final person = ref.read(selectedPersonProvider);
    try {
      await apiClient.dio.post(ApiConstants.hydrationLog, data: {
        'beverage_type': beverage,
        'quantity': quantity,
        'time': _timeStr(TimeOfDay.now()),
        'date': DateTime.now().toIso8601String().substring(0, 10),
        if (person != 'self') 'family_member_id': person,
      });
      ref.invalidate(todayHydrationProvider(person));
      ref.invalidate(hydrationHistoryProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${quantity.toInt()} ml!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _logHydration() async {
    if (_quantityCtrl.text.isEmpty) return;
    final person = ref.read(selectedPersonProvider);
    setState(() => _isSaving = true);
    try {
      await apiClient.dio.post(ApiConstants.hydrationLog, data: {
        'beverage_type': _selectedBeverage,
        'quantity': double.parse(_quantityCtrl.text),
        'notes': _notesCtrl.text,
        'time': _timeStr(_selectedTime),
        'date': DateTime.now().toIso8601String().substring(0, 10),
        if (person != 'self') 'family_member_id': person,
      });
      _quantityCtrl.clear();
      _notesCtrl.clear();
      setState(() => _selectedTime = TimeOfDay.now());
      ref.invalidate(todayHydrationProvider(person));
      ref.invalidate(hydrationHistoryProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hydration logged!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
