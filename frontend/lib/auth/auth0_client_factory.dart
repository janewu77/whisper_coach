/// Picks the right [Auth0Client] implementation at compile time:
/// the web SDK when `dart:html` is available, the native SDK otherwise, and a
/// stub that errors clearly on unsupported targets.
export 'auth0_client_stub.dart'
    if (dart.library.html) 'auth0_client_web.dart'
    if (dart.library.io) 'auth0_client_native.dart';
