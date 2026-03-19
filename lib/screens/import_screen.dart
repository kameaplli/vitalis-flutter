import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/sync_models.dart';
import '../providers/sync_provider.dart';
import '../services/health_import_service.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  int _step = 0; // 0=source, 1=file, 2=preview, 3=importing, 4=summary
  ImportFormat? _selectedFormat;
  String? _filePath;
  String? _fileName;
  String? _jobId;
  int _estimatedCount = 0;
  DateTime? _dateRangeStart;
  DateTime? _dateRangeEnd;
  ImportProgress? _progress;
  bool _cancelled = false;
  String? _errorMessage;

  // History tab
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_showHistory ? 'Import History' : 'Import Health Data'),
        actions: [
          IconButton(
            icon: Icon(_showHistory ? Icons.add_rounded : Icons.history_rounded),
            tooltip: _showHistory ? 'New Import' : 'Import History',
            onPressed: () => setState(() {
              _showHistory = !_showHistory;
              if (!_showHistory) _resetState();
            }),
          ),
        ],
      ),
      body: _showHistory ? _buildHistory(cs, tt) : _buildImportFlow(cs, tt),
    );
  }

  Widget _buildImportFlow(ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        // Step indicator
        _StepIndicator(currentStep: _step, cs: cs, tt: tt),
        const Divider(height: 1),
        // Step content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_step) {
              0 => _buildSourceStep(cs, tt),
              1 => _buildFileStep(cs, tt),
              2 => _buildPreviewStep(cs, tt),
              3 => _buildImportingStep(cs, tt),
              4 => _buildSummaryStep(cs, tt),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    );
  }

  // ── Step 0: Select Source ─────────────────────────────────────────────────

  Widget _buildSourceStep(ColorScheme cs, TextTheme tt) {
    return ListView(
      key: const ValueKey('step0'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Select the source of your health data:',
          style: tt.titleMedium,
        ),
        const SizedBox(height: 16),
        for (final fmt in ImportFormat.values)
          _SourceCard(
            format: fmt,
            isSelected: _selectedFormat == fmt,
            onTap: () => setState(() => _selectedFormat = fmt),
            cs: cs,
            tt: tt,
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _selectedFormat != null ? () => setState(() => _step = 1) : null,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
        ),
      ],
    );
  }

  // ── Step 1: Pick File ─────────────────────────────────────────────────────

  Widget _buildFileStep(ColorScheme cs, TextTheme tt) {
    return ListView(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Select your ${_selectedFormat?.displayName ?? ""} file:',
          style: tt.titleMedium,
        ),
        const SizedBox(height: 8),
        _buildFormatHint(cs, tt),
        const SizedBox(height: 24),
        if (_filePath != null) ...[
          Card(
            child: ListTile(
              leading: Icon(Icons.insert_drive_file_rounded, color: cs.primary),
              title: Text(_fileName ?? 'Selected file'),
              trailing: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() {
                  _filePath = null;
                  _fileName = null;
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(_filePath == null ? 'Choose File' : 'Change File'),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Back'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _filePath != null ? _analyzeFile : null,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Analyze'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 2: Preview ───────────────────────────────────────────────────────

  Widget _buildPreviewStep(ColorScheme cs, TextTheme tt) {
    final dateFmt = DateFormat('MMM d, y');
    return ListView(
      key: const ValueKey('step2'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Import Preview', style: tt.titleMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreviewRow(
                  label: 'Source',
                  value: _selectedFormat?.displayName ?? '',
                ),
                _PreviewRow(label: 'File', value: _fileName ?? ''),
                _PreviewRow(
                  label: 'Estimated Records',
                  value: NumberFormat('#,###').format(_estimatedCount),
                ),
                if (_dateRangeStart != null)
                  _PreviewRow(
                    label: 'Date Range',
                    value:
                        '${dateFmt.format(_dateRangeStart!)} - ${_dateRangeEnd != null ? dateFmt.format(_dateRangeEnd!) : "present"}',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_estimatedCount > 10000)
          Card(
            color: cs.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: cs.onTertiaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Large file detected. Import may take several minutes. '
                      'You can cancel at any time.',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Back'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _startImport,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Import'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 3: Importing ─────────────────────────────────────────────────────

  Widget _buildImportingStep(ColorScheme cs, TextTheme tt) {
    final p = _progress;
    final percent = p != null && p.totalRecords > 0
        ? p.processedCount / p.totalRecords
        : 0.0;

    return ListView(
      key: const ValueKey('step3'),
      padding: const EdgeInsets.all(20),
      children: [
        Text('Importing...', style: tt.titleMedium),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent > 0 ? percent : null,
            minHeight: 12,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          p != null
              ? '${NumberFormat('#,###').format(p.processedCount)} / ${NumberFormat('#,###').format(p.totalRecords)} records'
              : 'Preparing...',
          textAlign: TextAlign.center,
          style: tt.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (p != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewRow(
                    label: 'Inserted',
                    value: NumberFormat('#,###').format(p.insertedCount),
                  ),
                  _PreviewRow(
                    label: 'Skipped (duplicates)',
                    value: NumberFormat('#,###').format(p.skippedCount),
                  ),
                  if (p.errorCount > 0)
                    _PreviewRow(
                      label: 'Errors',
                      value: NumberFormat('#,###').format(p.errorCount),
                    ),
                ],
              ),
            ),
          ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Card(
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _errorMessage!,
                style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _cancelImport,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Cancel Import'),
          style: OutlinedButton.styleFrom(foregroundColor: cs.error),
        ),
      ],
    );
  }

  // ── Step 4: Summary ───────────────────────────────────────────────────────

  Widget _buildSummaryStep(ColorScheme cs, TextTheme tt) {
    final p = _progress;
    final isSuccess = p != null && p.status == 'completed' && p.errorCount == 0;

    return ListView(
      key: const ValueKey('step4'),
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          isSuccess
              ? Icons.check_circle_rounded
              : _cancelled
                  ? Icons.cancel_rounded
                  : Icons.warning_rounded,
          size: 64,
          color: isSuccess
              ? cs.primary
              : _cancelled
                  ? cs.outline
                  : cs.error,
        ),
        const SizedBox(height: 16),
        Text(
          _cancelled
              ? 'Import Cancelled'
              : isSuccess
                  ? 'Import Complete'
                  : 'Import Finished with Issues',
          textAlign: TextAlign.center,
          style: tt.titleLarge,
        ),
        const SizedBox(height: 24),
        if (p != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewRow(
                    label: 'Total Processed',
                    value: NumberFormat('#,###').format(p.processedCount),
                  ),
                  _PreviewRow(
                    label: 'Inserted',
                    value: NumberFormat('#,###').format(p.insertedCount),
                  ),
                  _PreviewRow(
                    label: 'Skipped (duplicates)',
                    value: NumberFormat('#,###').format(p.skippedCount),
                  ),
                  if (p.errorCount > 0)
                    _PreviewRow(
                      label: 'Errors',
                      value: NumberFormat('#,###').format(p.errorCount),
                    ),
                ],
              ),
            ),
          ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Card(
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _errorMessage!,
                style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (p != null && p.insertedCount > 0 && _jobId != null) ...[
          OutlinedButton.icon(
            onPressed: _rollback,
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Undo Import'),
            style: OutlinedButton.styleFrom(foregroundColor: cs.error),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: _resetState,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Import More Data'),
        ),
      ],
    );
  }

  // ── Import History ────────────────────────────────────────────────────────

  Widget _buildHistory(ColorScheme cs, TextTheme tt) {
    final jobsAsync = ref.watch(importJobsProvider);
    return jobsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Failed to load import history: $e',
              textAlign: TextAlign.center),
        ),
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_upload_rounded, size: 64, color: cs.outline),
                const SizedBox(height: 12),
                Text('No imports yet', style: tt.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Import data from Apple Health, MyFitnessPal,\nCronometer, or Fitbit.',
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          itemBuilder: (_, i) => _ImportJobCard(job: jobs[i], cs: cs, tt: tt),
        );
      },
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final file = await HealthImportService.pickFile();
    if (file == null) return;
    if (!mounted) return;

    // Auto-detect format from filename if not already set
    final detected = ImportFormat.fromFilename(file.name);
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
      if (detected != null && _selectedFormat == null) {
        _selectedFormat = detected;
      }
    });
  }

  Future<void> _analyzeFile() async {
    if (_filePath == null || _selectedFormat == null) return;

    // Show a loading indicator
    setState(() {
      _step = 2;
      _estimatedCount = 0;
      _dateRangeStart = null;
      _dateRangeEnd = null;
    });

    try {
      final count = await HealthImportService.estimateRecordCount(
        _filePath!,
        _selectedFormat!,
      );
      final range = await HealthImportService.getDateRange(
        _filePath!,
        _selectedFormat!,
      );
      if (!mounted) return;
      setState(() {
        _estimatedCount = count;
        _dateRangeStart = range.earliest;
        _dateRangeEnd = range.latest;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to analyze file: $e';
      });
    }
  }

  Future<void> _startImport() async {
    if (_filePath == null || _selectedFormat == null) return;

    setState(() {
      _step = 3;
      _cancelled = false;
      _errorMessage = null;
      _progress = ImportProgress(
        jobId: '',
        source: _selectedFormat!.code,
        status: 'pending',
        totalRecords: _estimatedCount,
      );
    });

    try {
      // Upload file to create the import job
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_filePath!, filename: _fileName),
      });
      final resp = await apiClient.dio.post(
        ApiConstants.importUpload,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (resp.statusCode != 200) {
        throw Exception('Upload failed: ${resp.statusCode}');
      }

      _jobId = resp.data['job_id'] as String;

      if (!mounted || _cancelled) return;

      // Process the import
      await HealthImportService.processImport(
        filePath: _filePath!,
        jobId: _jobId!,
        format: _selectedFormat!,
        totalRecords: _estimatedCount,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );

      if (!mounted) return;
      ref.invalidate(importJobsProvider);
      setState(() => _step = 4);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Import failed: $e';
        _step = 4;
        _progress = _progress != null
            ? ImportProgress(
                jobId: _progress!.jobId,
                source: _progress!.source,
                status: 'failed',
                totalRecords: _progress!.totalRecords,
                processedCount: _progress!.processedCount,
                insertedCount: _progress!.insertedCount,
                skippedCount: _progress!.skippedCount,
                errorCount: _progress!.errorCount,
                lastError: e.toString(),
              )
            : null;
      });
    }
  }

  Future<void> _cancelImport() async {
    _cancelled = true;
    if (_jobId != null) {
      try {
        await HealthImportService.cancelImport(_jobId!);
      } catch (_) {}
    }
    if (!mounted) return;
    ref.invalidate(importJobsProvider);
    setState(() => _step = 4);
  }

  Future<void> _rollback() async {
    if (_jobId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo Import?'),
        content: Text(
          'This will remove ${NumberFormat('#,###').format(_progress?.insertedCount ?? 0)} '
          'imported records. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Undo'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final count = await HealthImportService.rollbackImport(_jobId!);
      if (!mounted) return;
      ref.invalidate(importJobsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rolled back $count records')),
      );
      _resetState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rollback failed: $e')),
      );
    }
  }

  void _resetState() {
    setState(() {
      _step = 0;
      _selectedFormat = null;
      _filePath = null;
      _fileName = null;
      _jobId = null;
      _estimatedCount = 0;
      _dateRangeStart = null;
      _dateRangeEnd = null;
      _progress = null;
      _cancelled = false;
      _errorMessage = null;
    });
  }

  Widget _buildFormatHint(ColorScheme cs, TextTheme tt) {
    final hints = switch (_selectedFormat) {
      ImportFormat.appleHealthXml =>
        'Open the Health app on iPhone > Profile > Export All Health Data. '
            'This creates a ZIP file containing export.xml.',
      ImportFormat.mfpCsv =>
        'Log in to MyFitnessPal on the web > Reports > Export Data. '
            'Download the CSV file.',
      ImportFormat.cronometerCsv =>
        'In Cronometer, go to Settings > Account > Export Data. '
            'Select "Servings" or "Daily Nutrition" and download CSV.',
      ImportFormat.fitbitJson =>
        'Go to fitbit.com > Settings > Data Export > Request Data. '
            'Fitbit will email you a JSON archive.',
      _ => '',
    };

    if (hints.isEmpty) return const SizedBox.shrink();

    return Card(
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(hints, style: tt.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step Indicator ──────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final ColorScheme cs;
  final TextTheme tt;

  const _StepIndicator({
    required this.currentStep,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    const steps = ['Source', 'File', 'Preview', 'Import', 'Done'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= currentStep
                      ? cs.primary
                      : cs.surfaceContainerHighest,
                ),
              ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= currentStep ? cs.primary : cs.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: i < currentStep
                  ? Icon(Icons.check_rounded, size: 16, color: cs.onPrimary)
                  : Text(
                      '${i + 1}',
                      style: tt.labelSmall?.copyWith(
                        color: i == currentStep
                            ? cs.onPrimary
                            : cs.onSurfaceVariant,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Source Card ──────────────────────────────────────────────────────────────

class _SourceCard extends StatelessWidget {
  final ImportFormat format;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;

  const _SourceCard({
    required this.format,
    required this.isSelected,
    required this.onTap,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, subtitle) = switch (format) {
      ImportFormat.appleHealthXml => (
          Icons.apple_rounded,
          'XML/ZIP export from Apple Health app'
        ),
      ImportFormat.mfpCsv => (
          Icons.restaurant_menu_rounded,
          'CSV export from MyFitnessPal'
        ),
      ImportFormat.cronometerCsv => (
          Icons.science_rounded,
          'CSV export with 80+ nutrient columns'
        ),
      ImportFormat.fitbitJson => (
          Icons.watch_rounded,
          'JSON archive from Fitbit data export'
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: cs.primary, width: 2)
              : BorderSide.none,
        ),
        color: isSelected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
        child: ListTile(
          leading: Icon(icon, color: isSelected ? cs.primary : cs.onSurfaceVariant),
          title: Text(format.displayName),
          subtitle: Text(subtitle, style: tt.bodySmall),
          trailing: isSelected
              ? Icon(Icons.check_circle_rounded, color: cs.primary)
              : null,
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Preview Row ─────────────────────────────────────────────────────────────

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

// ── Import Job History Card ─────────────────────────────────────────────────

class _ImportJobCard extends StatelessWidget {
  final ImportProgress job;
  final ColorScheme cs;
  final TextTheme tt;

  const _ImportJobCard({
    required this.job,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, y h:mm a');
    final (statusIcon, statusColor, statusLabel) = switch (job.status) {
      'completed' => (Icons.check_circle_rounded, cs.primary, 'Completed'),
      'running' => (Icons.sync_rounded, cs.tertiary, 'Running'),
      'pending' => (Icons.schedule_rounded, cs.outline, 'Pending'),
      'failed' => (Icons.error_rounded, cs.error, 'Failed'),
      'cancelled' => (Icons.cancel_rounded, cs.outline, 'Cancelled'),
      'rolled_back' => (Icons.undo_rounded, cs.outline, 'Rolled Back'),
      _ => (Icons.help_rounded, cs.outline, job.status),
    };

    final sourceLabel = switch (job.source) {
      'apple_health_xml' => 'Apple Health',
      'mfp_csv' => 'MyFitnessPal',
      'cronometer_csv' => 'Cronometer',
      'fitbit_json' => 'Fitbit',
      'csv_generic' => 'CSV Import',
      'json_generic' => 'JSON Import',
      _ => job.source,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, size: 20, color: statusColor),
                const SizedBox(width: 8),
                Text(sourceLabel, style: tt.titleSmall),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: tt.labelSmall?.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Inserted: ${NumberFormat('#,###').format(job.insertedCount)}',
                  style: tt.bodySmall,
                ),
                const SizedBox(width: 16),
                Text(
                  'Skipped: ${NumberFormat('#,###').format(job.skippedCount)}',
                  style: tt.bodySmall,
                ),
                if (job.errorCount > 0) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Errors: ${job.errorCount}',
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ],
              ],
            ),
            if (job.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                dateFmt.format(DateTime.parse(job.createdAt!)),
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
