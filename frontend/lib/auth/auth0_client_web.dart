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
    //
    // useRefreshTokens + localStorage cache are required for iOS / Safari (and
    // every iOS browser, since they all run on WebKit): WebKit's ITP blocks the
    // third-party cookies that auth0-spa-js's default iframe silent-auth relies
    // on, which otherwise breaks login and token renewal. Refresh-token rotation
    // (via the requested `offline_access` scope) avoids the iframe entirely, and
    // localStorage persists the session across reloads.
    //
    // audience + scopes must be passed here too so the SDK's silent token
    // request targets the API (otherwise the audience is empty and the access
    // token isn't valid for the backend). Requires, on the Auth0 side: the API
    // to "Allow Offline Access" and the SPA app to have Refresh Token Rotation.
    try {
      final creds = await _auth0.onLoad(
        audience: _audience,
        scopes: Config.auth0Scopes,
        useRefreshTokens: true,
        cacheLocation: CacheLocation.localStorage,
      );
      if (creds == null) return null;
      return AuthSession(
          accessToken: creds.accessToken, userName: creds.user.name);
    } catch (e) {
      // No stored session yet — on a first visit (before login) the SDK throws
      // `login_required` / `MISSING_REFRESH_TOKEN` because there's nothing
      // cached. That's not an error to show the user: just fall through to the
      // login screen. A genuine login still works via the redirect flow.
      if (_isNoSessionError(e)) return null;
      rethrow;
    }
  }

  /// Whether an exception just means "not signed in yet" (vs a real failure).
  bool _isNoSessionError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('login_required') ||
        msg.contains('missing_refresh_token') ||
        msg.contains('missing refresh token') ||
        msg.contains('consent_required') ||
        msg.contains('interaction_required');
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
