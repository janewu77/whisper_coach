import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A speaker language the user can pick in the Profile tab. `code` is an
/// ISO-639-1 code sent to the backend for speech recognition; empty = auto.
/// (Labels are intentionally in English — the app UI is English-only.)
class SpeakerLanguage {
  final String code;
  final String label;
  const SpeakerLanguage(this.code, this.label);
}

const kSpeakerLanguages = <SpeakerLanguage>[
  SpeakerLanguage('', 'Auto-detect'),
  SpeakerLanguage('en', 'English'),
  SpeakerLanguage('zh', 'Chinese (中文)'),
  SpeakerLanguage('de', 'German (Deutsch)'),
  SpeakerLanguage('es', 'Spanish (Español)'),
  SpeakerLanguage('fr', 'French (Français)'),
  SpeakerLanguage('ja', 'Japanese (日本語)'),
];

/// App-wide user preferences. Currently the speaker language used for voice
/// input (transcription). Persisted with shared_preferences. Singleton like the
/// other services so the API layer can read it without plumbing.
class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const _kLangKey = 'speaker_language';

  String _speakerLanguage = 'en';
  String get speakerLanguage => _speakerLanguage;

  SpeakerLanguage get speakerLanguageOption => kSpeakerLanguages.firstWhere(
        (l) => l.code == _speakerLanguage,
        orElse: () => kSpeakerLanguages.first,
      );

  /// Load persisted settings on startup.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _speakerLanguage = prefs.getString(_kLangKey) ?? 'en';
    } catch (_) {
      // Storage unavailable — keep the default.
    }
    notifyListeners();
  }

  Future<void> setSpeakerLanguage(String code) async {
    if (code == _speakerLanguage) return;
    _speakerLanguage = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLangKey, code);
    } catch (_) {
      // Best-effort persistence.
    }
  }
}
