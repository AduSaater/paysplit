import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/secure_storage_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
    ref.watch(localCacheProvider),
  );
});

class AuthRepository {
  AuthRepository(this._api, this._storage, this._cache);

  final ApiClient _api;
  final SecureStorageService _storage;
  final LocalCacheService _cache;

  static const _meCacheKey = 'auth_me';

  Future<Map<String, dynamic>> signup({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.signup,
      data: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
      },
    );
    await _storage.saveUserEmail(email.trim());
    return res.data ?? {};
  }

  Future<String> verifyEmail({
    required String email,
    required String code,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.verifyEmail,
      data: {'email': email.trim(), 'code': code.trim()},
    );
    final data = res.data ?? {};
    final setupToken =
        (data['setupToken'] ?? data['token'] ?? '').toString();
    if (setupToken.isNotEmpty) {
      await _storage.saveSetupToken(setupToken);
    }
    return setupToken;
  }

  Future<int> resendEmailCode(String email) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.resendEmail,
      data: {'email': email.trim()},
    );
    final data = res.data ?? {};
    return (data['resendAvailableInSeconds'] as num?)?.toInt() ?? 60;
  }

  Future<Map<String, dynamic>> setPassword({
    required String password,
    required String confirmPassword,
  }) async {
    final setupToken = await _storage.getSetupToken();
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.setPassword,
      data: {'password': password, 'confirmPassword': confirmPassword},
      options: Options(
        headers: {
          if (setupToken != null && setupToken.isNotEmpty)
            'Authorization': 'Bearer $setupToken',
        },
      ),
    );
    final data = res.data ?? {};
    final accessToken =
        (data['accessToken'] ?? data['token'] ?? '').toString();
    if (accessToken.isNotEmpty) {
      await _storage.saveAccessToken(accessToken);
      await _storage.deleteSetupToken();
    }
    await _cache.setJson(_meCacheKey, data);
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {
        'email': email.trim(),
        'password': password,
        'rememberMe': rememberMe,
      },
    );
    final data = res.data ?? {};
    final accessToken =
        (data['accessToken'] ?? data['token'] ?? '').toString();
    if (accessToken.isNotEmpty) {
      await _storage.saveAccessToken(accessToken);
    }
    await _storage.saveUserEmail(email.trim());
    await _cache.setJson(_meCacheKey, data);
    return data;
  }

  Future<Map<String, dynamic>> getMe() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.me);
      final data = res.data ?? {};
      await _cache.setJson(_meCacheKey, data);
      return data;
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        final cached = _cache.getJson<Map<String, dynamic>>(_meCacheKey);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post<dynamic>(ApiEndpoints.logout);
    } catch (_) {
      // Clear local credentials even if network fails during sign-out
    } finally {
      await _storage.clearAll();
      await _cache.clearAll();
    }
  }

  Future<void> forgotPassword(String email) async {
    await _api.post<dynamic>(
      ApiEndpoints.forgotPassword,
      data: {'email': email.trim()},
    );
  }

  Future<void> verifyResetCode({
    required String email,
    required String code,
  }) async {
    await _api.post<dynamic>(
      ApiEndpoints.verifyResetCode,
      data: {'email': email.trim(), 'code': code.trim()},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await _api.post<dynamic>(
      ApiEndpoints.resetPassword,
      data: {'email': email.trim(), 'newPassword': newPassword},
    );
  }

  Future<bool> hasToken() async {
    final token = await _storage.getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
