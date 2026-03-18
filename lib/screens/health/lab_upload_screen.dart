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

// ── 3-tick state per file ────────────────────────────────────────────────────

enum _TickState { pending, active, done, error }

class _FileProcessState {
  final PlatformFile file;
  _TickState uploaded;
  _TickState analysed;
  _TickState ready;
  String? errorMessage;
  int savedCount;
  String? labProvider;

  _FileProcessState({required this.file})
      : uploaded = _TickState.pending,
        analysed = _TickState.pending,
        ready = _TickState.pending,
        savedCount = 0;

  bool get isIdle => uploaded == _TickState.pending;
  bool get isComplete =>
      ready == _TickState.done || uploaded == _TickState.error;
}

// ── Main Screen ──────────────────────────────────────────────────────────────

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
  final List<_FileProcessState> _files = [];
  bool _processing = false;
  bool _allDone = false;
  String _statusText = ''; // Overall status message shown during processing

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

  // ── Upload Tab ─────────────────────────────────────────────────────────────

  Widget _buildUploadTab() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasFiles = _files.isNotEmpty;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Pick zone ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: _processing ? null : _pickFiles,
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
                          vertical: hasFiles ? 16 : 36,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
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
                                size: 26,
                                color: _processing
                                    ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                                    : cs.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hasFiles
                                  ? 'Tap to add more files'
                                  : 'Select your lab reports',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _processing
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'PDF, JPG, PNG, TIFF, BMP, WebP',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── File list header ───────────────────────────────────────
                if (hasFiles)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                      child: Row(
                        children: [
                          Icon(Icons.attach_file_rounded,
                              size: 18, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${_files.length} ${_files.length == 1 ? 'file' : 'files'}',
                            style: tt.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          if (_processing) ...[
                            const SizedBox(width: 8),
                            _buildSummaryChips(),
                          ],
                          const Spacer(),
                          if (!_processing)
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _files.clear()),
                              icon: Icon(Icons.clear_all_rounded,
                                  size: 18, color: cs.error),
                              label: Text('Clear',
                                  style: TextStyle(
                                      color: cs.error, fontSize: 12)),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // ── Status text + legend ───────────────────────────────────
                if (hasFiles)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status message
                          if (_statusText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  if (_processing)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cs.primary,
                                        ),
                                      ),
                                    ),
                                  if (_allDone && !_processing)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      _statusText,
                                      style: tt.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: _allDone
                                            ? const Color(0xFF16A34A)
                                            : cs.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Legend
                          Row(
                            children: [
                              _buildLegendItem(
                                  'Uploaded', const Color(0xFF16A34A)),
                              const SizedBox(width: 16),
                              _buildLegendItem(
                                  'Analysed', const Color(0xFF2563EB)),
                              const SizedBox(width: 16),
                              _buildLegendItem(
                                  'Ready', const Color(0xFF9333EA)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── File cards with 3 ticks ────────────────────────────────
                if (hasFiles)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: _files.length,
                      itemBuilder: (context, i) {
                        final f = _files[i];
                        // ValueKey forces Flutter to rebuild when tick states change
                        return _FileTickCard(
                          key: ValueKey(
                              '${f.file.path}_${f.uploaded}_${f.analysed}_${f.ready}'),
                          state: f,
                          showTicks: true,
                          onRemove: _processing
                              ? null
                              : () => setState(() => _files.removeAt(i)),
                        );
                      },
                    ),
                  ),

                // ── Empty state ────────────────────────────────────────────
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

          // ── Bottom action bar ──────────────────────────────────────────
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
                child: _allDone
                    ? FilledButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                            Icons.dashboard_rounded, size: 20),
                        label: const Text(
                          'View Dashboard',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _processing ? null : _startProcessing,
                        icon: _processing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: cs.onPrimary,
                                ),
                              )
                            : const Icon(
                                Icons.rocket_launch_rounded, size: 20),
                        label: Text(
                          _processing
                              ? _statusText
                              : 'Analyse ${_files.length} '
                                  '${_files.length == 1 ? 'Report' : 'Reports'}',
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }

  Widget _buildSummaryChips() {
    final done = _files.where((f) => f.ready == _TickState.done).length;
    final errors =
        _files.where((f) => f.uploaded == _TickState.error).length;
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (done > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
            ),
            child: Text(
              '$done done',
              style: tt.labelSmall?.copyWith(
                color: const Color(0xFF16A34A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (errors > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context)
                  .colorScheme
                  .error
                  .withValues(alpha: 0.12),
            ),
            child: Text(
              '$errors failed',
              style: tt.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── File picking ───────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'jpg', 'jpeg', 'png', 'tiff', 'bmp', 'webp'
      ],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      for (final file in result.files) {
        if (!_files.any((f) => f.file.path == file.path)) {
          _files.add(_FileProcessState(file: file));
        }
      }
    });
  }

  // ── Processing pipeline ────────────────────────────────────────────────────

  Future<void> _startProcessing() async {
    if (_files.isEmpty || _processing) return;

    setState(() {
      _processing = true;
      _statusText = 'Starting...';
    });

    try {
      // Fire-and-forget notification — don't block processing
      NotificationService.showLabUploaded(fileCount: _files.length)
          .catchError((_) {});

      final person = ref.read(selectedPersonProvider);

      for (int i = 0; i < _files.length; i++) {
        if (!mounted) return;
        setState(() {
          _statusText = 'Processing file ${i + 1} of ${_files.length}';
        });
        await _processFile(i, person);
      }

      // Invalidate dashboard for all successful files
      final successCount =
          _files.where((f) => f.analysed == _TickState.done).length;
      if (successCount > 0) {
        if (mounted) {
          setState(() => _statusText = 'Updating dashboard...');
        }

        ref.invalidate(labDashboardProvider(person));
        ref.invalidate(labReportsProvider(person));

        // Mark all analysed files as "ready"
        for (final f in _files) {
          if (f.analysed == _TickState.done) {
            f.ready = _TickState.done;
          }
        }

        final totalSaved =
            _files.where((f) => f.ready == _TickState.done)
                .fold(0, (sum, f) => sum + f.savedCount);

        // Fire-and-forget — don't block
        NotificationService.showLabAnalysisComplete(
                resultsCount: totalSaved)
            .catchError((_) {});
      }

      if (mounted) {
        final errorCount =
            _files.where((f) => f.uploaded == _TickState.error ||
                f.analysed == _TickState.error).length;
        setState(() {
          _processing = false;
          _allDone = true;
          _statusText = errorCount > 0
              ? '$successCount succeeded, $errorCount failed'
              : '$successCount ${successCount == 1 ? 'report' : 'reports'} analysed';
        });
      }
    } catch (e) {
      debugPrint('[LabUpload] FATAL: _startProcessing crashed: $e');
      if (mounted) {
        setState(() {
          _processing = false;
          _allDone = true;
          _statusText = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _processFile(int index, String person) async {
    final state = _files[index];
    final filePath = state.file.path;

    if (filePath == null) {
      setState(() {
        state.uploaded = _TickState.error;
        state.errorMessage = 'File path unavailable';
      });
      return;
    }

    try {
      // ── Tick 1: Uploading ──────────────────────────────────────────────
      debugPrint('[LabUpload] Processing file ${index + 1}: ${state.file.name}');
      setState(() => state.uploaded = _TickState.active);

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: state.file.name,
        ),
        if (person != 'self') 'family_member_id': person,
      });

      bool uploadDone = false;

      final response = await apiClient.dio.post(
        ApiConstants.labUpload,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 300),
          receiveTimeout: const Duration(seconds: 300),
        ),
        onSendProgress: (sent, total) {
          if (!uploadDone && total > 0 && sent >= total) {
            uploadDone = true;
            if (mounted) {
              setState(() {
                state.uploaded = _TickState.done;
                // ── Tick 2: Analysing ────────────────────────────────────
                state.analysed = _TickState.active;
              });
            }
          }
        },
      );

      // Ensure upload tick is done even if onSendProgress didn't fire
      if (state.uploaded != _TickState.done) {
        setState(() {
          state.uploaded = _TickState.done;
          state.analysed = _TickState.active;
        });
      }

      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';

      if (status == 'completed') {
        debugPrint('[LabUpload] File ${index + 1} analysed: ${data['saved_count']} biomarkers');
        setState(() {
          state.analysed = _TickState.done;
          state.savedCount = data['saved_count'] as int? ?? 0;
          state.labProvider = data['lab_provider'] as String?;
          // Tick 3 (Ready) set after all files processed + provider invalidation
          state.ready = _TickState.active;
        });
      } else {
        debugPrint('[LabUpload] File ${index + 1} failed: ${data['detail']}');
        setState(() {
          state.analysed = _TickState.error;
          state.errorMessage =
              data['detail'] as String? ?? 'Analysis failed';
        });
      }
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString()
          : e.message;
      debugPrint('[LabUpload] File ${index + 1} DioException: $detail '
          '(status=${e.response?.statusCode}, type=${e.type})');

      setState(() {
        if (state.uploaded == _TickState.active) {
          state.uploaded = _TickState.error;
        } else {
          state.analysed = _TickState.error;
        }
        state.errorMessage = detail ?? 'Connection error';
      });
    } catch (e) {
      debugPrint('[LabUpload] File ${index + 1} error: $e');
      setState(() {
        if (state.uploaded == _TickState.active) {
          state.uploaded = _TickState.error;
        } else {
          state.analysed = _TickState.error;
        }
        state.errorMessage = e.toString();
      });
    }
  }
}

// ── File Card with 3 Ticks ───────────────────────────────────────────────────

class _FileTickCard extends StatelessWidget {
  final _FileProcessState state;
  final bool showTicks;
  final VoidCallback? onRemove;

  const _FileTickCard({
    super.key,
    required this.state,
    required this.showTicks,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isPdf = state.file.name.toLowerCase().endsWith('.pdf');
    final sizeKb = state.file.size / 1024;
    final sizeStr = sizeKb >= 1024
        ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
        : '${sizeKb.toStringAsFixed(0)} KB';
    final hasError = state.uploaded == _TickState.error ||
        state.analysed == _TickState.error;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cs.surfaceContainerLow,
        border: Border.all(
          color: hasError
              ? cs.error.withValues(alpha: 0.3)
              : (state.uploaded == _TickState.active ||
                      state.analysed == _TickState.active)
                  ? cs.primary.withValues(alpha: 0.25)
                  : state.ready == _TickState.done
                      ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                      : cs.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon + name + remove/status ─────────────────────
            Row(
              children: [
                // File type badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isPdf
                          ? [
                              const Color(0xFFEF4444)
                                  .withValues(alpha: 0.12),
                              const Color(0xFFDC2626)
                                  .withValues(alpha: 0.08),
                            ]
                          : [
                              const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.12),
                              const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.08),
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
                        size: 18,
                      ),
                      Text(
                        isPdf ? 'PDF' : 'IMG',
                        style: TextStyle(
                          fontSize: 7,
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

                // Name + size + result info
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
                      if (hasError)
                        Text(
                          state.errorMessage ?? 'Failed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              tt.bodySmall?.copyWith(color: cs.error),
                        )
                      else if (state.analysed == _TickState.done)
                        Text(
                          '${state.savedCount} biomarkers'
                          '${state.labProvider != null ? ' \u2022 ${state.labProvider}' : ''}',
                          style: tt.bodySmall?.copyWith(
                            color: const Color(0xFF16A34A),
                          ),
                        )
                      else
                        Text(
                          sizeStr,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),

                // Remove button (only before processing)
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: Icon(Icons.remove_circle_rounded,
                        color: cs.error.withValues(alpha: 0.6),
                        size: 22),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
              ],
            ),

            // ── 3-tick progress row ──────────────────────────────────────
            if (showTicks) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _TickIndicator(
                    label: 'Uploaded',
                    state: state.uploaded,
                    color: const Color(0xFF16A34A),
                  ),
                  _buildTickConnector(state.uploaded),
                  _TickIndicator(
                    label: 'Analysed',
                    state: state.analysed,
                    color: const Color(0xFF2563EB),
                  ),
                  _buildTickConnector(state.analysed),
                  _TickIndicator(
                    label: 'Ready',
                    state: state.ready,
                    color: const Color(0xFF9333EA),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTickConnector(_TickState tickState) {
    final Color color;
    if (tickState == _TickState.done) {
      color = const Color(0xFF16A34A).withValues(alpha: 0.4);
    } else if (tickState == _TickState.error) {
      color = const Color(0xFFEF4444).withValues(alpha: 0.3);
    } else {
      color = const Color(0xFFD1D5DB);
    }

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14),
        color: color,
      ),
    );
  }
}

// ── Individual Tick Indicator ─────────────────────────────────────────────────

class _TickIndicator extends StatelessWidget {
  final String label;
  final _TickState state;
  final Color color;

  const _TickIndicator({
    required this.label,
    required this.state,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: _buildIcon(cs),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: state == _TickState.done
                ? color
                : state == _TickState.error
                    ? cs.error
                    : state == _TickState.active
                        ? cs.primary
                        : cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(ColorScheme cs) {
    switch (state) {
      case _TickState.pending:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
        );
      case _TickState.active:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: color,
          ),
        );
      case _TickState.done:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: Colors.white,
          ),
        );
      case _TickState.error:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.error,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 16,
            color: Colors.white,
          ),
        );
    }
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
                          const TextInputType.numberWithOptions(
                              decimal: true),
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
                    icon: Icon(Icons.remove_circle_outline,
                        color: cs.error),
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
                      child:
                          CircularProgressIndicator(strokeWidth: 2))
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
