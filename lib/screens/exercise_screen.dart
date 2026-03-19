import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/health_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../widgets/friendly_error.dart';
import '../widgets/shimmer_placeholder.dart';

class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final logs = ref.watch(exerciseProvider('${person}_30'));
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: logs.when(
        loading: () => const ShimmerList(itemCount: 5, itemHeight: 72),
        error: (e, _) => FriendlyError(error: e, context: 'exercise logs'),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text('Your exercise log is empty.\nTap + to get started tracking workouts.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return Card(
                child: ListTile(
                  leading: Icon(Icons.fitness_center, color: cs.primary),
                  title: Text(e['exercise_type'] ?? 'Exercise'),
                  subtitle: Text('${e['duration_minutes'] ?? 0} min'),
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
    final typeCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Type (e.g. Running)')),
            TextField(controller: durationCtrl, decoration: const InputDecoration(labelText: 'Duration (minutes)'), keyboardType: TextInputType.number),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final person = ref.read(selectedPersonProvider);
              await apiClient.dio.post(ApiConstants.exercise, data: {
                'category': 'exercise',
                'exercise_type': typeCtrl.text,
                'duration_minutes': int.tryParse(durationCtrl.text) ?? 0,
                'notes': notesCtrl.text,
                if (person != 'self') 'family_member_id': person,
              });
              ref.invalidate(exerciseProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
