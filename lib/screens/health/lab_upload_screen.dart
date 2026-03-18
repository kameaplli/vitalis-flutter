import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/lab_result.dart';
import '../../providers/lab_provider.dart';
import '../../providers/selected_person_provider.dart';
import '../../services/notification_service.dart';

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

  // Selected files (before upload)
  final List<PlatformFile> _selectedFiles = [];

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Lab Results'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file_rounded), text: 'Upload Files'),
            Tab(icon: Icon(Icons.edit_rounded), text: 'Manual Entry'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UploadTab(
            selectedFiles: _selectedFiles,
            onPickFiles: _pickFiles,
            onRemoveFile: _removeFile,
            onUpload: _uploadFiles,
          ),
          _ManualEntryTab(
            dateController: _dateController,
            notesController: _notesController,
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'tiff', 'bmp', 'webp'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      for (final file in result.files) {
        // Avoid duplicates by path
        if (!_selectedFiles.any((f) => f.path == file.path)) {
          _selectedFiles.add(file);
        }
      }
    });
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) return;

    final person = ref.read(selectedPersonProvider);
    final files = List<PlatformFile>.from(_selectedFiles);

    // Navigate to processing screen
    if (!mounted) return;
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _MultiProcessingScreen(
          files: files,
          person: person,
        ),
      ),
    );

    // When user returns, refresh dashboard and go back
    if (mounted) {
      if (success == true) {
        ref.invalidate(labDashboardProvider(person));
        ref.invalidate(labReportsProvider(person));
        setState(() => _selectedFiles.clear());
      }
      context.pop();
    }
  }
}

// ── Upload Tab (multi-file selection) ──────────────────────────────────────

class _UploadTab extends StatelessWidget {
  final List<PlatformFile> selectedFiles;
  final VoidCallback onPickFiles;
  final void Function(int) onRemoveFile;
  final VoidCallback onUpload;

  const _UploadTab({
    required this.selectedFiles,
    required this.onPickFiles,
    required this.onRemoveFile,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // Header area
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.upload_file_rounded,
                    size: 32, color: cs.primary),
              ),
              const SizedBox(height: 16),
              Text('Upload Lab Reports',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Select one or more PDFs or photos of your blood test reports.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Add files button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onPickFiles,
              icon: const Icon(Icons.add_rounded),
              label: Text(selectedFiles.isEmpty
                  ? 'Select Files'
                  : 'Add More Files'),
            ),
          ),
        ),

        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Supported: PDF, JPG, PNG, TIFF, BMP, WebP',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),

        const SizedBox(height: 12),

        // Selected files list
        Expanded(
          child: selectedFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open_rounded,
                          size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('No files selected',
                          style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: selectedFiles.length,
                  itemBuilder: (context, i) {
                    final file = selectedFiles[i];
                    final name = file.name;
                    final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(1);
                    final isPdf = name.toLowerCase().endsWith('.pdf');

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: (isPdf ? cs.error : cs.tertiary)
                                .withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.image_rounded,
                            color: isPdf ? cs.error : cs.tertiary,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('$sizeMb MB'),
                        trailing: IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: cs.onSurfaceVariant),
                          onPressed: () => onRemoveFile(i),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Upload button
        if (selectedFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: Text(
                  'Upload & Analyse ${selectedFiles.length} '
                  '${selectedFiles.length == 1 ? 'File' : 'Files'}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Multi-file Processing Screen ────────────────────────────────────────────

enum _FileStatus { pending, uploading, analysing, done, error }

class _FileUploadState {
  final PlatformFile file;
  _FileStatus status;
  String? errorMessage;
  int savedCount;
  String? labProvider;

  _FileUploadState({required this.file})
      : status = _FileStatus.pending,
        savedCount = 0;
}

class _MultiProcessingScreen extends StatefulWidget {
  final List<PlatformFile> files;
  final String person;

  const _MultiProcessingScreen({
    required this.files,
    required this.person,
  });

  @override
  State<_MultiProcessingScreen> createState() => _MultiProcessingScreenState();
}

class _MultiProcessingScreenState extends State<_MultiProcessingScreen> {
  late final List<_FileUploadState> _fileStates;
  bool _allDone = false;
  int _totalSaved = 0;

  @override
  void initState() {
    super.initState();
    _fileStates = widget.files
        .map((f) => _FileUploadState(file: f))
        .toList();
    _processAllFiles();
  }

  Future<void> _processAllFiles() async {
    for (int i = 0; i < _fileStates.length; i++) {
      await _processFile(i);
    }

    _totalSaved = _fileStates
        .where((f) => f.status == _FileStatus.done)
        .fold(0, (sum, f) => sum + f.savedCount);

    final successCount =
        _fileStates.where((f) => f.status == _FileStatus.done).length;

    setState(() => _allDone = true);

    if (successCount > 0) {
      await NotificationService.showLabAnalysisComplete(
          resultsCount: _totalSaved);
    }
  }

  Future<void> _processFile(int index) async {
    final state = _fileStates[index];
    final filePath = state.file.path;
    if (filePath == null) {
      setState(() {
        state.status = _FileStatus.error;
        state.errorMessage = 'File path unavailable';
      });
      return;
    }

    try {
      setState(() => state.status = _FileStatus.uploading);

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: state.file.name,
        ),
        if (widget.person != 'self') 'family_member_id': widget.person,
      });

      setState(() => state.status = _FileStatus.analysing);

      final response = await apiClient.dio.post(
        ApiConstants.labUpload,
        data: formData,
        options: Options(
          sendTimeout: const Duration(seconds: 300),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';

      if (status == 'completed') {
        setState(() {
          state.status = _FileStatus.done;
          state.savedCount = data['saved_count'] as int? ?? 0;
          state.labProvider = data['lab_provider'] as String?;
        });
      } else {
        setState(() {
          state.status = _FileStatus.error;
          state.errorMessage =
              data['detail'] as String? ?? 'Unknown error';
        });
      }
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString()
          : e.message;
      setState(() {
        state.status = _FileStatus.error;
        state.errorMessage = detail ?? 'Connection error';
      });
    } catch (e) {
      setState(() {
        state.status = _FileStatus.error;
        state.errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final doneCount =
        _fileStates.where((f) => f.status == _FileStatus.done).length;
    final errorCount =
        _fileStates.where((f) => f.status == _FileStatus.error).length;
    final total = _fileStates.length;
    final allSuccess = _allDone && errorCount == 0;
    final hasErrors = _allDone && errorCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_allDone
            ? 'Upload Complete'
            : 'Processing ${doneCount + errorCount}/$total'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Summary banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _allDone
                  ? allSuccess
                      ? const Color(0xFF16A34A).withValues(alpha: 0.08)
                      : cs.error.withValues(alpha: 0.08)
                  : cs.primary.withValues(alpha: 0.08),
            ),
            child: Column(
              children: [
                if (!_allDone)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: cs.primary),
                  )
                else
                  Icon(
                    allSuccess
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                    size: 48,
                    color: allSuccess
                        ? const Color(0xFF16A34A)
                        : cs.error,
                  ),
                const SizedBox(height: 12),
                Text(
                  _allDone
                      ? allSuccess
                          ? '$_totalSaved biomarkers extracted from $total ${total == 1 ? 'file' : 'files'}'
                          : '$doneCount of $total files processed successfully'
                      : 'Analysing your lab reports...',
                  textAlign: TextAlign.center,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                if (hasErrors) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$errorCount ${errorCount == 1 ? 'file' : 'files'} failed — see details below',
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ],
              ],
            ),
          ),

          // Per-file status list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _fileStates.length,
              itemBuilder: (context, i) {
                final fs = _fileStates[i];
                return _FileStatusCard(state: fs);
              },
            ),
          ),

          // Bottom button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _allDone
                    ? () => Navigator.of(context).pop(doneCount > 0)
                    : null,
                icon: Icon(_allDone
                    ? Icons.dashboard_rounded
                    : Icons.hourglass_top_rounded),
                label: Text(
                  _allDone ? 'View Dashboard' : 'Processing...',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-file status card ────────────────────────────────────────────────────

class _FileStatusCard extends StatelessWidget {
  final _FileUploadState state;
  const _FileStatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isPdf = state.file.name.toLowerCase().endsWith('.pdf');

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    switch (state.status) {
      case _FileStatus.pending:
        statusColor = cs.onSurfaceVariant.withValues(alpha: 0.4);
        statusIcon = Icons.schedule_rounded;
        statusText = 'Waiting...';
      case _FileStatus.uploading:
        statusColor = cs.primary;
        statusIcon = Icons.cloud_upload_rounded;
        statusText = 'Uploading...';
      case _FileStatus.analysing:
        statusColor = cs.primary;
        statusIcon = Icons.psychology_rounded;
        statusText = 'Analysing...';
      case _FileStatus.done:
        statusColor = const Color(0xFF16A34A);
        statusIcon = Icons.check_circle_rounded;
        statusText = '${state.savedCount} biomarkers'
            '${state.labProvider != null ? ' • ${state.labProvider}' : ''}';
      case _FileStatus.error:
        statusColor = cs.error;
        statusIcon = Icons.error_outline_rounded;
        statusText = state.errorMessage ?? 'Failed';
    }

    final isActive = state.status == _FileStatus.uploading ||
        state.status == _FileStatus.analysing;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: cs.primary.withValues(alpha: 0.3))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // File icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: (isPdf ? cs.error : cs.tertiary)
                    .withValues(alpha: 0.1),
              ),
              child: Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_rounded,
                color: isPdf ? cs.error : cs.tertiary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: state.status == _FileStatus.done ||
                              state.status == _FileStatus.error
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Status indicator
            if (isActive)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: cs.primary),
              )
            else
              Icon(statusIcon, color: statusColor, size: 24),
          ],
        ),
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

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _entries.length,
            itemBuilder: (context, i) {
              final entry = _entries[i];
              return Card(
                child: ListTile(
                  title: Text(entry.name),
                  subtitle: Text(entry.unit),
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
