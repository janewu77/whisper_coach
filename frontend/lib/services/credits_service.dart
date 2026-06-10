import 'package:flutter/foundation.dart';

import '../api/api.dart';

/// App-wide credit balance shown in the header. A singleton (like
/// [TeamService]) so the header can react to spends from anywhere.
///
/// [refresh] is called on load and after any credit-spending action (wired via
/// a Dio response interceptor on successful POSTs), so the balance stays live
/// without each screen having to update it.
class CreditsService extends ChangeNotifier {
  CreditsService._();

  static final CreditsService instance = CreditsService._();

  int? _balance;
  bool _loaded = false;

  int? get balance => _balance;
  bool get loaded => _loaded;

  /// Re-fetch the balance from the backend. Silently ignores failures (the
  /// header just keeps the last known value).
  Future<void> refresh() async {
    try {
      final value = await api.getCredits();
      _balance = value;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Keep the previous value on transient errors.
    }
  }

  /// Reset on logout so the next user starts clean.
  void reset() {
    _balance = null;
    _loaded = false;
    notifyListeners();
  }
}
