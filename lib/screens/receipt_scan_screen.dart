import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/grocery_models.dart';
import '../providers/grocery_provider.dart';
import '../providers/selected_person_provider.dart';

class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen> {
  final _picker = ImagePicker();

  File? _image;
  bool  _uploading  = false;
  String? _pollStatus;
  GroceryReceipt? _doneReceipt;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Image pick ─────────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(
      source:    source,
      imageQuality: 85,
      maxWidth:  1200,
      maxHeight: 1600,
    );
    if (xFile == null) return;
    setState(() {
      _image       = File(xFile.path);
      _pollStatus  = null;
      _doneReceipt = null;
    });
  }

  // ── Upload ─────────────────────────────────────────────────────────────────

  Future<void> _upload() async {
    if (_image == null) return;
    setState(() => _uploading = true);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(_image!.path,
            filename: 'receipt.jpg'),
      });
      final res = await apiClient.dio.post(
        ApiConstants.groceryReceipts,
        data: formData,
      );
      final id = res.data['receipt_id'] as String;
      setState(() {
        _pollStatus = 'pending';
        _uploading  = false;
      });
      _startPolling(id);
    } on DioException catch (e) {
      setState(() => _uploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.message}')),
        );
      }
    }
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  void _startPolling(String id) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final res = await apiClient.dio.get(
            '${ApiConstants.groceryReceipts}/$id');
        final receipt = GroceryReceipt.fromJson(
            res.data as Map<String, dynamic>);
        if (!mounted) return;
        setState(() => _pollStatus = receipt.status);
        if (receipt.status == 'done') {
          _pollTimer?.cancel();
          setState(() => _doneReceipt = receipt);
        } else if (receipt.status == 'failed') {
          _pollTimer?.cancel();
        }
      } catch (_) {}
    });
  }

  // ── Confirm (done) ─────────────────────────────────────────────────────────

  void _confirm() {
    final person = ref.read(selectedPersonProvider);
    ref.invalidate(groceryReceiptsProvider(person));
    Navigator.of(context).pop();
  }

  // ── Retry ──────────────────────────────────────────────────────────────────

  void _retry() {
    setState(() {
      _pollStatus  = null;
      _doneReceipt = null;
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    // After done — show parsed items for review
    if (_doneReceipt != null) return _DoneView(receipt: _doneReceipt!, onConfirm: _confirm);

    // After failed
    if (_pollStatus == 'failed') return _FailedView(onRetry: _retry);

    // Processing spinner
    if (_pollStatus != null && _pollStatus != 'done') {
      return _ProcessingView(status: _pollStatus!);
    }

    // Initial / upload flow
    return _PickView(
      image:     _image,
      uploading: _uploading,
      onCamera:  () => _pickImage(ImageSource.camera),
      onGallery: () => _pickImage(ImageSource.gallery),
      onUpload:  _upload,
    );
  }
}

// ── Pick / upload view ─────────────────────────────────────────────────────────

class _PickView extends StatelessWidget {
  final File? image;
  final bool uploading;
  final VoidCallback onCamera, onGallery, onUpload;

  const _PickView({
    required this.image,
    required this.uploading,
    required this.onCamera,
    required this.onGallery,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (image == null) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 80, color: cs.outline),
                  const SizedBox(height: 24),
                  const Text('Take a photo of your grocery receipt',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onCamera,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Camera'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(image!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: uploading ? null : onGallery,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: uploading ? null : onUpload,
                    icon: uploading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(uploading ? 'Uploading…' : 'Upload Receipt'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Processing view ────────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  final String status;
  const _ProcessingView({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              status == 'processing'
                  ? 'Analysing receipt with AI…'
                  : 'Uploading and queuing…',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This usually takes 8–15 seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Failed view ────────────────────────────────────────────────────────────────

class _FailedView extends StatelessWidget {
  final VoidCallback onRetry;
  const _FailedView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Processing failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'The receipt could not be processed. '
              'Make sure the image is clear and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Done view — parsed items review ───────────────────────────────────────────

class _DoneView extends StatelessWidget {
  final GroceryReceipt receipt;
  final VoidCallback onConfirm;

  const _DoneView({required this.receipt, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final items = receipt.items ?? [];
    final fmt   = NumberFormat.currency(symbol: '\$');
    final cs    = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header summary
        Container(
          color: cs.primaryContainer.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(receipt.storeName ?? 'Receipt processed',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${items.length} items detected',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              if (receipt.totalAmount != null)
                Text(fmt.format(receipt.totalAmount),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                        fontSize: 16)),
            ],
          ),
        ),
        // Item list
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              return ListTile(
                dense: true,
                leading: Text(
                  _catEmoji(item.category),
                  style: const TextStyle(fontSize: 20),
                ),
                title: Text(
                    item.normalizedName ?? item.rawText ?? '',
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${item.category}'
                  '${item.brand != null && item.brand!.isNotEmpty ? ' · ${item.brand}' : ''}'
                  '${item.estCalories != null ? ' · ~${item.estCalories!.round()} kcal' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: item.totalPrice != null
                    ? Text(fmt.format(item.totalPrice),
                        style: const TextStyle(fontWeight: FontWeight.w500))
                    : null,
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
              onPressed: onConfirm,
              icon: const Icon(Icons.check),
              label: const Text('Done'),
            ),
          ),
        ),
      ],
    );
  }

  String _catEmoji(String cat) {
    const emojis = {
      'produce':       '🥦',
      'dairy':         '🥛',
      'meat':          '🥩',
      'seafood':       '🐟',
      'bakery':        '🍞',
      'frozen':        '🧊',
      'beverages':     '🧃',
      'snacks':        '🍿',
      'pantry':        '🥫',
      'household':     '🧹',
      'personal_care': '🧴',
    };
    return emojis[cat] ?? '🛒';
  }
}
