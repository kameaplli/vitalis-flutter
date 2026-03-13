import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
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

  SkinPhoto({
    required this.id,
    required this.photoUrl,
    this.bodyRegion,
    this.severityAi,
    this.severityUser,
    this.notes,
    this.takenAt,
  });

  factory SkinPhoto.fromJson(Map<String, dynamic> json) => SkinPhoto(
        id: json['id'] as String? ?? '',
        photoUrl: json['photo_url'] as String? ?? '',
        bodyRegion: json['body_region'] as String?,
        severityAi: (json['severity_ai'] as num?)?.toDouble(),
        severityUser: json['severity_user'] as int?,
        notes: json['notes'] as String?,
        takenAt: json['taken_at'] as String?,
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

  Future<void> _takePhoto(ImageSource source) async {
    final img = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 80);
    if (img == null) return;

    final bytes = await img.readAsBytes();
    final person = ref.read(selectedPersonProvider);

    setState(() => _uploading = true);
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'skin.jpg'),
        'severity_user': _severity,
        if (person != 'self') 'family_member_id': person,
      });
      await apiClient.dio.post(
        '${ApiConstants.skinPhotoUpload}?severity_user=$_severity'
            '${person != 'self' ? '&family_member_id=$person' : ''}',
        data: formData,
      );
      ref.invalidate(skinPhotosProvider(person));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, context: 'skin photos'))));
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
      appBar: AppBar(title: const Text('Skin Photos')),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4,
            ),
            itemCount: photos.length,
            itemBuilder: (ctx, i) {
              final photo = photos[i];
              final url = ApiConstants.resolveUrl(photo.photoUrl);
              return GestureDetector(
                onTap: () => _showPhotoDetail(context, photo),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.grey[200]),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                      if (photo.severityUser != null)
                        Positioned(
                          bottom: 4, right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('${photo.severityUser}/10',
                                style: const TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Severity: $_severity/10',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Slider(
                value: _severity.toDouble(),
                min: 0, max: 10, divisions: 10,
                label: '$_severity',
                onChanged: (v) => setState(() => _severity = v.round()),
              ),
              const SizedBox(height: 8),
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
    );
  }

  void _showPhotoDetail(BuildContext context, SkinPhoto photo) {
    final url = ApiConstants.resolveUrl(photo.photoUrl);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (photo.takenAt != null)
                    Text(photo.takenAt!.substring(0, 10),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (photo.severityUser != null)
                    Text('Severity: ${photo.severityUser}/10',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (photo.bodyRegion != null)
                    Text('Zone: ${photo.bodyRegion}',
                        style: const TextStyle(fontSize: 12)),
                  if (photo.notes != null && photo.notes!.isNotEmpty)
                    Text(photo.notes!, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
