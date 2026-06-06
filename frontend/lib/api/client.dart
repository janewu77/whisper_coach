import 'package:dio/dio.dart';
import '../config.dart';

/// Singleton Dio instance with base URL, JSON content-type, and error logging.
final Dio dio = _buildDio();

Dio _buildDio() {
  final d = Dio(
    BaseOptions(
      baseUrl: Config.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
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
