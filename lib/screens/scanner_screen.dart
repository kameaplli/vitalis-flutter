import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/food_provider.dart';

// On web, camera requires HTTPS or localhost (browser secure-context rule).
bool get _webCameraBlocked {
  if (!kIsWeb) return false;
  final host = Uri.base.host;
  final scheme = Uri.base.scheme;
  return scheme != 'https' && host != 'localhost' && host != '127.0.0.1';
}

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});
  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  bool _useCamera = true;
  bool _scanned = false;
  bool _lookingUp = false;
  String? _detectedBarcode;
  MobileScannerController? _cameraCtrl;

  // Manual entry form
  final _barcodeCtrl  = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _calCtrl      = TextEditingController();
  final _proteinCtrl  = TextEditingController();
  final _carbsCtrl    = TextEditingController();
  final _fatCtrl      = TextEditingController();
  final _servingCtrl  = TextEditingController(text: '100');
  bool _isSaving = false;
  bool _savedFood = false;
  String _savedFoodName = '';

  @override
  void initState() {
    super.initState();
    if (_webCameraBlocked) {
      // Insecure HTTP context — camera API is unavailable, go straight to manual.
      _useCamera = false;
    } else {
      _cameraCtrl = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _servingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Scanner'),
        actions: [
          if (!_webCameraBlocked)
            IconButton(
              icon: Icon(_useCamera ? Icons.keyboard : Icons.qr_code_scanner),
              onPressed: () => setState(() {
                _useCamera = !_useCamera;
                _scanned = false;
                _detectedBarcode = null;
              }),
            ),
        ],
      ),
      body: _useCamera ? _buildCamera() : _buildManualForm(),
    );
  }

  Widget _buildCamera() {
    if (_scanned && _detectedBarcode != null) {
      return _buildFoodEntryForm(barcode: _detectedBarcode);
    }

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: MobileScanner(
            controller: _cameraCtrl,
            errorBuilder: (context, error, child) {
              return _CameraErrorView(
                error: error,
                onManualEntry: () => setState(() => _useCamera = false),
              );
            },
            onDetect: (capture) {
              if (_scanned) return;
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                final code = barcodes.first.rawValue!;
                setState(() {
                  _scanned = true;
                  _detectedBarcode = code;
                  _barcodeCtrl.text = code;
                });
                _lookupBarcode(code);
              }
            },
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner, size: 36, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('Point camera at barcode',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _useCamera = false),
                  child: const Text('Enter manually instead'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualForm() {
    return _buildFoodEntryForm();
  }

  Widget _buildFoodEntryForm({String? barcode}) {
    if (barcode != null && _barcodeCtrl.text.isEmpty) {
      _barcodeCtrl.text = barcode;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success banner after saving a food
          if (_savedFood)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"$_savedFoodName" saved!',
                      style: TextStyle(color: Colors.green.shade800),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/nutrition'),
                    child: const Text('Log it now'),
                  ),
                ],
              ),
            ),

          // Show HTTPS warning banner if camera was blocked
          if (_webCameraBlocked)
            _buildHttpsBanner(),

          if (barcode != null) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _lookingUp
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_lookingUp
                          ? 'Looking up barcode…'
                          : 'Barcode: $barcode'),
                    ),
                    if (!_lookingUp)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => setState(() {
                          _scanned = false;
                          _detectedBarcode = null;
                          _barcodeCtrl.clear();
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('Food Details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (barcode == null) ...[
            TextFormField(
              controller: _barcodeCtrl,
              decoration: const InputDecoration(
                  labelText: 'Barcode (optional)',
                  prefixIcon: Icon(Icons.qr_code)),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Product Name *'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _calCtrl,
                decoration: const InputDecoration(
                    labelText: 'Calories (per 100g)', suffixText: 'kcal'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _servingCtrl,
                decoration: const InputDecoration(
                    labelText: 'Serving size', suffixText: 'g'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _proteinCtrl,
                decoration: const InputDecoration(labelText: 'Protein (g)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _carbsCtrl,
                decoration: const InputDecoration(labelText: 'Carbs (g)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _fatCtrl,
                decoration: const InputDecoration(labelText: 'Fat (g)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveFood,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Save to Food Database'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHttpsBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Camera scanning requires HTTPS. '
              'Enter the barcode manually or open the app via localhost.',
              style: TextStyle(
                  fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _lookupBarcode(String barcode) async {
    setState(() => _lookingUp = true);
    try {
      final dio = Dio();
      final res = await dio.get(
        'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final data = res.data;
      if (data['status'] == 1) {
        final product = data['product'] as Map<String, dynamic>;
        final nutriments = (product['nutriments'] as Map<String, dynamic>?) ?? {};
        final name = product['product_name'] ?? product['product_name_en'] ?? '';
        final cal = _toDouble(nutriments['energy-kcal_100g'] ?? nutriments['energy_100g']);
        final protein = _toDouble(nutriments['proteins_100g']);
        final carbs = _toDouble(nutriments['carbohydrates_100g']);
        final fat = _toDouble(nutriments['fat_100g']);
        final serving = _parseServingSize(product['serving_size']);

        if (mounted) {
          setState(() {
            if (name.isNotEmpty) _nameCtrl.text = name;
            if (cal != null) _calCtrl.text = cal.toStringAsFixed(1);
            if (protein != null) _proteinCtrl.text = protein.toStringAsFixed(1);
            if (carbs != null) _carbsCtrl.text = carbs.toStringAsFixed(1);
            if (fat != null) _fatCtrl.text = fat.toStringAsFixed(1);
            if (serving != null) _servingCtrl.text = serving.toStringAsFixed(0);
          });
          if (name.isNotEmpty || cal != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nutrition info loaded from Open Food Facts')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Product found but no nutrition data — fill in manually')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found — fill in nutrition details manually')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not look up barcode — fill in manually')),
        );
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  double? _parseServingSize(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(s);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  Future<void> _saveFood() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product name is required')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final savedName = _nameCtrl.text.trim();
      await apiClient.dio.post(ApiConstants.customFoods, data: {
        'name': savedName,
        'calories': double.tryParse(_calCtrl.text) ?? 0,
        'protein': double.tryParse(_proteinCtrl.text) ?? 0,
        'carbs': double.tryParse(_carbsCtrl.text) ?? 0,
        'fat': double.tryParse(_fatCtrl.text) ?? 0,
        'serving_size': double.tryParse(_servingCtrl.text) ?? 100,
        'barcode': _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
      });
      if (mounted) {
        // Invalidate food database so new food appears in search
        ref.invalidate(foodDatabaseProvider);
        setState(() {
          _savedFood = true;
          _savedFoodName = savedName;
          // Clear form for next entry
          _barcodeCtrl.clear();
          _nameCtrl.clear();
          _calCtrl.clear();
          _proteinCtrl.clear();
          _carbsCtrl.clear();
          _fatCtrl.clear();
          _servingCtrl.text = '100';
          _scanned = false;
          _detectedBarcode = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Food saved to your database!')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── Camera error overlay ──────────────────────────────────────────────────────

class _CameraErrorView extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onManualEntry;

  const _CameraErrorView({required this.error, required this.onManualEntry});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = _content();
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onManualEntry,
                icon: const Icon(Icons.keyboard),
                label: const Text('Enter manually instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, String, String) _content() {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return (
          Icons.no_photography_outlined,
          'Camera permission denied',
          'Go to your browser or device settings and allow camera access for this app, then come back.',
        );
      case MobileScannerErrorCode.unsupported:
        return (
          Icons.browser_not_supported_outlined,
          'Camera not supported',
          'Barcode scanning via camera is not supported in this browser. '
              'Try Chrome or Edge, or use manual entry.',
        );
      default:
        return (
          Icons.camera_alt_outlined,
          'Camera unavailable',
          error.errorDetails?.message ??
              'Could not start the camera. Use manual entry or try again.',
        );
    }
  }
}
