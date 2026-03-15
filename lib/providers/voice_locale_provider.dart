import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted voice locale preference for speech recognition.
///
/// Stores the user's preferred speech locale (e.g. 'en_IN', 'hi_IN', 'en_US').
/// Used by VoiceMealSheet and can be set during onboarding or in settings.

const _kVoiceLocaleKey = 'voice_locale';
const defaultVoiceLocale = 'en_IN';

/// All supported voice locales with display labels.
const voiceLocaleOptions = <String, String>{
  'en_IN': '🇮🇳 English (India)',
  'hi_IN': '🇮🇳 हिन्दी (Hindi)',
  'ta_IN': '🇮🇳 தமிழ் (Tamil)',
  'te_IN': '🇮🇳 తెలుగు (Telugu)',
  'kn_IN': '🇮🇳 ಕನ್ನಡ (Kannada)',
  'ml_IN': '🇮🇳 മലയാളം (Malayalam)',
  'mr_IN': '🇮🇳 मराठी (Marathi)',
  'bn_IN': '🇮🇳 বাংলা (Bengali)',
  'gu_IN': '🇮🇳 ગુજરાતી (Gujarati)',
  'en_US': '🇺🇸 English (US)',
  'en_GB': '🇬🇧 English (UK)',
  'en_AU': '🇦🇺 English (AU)',
};

class VoiceLocaleNotifier extends StateNotifier<String> {
  VoiceLocaleNotifier() : super(defaultVoiceLocale) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kVoiceLocaleKey);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setLocale(String localeId) async {
    state = localeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVoiceLocaleKey, localeId);
  }
}

final voiceLocaleProvider =
    StateNotifierProvider<VoiceLocaleNotifier, String>((ref) {
  return VoiceLocaleNotifier();
});
