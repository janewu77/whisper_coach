import 'package:auth0_flutter/auth0_flutter_web.dart';

import '../config.dart';
import 'auth0_client.dart';

Auth0Client createAuth0Client() => WebAuth0Client();

/// Flutter web implementation, backed by auth0-spa-js (loaded via a <script>
/// tag in web/index.html). Login uses a full-page redirect; tokens are obtained
/// silently afterwards.
class WebAuth0Client implements Auth0Client {
  final Auth0Web _auth0 = Auth0Web(Config.auth0Domain, Config.auth0ClientId);

  String? get _audience =>
      Config.auth0Audience.isEmpty ? null : Config.auth0Audience;

  /// The current page URL without query/fragment, e.g.
  /// `https://whisper-coach.dacheng.dev/app/`. Used as the explicit redirect /
  /// logout target so it matches the Auth0 Allowed Callback/Logout URLs exactly
  /// (auth0-spa-js would otherwise default to the bare origin). Adapts to both
  /// the `/app/` and the GitHub Pages `/whisper_coach/app/` base paths.
  String get _appUrl {
    final b = Uri.base;
    return '${b.origin}${b.path}';
  }

  @override
  Future<AuthSession?> init() async {
    // Completes the redirect callback (if returning from Auth0) and hydrates the
    // SPA session. onLoad returns the credentials when authenticated, else null.
    final creds = await _auth0.onLoad();
    if (creds == null) return null;
    return AuthSession(accessToken: creds.accessToken, userName: creds.user.name);
  }

  @override
  Future<AuthSession?> login() async {
    // Redirects the page to Auth0; the session is read back by [init] on reload.
    await _auth0.loginWithRedirect(
      audience: _audience,
      scopes: Config.auth0Scopes,
      redirectUrl: _appUrl,
    );
    return null;
  }

  @override
  Future<void> logout() => _auth0.logout(returnToUrl: _appUrl);

  @override
  Future<String?> accessToken() async {
    try {
      final creds = await _auth0.credentials(
        audience: _audience,
        scopes: Config.auth0Scopes,
      );
      return creds.accessToken;
    } catch (_) {
      // Not authenticated / silent auth failed.
      return null;
    }
  }
}
