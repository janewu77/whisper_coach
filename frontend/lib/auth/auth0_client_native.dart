import 'package:auth0_flutter/auth0_flutter.dart';

import '../config.dart';
import 'auth0_client.dart';

Auth0Client createAuth0Client() => NativeAuth0Client();

/// iOS / Android implementation. Uses the system browser
/// (ASWebAuthenticationSession / Chrome Custom Tabs) via Auth0's
/// `webAuthentication`, and the built-in CredentialsManager for secure,
/// auto-renewing token storage (Keychain / Keystore).
class NativeAuth0Client implements Auth0Client {
  final Auth0 _auth0 = Auth0(Config.auth0Domain, Config.auth0ClientId);

  WebAuthentication get _web =>
      _auth0.webAuthentication(scheme: Config.auth0Scheme);

  AuthSession _toSession(Credentials c) => AuthSession(
        accessToken: c.accessToken,
        userName: c.user.name,
        userEmail: c.user.email,
      );

  @override
  Future<AuthSession?> init() async {
    if (!await _auth0.credentialsManager.hasValidCredentials()) return null;
    final creds = await _auth0.credentialsManager.credentials();
    return _toSession(creds);
  }

  @override
  Future<AuthSession?> login() async {
    final creds = await _web.login(
      audience: Config.auth0Audience.isEmpty ? null : Config.auth0Audience,
      scopes: Config.auth0Scopes,
    );
    // webAuthentication().login() stores credentials in the CredentialsManager
    // automatically.
    return _toSession(creds);
  }

  @override
  Future<void> logout() async {
    await _web.logout();
    await _auth0.credentialsManager.clearCredentials();
  }

  @override
  Future<String?> accessToken() async {
    if (!await _auth0.credentialsManager.hasValidCredentials()) return null;
    final creds = await _auth0.credentialsManager.credentials();
    return creds.accessToken;
  }
}
