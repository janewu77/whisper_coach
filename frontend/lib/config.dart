/// App configuration.
///
/// Values can be overridden at build/run time with `--dart-define`, e.g.
///   flutter run -d chrome \
///     --dart-define=AUTH0_DOMAIN=your-tenant.eu.auth0.com \
///     --dart-define=AUTH0_CLIENT_ID=xxxx \
///     --dart-define=AUTH0_AUDIENCE=https://whisper-coach.dacheng.dev/api
class Config {
  /// Backend API base URL.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://whisper-coach.dacheng.dev',
  );

  // ── Auth0 ──────────────────────────────────────────────────────────────
  // Leave domain/clientId empty to run the app without login (the backend is
  // also open until its AUTH0_* vars are set). Set all three to enable login.
  static const String auth0Domain =
      String.fromEnvironment('AUTH0_DOMAIN', defaultValue: '');
  static const String auth0ClientId =
      String.fromEnvironment('AUTH0_CLIENT_ID', defaultValue: '');

  /// The Auth0 API "Identifier" — must match the backend's AUTH0_AUDIENCE so
  /// the access token is accepted. Without it Auth0 issues an opaque token the
  /// backend cannot verify.
  static const String auth0Audience =
      String.fromEnvironment('AUTH0_AUDIENCE', defaultValue: '');

  /// Custom URL scheme for the native (iOS/Android) login callback. Must match
  /// the iOS Info.plist `CFBundleURLSchemes` (which uses the bundle id,
  /// `com.example.whisperCoach`) and the Android `auth0Scheme` manifest
  /// placeholder. Override per build with `--dart-define=AUTH0_SCHEME=...`.
  static const String auth0Scheme =
      String.fromEnvironment('AUTH0_SCHEME', defaultValue: 'com.example.whisperCoach');

  /// OAuth scopes. `offline_access` yields a refresh token on native.
  static const Set<String> auth0Scopes = {
    'openid',
    'profile',
    'email',
    'offline_access',
  };

  /// Whether login is wired up. When false the app skips the login gate.
  static bool get authEnabled =>
      auth0Domain.isNotEmpty && auth0ClientId.isNotEmpty;
}
