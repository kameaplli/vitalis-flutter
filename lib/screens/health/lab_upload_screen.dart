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

enum _TickState { pending, active, done, error, skipped }

class _FileProcessState {
  final PlatformFile file;
  _TickState uploaded;
  _TickState analysed;
  _TickState ready;
  String? errorMessage;
  int savedCount;
  String? labProvider;
  String? reportId; // backend report ID (for deletion)
  bool processing; // currently being processed
  CancelToken? cancelToken;

  _FileProcessState({required this.file})
      : uploaded = _TickState.pending,
        analysed = _TickState.pending,
        ready = _TickState.pending,
        savedCount = 0,
        processing = false;

  bool get isIdle => uploaded == _TickState.pending && !processing;
  bool get isDone => ready == _TickState.done;
  bool get isFailed =>
      uploaded == _TickState.error || analysed == _TickState.error;
  bool get isSkipped =>
      uploaded == _TickState.skipped ||
      analysed == _TickState.skipped ||
      ready == _TickState.skipped;
  bool get isTerminal => isDone || isFailed || isSkipped;

  void reset() {
    uploaded = _TickState.pending;
    analysed = _TickState.pending;
    ready = _TickState.pending;
    errorMessage = null;
    savedCount = 0;
    labProvider = null;
    reportId = null;
    processing = false;
    cancelToken = null;
  }
}

// ── Main Screen ──────────────────────────────────────────────────────────────

class LabUploadScreen extends ConsumerStatefulWidget {
  const LabUploadScreen({super.key});

  @override
  ConsumerState<LabUploadScreen> createState() => _LabUploadScreenState();
}

class _LabUploadScreenState extends ConsumerState<LabUploadScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final _notesController = TextEditingController();
  final List<_FileProcessState> _files = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('[LabUpload] ===== SCREEN INIT v5 =====');
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // Cancel any in-flight uploads
    for (final f in _files) {
      f.cancelToken?.cancel('Screen disposed');
    }
    _tabController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Computed properties
  int get _doneCount => _files.where((f) => f.isDone).length;
  int get _failedCount => _files.where((f) => f.isFailed).length;
  int get _processingCount => _files.where((f) => f.processing).length;
  bool get _anyProcessing => _processingCount > 0;
  bool get _anyDone => _doneCount > 0;
  bool get _allTerminal =>
      _files.isNotEmpty && _files.every((f) => f.isTerminal);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Results'),
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
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hasFiles
                                  ? 'Tap to add more files'
                                  : 'Select your reports',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
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
                          if (_anyProcessing || _anyDone) ...[
                            const SizedBox(width: 8),
                            _buildSummaryChips(),
                          ],
                          const Spacer(),
                          // Start all idle files
                          if (_files.any((f) => f.isIdle))
                            TextButton.icon(
                              onPressed: _anyProcessing ? null : _startAll,
                              icon: Icon(Icons.play_arrow_rounded,
                                  size: 18, color: cs.primary),
                              label: Text('Start All',
                                  style: TextStyle(
                                      color: cs.primary, fontSize: 12)),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                              ),
                            ),
                          if (!_anyProcessing &&
                              _files.every((f) => f.isIdle))
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

                // ── Legend ────────────────────────────────────────────────
                if (hasFiles)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Row(
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
                    ),
                  ),

                // ── File cards with per-file controls ────────────────────
                if (hasFiles)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: _files.length,
                      itemBuilder: (context, i) {
                        final f = _files[i];
                        return _FileTickCard(
                          key: ValueKey(
                              '${f.file.path}_${f.uploaded}_${f.analysed}_${f.ready}_${f.processing}'),
                          state: f,
                          onRemove: f.processing
                              ? null
                              : () => _removeFile(i),
                          onStart: f.isIdle
                              ? () => _startSingle(i)
                              : null,
                          onSkip: f.isIdle
                              ? () => _skipFile(i)
                              : null,
                          onCancel: f.processing
                              ? () => _cancelFile(i)
                              : null,
                          onRetry: f.isFailed
                              ? () => _retryFile(i)
                              : null,
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

          // ── Bottom bar: View Dashboard (only when at least one done) ──
          if (_anyDone)
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
                  onPressed: () {
                    // Invalidate dashboard before navigating
                    final person = ref.read(selectedPersonProvider);
                    ref.invalidate(labDashboardProvider(person));
                    ref.invalidate(labReportsProvider(person));
                    context.pop();
                  },
                  icon: const Icon(Icons.dashboard_rounded, size: 20),
                  label: Text(
                    _allTerminal
                        ? 'View Dashboard'
                        : 'View Dashboard ($_doneCount done)',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
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
    final tt = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_doneCount > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
            ),
            child: Text(
              '$_doneCount done',
              style: tt.labelSmall?.copyWith(
                color: const Color(0xFF16A34A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (_failedCount > 0) ...[
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
              '$_failedCount failed',
              style: tt.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (_processingCount > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.12),
            ),
            child: Text(
              '$_processingCount processing',
              style: tt.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
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
    debugPrint('[LabUpload] _pickFiles called, opening picker...');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'jpg', 'jpeg', 'png', 'tiff', 'bmp', 'webp'
      ],
      allowMultiple: true,
    );
    debugPrint(
        '[LabUpload] Picker returned: ${result?.files.length ?? 0} files');
    if (result == null || result.files.isEmpty) return;
    if (!mounted) {
      debugPrint('[LabUpload] WARNING: not mounted after picker!');
      return;
    }

    setState(() {
      for (final file in result.files) {
        if (!_files.any((f) => f.file.path == file.path)) {
          _files.add(_FileProcessState(file: file));
        }
      }
      debugPrint(
          '[LabUpload] Files now: ${_files.length} — ${_files.map((f) => f.file.name).join(', ')}');
    });
  }

  // ── Per-file actions ───────────────────────────────────────────────────────

  void _removeFile(int index) {
    final f = _files[index];
    f.cancelToken?.cancel('Removed');

    // If this file was already saved to backend, delete the report
    if (f.reportId != null) {
      apiClient.dio.delete(ApiConstants.labReport(f.reportId!)).then((_) {
        final person = ref.read(selectedPersonProvider);
        ref.invalidate(labDashboardProvider(person));
        ref.invalidate(labReportsProvider(person));
      }).catchError((_) {}); // silent — best effort
    }

    setState(() => _files.removeAt(index));
  }

  void _skipFile(int index) {
    setState(() {
      final f = _files[index];
      f.uploaded = _TickState.skipped;
      f.analysed = _TickState.skipped;
      f.ready = _TickState.skipped;
    });
  }

  void _cancelFile(int index) {
    final f = _files[index];
    f.cancelToken?.cancel('Cancelled by user');
    setState(() {
      f.processing = false;
      if (f.uploaded == _TickState.active) {
        f.uploaded = _TickState.error;
        f.errorMessage = 'Cancelled';
      } else if (f.analysed == _TickState.active) {
        f.analysed = _TickState.error;
        f.errorMessage = 'Cancelled';
      }
    });
  }

  void _retryFile(int index) {
    setState(() => _files[index].reset());
    _startSingle(index);
  }

  Future<void> _startSingle(int index) async {
    if (_files[index].processing) return;
    final person = ref.read(selectedPersonProvider);
    await _processFile(index, person);
    _onFileCompleted();
  }

  Future<void> _startAll() async {
    final person = ref.read(selectedPersonProvider);
    final idleIndexes = <int>[];
    for (int i = 0; i < _files.length; i++) {
      if (_files[i].isIdle) idleIndexes.add(i);
    }

    for (final i in idleIndexes) {
      if (!mounted) return;
      await _processFile(i, person);
    }
    _onFileCompleted();
  }

  void _onFileCompleted() {
    if (!mounted) return;
    // Invalidate providers if any files succeeded
    if (_anyDone) {
      final person = ref.read(selectedPersonProvider);
      ref.invalidate(labDashboardProvider(person));
      ref.invalidate(labReportsProvider(person));

      final totalSaved = _files
          .where((f) => f.isDone)
          .fold(0, (sum, f) => sum + f.savedCount);
      NotificationService.showLabAnalysisComplete(resultsCount: totalSaved)
          .catchError((_) {});
    }
    setState(() {}); // refresh UI
  }

  // ── Processing pipeline (per file) ─────────────────────────────────────────

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

    state.cancelToken = CancelToken();
    setState(() {
      state.processing = true;
      state.uploaded = _TickState.active;
    });

    try {
      debugPrint(
          '[LabUpload] Processing file ${index + 1}: ${state.file.name}');

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
        cancelToken: state.cancelToken,
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

      final rawData = response.data;
      if (rawData == null || rawData is! Map<String, dynamic>) {
        debugPrint(
            '[LabUpload] File ${index + 1} unexpected response: $rawData');
        setState(() {
          state.analysed = _TickState.error;
          state.errorMessage = 'Unexpected server response';
          state.processing = false;
        });
        return;
      }
      final data = rawData;
      final status = data['status'] as String? ?? '';

      if (status == 'completed') {
        final prevCount = data['previous_saved_count'] as int? ?? 0;
        final prevDate = data['previous_date'] as String?;
        debugPrint(
            '[LabUpload] File ${index + 1} analysed: ${data['saved_count']} biomarkers'
            '${prevCount > 0 ? ' + $prevCount previous ($prevDate)' : ''}'
            '${data['duplicate'] == true ? ' (duplicate)' : ''}');
        setState(() {
          state.analysed = _TickState.done;
          state.savedCount = (data['saved_count'] as int? ?? 0) + prevCount;
          state.labProvider = data['lab_provider'] as String?;
          state.reportId = data['report_id'] as String?;
          state.ready = _TickState.done;
          state.processing = false;
        });
      } else {
        debugPrint(
            '[LabUpload] File ${index + 1} failed: ${data['detail']}');
        setState(() {
          state.analysed = _TickState.error;
          state.errorMessage =
              data['detail'] as String? ?? 'Analysis failed';
          state.processing = false;
        });
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('[LabUpload] File ${index + 1} cancelled');
        // Already handled in _cancelFile
        return;
      }
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
        state.processing = false;
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
        state.processing = false;
      });
    }
  }
}

// ── File Card with 3 Ticks + Per-File Controls ──────────────────────────────

class _FileTickCard extends StatelessWidget {
  final _FileProcessState state;
  final VoidCallback? onRemove;
  final VoidCallback? onStart;
  final VoidCallback? onSkip;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const _FileTickCard({
    super.key,
    required this.state,
    this.onRemove,
    this.onStart,
    this.onSkip,
    this.onCancel,
    this.onRetry,
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
    final hasError = state.isFailed;
    final isSkipped = state.isSkipped;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isSkipped
            ? cs.surfaceContainerLow.withValues(alpha: 0.5)
            : cs.surfaceContainerLow,
        border: Border.all(
          color: hasError
              ? cs.error.withValues(alpha: 0.3)
              : state.processing
                  ? cs.primary.withValues(alpha: 0.25)
                  : state.isDone
                      ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                      : isSkipped
                          ? cs.outlineVariant.withValues(alpha: 0.1)
                          : cs.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon + name + actions ──────────────────────────
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
                                  .withValues(alpha: isSkipped ? 0.06 : 0.12),
                              const Color(0xFFDC2626)
                                  .withValues(alpha: isSkipped ? 0.04 : 0.08),
                            ]
                          : [
                              const Color(0xFF8B5CF6)
                                  .withValues(alpha: isSkipped ? 0.06 : 0.12),
                              const Color(0xFF7C3AED)
                                  .withValues(alpha: isSkipped ? 0.04 : 0.08),
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
                        color: (isPdf
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF8B5CF6))
                            .withValues(alpha: isSkipped ? 0.4 : 1.0),
                        size: 18,
                      ),
                      Text(
                        isPdf ? 'PDF' : 'IMG',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: (isPdf
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF8B5CF6))
                              .withValues(alpha: isSkipped ? 0.4 : 1.0),
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
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSkipped
                              ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                              : null,
                        ),
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
                      else if (isSkipped)
                        Text(
                          'Skipped',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant
                                .withValues(alpha: 0.4),
                            fontStyle: FontStyle.italic,
                          ),
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

                // ── Per-file action buttons ────────────────────────────
                _buildActionButtons(cs),
              ],
            ),

            // ── 3-tick progress row ──────────────────────────────────────
            if (!state.isIdle || state.processing || state.isTerminal) ...[
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

  Widget _buildActionButtons(ColorScheme cs) {
    // Processing: show cancel button
    if (state.processing) {
      return IconButton(
        onPressed: onCancel,
        icon: Icon(Icons.cancel_rounded,
            color: cs.error.withValues(alpha: 0.7), size: 24),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        tooltip: 'Cancel',
      );
    }

    // Failed: show retry + remove
    if (state.isFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onRetry,
            icon: Icon(Icons.refresh_rounded,
                color: cs.primary, size: 22),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Retry',
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.remove_circle_rounded,
                color: cs.error.withValues(alpha: 0.5), size: 20),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            tooltip: 'Remove',
          ),
        ],
      );
    }

    // Done or skipped: just remove
    if (state.isDone || state.isSkipped) {
      return IconButton(
        onPressed: onRemove,
        icon: Icon(Icons.remove_circle_rounded,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3), size: 20),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        tooltip: 'Remove',
      );
    }

    // Idle: show start + skip + remove
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onStart,
          icon: Icon(Icons.play_circle_rounded,
              color: cs.primary, size: 28),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          tooltip: 'Analyse',
        ),
        IconButton(
          onPressed: onSkip,
          icon: Icon(Icons.skip_next_rounded,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5), size: 22),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
          tooltip: 'Skip',
        ),
        IconButton(
          onPressed: onRemove,
          icon: Icon(Icons.remove_circle_rounded,
              color: cs.error.withValues(alpha: 0.5), size: 20),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
          tooltip: 'Remove',
        ),
      ],
    );
  }

  Widget _buildTickConnector(_TickState tickState) {
    final Color color;
    if (tickState == _TickState.done) {
      color = const Color(0xFF16A34A).withValues(alpha: 0.4);
    } else if (tickState == _TickState.error) {
      color = const Color(0xFFEF4444).withValues(alpha: 0.3);
    } else if (tickState == _TickState.skipped) {
      color = const Color(0xFFD1D5DB).withValues(alpha: 0.3);
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
                        : state == _TickState.skipped
                            ? cs.onSurfaceVariant.withValues(alpha: 0.25)
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
      case _TickState.skipped:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.onSurfaceVariant.withValues(alpha: 0.15),
          ),
          child: Icon(
            Icons.remove_rounded,
            size: 16,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
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
          const SnackBar(content: Text('Results saved!')),
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
