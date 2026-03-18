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
            Tab(icon: Icon(Icons.upload_file_rounded), text: 'Upload'),
            Tab(icon: Icon(Icons.edit_rounded), text: 'Manual'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUploadTab(),
          _ManualEntryTab(
            dateController: _dateController,
            notesController: _notesController,
          ),
        ],
      ),
    );
  }

  // ── Upload Tab (built inline so setState works) ───────────────────────────

  Widget _buildUploadTab() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasFiles = _selectedFiles.isNotEmpty;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Drop zone / pick area ─────────────────────────────────
                SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: _pickFiles,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.25),
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cs.primary.withValues(alpha: 0.04),
                            cs.tertiary.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: hasFiles ? 20 : 40,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    cs.primary.withValues(alpha: 0.15),
                                    cs.tertiary.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                              child: Icon(
                                hasFiles
                                    ? Icons.add_circle_outline_rounded
                                    : Icons.cloud_upload_rounded,
                                size: 28,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              hasFiles ? 'Tap to add more files' : 'Select your lab reports',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PDF, JPG, PNG, TIFF, BMP, WebP',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Selected files header ─────────────────────────────────
                if (hasFiles)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.attach_file_rounded,
                              size: 18, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${_selectedFiles.length} ${_selectedFiles.length == 1 ? 'file' : 'files'} selected',
                            style: tt.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setState(() => _selectedFiles.clear()),
                            icon: Icon(Icons.clear_all_rounded,
                                size: 18, color: cs.error),
                            label: Text('Clear all',
                                style: TextStyle(
                                    color: cs.error, fontSize: 12)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── File cards ────────────────────────────────────────────
                if (hasFiles)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: _selectedFiles.length,
                      itemBuilder: (context, i) =>
                          _SelectedFileCard(
                            file: _selectedFiles[i],
                            onRemove: () {
                              setState(() => _selectedFiles.removeAt(i));
                            },
                          ),
                    ),
                  ),

                // ── Empty hint ────────────────────────────────────────────
                if (!hasFiles)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 80),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.science_rounded,
                                size: 44,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.15)),
                            const SizedBox(height: 10),
                            Text(
                              'Your biomarkers will appear here\nonce you upload a report',
                              textAlign: TextAlign.center,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom action bar ─────────────────────────────────────────
          if (hasFiles)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _uploadFiles,
                  icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                  label: Text(
                    'Analyse ${_selectedFiles.length} '
                    '${_selectedFiles.length == 1 ? 'Report' : 'Reports'}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
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
        if (!_selectedFiles.any((f) => f.path == file.path)) {
          _selectedFiles.add(file);
        }
      }
    });
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) return;

    final person = ref.read(selectedPersonProvider);
    final files = List<PlatformFile>.from(_selectedFiles);

    // Show "uploading" notification
    await NotificationService.showLabUploaded(fileCount: files.length);

    if (!mounted) return;
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _MultiProcessingScreen(
          files: files,
          person: person,
        ),
      ),
    );

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

// ── Selected File Card ──────────────────────────────────────────────────────

class _SelectedFileCard extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback onRemove;

  const _SelectedFileCard({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isPdf = file.name.toLowerCase().endsWith('.pdf');
    final sizeKb = file.size / 1024;
    final sizeStr = sizeKb >= 1024
        ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
        : '${sizeKb.toStringAsFixed(0)} KB';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.surfaceContainerLow,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // File type badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPdf
                      ? [
                          const Color(0xFFEF4444).withValues(alpha: 0.12),
                          const Color(0xFFDC2626).withValues(alpha: 0.08),
                        ]
                      : [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_rounded,
                    color: isPdf
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF8B5CF6),
                    size: 20,
                  ),
                  Text(
                    isPdf ? 'PDF' : 'IMG',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: isPdf
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Name + size
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sizeStr,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Remove
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.remove_circle_rounded,
                  color: cs.error.withValues(alpha: 0.6), size: 22),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
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
    _fileStates =
        widget.files.map((f) => _FileUploadState(file: f)).toList();
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
    final processed = doneCount + errorCount;
    final allSuccess = _allDone && errorCount == 0;
    final hasErrors = _allDone && errorCount > 0;
    final progress = total > 0 ? processed / total : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Animated status ring ────────────────────────────────────
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress ring
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: _allDone ? 1.0 : progress,
                        strokeWidth: 5,
                        backgroundColor:
                            cs.outlineVariant.withValues(alpha: 0.15),
                        color: _allDone
                            ? allSuccess
                                ? const Color(0xFF16A34A)
                                : cs.error
                            : cs.primary,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    // Center icon / count
                    if (_allDone)
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (allSuccess
                                  ? const Color(0xFF16A34A)
                                  : cs.error)
                              .withValues(alpha: 0.1),
                        ),
                        child: Icon(
                          allSuccess
                              ? Icons.check_rounded
                              : Icons.warning_rounded,
                          size: 36,
                          color: allSuccess
                              ? const Color(0xFF16A34A)
                              : cs.error,
                        ),
                      )
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$processed',
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.primary,
                            ),
                          ),
                          Text(
                            'of $total',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ───────────────────────────────────────────────────
              Text(
                _allDone
                    ? allSuccess
                        ? 'Analysis Complete!'
                        : '$doneCount of $total Succeeded'
                    : 'Analysing Reports...',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              if (_allDone && _totalSaved > 0)
                Text(
                  '$_totalSaved biomarkers extracted and classified',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              if (hasErrors)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$errorCount ${errorCount == 1 ? 'file' : 'files'} failed',
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
              if (!_allDone)
                Text(
                  'This may take a few seconds per file',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),

              const SizedBox(height: 28),

              // ── Per-file status list ─────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  itemCount: _fileStates.length,
                  itemBuilder: (context, i) =>
                      _FileStatusTile(state: _fileStates[i]),
                ),
              ),

              // ── Bottom button ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
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
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Per-file status tile ────────────────────────────────────────────────────

class _FileStatusTile extends StatelessWidget {
  final _FileUploadState state;
  const _FileStatusTile({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isPdf = state.file.name.toLowerCase().endsWith('.pdf');

    final Color statusColor;
    final Widget trailing;
    final String statusText;

    switch (state.status) {
      case _FileStatus.pending:
        statusColor = cs.onSurfaceVariant.withValues(alpha: 0.4);
        statusText = 'Queued';
        trailing = Icon(Icons.schedule_rounded,
            color: statusColor, size: 20);
      case _FileStatus.uploading:
        statusColor = cs.primary;
        statusText = 'Uploading...';
        trailing = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: cs.primary),
        );
      case _FileStatus.analysing:
        statusColor = cs.primary;
        statusText = 'Analysing...';
        trailing = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: cs.primary),
        );
      case _FileStatus.done:
        statusColor = const Color(0xFF16A34A);
        statusText = '${state.savedCount} biomarkers'
            '${state.labProvider != null ? ' \u2022 ${state.labProvider}' : ''}';
        trailing = const Icon(Icons.check_circle_rounded,
            color: Color(0xFF16A34A), size: 22);
      case _FileStatus.error:
        statusColor = cs.error;
        statusText = state.errorMessage ?? 'Failed';
        trailing =
            Icon(Icons.error_rounded, color: cs.error, size: 22);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.surfaceContainerLow,
        border: (state.status == _FileStatus.uploading ||
                state.status == _FileStatus.analysing)
            ? Border.all(color: cs.primary.withValues(alpha: 0.25))
            : null,
      ),
      child: Row(
        children: [
          // File icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: (isPdf
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF8B5CF6))
                  .withValues(alpha: 0.1),
            ),
            child: Icon(
              isPdf
                  ? Icons.picture_as_pdf_rounded
                  : Icons.image_rounded,
              color: isPdf
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF8B5CF6),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 1),
                Text(
                  statusText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                    icon:
                        Icon(Icons.remove_circle_outline, color: cs.error),
                    onPressed: () =>
                        setState(() => _entries.removeAt(i)),
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
              onPressed:
                  _entries.isEmpty || _saving ? null : _saveManual,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
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
          'notes': widget.notesController.text.isEmpty
              ? null
              : widget.notesController.text,
          'results': valid
              .map((e) => {
                    'biomarker_code': e.code,
                    'value': e.value,
                    'unit': e.unit,
                  })
              .toList(),
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
  _ManualEntry(
      {required this.code, required this.name, required this.unit});
}

// ── Biomarker Search Delegate ────────────────────────────────────────────────

class _BiomarkerSearchDelegate
    extends SearchDelegate<BiomarkerDefinition?> {
  final List<BiomarkerDefinition> catalog;

  _BiomarkerSearchDelegate(this.catalog);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));

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
          subtitle: Text('${bm.category} \u2022 ${bm.unit}'),
          trailing: Text(bm.code,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(
                      color: Theme.of(context).colorScheme.primary)),
          onTap: () => close(context, bm),
        );
      },
    );
  }
}
