import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/health_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../widgets/friendly_error.dart';
import '../widgets/shimmer_placeholder.dart';

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final logs = ref.watch(sleepProvider('${person}_30'));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sleep')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: logs.when(
        loading: () => const ShimmerList(itemCount: 5, itemHeight: 72),
        error: (e, _) => FriendlyError(error: e, context: 'sleep logs'),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text('Your sleep log is empty.\nTap + to get started tracking sleep.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return Card(
                child: ListTile(
                  leading: Icon(Icons.bedtime, color: cs.primary),
                  title: Text('${e['sleep_hours'] ?? 0}h ${e['sleep_quality'] ?? ''}'),
                  subtitle: Text(e['notes'] ?? ''),
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
    final hoursCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String quality = 'Good';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Sleep'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: hoursCtrl, decoration: const InputDecoration(labelText: 'Hours slept'), keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: quality,
              decoration: const InputDecoration(labelText: 'Quality'),
              items: ['Poor', 'Fair', 'Good', 'Excellent'].map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
              onChanged: (v) => quality = v ?? 'Good',
            ),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final person = ref.read(selectedPersonProvider);
              await apiClient.dio.post(ApiConstants.sleep, data: {
                'category': 'sleep',
                'sleep_hours': double.tryParse(hoursCtrl.text) ?? 0,
                'sleep_quality': quality,
                'notes': notesCtrl.text,
                if (person != 'self') 'family_member_id': person,
              });
              ref.invalidate(sleepProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
