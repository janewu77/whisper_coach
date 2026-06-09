/// Platform-agnostic contract for the Auth0 client.
///
/// Web and native use different Auth0 SDKs (`Auth0Web` vs `Auth0`) with
/// different flows (redirect vs system-browser). We hide that behind this
/// interface and pick the implementation with a conditional import in
/// [auth0_client_factory.dart].
library;

/// The result of a successful authentication: the access token to send to the
/// backend, plus a human-readable label for the UI.
class AuthSession {
  final String accessToken;
  final String? userName;
  final String? userEmail;

  const AuthSession({required this.accessToken, this.userName, this.userEmail});
}

abstract class Auth0Client {
  /// Restore an existing session on app start.
  ///
  /// On web this also completes the redirect callback (reading the code/state
  /// from the URL). Returns the session if the user is already logged in, else
  /// null.
  Future<AuthSession?> init();

  /// Begin login.
  ///
  /// Native: opens the system browser, awaits the result, and returns the
  /// session. Web: redirects the page to Auth0 and the returned future does not
  /// meaningfully complete (the session is picked up by [init] after reload),
  /// so it returns null.
  Future<AuthSession?> login();

  /// Log out of Auth0 and clear stored credentials.
  Future<void> logout();

  /// The current valid access token (refreshing silently if needed), or null
  /// when not authenticated. Called by the Dio interceptor on every request.
  Future<String?> accessToken();
}
