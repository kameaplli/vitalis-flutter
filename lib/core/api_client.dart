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
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

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
          await clearToken();
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
