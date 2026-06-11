import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the live-match countdown per match (locally) so leaving the
/// screen doesn't reset it. A RUNNING clock stores its absolute end time, so
/// it keeps ticking while the screen is closed — including into overtime.
/// A PAUSED clock stores the frozen remaining/overtime seconds.
class MatchClockStore {
  static String _key(int matchId) => 'match_clock_$matchId';

  static Future<void> saveRunning(
    int matchId, {
    required int setMin,
    required int endsAtMs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(matchId),
      jsonEncode({'setMin': setMin, 'running': true, 'endsAtMs': endsAtMs}),
    );
  }

  static Future<void> savePaused(
    int matchId, {
    required int setMin,
    required int remainingSec,
    required int overtimeSec,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(matchId),
      jsonEncode({
        'setMin': setMin,
        'running': false,
        'remainingSec': remainingSec,
        'overtimeSec': overtimeSec,
      }),
    );
  }

  static Future<Map<String, dynamic>?> load(int matchId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(matchId));
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(int matchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(matchId));
  }

  /// Whether this match's clock is currently running (incl. overtime).
  static Future<bool> isRunning(int matchId) async {
    final saved = await load(matchId);
    return saved != null && saved['running'] == true;
  }
}
