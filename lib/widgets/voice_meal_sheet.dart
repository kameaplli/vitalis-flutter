import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

/// Voice meal logging bottom sheet.
///
/// Flow: tap mic → speak naturally → AI parses → confirm → logged.
/// Supports multi-accent English, compound meals, cultural foods,
/// conversational corrections, and family logging.
class VoiceMealSheet extends ConsumerStatefulWidget {
  final String? personId;
  final VoidCallback? onLogged;
  const VoiceMealSheet({super.key, this.personId, this.onLogged});

  @override
  ConsumerState<VoiceMealSheet> createState() => _VoiceMealSheetState();
}

enum _VoiceState { idle, listening, processing, confirmed, error }

class _VoiceMealSheetState extends ConsumerState<VoiceMealSheet>
    with SingleTickerProviderStateMixin {
  final _speech = stt.SpeechToText();
  var _state = _VoiceState.idle;
  String _transcript = '';
  String _partialText = '';
  String _errorMsg = '';
  bool _speechAvailable = false;

  // Parsed result
  List<Map<String, dynamic>> _meals = [];
  String? _forPerson;

  // Conversation context for corrections
  final List<Map<String, dynamic>> _context = [];

  // Animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) {
        if (mounted && _state == _VoiceState.listening) {
          // If we have a partial transcript, process it
          if (_transcript.isNotEmpty || _partialText.isNotEmpty) {
            _processTranscript(_transcript.isNotEmpty ? _transcript : _partialText);
          } else {
            setState(() {
              _state = _VoiceState.error;
              _errorMsg = 'Speech recognition error: ${e.errorMsg}';
            });
          }
        }
      },
      onStatus: (status) {
        if (status == 'done' && _state == _VoiceState.listening) {
          if (_transcript.isNotEmpty) {
            _processTranscript(_transcript);
          }
        }
      },
    );
    if (mounted) setState(() {});
  }

  void _startListening() {
    if (!_speechAvailable) {
      setState(() {
        _state = _VoiceState.error;
        _errorMsg = 'Speech recognition not available on this device';
      });
      return;
    }

    setState(() {
      _state = _VoiceState.listening;
      _transcript = '';
      _partialText = '';
    });

    _speech.listen(
      onResult: (result) {
        setState(() {
          if (result.finalResult) {
            _transcript = result.recognizedWords;
          } else {
            _partialText = result.recognizedWords;
          }
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en',
      cancelOnError: false,
      partialResults: true,
    );
  }

  void _stopListening() {
    _speech.stop();
    final text = _transcript.isNotEmpty ? _transcript : _partialText;
    if (text.isNotEmpty) {
      _processTranscript(text);
    } else {
      setState(() => _state = _VoiceState.idle);
    }
  }

  Future<void> _processTranscript(String transcript) async {
    setState(() {
      _state = _VoiceState.processing;
      _transcript = transcript;
    });

    try {
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final res = await apiClient.dio.post(
        ApiConstants.nutritionVoice,
        data: {
          'transcript': transcript,
          'current_time': timeStr,
          'context': _context.isNotEmpty ? _context : null,
        },
      );

      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final meals = (data['meals'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        // Add to conversation context for potential corrections
        _context.add({'role': 'user', 'text': transcript});
        _context.add({'role': 'assistant', 'parsed': meals});

        setState(() {
          _meals = meals;
          _forPerson = data['for_person'] as String?;
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
        _errorMsg = 'Connection error: $e';
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
          // Remove the logged meal from the list
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

          // If no more meals, close
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
    _speech.stop();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
              Icon(Icons.mic, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _state == _VoiceState.confirmed ? 'Confirm Your Meal' : 'Voice Meal Logger',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              )),
              if (_state != _VoiceState.idle)
                TextButton(
                  onPressed: () => setState(() {
                    _state = _VoiceState.idle;
                    _transcript = '';
                    _partialText = '';
                    _meals = [];
                  }),
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
    );
  }

  Widget _buildContent(ColorScheme cs, TextTheme tt) {
    switch (_state) {
      case _VoiceState.idle:
        return _buildIdleState(cs, tt);
      case _VoiceState.listening:
        return _buildListeningState(cs, tt);
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
        onTap: _startListening,
        child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary,
            boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5)],
          ),
          child: const Icon(Icons.mic, size: 48, color: Colors.white),
        ),
      ),
      const SizedBox(height: 24),
      Text('Tap to speak', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(
        'Describe your meal naturally',
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
            _exampleChip('"I had 2 rotis with dal and a glass of milk for lunch"'),
            _exampleChip('"Oatmeal with banana and coffee for breakfast"'),
            _exampleChip('"Same as yesterday\'s dinner"'),
            _exampleChip('"Chicken sandwich, fries, and a coke"'),
          ],
        ),
      ),

      // Conversation context indicator
      if (_context.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.tertiaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.chat_bubble_outline, size: 16, color: cs.tertiary),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Conversation active — you can make corrections',
              style: tt.bodySmall?.copyWith(color: cs.tertiary),
            )),
          ]),
        ),
      ],
    ]);
  }

  Widget _exampleChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(Icons.format_quote, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }

  Widget _buildListeningState(ColorScheme cs, TextTheme tt) {
    return Column(children: [
      const SizedBox(height: 20),
      // Pulsing mic
      AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Transform.scale(
          scale: _pulseAnim.value,
          child: GestureDetector(
            onTap: _stopListening,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 20 * _pulseAnim.value,
                  spreadRadius: 5 * _pulseAnim.value,
                )],
              ),
              child: const Icon(Icons.stop, size: 48, color: Colors.white),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text('Listening...', style: tt.titleMedium?.copyWith(
        fontWeight: FontWeight.bold, color: Colors.red,
      )),
      const SizedBox(height: 8),
      Text('Tap to stop', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      const SizedBox(height: 20),
      // Live transcript
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          (_partialText.isNotEmpty ? _partialText : _transcript).isEmpty
              ? 'Say something...'
              : _partialText.isNotEmpty ? _partialText : _transcript,
          style: tt.bodyLarge?.copyWith(
            color: (_partialText + _transcript).isEmpty ? cs.onSurfaceVariant : cs.onSurface,
            fontStyle: (_partialText + _transcript).isEmpty ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    ]);
  }

  Widget _buildProcessingState(ColorScheme cs, TextTheme tt) {
    return Column(children: [
      const SizedBox(height: 40),
      CircularProgressIndicator(color: cs.primary),
      const SizedBox(height: 24),
      Text('Understanding your meal...', style: tt.titleMedium),
      const SizedBox(height: 8),
      if (_transcript.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('"$_transcript"', style: tt.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
          )),
        ),
    ]);
  }

  Widget _buildConfirmedState(ColorScheme cs, TextTheme tt) {
    if (_meals.isEmpty) {
      return Column(children: [
        Icon(Icons.check_circle, size: 64, color: cs.primary),
        const SizedBox(height: 16),
        Text('All meals logged!', style: tt.titleMedium),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transcript
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.record_voice_over, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text('"$_transcript"', style: tt.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ))),
          ]),
        ),
        const SizedBox(height: 16),

        // Each meal group
        ..._meals.map((meal) => _buildMealCard(meal, cs, tt)),

        // Add more / correct via voice
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _state = _VoiceState.idle),
          icon: const Icon(Icons.mic),
          label: const Text('Add more or correct'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
        ),
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

        // Items
        ...items.map((item) {
          final matched = (item['match_confidence'] as num?)?.toDouble() ?? 0;
          final isMatched = matched > 0.4;
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: isMatched ? cs.primaryContainer : Colors.orange.shade100,
              child: Icon(
                isMatched ? Icons.check : Icons.help_outline,
                size: 16,
                color: isMatched ? cs.primary : Colors.orange.shade700,
              ),
            ),
            title: Text(item['food_name'] as String? ?? '', style: tt.bodyMedium),
            subtitle: Text(
              '${(item['grams'] as num?)?.toInt() ?? 0}g  •  ${(item['calories'] as num?)?.toInt() ?? 0} cal',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            trailing: isMatched
                ? null
                : Tooltip(
                    message: 'AI estimated — will create as custom food',
                    child: Icon(Icons.auto_awesome, size: 16, color: Colors.orange.shade600),
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
      'breakfast' => Icons.free_breakfast,
      'lunch' => Icons.lunch_dining,
      'dinner' => Icons.dinner_dining,
      _ => Icons.restaurant,
    };
    return Icon(icon, color: cs.primary);
  }

  Widget _buildErrorState(ColorScheme cs, TextTheme tt) {
    return Column(children: [
      const SizedBox(height: 30),
      Icon(Icons.error_outline, size: 64, color: cs.error),
      const SizedBox(height: 16),
      Text('Oops!', style: tt.titleMedium?.copyWith(color: cs.error)),
      const SizedBox(height: 8),
      Text(_errorMsg, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        textAlign: TextAlign.center),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => setState(() => _state = _VoiceState.idle),
        icon: const Icon(Icons.mic),
        label: const Text('Try Again'),
      ),
      const SizedBox(height: 8),
      // Text fallback
      OutlinedButton.icon(
        onPressed: _showTextInput,
        icon: const Icon(Icons.keyboard),
        label: const Text('Type instead'),
      ),
    ]);
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
            hintText: 'e.g. 2 rotis with dal for lunch',
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
                _processTranscript(ctrl.text.trim());
              }
            },
            child: const Text('Parse'),
          ),
        ],
      ),
    );
  }
}
