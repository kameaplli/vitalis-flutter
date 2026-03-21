import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/skin_analysis_data.dart';
import '../providers/selected_person_provider.dart';
import '../widgets/friendly_error.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class SkinPhoto {
  final String id;
  final String photoUrl;
  final String? bodyRegion;
  final double? severityAi;
  final int? severityUser;
  final String? notes;
  final String? takenAt;
  final bool hasAnalysis;
  final AnalysisSummary? analysisSummary;

  SkinPhoto({
    required this.id,
    required this.photoUrl,
    this.bodyRegion,
    this.severityAi,
    this.severityUser,
    this.notes,
    this.takenAt,
    this.hasAnalysis = false,
    this.analysisSummary,
  });

  factory SkinPhoto.fromJson(Map<String, dynamic> json) => SkinPhoto(
        id: json['id'] as String? ?? '',
        photoUrl: json['photo_url'] as String? ?? '',
        bodyRegion: json['body_region'] as String?,
        severityAi: (json['severity_ai'] as num?)?.toDouble(),
        severityUser: json['severity_user'] as int?,
        notes: json['notes'] as String?,
        takenAt: json['taken_at'] as String?,
        hasAnalysis: json['has_analysis'] == true,
        analysisSummary: json['analysis_summary'] != null
            ? AnalysisSummary.fromJson(json['analysis_summary'] as Map<String, dynamic>)
            : null,
      );
}

// ── Provider ─────────────────────────────────────────────────────────────────

final skinPhotosProvider = FutureProvider.family<List<SkinPhoto>, String>((ref, person) async {
  try {
    final qp = <String, dynamic>{'days': 180};
    if (person != 'self') qp['family_member_id'] = person;
    final res = await apiClient.dio.get(ApiConstants.skinPhotos, queryParameters: qp);
    return (res.data as List<dynamic>)
        .map((e) => SkinPhoto.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Screen ───────────────────────────────────────────────────────────────────

class SkinPhotosScreen extends ConsumerStatefulWidget {
  const SkinPhotosScreen({super.key});

  @override
  ConsumerState<SkinPhotosScreen> createState() => _SkinPhotosScreenState();
}

class _SkinPhotosScreenState extends ConsumerState<SkinPhotosScreen> {
  bool _uploading = false;
  int _severity = 5;
  int _columns = 3;

  Future<void> _takePhoto(ImageSource source) async {
    final img = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 80);
    if (img == null) return;

    final bytes = await img.readAsBytes();
    final person = ref.read(selectedPersonProvider);

    setState(() => _uploading = true);
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'skin.jpg'),
      });
      await apiClient.dio.post(
        '${ApiConstants.skinAnalyzeUpload}?severity_user=$_severity&auto_analyze=true'
            '${person != 'self' ? '&family_member_id=$person' : ''}',
        data: formData,
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );
      ref.invalidate(skinPhotosProvider(person));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo saved & analyzed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyErrorMessage(e, context: 'skin photos'))));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final photosAsync = ref.watch(skinPhotosProvider(person));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Intelligence'),
        actions: [
          IconButton(
            icon: Icon(_columns == 3 ? Icons.grid_view : Icons.view_module),
            tooltip: _columns == 3 ? 'Medium tiles' : 'Small tiles',
            onPressed: () => setState(() => _columns = _columns == 3 ? 2 : 3),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : () => _showUploadSheet(context),
        child: _uploading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_a_photo),
      ),
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => FriendlyError(error: e, context: 'skin photos'),
        data: (photos) {
          if (photos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_camera_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No skin photos yet', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('Take photos to track your skin over time',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              crossAxisSpacing: _columns == 2 ? 6 : 4,
              mainAxisSpacing: _columns == 2 ? 6 : 4,
            ),
            itemCount: photos.length,
            itemBuilder: (ctx, i) => _PhotoTile(
              photo: photos[i],
              columns: _columns,
              onTap: () => _showPhotoDetail(context, photos[i], photos),
            ),
          );
        },
      ),
    );
  }

  Color _severityColor(int severity) {
    if (severity <= 3) return Colors.green;
    if (severity <= 6) return Colors.orange;
    return Colors.redAccent;
  }

  String _severityLabel(int s) {
    if (s == 0) return 'Clear';
    if (s <= 2) return 'Mild';
    if (s <= 4) return 'Moderate';
    if (s <= 6) return 'Noticeable';
    if (s <= 8) return 'Severe';
    return 'Very Severe';
  }

  String _severityHint(int s) {
    if (s == 0) return 'No visible irritation';
    if (s <= 2) return 'Slight redness, barely noticeable';
    if (s <= 4) return 'Visible redness, mild itch or dryness';
    if (s <= 6) return 'Clear patches, regular itch or flaking';
    if (s <= 8) return 'Widespread, painful or very itchy';
    return 'Extreme flare-up, urgent attention needed';
  }

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How does your skin look today?',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$_severity',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800,
                          color: _severityColor(_severity))),
                    const Text('/10', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _severityColor(_severity).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_severityLabel(_severity),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                            color: _severityColor(_severity))),
                    ),
                  ],
                ),
                Slider(
                  value: _severity.toDouble(), min: 0, max: 10, divisions: 10,
                  activeColor: _severityColor(_severity),
                  onChanged: (v) {
                    setState(() => _severity = v.round());
                    setSheetState(() {});
                  },
                ),
                Text(_severityHint(_severity),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0 Clear', style: TextStyle(fontSize: 10, color: Colors.green.shade600)),
                      Text('5 Moderate', style: TextStyle(fontSize: 10, color: Colors.orange.shade600)),
                      Text('10 Severe', style: TextStyle(fontSize: 10, color: Colors.red.shade600)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('AI will automatically analyze the photo for severity scoring',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _takePhoto(ImageSource.camera);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _takePhoto(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPhotoDetail(BuildContext context, SkinPhoto photo, List<SkinPhoto> allPhotos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollCtrl) => _PhotoDetailSheet(
          photo: photo,
          allPhotos: allPhotos,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }
}

// ── Photo Grid Tile ──────────────────────────────────────────────────────────

class _PhotoTile extends StatelessWidget {
  final SkinPhoto photo;
  final int columns;
  final VoidCallback onTap;

  const _PhotoTile({required this.photo, required this.columns, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = ApiConstants.resolveUrl(photo.photoUrl);
    final hasAi = photo.hasAnalysis && photo.analysisSummary != null;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url, fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey[200]),
              errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (photo.takenAt != null && photo.takenAt!.length >= 10)
                      Text(photo.takenAt!.substring(5, 10),
                          style: TextStyle(fontSize: columns == 2 ? 12 : 10, color: Colors.white70))
                    else
                      const SizedBox.shrink(),
                    if (hasAi)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _aiColor(photo.analysisSummary!.overallSeverity),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(photo.analysisSummary!.overallSeverity.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    else if (photo.severityUser != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _userColor(photo.severityUser!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${photo.severityUser}/10',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ),
            if (!hasAi)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black38, borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 12, color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _aiColor(double s) {
    if (s <= 2) return Colors.green;
    if (s <= 4) return Colors.lime.shade700;
    if (s <= 6) return Colors.orange;
    return Colors.redAccent;
  }

  Color _userColor(int s) {
    if (s <= 3) return Colors.green;
    if (s <= 6) return Colors.orange;
    return Colors.redAccent;
  }
}

// ── Photo Detail Sheet ───────────────────────────────────────────────────────

class _PhotoDetailSheet extends ConsumerStatefulWidget {
  final SkinPhoto photo;
  final List<SkinPhoto> allPhotos;
  final ScrollController scrollController;

  const _PhotoDetailSheet({
    required this.photo,
    required this.allPhotos,
    required this.scrollController,
  });

  @override
  ConsumerState<_PhotoDetailSheet> createState() => _PhotoDetailSheetState();
}

class _PhotoDetailSheetState extends ConsumerState<_PhotoDetailSheet> {
  SkinAnalysis? _analysis;
  bool _analyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.photo.hasAnalysis) {
      _loadExistingAnalysis();
    }
  }

  Future<void> _loadExistingAnalysis() async {
    try {
      final resp = await apiClient.dio.get(
        ApiConstants.skinAnalyses,
        queryParameters: {'photo_id': widget.photo.id},
      );
      final list = resp.data as List;
      if (list.isNotEmpty && mounted) {
        setState(() {
          _analysis = SkinAnalysis.fromJson(list.first as Map<String, dynamic>);
        });
      }
    } catch (_) {}
  }

  Future<void> _analyzePhoto({String? compareToId}) async {
    setState(() { _analyzing = true; _error = null; });
    try {
      final resp = await apiClient.dio.post(
        ApiConstants.skinAnalyze,
        data: {
          'photo_id': widget.photo.id,
          if (compareToId != null) 'compare_to_id': compareToId,
        },
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );
      if (mounted) {
        setState(() {
          _analysis = SkinAnalysis.fromJson(resp.data as Map<String, dynamic>);
          _analyzing = false;
        });
        final person = ref.read(selectedPersonProvider);
        ref.invalidate(skinPhotosProvider(person));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e, context: 'skin analysis');
          _analyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = ApiConstants.resolveUrl(widget.photo.photoUrl);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Photo
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),

          // Photo metadata
          Row(
            children: [
              if (widget.photo.takenAt != null)
                Text(widget.photo.takenAt!.substring(0, 10),
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const Spacer(),
              if (widget.photo.severityUser != null)
                Text('Self-rated: ${widget.photo.severityUser}/10',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
          ),
          if (widget.photo.notes != null && widget.photo.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(widget.photo.notes!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],

          const SizedBox(height: 16),

          // Analysis section
          if (_analyzing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Analyzing skin photo...', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('AI is evaluating severity components', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            )
          else if (_error != null)
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _analyzePhoto, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else if (_analysis != null)
            _AnalysisResultCard(analysis: _analysis!)
          else
            // No analysis yet — show analyze button
            FilledButton.icon(
              onPressed: _analyzePhoto,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Analyze with AI'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

          // Compare button
          if (_analysis != null && widget.allPhotos.length > 1) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showCompareDialog(),
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Compare with another photo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          // Disclaimer
          if (_analysis != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                _analysis!.disclaimer,
                style: TextStyle(fontSize: 10, color: cs.error),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showCompareDialog() {
    final others = widget.allPhotos.where((p) => p.id != widget.photo.id).toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compare with...'),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: ListView.builder(
            itemCount: others.length,
            itemBuilder: (ctx, i) {
              final p = others[i];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: ApiConstants.resolveUrl(p.photoUrl),
                    width: 48, height: 48, fit: BoxFit.cover,
                  ),
                ),
                title: Text(p.takenAt?.substring(0, 10) ?? 'Unknown date'),
                subtitle: p.severityUser != null ? Text('Self-rated: ${p.severityUser}/10') : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _analyzePhoto(compareToId: p.id);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Analysis Result Card ─────────────────────────────────────────────────────

class _AnalysisResultCard extends StatelessWidget {
  final SkinAnalysis analysis;
  const _AnalysisResultCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sevColor = Color(analysis.severityColorValue);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('AI Analysis', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (analysis.confidence != null)
                  Text('${(analysis.confidence! * 100).round()}% confident',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
            const Divider(height: 20),

            // Overall severity
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sevColor.withValues(alpha: 0.15),
                    border: Border.all(color: sevColor, width: 2.5),
                  ),
                  child: Center(
                    child: Text(
                      analysis.overallSeverity.toStringAsFixed(1),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: sevColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(analysis.severityLabel,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: sevColor)),
                      if (analysis.affectedAreaPct != null)
                        Text('${analysis.affectedAreaPct!.round()}% area affected',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      if (analysis.patternType != null && analysis.patternType != 'clear')
                        Text('Pattern: ${analysis.patternType}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Component bars
            Text('EASI Components', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            ...analysis.components.entries.map((e) => _ComponentBar(name: e.key, value: e.value)),

            // Conditions
            if (analysis.conditions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Detected Conditions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 4,
                children: analysis.conditions.map((c) => Chip(
                  label: Text('${c.name} (${(c.confidence * 100).round()}%)',
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],

            // Description
            if (analysis.description != null && analysis.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(analysis.description!, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],

            // Recommendations
            if (analysis.recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Recommendations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              ...analysis.recommendations.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('  \u2022 ', style: TextStyle(color: cs.primary)),
                    Expanded(child: Text(r, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              )),
            ],

            // Comparison result
            if (analysis.comparison != null) ...[
              const SizedBox(height: 16),
              _ComparisonResult(comparison: analysis.comparison!),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Component Bar ────────────────────────────────────────────────────────────

class _ComponentBar extends StatelessWidget {
  final String name;
  final double value;
  const _ComponentBar({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = (value / 3.0).clamp(0.0, 1.0);
    final color = fraction <= 0.33
        ? Colors.green
        : fraction <= 0.66
            ? Colors.orange
            : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(name, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(value.toStringAsFixed(1),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

// ── Comparison Result ────────────────────────────────────────────────────────

class _ComparisonResult extends StatelessWidget {
  final SkinComparison comparison;
  const _ComparisonResult({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final improving = comparison.changeScore < -0.5;
    final worsening = comparison.changeScore > 0.5;
    final color = improving ? Colors.green : worsening ? Colors.redAccent : Colors.grey;
    final icon = improving ? Icons.trending_down : worsening ? Icons.trending_up : Icons.trending_flat;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, size: 16, color: color),
              const SizedBox(width: 6),
              Text('Comparison', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              const Spacer(),
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 4),
              Text(comparison.changeLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          if (comparison.changeSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comparison.changeSummary, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 4),
          Text('Change score: ${comparison.changeScore > 0 ? "+" : ""}${comparison.changeScore.toStringAsFixed(1)}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
