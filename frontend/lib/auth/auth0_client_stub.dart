import 'auth0_client.dart';

/// Fallback used on platforms where neither web nor native SDK applies.
Auth0Client createAuth0Client() => _UnsupportedAuth0Client();

class _UnsupportedAuth0Client implements Auth0Client {
  Never _fail() =>
      throw UnsupportedError('Auth0 is not supported on this platform');

  @override
  Future<AuthSession?> init() async => null;

  @override
  Future<AuthSession?> login() => _fail();

  @override
  Future<void> logout() => _fail();

  @override
  Future<String?> accessToken() async => null;
}
