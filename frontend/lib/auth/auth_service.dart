import 'package:flutter/foundation.dart';

import '../config.dart';
import 'auth0_client.dart';
import 'auth0_client_factory.dart';

/// App-wide auth state. Wraps the platform [Auth0Client] and exposes a simple
/// authenticated / not-authenticated state for the UI, plus a token accessor
/// for the Dio interceptor.
class AuthService extends ChangeNotifier {
  AuthService._() : _client = createAuth0Client();

  /// Singleton so the Dio interceptor (in api/client.dart) can reach the token
  /// without plumbing it through every call site.
  static final AuthService instance = AuthService._();

  final Auth0Client _client;

  bool _ready = false;
  bool _authenticated = false;
  String? _userName;
  String? _error;

  /// True once [init] has finished (so the UI can show a splash until then).
  bool get isReady => _ready;
  bool get isAuthenticated => _authenticated;
  String? get userName => _userName;
  String? get error => _error;

  /// Restore any existing session on startup (and complete the web redirect).
  Future<void> init() async {
    if (!Config.authEnabled) {
      _authenticated = true; // login disabled → treat everyone as allowed
      _ready = true;
      notifyListeners();
      return;
    }
    try {
      final session = await _client.init();
      _applySession(session);
    } catch (e) {
      _error = e.toString();
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> login() async {
    _error = null;
    try {
      final session = await _client.login();
      // Web redirects away and returns null here; native returns the session.
      _applySession(session);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _client.logout();
    } finally {
      _authenticated = false;
      _userName = null;
      notifyListeners();
    }
  }

  /// Current bearer token for outgoing requests, or null if unavailable.
  Future<String?> accessToken() {
    if (!Config.authEnabled) return Future.value(null);
    return _client.accessToken();
  }

  void _applySession(AuthSession? session) {
    if (session == null) return;
    _authenticated = true;
    _userName = session.userName;
  }
}
