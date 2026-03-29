import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import 'help_tooltip.dart';
import 'package:hugeicons/hugeicons.dart';

/// Voice meal logging bottom sheet.
///
/// Flow: tap mic → record audio → tap Done → Whisper transcribes → Gemini parses → confirm → logged.
/// Uses server-side OpenAI Whisper for accurate transcription (handles Indian accents).
class VoiceMealSheet extends ConsumerStatefulWidget {
  final String? personId;
  final VoidCallback? onLogged;
  const VoiceMealSheet({super.key, this.personId, this.onLogged});

  @override
  ConsumerState<VoiceMealSheet> createState() => _VoiceMealSheetState();
}

enum _VoiceState { idle, recording, processing, confirmed, error }

class _VoiceMealSheetState extends ConsumerState<VoiceMealSheet>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  var _state = _VoiceState.idle;
  String _errorMsg = '';
  String _transcript = '';

  // Recording state
  bool _recorderReady = false;
  String? _audioPath;
  Duration _recordDuration = Duration.zero;
  Timer? _durationTimer;

  // Amplitude for visual feedback
  double _currentAmplitude = 0.0;
  Timer? _amplitudeTimer;

  // Parsed result
  List<Map<String, dynamic>> _meals = [];

  // Animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final hasPermission = await _recorder.hasPermission();
    if (mounted) {
      setState(() => _recorderReady = hasPermission);
    }
  }

  Future<void> _startRecording() async {
    if (!_recorderReady) {
      setState(() {
        _state = _VoiceState.error;
        _errorMsg = 'Microphone permission denied. Please enable it in Settings.';
      });
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_meal_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: path,
      );

      _audioPath = path;
      _recordDuration = Duration.zero;

      // Duration timer
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _state == _VoiceState.recording) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        }
      });

      // Amplitude polling for visual feedback
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
        if (_state != _VoiceState.recording) return;
        try {
          final amp = await _recorder.getAmplitude();
          if (mounted) {
            setState(() {
              // Normalize: amp.current is typically -160 to 0 dB
              _currentAmplitude = ((amp.current + 50) / 50).clamp(0.0, 1.0);
            });
          }
        } catch (_) {}
      });

      setState(() => _state = _VoiceState.recording);
    } catch (e) {
      setState(() {
        _state = _VoiceState.error;
        _errorMsg = 'Failed to start recording: $e';
      });
    }
  }

  Future<void> _stopAndProcess() async {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();

    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        setState(() {
          _state = _VoiceState.error;
          _errorMsg = 'No audio recorded. Please try again.';
        });
        return;
      }

      final file = File(path);
      if (!file.existsSync() || file.lengthSync() < 1000) {
        setState(() {
          _state = _VoiceState.error;
          _errorMsg = 'Recording too short. Please speak for at least 2 seconds.';
        });
        return;
      }

      setState(() => _state = _VoiceState.processing);

      // Upload audio to backend for Whisper transcription + Gemini parsing
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          path,
          filename: 'voice_meal.m4a',
          contentType: DioMediaType('audio', 'mp4'),
        ),
        'current_time': timeStr,
      });

      final res = await apiClient.dio.post(
        ApiConstants.nutritionVoiceAudio,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      final data = res.data as Map<String, dynamic>;
      _transcript = (data['transcript'] as String?) ?? '';

      if (data['success'] == true) {
        final meals = (data['meals'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        if (meals.isEmpty || meals.every((m) => ((m['items'] as List?) ?? []).isEmpty)) {
          setState(() {
            _state = _VoiceState.error;
            _errorMsg = _transcript.isNotEmpty
                ? 'Heard: "$_transcript"\n\nNo food items found. Try again with specific food names.'
                : 'No food items found in your description. Try again.';
          });
          return;
        }

        setState(() {
          _meals = meals;
          _state = _VoiceState.confirmed;
        });
      } else {
        setState(() {
          _state = _VoiceState.error;
          _errorMsg = data['error'] as String? ?? 'Failed to parse meal';
        });
      }

      // Clean up audio file
      try { file.deleteSync(); } catch (_) {}

    } on DioException catch (e) {
      // Show real error for debugging
      final status = e.response?.statusCode;
      final body = e.response?.data;
      String detail = '';
      if (body is Map) {
        detail = (body['detail'] as String?) ?? '';
      } else if (body is String) {
        detail = body.length > 200 ? body.substring(0, 200) : body;
      }

      String msg;
      if (status == 503) {
        msg = 'Voice transcription not available on server.\n\nUse "Type instead" below.';
      } else if (status == 502 || status == 504) {
        msg = 'Server timed out processing audio. Try a shorter recording or use "Type instead".';
      } else if (status != null) {
        msg = 'Server error ($status)${detail.isNotEmpty ? ': $detail' : ''}.\n\nTry "Type instead" below.';
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.sendTimeout) {
        msg = 'Upload timed out — audio file may be too large. Try a shorter recording.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        msg = 'Server took too long to process. Try a shorter recording or "Type instead".';
      } else {
        msg = 'Network error: ${e.message ?? e.type.name}.\n\nCheck your connection or use "Type instead".';
      }
      setState(() {
        _state = _VoiceState.error;
        _errorMsg = msg;
      });
    } catch (e) {
      setState(() {
        _state = _VoiceState.error;
        _errorMsg = 'Unexpected error: $e\n\nTry "Type instead" below.';
      });
    }
  }

  Future<void> _confirmAndLog(Map<String, dynamic> meal) async {
    setState(() => _state = _VoiceState.processing);

    try {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final res = await apiClient.dio.post(
        ApiConstants.nutritionVoiceConfirm,
        data: {
          'meal_type': meal['meal_type'],
          'items': meal['items'],
          'date': now.toIso8601String().substring(0, 10),
          'time': timeStr,
          'for_child': widget.personId != 'self' ? widget.personId : null,
        },
      );

      if (res.data['success'] == true) {
        if (mounted) {
          setState(() {
            _meals.remove(meal);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${meal['summary'] ?? 'Meal'} logged! (${(meal['total_calories'] as num?)?.toInt() ?? 0} cal)',
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );

          widget.onLogged?.call();

          if (_meals.isEmpty) {
            if (mounted) Navigator.pop(context);
          } else {
            setState(() => _state = _VoiceState.confirmed);
          }
        }
      }
    } catch (e) {
      setState(() {
        _state = _VoiceState.error;
        _errorMsg = 'Failed to log: $e';
      });
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _recorder.dispose();
    _pulseCtrl.dispose();
    // Clean up any leftover audio file
    if (_audioPath != null) {
      try { File(_audioPath!).deleteSync(); } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: cs.outlineVariant, borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              HugeIcon(icon: HugeIcons.strokeRoundedMic01, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _state == _VoiceState.confirmed ? 'Confirm Your Meal' : 'Voice Meal Logger',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              )),
              const HelpTooltip(
                message: "Tap the mic and describe your meal. "
                    "Say things like '2 dosa, 1 idli with peanut chutney and coffee'. "
                    "Tap Done when finished. Works great with Indian accents!",
              ),
              if (_state != _VoiceState.idle)
                TextButton(
                  onPressed: () {
                    _durationTimer?.cancel();
                    _amplitudeTimer?.cancel();
                    _recorder.stop();
                    setState(() {
                      _state = _VoiceState.idle;
                      _transcript = '';
                      _meals = [];
                    });
                  },
                  child: const Text('Reset'),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: cs.outlineVariant),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildContent(cs, tt),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs, TextTheme tt) {
    switch (_state) {
      case _VoiceState.idle:
        return _buildIdleState(cs, tt);
      case _VoiceState.recording:
        return _buildRecordingState(cs, tt);
      case _VoiceState.processing:
        return _buildProcessingState(cs, tt);
      case _VoiceState.confirmed:
        return _buildConfirmedState(cs, tt);
      case _VoiceState.error:
        return _buildErrorState(cs, tt);
    }
  }

  Widget _buildIdleState(ColorScheme cs, TextTheme tt) {
    return Column(children: [
      const SizedBox(height: 20),
      // Mic button
      GestureDetector(
        onTap: _startRecording,
        child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary,
            boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5)],
          ),
          child: HugeIcon(icon: HugeIcons.strokeRoundedMic01, size: 48, color: Colors.white),
        ),
      ),
      const SizedBox(height: 24),
      Text('Tap to speak', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(
        'Describe your full meal — speak naturally',
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
      const SizedBox(height: 6),
      // Whisper badge
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedStars, size: 14, color: cs.primary),
            const SizedBox(width: 4),
            Text('AI-powered transcription',
              style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      const SizedBox(height: 20),
      // Examples
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Try saying:', style: tt.labelLarge?.copyWith(color: cs.primary)),
            const SizedBox(height: 8),
            _exampleChip('"2 dosa, 1 idli with peanut chutney and filter coffee"'),
            _exampleChip('"I had 2 rotis with dal and a glass of milk for lunch"'),
            _exampleChip('"Poha with chai for breakfast and rice with sambar for lunch"'),
            _exampleChip('"Chicken biryani, raita and gulab jamun for dinner"'),
          ],
        ),
      ),

      const SizedBox(height: 16),
      // Type instead option
      OutlinedButton.icon(
        onPressed: _showTextInput,
        icon: HugeIcon(icon: HugeIcons.strokeRoundedKeyboard, size: 18),
        label: const Text('Type instead'),
      ),
    ]);
  }

  Widget _exampleChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        HugeIcon(icon: HugeIcons.strokeRoundedQuoteDown, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }

  Widget _buildRecordingState(ColorScheme cs, TextTheme tt) {
    final minutes = _recordDuration.inMinutes.toString().padLeft(2, '0');
    final seconds = (_recordDuration.inSeconds % 60).toString().padLeft(2, '0');

    return Column(children: [
      const SizedBox(height: 20),
      // Pulsing mic with amplitude indicator
      AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) {
          final ampScale = 1.0 + (_currentAmplitude * 0.3);
          return Transform.scale(
            scale: _pulseAnim.value * ampScale * 0.85,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3 + _currentAmplitude * 0.3),
                  blurRadius: 20 + _currentAmplitude * 20,
                  spreadRadius: 5 + _currentAmplitude * 10,
                )],
              ),
              child: HugeIcon(icon: HugeIcons.strokeRoundedMic01, size: 48, color: Colors.white),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      Text('Recording...', style: tt.titleMedium?.copyWith(
        fontWeight: FontWeight.bold, color: Colors.red,
      )),
      const SizedBox(height: 4),
      // Duration display
      Text(
        '$minutes:$seconds',
        style: tt.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.red,
          fontFeatures: [const FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Describe your full meal — tap Done when finished',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),

      // Amplitude visualizer
      const SizedBox(height: 16),
      SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(20, (i) {
            final barHeight = 8.0 + (_currentAmplitude * 32.0 * ((i % 3 == 0) ? 1.0 : 0.6));
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 4,
              height: barHeight,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.4 + _currentAmplitude * 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),

      const SizedBox(height: 24),

      // Done button
      SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _stopAndProcess,
          icon: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01),
          label: const Text('Done — Process my meal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(backgroundColor: cs.primary),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () {
          _durationTimer?.cancel();
          _amplitudeTimer?.cancel();
          _recorder.stop();
          setState(() => _state = _VoiceState.idle);
        },
        child: const Text('Cancel'),
      ),
    ]);
  }

  Widget _buildProcessingState(ColorScheme cs, TextTheme tt) {
    return Column(children: [
      const SizedBox(height: 40),
      CircularProgressIndicator(color: cs.primary),
      const SizedBox(height: 24),
      Text('Transcribing & parsing...', style: tt.titleMedium),
      const SizedBox(height: 8),
      Text(
        'Whisper AI is transcribing your voice,\nthen Gemini will identify the foods',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    ]);
  }

  Widget _buildConfirmedState(ColorScheme cs, TextTheme tt) {
    if (_meals.isEmpty) {
      return Column(children: [
        HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, size: 64, color: cs.primary),
        const SizedBox(height: 16),
        Text('All meals logged!', style: tt.titleMedium),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transcript + match quality summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                HugeIcon(icon: HugeIcons.strokeRoundedMic01, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text('"$_transcript"', style: tt.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ))),
              ]),
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final allItems = _meals.expand((m) => (m['items'] as List?) ?? []).toList();
                final matched = allItems.where((i) => ((i as Map)['match_confidence'] as num? ?? 0) > 0.4).length;
                final total = allItems.length;
                final pct = total > 0 ? (matched / total * 100).round() : 0;
                return Row(children: [
                  HugeIcon(
                    icon: pct >= 80 ? HugeIcons.strokeRoundedCheckmarkCircle01 : pct >= 50 ? HugeIcons.strokeRoundedInformationCircle : HugeIcons.strokeRoundedAlert02,
                    size: 14,
                    color: pct >= 80 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$matched/$total items matched in database ($pct%)',
                    style: tt.bodySmall?.copyWith(
                      color: pct >= 80 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]);
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Tap any item to edit quantity or remove',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 12),

        // Log All button
        if (_meals.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _logAllMeals,
              icon: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01),
              label: Text(
                _meals.length == 1 ? 'Log Meal' : 'Log All ${_meals.length} Meals',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(backgroundColor: cs.primary),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Each meal group
        ..._meals.map((meal) => _buildMealCard(meal, cs, tt)),

        // Action buttons
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _state = _VoiceState.idle),
              icon: HugeIcon(icon: HugeIcons.strokeRoundedMic01, size: 18),
              label: const Text('Add more'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showTextInput,
              icon: HugeIcon(icon: HugeIcons.strokeRoundedKeyboard, size: 18),
              label: const Text('Type to add'),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal, ColorScheme cs, TextTheme tt) {
    final items = (meal['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final mealType = meal['meal_type'] as String? ?? 'snack';
    final totalCal = (meal['total_calories'] as num?)?.toInt() ?? 0;
    final totalProtein = (meal['total_protein'] as num?)?.toDouble() ?? 0;
    final totalCarbs = (meal['total_carbs'] as num?)?.toDouble() ?? 0;
    final totalFat = (meal['total_fat'] as num?)?.toDouble() ?? 0;
    final summary = meal['summary'] as String? ?? '';
    final nf = NumberFormat('#,##0');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(children: [
            _mealIcon(mealType, cs),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mealType[0].toUpperCase() + mealType.substring(1),
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                if (summary.isNotEmpty) Text(summary, style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                )),
              ],
            )),
            Text('${nf.format(totalCal)} cal', style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.bold, color: cs.primary,
            )),
          ]),
        ),

        // Items — tappable to edit quantity
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final matched = (item['match_confidence'] as num?)?.toDouble() ?? 0;
          final isMatched = matched > 0.4;
          final grams = (item['grams'] as num?)?.toDouble() ?? 0;
          final unitQty = (item['unit_quantity'] as num?)?.toDouble() ?? 1;
          final unit = item['unit'] as String? ?? 'serving';
          return ListTile(
            dense: true,
            onTap: () => _editItemQuantity(meal, idx),
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: isMatched ? cs.primaryContainer : Colors.orange.shade100,
              child: HugeIcon(icon: 
                isMatched ? HugeIcons.strokeRoundedCheckmarkCircle01 : HugeIcons.strokeRoundedHelpCircle,
                size: 16,
                color: isMatched ? cs.primary : Colors.orange.shade700,
              ),
            ),
            title: Text(item['food_name'] as String? ?? '', style: tt.bodyMedium),
            subtitle: Text(
              '${unitQty % 1 == 0 ? unitQty.toInt() : unitQty}× $unit (${grams.toInt()}g)  •  ${(item['calories'] as num?)?.toInt() ?? 0} cal',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMatched)
                  Tooltip(
                    message: 'AI estimated — will create as custom food',
                    child: HugeIcon(icon: HugeIcons.strokeRoundedStars, size: 16, color: Colors.orange.shade600),
                  ),
                HugeIcon(icon: HugeIcons.strokeRoundedEdit01, size: 14, color: cs.onSurfaceVariant),
              ],
            ),
          );
        }),

        // Macro summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _macroChip('P', totalProtein, Colors.blue, cs),
            const SizedBox(width: 8),
            _macroChip('C', totalCarbs, Colors.orange, cs),
            const SizedBox(width: 8),
            _macroChip('F', totalFat, Colors.red, cs),
            const Spacer(),
            FilledButton(
              onPressed: () => _confirmAndLog(meal),
              child: const Text('Log Meal'),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _macroChip(String label, double value, Color color, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(0)}g',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _mealIcon(String type, ColorScheme cs) {
    final icon = switch (type) {
      'breakfast' => HugeIcons.strokeRoundedCoffee01,
      'lunch' => HugeIcons.strokeRoundedRestaurant01,
      'dinner' => HugeIcons.strokeRoundedRestaurant01,
      _ => HugeIcons.strokeRoundedRestaurant01,
    };
    return HugeIcon(icon: icon, color: cs.primary);
  }

  Widget _buildErrorState(ColorScheme cs, TextTheme tt) {
    return Column(children: [
      const SizedBox(height: 30),
      HugeIcon(icon: HugeIcons.strokeRoundedAlert01, size: 64, color: cs.error),
      const SizedBox(height: 16),
      Text('Oops!', style: tt.titleMedium?.copyWith(color: cs.error)),
      const SizedBox(height: 8),
      Text(_errorMsg, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        textAlign: TextAlign.center),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => setState(() => _state = _VoiceState.idle),
        icon: HugeIcon(icon: HugeIcons.strokeRoundedMic01),
        label: const Text('Try Again'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _showTextInput,
        icon: HugeIcon(icon: HugeIcons.strokeRoundedKeyboard),
        label: const Text('Type instead'),
      ),
    ]);
  }

  Future<void> _logAllMeals() async {
    final mealsToLog = List<Map<String, dynamic>>.from(_meals);
    for (final meal in mealsToLog) {
      await _confirmAndLog(meal);
      if (_state == _VoiceState.error) break;
    }
  }

  void _editItemQuantity(Map<String, dynamic> meal, int itemIndex) {
    final items = (meal['items'] as List).cast<Map<String, dynamic>>();
    final item = items[itemIndex];
    final qtyCtrl = TextEditingController(
      text: ((item['unit_quantity'] as num?)?.toDouble() ?? 1).toString(),
    );
    final gramsCtrl = TextEditingController(
      text: ((item['grams'] as num?)?.toDouble() ?? 100).toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit: ${item['food_name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Quantity (${item['unit'] ?? 'serving'}s)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gramsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total grams',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                items.removeAt(itemIndex);
                _recalcMealTotals(meal);
              });
              Navigator.pop(ctx);
            },
            child: Text('Remove', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final newQty = double.tryParse(qtyCtrl.text) ?? 1;
              final newGrams = double.tryParse(gramsCtrl.text) ?? 100;
              setState(() {
                item['unit_quantity'] = newQty;
                item['grams'] = newGrams;
                final factor = newGrams / 100;
                final calPer100 = (item['estimated_cal_per_100g'] as num?)?.toDouble() ?? 100;
                final pPer100 = (item['estimated_protein_per_100g'] as num?)?.toDouble() ?? 5;
                final cPer100 = (item['estimated_carbs_per_100g'] as num?)?.toDouble() ?? 20;
                final fPer100 = (item['estimated_fat_per_100g'] as num?)?.toDouble() ?? 3;
                item['calories'] = (calPer100 * factor).round();
                item['protein'] = (pPer100 * factor * 10).round() / 10;
                item['carbs'] = (cPer100 * factor * 10).round() / 10;
                item['fat'] = (fPer100 * factor * 10).round() / 10;
                item['quantity'] = newGrams / (item['serving_size'] as num? ?? 100).toDouble();
                _recalcMealTotals(meal);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _recalcMealTotals(Map<String, dynamic> meal) {
    final items = (meal['items'] as List).cast<Map<String, dynamic>>();
    meal['total_calories'] = items.fold<num>(0, (s, i) => s + ((i['calories'] as num?) ?? 0));
    meal['total_protein'] = items.fold<num>(0, (s, i) => s + ((i['protein'] as num?) ?? 0));
    meal['total_carbs'] = items.fold<num>(0, (s, i) => s + ((i['carbs'] as num?) ?? 0));
    meal['total_fat'] = items.fold<num>(0, (s, i) => s + ((i['fat'] as num?) ?? 0));
  }

  void _showTextInput() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Describe your meal'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. 2 dosa, 1 idli with peanut chutney',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (ctrl.text.trim().isNotEmpty) {
                _processText(ctrl.text.trim());
              }
            },
            child: const Text('Parse'),
          ),
        ],
      ),
    );
  }

  /// Process typed text via the original text-based endpoint
  Future<void> _processText(String text) async {
    setState(() => _state = _VoiceState.processing);

    try {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final res = await apiClient.dio.post(
        ApiConstants.nutritionVoice,
        data: {
          'transcript': text,
          'current_time': timeStr,
        },
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );

      final data = res.data as Map<String, dynamic>;
      _transcript = text;

      if (data['success'] == true) {
        final meals = (data['meals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (meals.isEmpty || meals.every((m) => ((m['items'] as List?) ?? []).isEmpty)) {
          setState(() {
            _state = _VoiceState.error;
            _errorMsg = 'No food items found. Try specific food names like "2 dosa with chutney".';
          });
          return;
        }

        setState(() {
          _meals = meals;
          _state = _VoiceState.confirmed;
        });
      } else {
        setState(() {
          _state = _VoiceState.error;
          _errorMsg = data['error'] as String? ?? 'Failed to parse meal';
        });
      }
    } catch (e) {
      setState(() {
        _state = _VoiceState.error;
        _errorMsg = 'Connection error. Please check your internet and try again.';
      });
    }
  }
}
