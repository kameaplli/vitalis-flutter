import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/social_provider.dart';
import '../../widgets/social/share_card_generator.dart';

/// Full-screen preview of a shareable nutrition report card.
///
/// Renders a high-quality card image and provides Share/Download actions.
class ShareCardScreen extends ConsumerStatefulWidget {
  final String cardType;

  const ShareCardScreen({
    super.key,
    required this.cardType,
  });

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final _repaintKey = GlobalKey();
  bool _isRendering = false;

  Future<Uint8List?> _renderCard() async {
    setState(() => _isRendering = true);
    try {
      // Wait for the next frame so the widget is fully painted
      await Future.delayed(const Duration(milliseconds: 100));
      return await ShareCardGenerator.renderToImage(_repaintKey);
    } finally {
      if (mounted) setState(() => _isRendering = false);
    }
  }

  Future<void> _handleShare() async {
    HapticFeedback.mediumImpact();
    final imageBytes = await _renderCard();
    if (imageBytes == null) {
      _showSnackBar('Failed to render card');
      return;
    }
    // Image rendered successfully — share_plus not yet in dependencies
    _showSnackBar('Share functionality coming soon');
  }

  Future<void> _handleDownload() async {
    HapticFeedback.mediumImpact();
    final imageBytes = await _renderCard();
    if (imageBytes == null) {
      _showSnackBar('Failed to render card');
      return;
    }
    // Image rendered successfully — gallery save not yet implemented
    _showSnackBar('Download functionality coming soon');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardData = ref.watch(shareCardDataProvider(widget.cardType));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(_titleForType(widget.cardType)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: cardData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text(
                  'Failed to load card data',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(shareCardDataProvider(widget.cardType)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => Column(
          children: [
            // ── Card Preview ──────────────────────────────────────────
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  child: ShareCardGenerator(
                    repaintBoundaryKey: _repaintKey,
                    cardType: widget.cardType,
                    data: data,
                  ),
                ),
              ),
            ),

            // ── Deep Link ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                data['deep_link'] ?? '',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Action Buttons ───────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isRendering ? null : _handleDownload,
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text('Download'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isRendering ? null : _handleShare,
                      icon: _isRendering
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.share_rounded, size: 20),
                      label: const Text('Share'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  String _titleForType(String type) {
    switch (type) {
      case 'daily_nutrition':
        return 'Daily Report Card';
      case 'streak':
        return 'Streak Card';
      case 'weekly_report':
        return 'Weekly Report Card';
      case 'achievement':
        return 'Achievement Card';
      default:
        return 'Share Card';
    }
  }
}
