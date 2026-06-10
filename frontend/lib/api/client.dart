import 'package:dio/dio.dart';
import '../auth/auth_service.dart';
import '../config.dart';

/// Singleton Dio instance with base URL, JSON content-type, and error logging.
final Dio dio = _buildDio();

/// Called after a successful API mutation (POST) that may have spent credits,
/// so the header balance can refresh. Wired up in `main()` to point at
/// `CreditsService.refresh` — kept as a hook here to avoid a circular import.
void Function()? onApiMutation;

Dio _buildDio() {
  final d = Dio(
    BaseOptions(
      baseUrl: Config.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
    ),
  );

  // Attach the Auth0 access token to every request (no-op when login is off).
  d.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AuthService.instance.accessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  // After a successful POST (the credit-spending verb), nudge the header to
  // refresh the balance. Skips the credits endpoints themselves to avoid loops.
  d.interceptors.add(
    InterceptorsWrapper(
      onResponse: (Response r, ResponseInterceptorHandler handler) {
        final opts = r.requestOptions;
        if (opts.method == 'POST' &&
            opts.path.startsWith('/api') &&
            !opts.path.startsWith('/api/credits')) {
          onApiMutation?.call();
        }
        handler.next(r);
      },
    ),
  );

  d.interceptors.add(
    InterceptorsWrapper(
      onError: (DioException e, ErrorInterceptorHandler handler) {
        // Surface FastAPI {detail} errors as readable messages
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              message: data['detail'].toString(),
              type: e.type,
            ),
          );
          return;
        }
        handler.next(e);
      },
    ),
  );

  return d;
}

/// Extracts the human-readable error message from a DioException.
String dioErrorMessage(Object e) {
  if (e is DioException) {
    if (e.message != null && e.message!.isNotEmpty) return e.message!;
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return 'Network error (${e.response?.statusCode ?? 'no response'})';
  }
  return e.toString();
}
