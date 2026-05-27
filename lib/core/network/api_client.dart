import 'package:dio/dio.dart';

import '../config/env_config.dart';
import '../storage/secure_storage_service.dart';
import '../utils/api_exception.dart';

typedef UnauthorizedCallback = void Function();

class ApiClient {
  late final Dio dio;
  final SecureStorageService _storage;
  UnauthorizedCallback? onUnauthorized;

  ApiClient(this._storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  String messageFromError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'] ?? data['message'];
      if (err != null) return err.toString();
    }
    return e.message ?? 'Network error';
  }

  Never throwFromDio(DioException e) {
    throw ApiException(
      messageFromError(e),
      statusCode: e.response?.statusCode,
    );
  }
}
