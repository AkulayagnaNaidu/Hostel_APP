import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/utils/api_exception.dart';
import '../models/auth_user.dart';

class AuthService {
  final ApiClient _client;
  final SecureStorageService _storage;

  AuthUser? currentUser;
  final ValueNotifier<bool> isLoggedIn = ValueNotifier(false);

  AuthService(this._client, this._storage);

  Future<void> restoreSession() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      isLoggedIn.value = false;
      currentUser = null;
      return;
    }

    final id = await _storage.readUserId();
    final role = await _storage.readUserRole();
    final name = await _storage.readUserName();
    final email = await _storage.readUserEmail();

    if (id != null && id.isNotEmpty) {
      currentUser = AuthUser(
        id: id,
        name: name,
        email: email,
        role: role ?? 'TENANT',
      );
    }

    isLoggedIn.value = true;
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final resp = await _client.dio.post(
        ApiEndpoints.authLogin,
        data: {'email': email, 'password': password},
      );
      return _persistAuthResponse(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    String role = 'TENANT',
  }) async {
    try {
      final resp = await _client.dio.post(
        ApiEndpoints.authRegister,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          'phone': phone,
        },
      );
      return _persistAuthResponse(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _client.throwFromDio(e);
    }
  }

  Future<AuthUser> _persistAuthResponse(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('No token in response');
    }
    await _storage.saveToken(token);

    final userJson = data['user'] as Map<String, dynamic>? ?? {};
    final user = AuthUser.fromJson(userJson);
    await _storage.saveUserId(user.id);
    await _storage.saveUserRole(user.role);
    currentUser = user;
    isLoggedIn.value = true;
    return user;
  }

  Future<void> logout() async {
    await _storage.clearSession();
    currentUser = null;
    isLoggedIn.value = false;
  }
}
