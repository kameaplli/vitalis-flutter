import 'dart:async';
import 'package:dio/dio.dart';
import 'constants.dart';
import 'secure_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // 1. Request deduplication — prevents duplicate concurrent GET requests
    dio.interceptors.add(_DeduplicationInterceptor());

    // 2. Retry interceptor — survives Railway cold starts
    dio.interceptors.add(_RetryInterceptor(dio));

    // 3. Auth + 401 handling
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Attempt silent token refresh before giving up
          final refreshToken = await SecureStorage.getRefreshToken();
          if (refreshToken != null) {
            try {
              final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
              final res = await refreshDio.post(
                ApiConstants.tokenRefresh,
                data: {'refresh_token': refreshToken},
              );
              final newToken = res.data['access_token'] as String;
              await SecureStorage.saveToken(newToken);
              // Retry the original request with the new token
              final opts = e.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';
              final response = await dio.fetch(opts);
              return handler.resolve(response);
            } catch (_) {
              await SecureStorage.clearToken();
              await SecureStorage.clearRefreshToken();
            }
          } else {
            await clearToken();
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<void> saveToken(String token) => SecureStorage.saveToken(token);
  Future<String?> getToken()           => SecureStorage.getToken();
  Future<void> clearToken()            => SecureStorage.clearToken();
}

final apiClient = ApiClient();

// ── Retry interceptor ──────────────────────────────────────────────────────────
// Retries idempotent GET requests up to 2 times with exponential backoff.
// Primary purpose: survive Railway free-tier cold starts (30–60s wake-up time).

class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  static const _maxRetries = 2;

  _RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;

    // Only retry safe, idempotent methods
    if (options.method.toUpperCase() != 'GET') {
      return handler.next(err);
    }

    // Only retry on network-level errors or 502/503/504 gateway errors
    if (!_isRetryable(err)) {
      return handler.next(err);
    }

    final retryCount = (options.extra['_retryCount'] as int?) ?? 0;
    if (retryCount >= _maxRetries) {
      return handler.next(err);
    }

    // Exponential backoff: 2s, 4s
    final delay = Duration(seconds: 2 * (retryCount + 1));
    await Future.delayed(delay);

    options.extra['_retryCount'] = retryCount + 1;

    try {
      // Re-attach auth header before retry
      final token = await SecureStorage.getToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      final response = await _dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    } catch (e) {
      return handler.next(err);
    }
  }

  bool _isRetryable(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout) return true;
    if (err.type == DioExceptionType.receiveTimeout) return true;
    if (err.type == DioExceptionType.connectionError) return true;
    final status = err.response?.statusCode;
    return status == 502 || status == 503 || status == 504;
  }
}

// ── Deduplication interceptor ────────────────────────────────────────────────
// Prevents duplicate concurrent GET requests to the same endpoint.
// If a GET request is already in flight, subsequent identical requests
// wait for and share the same response.

class _DeduplicationInterceptor extends Interceptor {
  final Map<String, Completer<Response>> _pending = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() != 'GET') {
      return handler.next(options);
    }

    final key = '${options.method}:${options.path}?${options.queryParameters}';

    if (_pending.containsKey(key)) {
      // Duplicate request — wait for the in-flight one
      _pending[key]!.future.then(
        (res) => handler.resolve(Response(
          requestOptions: options,
          data: res.data,
          statusCode: res.statusCode,
          headers: res.headers,
        )),
        onError: (e) => handler.reject(
          e is DioException ? e : DioException(requestOptions: options, error: e),
        ),
      );
      return;
    }

    // First request — mark as in-flight
    _pending[key] = Completer<Response>();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final key = '${response.requestOptions.method}:${response.requestOptions.path}?${response.requestOptions.queryParameters}';
    if (_pending.containsKey(key)) {
      _pending[key]!.complete(response);
      _pending.remove(key);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final key = '${err.requestOptions.method}:${err.requestOptions.path}?${err.requestOptions.queryParameters}';
    if (_pending.containsKey(key)) {
      _pending[key]!.completeError(err);
      _pending.remove(key);
    }
    handler.next(err);
  }
}
