import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/lab_result.dart';
import '../../providers/lab_provider.dart';
import '../../providers/selected_person_provider.dart';

class LabUploadScreen extends ConsumerStatefulWidget {
  const LabUploadScreen({super.key});

  @override
  ConsumerState<LabUploadScreen> createState() => _LabUploadScreenState();
}

class _LabUploadScreenState extends ConsumerState<LabUploadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(labUploadProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Lab Results'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file_rounded), text: 'Upload File'),
            Tab(icon: Icon(Icons.edit_rounded), text: 'Manual Entry'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Upload Tab ──────────────────────────────────────────
          _UploadTab(
            uploadState: uploadState,
            dateController: _dateController,
            notesController: _notesController,
            onPickFile: _pickFile,
            onConfirm: _confirmResults,
            onReset: () => ref.read(labUploadProvider.notifier).reset(),
          ),

          // ── Manual Entry Tab ────────────────────────────────────
          _ManualEntryTab(
            dateController: _dateController,
            notesController: _notesController,
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'tiff', 'bmp', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    ref.read(labUploadProvider.notifier).uploadFile(file);
  }

  Future<void> _confirmResults() async {
    final person = ref.read(selectedPersonProvider);
    final success = await ref.read(labUploadProvider.notifier).confirmResults(
          testDate: _dateController.text,
          familyMemberId: person == 'self' ? null : person,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lab results saved successfully!')),
      );
      context.pop();
    }
  }
}

// ── Upload Tab ───────────────────────────────────────────────────────────────

class _UploadTab extends StatelessWidget {
  final LabUploadState uploadState;
  final TextEditingController dateController;
  final TextEditingController notesController;
  final VoidCallback onPickFile;
  final VoidCallback onConfirm;
  final VoidCallback onReset;

  const _UploadTab({
    required this.uploadState,
    required this.dateController,
    required this.notesController,
    required this.onPickFile,
    required this.onConfirm,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    switch (uploadState.status) {
      case LabUploadStatus.idle:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_rounded,
                  size: 64, color: cs.primary.withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              Text('Upload your lab report',
                  style: tt.titleMedium),
              const SizedBox(height: 8),
              Text('PDF, scanned PDFs, and photos of lab reports supported',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.file_open_rounded),
                label: const Text('Select File'),
              ),
            ],
          ),
        );

      case LabUploadStatus.uploading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Parsing lab report...'),
            ],
          ),
        );

      case LabUploadStatus.parsed:
        return _ReviewResults(
          uploadState: uploadState,
          dateController: dateController,
          notesController: notesController,
          onConfirm: onConfirm,
          onReset: onReset,
        );

      case LabUploadStatus.confirming:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Saving results...'),
            ],
          ),
        );

      case LabUploadStatus.done:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text('Results saved!', style: tt.titleMedium),
            ],
          ),
        );

      case LabUploadStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_rounded, size: 64, color: cs.error),
              const SizedBox(height: 16),
              Text(uploadState.errorMessage ?? 'An error occurred',
                  style: tt.bodyMedium?.copyWith(color: cs.error),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onReset, child: const Text('Try Again')),
            ],
          ),
        );
    }
  }
}

// ── Review Parsed Results ────────────────────────────────────────────────────

class _ReviewResults extends ConsumerWidget {
  final LabUploadState uploadState;
  final TextEditingController dateController;
  final TextEditingController notesController;
  final VoidCallback onConfirm;
  final VoidCallback onReset;

  const _ReviewResults({
    required this.uploadState,
    required this.dateController,
    required this.notesController,
    required this.onConfirm,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final results = uploadState.parsedResults;

    return Column(
      children: [
        // Header info
        Container(
          padding: const EdgeInsets.all(16),
          color: cs.primaryContainer.withValues(alpha: 0.3),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${results.length} biomarkers found',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    if (uploadState.labProvider != null &&
                        uploadState.labProvider != 'generic')
                      Text('Provider: ${uploadState.labProvider}',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    if (uploadState.confidence != null)
                      Text(
                          'Confidence: ${(uploadState.confidence! * 100).toStringAsFixed(0)}%',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded),
                onPressed: onReset,
                tooltip: 'Start over',
              ),
            ],
          ),
        ),

        // Date + notes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: dateController,
            decoration: const InputDecoration(
              labelText: 'Test Date',
              hintText: 'YYYY-MM-DD',
              prefixIcon: Icon(Icons.calendar_today_rounded),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),

        // Warnings
        if (uploadState.errors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final err in uploadState.errors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $err',
                          style: tt.bodySmall?.copyWith(color: cs.error)),
                    ),
                ],
              ),
            ),
          ),

        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            itemBuilder: (context, i) {
              final r = results[i];
              return _EditableResultTile(
                result: r,
                index: i,
                onValueChanged: (val) {
                  r.value = val;
                  ref.read(labUploadProvider.notifier).updateResult(i, r);
                },
                onRemove: () {
                  ref.read(labUploadProvider.notifier).removeResult(i);
                },
              );
            },
          ),
        ),

        // Confirm button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: results.isNotEmpty ? onConfirm : null,
              icon: const Icon(Icons.save_rounded),
              label: Text('Save ${results.length} Results'),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditableResultTile extends StatelessWidget {
  final ParsedLabResult result;
  final int index;
  final ValueChanged<double> onValueChanged;
  final VoidCallback onRemove;

  const _EditableResultTile({
    required this.result,
    required this.index,
    required this.onValueChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dismissible(
      key: ValueKey('${result.biomarkerCode}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: cs.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onRemove(),
      child: ListTile(
        dense: true,
        title: Text(result.biomarkerName,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${result.unit}${result.referenceLow != null ? ' • Ref: ${result.referenceLow}-${result.referenceHigh}' : ''}',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: SizedBox(
          width: 80,
          child: TextFormField(
            initialValue: result.value.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.end,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              isDense: true,
              border: UnderlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 4),
            ),
            onChanged: (val) {
              final parsed = double.tryParse(val);
              if (parsed != null) onValueChanged(parsed);
            },
          ),
        ),
        leading: result.isFlagged
            ? Icon(Icons.flag_rounded, size: 20, color: cs.error)
            : null,
      ),
    );
  }
}

// ── Manual Entry Tab ─────────────────────────────────────────────────────────

class _ManualEntryTab extends ConsumerStatefulWidget {
  final TextEditingController dateController;
  final TextEditingController notesController;

  const _ManualEntryTab({
    required this.dateController,
    required this.notesController,
  });

  @override
  ConsumerState<_ManualEntryTab> createState() => _ManualEntryTabState();
}

class _ManualEntryTabState extends ConsumerState<_ManualEntryTab> {
  final List<_ManualEntry> _entries = [];
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(biomarkerCatalogProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: widget.dateController,
            decoration: const InputDecoration(
              labelText: 'Test Date',
              hintText: 'YYYY-MM-DD',
              prefixIcon: Icon(Icons.calendar_today_rounded),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),

        // Add biomarker button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: catalogAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, st) => Text('Error loading biomarkers: $e'),
            data: (catalog) => OutlinedButton.icon(
              onPressed: () => _addBiomarker(catalog),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Biomarker'),
            ),
          ),
        ),

        // Entries list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _entries.length,
            itemBuilder: (context, i) {
              final entry = _entries[i];
              return Card(
                child: ListTile(
                  title: Text(entry.name),
                  subtitle: Text('${entry.unit}'),
                  trailing: SizedBox(
                    width: 80,
                    child: TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(
                        hintText: 'Value',
                        isDense: true,
                        border: UnderlineInputBorder(),
                      ),
                      onChanged: (val) {
                        entry.value = double.tryParse(val);
                      },
                    ),
                  ),
                  leading: IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: cs.error),
                    onPressed: () => setState(() => _entries.removeAt(i)),
                  ),
                ),
              );
            },
          ),
        ),

        // Save button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _entries.isEmpty || _saving ? null : _saveManual,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text('Save ${_entries.length} Results'),
            ),
          ),
        ),
      ],
    );
  }

  void _addBiomarker(List<BiomarkerDefinition> catalog) async {
    final selected = await showSearch<BiomarkerDefinition?>(
      context: context,
      delegate: _BiomarkerSearchDelegate(catalog),
    );
    if (selected != null) {
      setState(() {
        _entries.add(_ManualEntry(
          code: selected.code,
          name: selected.name,
          unit: selected.unit,
        ));
      });
    }
  }

  Future<void> _saveManual() async {
    final valid = _entries.where((e) => e.value != null).toList();
    if (valid.isEmpty) return;

    setState(() => _saving = true);
    try {
      final person = ref.read(selectedPersonProvider);
      await apiClient.dio.post(
        ApiConstants.labManual,
        data: {
          'test_date': widget.dateController.text,
          'family_member_id': person == 'self' ? null : person,
          'notes': widget.notesController.text.isEmpty ? null : widget.notesController.text,
          'results': valid.map((e) => {
            'biomarker_code': e.code,
            'value': e.value,
            'unit': e.unit,
          }).toList(),
        },
      );

      ref.invalidate(labDashboardProvider(person));
      ref.invalidate(labReportsProvider(person));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lab results saved!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ManualEntry {
  final String code;
  final String name;
  final String unit;
  double? value;
  _ManualEntry({required this.code, required this.name, required this.unit});
}

// ── Biomarker Search Delegate ────────────────────────────────────────────────

class _BiomarkerSearchDelegate extends SearchDelegate<BiomarkerDefinition?> {
  final List<BiomarkerDefinition> catalog;

  _BiomarkerSearchDelegate(this.catalog);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase();
    final filtered = catalog
        .where((b) =>
            b.name.toLowerCase().contains(q) ||
            b.code.toLowerCase().contains(q) ||
            b.category.toLowerCase().contains(q))
        .toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final bm = filtered[i];
        return ListTile(
          title: Text(bm.name),
          subtitle: Text('${bm.category} • ${bm.unit}'),
          trailing: Text(bm.code,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary)),
          onTap: () => close(context, bm),
        );
      },
    );
  }
}
