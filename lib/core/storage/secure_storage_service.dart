import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _tokenKey = 'token';
  static const _userIdKey = 'user_id';
  static const _userRoleKey = 'user_role';
  static const _userNameKey = 'user_name';
  static const _userEmailKey = 'user_email';
  static const _userPhoneKey = 'user_phone';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  Future<void> saveUserId(String id) => _storage.write(key: _userIdKey, value: id);

  Future<String?> readUserRole() => _storage.read(key: _userRoleKey);

  Future<void> saveUserRole(String role) =>
      _storage.write(key: _userRoleKey, value: role);

  Future<String?> readUserName() => _storage.read(key: _userNameKey);

  Future<String?> readUserEmail() => _storage.read(key: _userEmailKey);

  Future<String?> readUserPhone() => _storage.read(key: _userPhoneKey);

  Future<void> saveUserProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    await _storage.write(key: _userNameKey, value: name);
    await _storage.write(key: _userEmailKey, value: email);
    if (phone != null && phone.isNotEmpty) {
      await _storage.write(key: _userPhoneKey, value: phone);
    }
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userRoleKey);
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: _userPhoneKey);
  }
}
