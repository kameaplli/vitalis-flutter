import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/health_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../widgets/friendly_error.dart';
import '../widgets/shimmer_placeholder.dart';

class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final logs = ref.watch(vitalsProvider('${person}_30'));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Vitals')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: logs.when(
        loading: () => const ShimmerList(itemCount: 5, itemHeight: 72),
        error: (e, _) => FriendlyError(error: e, context: 'vitals'),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text('Your vitals log is empty.\nTap + to get started recording vitals.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              final bp = e['blood_pressure'] ?? '';
              final hr = e['heart_rate'];
              final temp = e['temperature'];
              return Card(
                child: ListTile(
                  leading: Icon(Icons.monitor_heart, color: cs.primary),
                  title: Text([
                    if (bp.toString().isNotEmpty) 'BP: $bp',
                    if (hr != null) 'HR: $hr bpm',
                    if (temp != null) 'Temp: $temp',
                  ].join(' | ')),
                  trailing: Text(
                    (e['logged_at'] ?? '').toString().substring(0, 10),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final bpCtrl = TextEditingController();
    final hrCtrl = TextEditingController();
    final tempCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Vitals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: bpCtrl, decoration: const InputDecoration(labelText: 'Blood Pressure (e.g. 120/80)')),
            TextField(controller: hrCtrl, decoration: const InputDecoration(labelText: 'Heart Rate (bpm)'), keyboardType: TextInputType.number),
            TextField(controller: tempCtrl, decoration: const InputDecoration(labelText: 'Temperature'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final person = ref.read(selectedPersonProvider);
              await apiClient.dio.post(ApiConstants.vitals, data: {
                'category': 'vitals',
                'blood_pressure': bpCtrl.text,
                'heart_rate': int.tryParse(hrCtrl.text),
                'temperature': double.tryParse(tempCtrl.text),
                if (person != 'self') 'family_member_id': person,
              });
              ref.invalidate(vitalsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
