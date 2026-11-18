import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Wraps platform Keychain (iOS) / Keystore (Android) for sensitive tokens.
class SecureStorageService {
  static const _accessTokenKey = 'paysplit_access_token';
  static const _setupTokenKey = 'paysplit_setup_token';
  static const _userEmailKey = 'paysplit_user_email';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<void> deleteAccessToken() => _storage.delete(key: _accessTokenKey);

  Future<void> saveSetupToken(String token) =>
      _storage.write(key: _setupTokenKey, value: token);

  Future<String?> getSetupToken() => _storage.read(key: _setupTokenKey);

  Future<void> deleteSetupToken() => _storage.delete(key: _setupTokenKey);

  Future<void> saveUserEmail(String email) =>
      _storage.write(key: _userEmailKey, value: email);

  Future<String?> getUserEmail() => _storage.read(key: _userEmailKey);

  Future<void> clearAll() => _storage.deleteAll();
}
