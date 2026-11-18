import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/secure_storage_service.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    ref.watch(apiClientProvider),
    ref.watch(localCacheProvider),
    ref.watch(secureStorageProvider),
  );
});

final userProfileProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(settingsRepositoryProvider).getProfile();
});

final notificationsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(settingsRepositoryProvider).getNotifications();
});

class SettingsRepository {
  SettingsRepository(this._api, this._cache, this._storage);

  final ApiClient _api;
  final LocalCacheService _cache;
  final SecureStorageService _storage;

  static const _profileCacheKey = 'user_profile_v1';

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final res =
          await _api.get<Map<String, dynamic>>(ApiEndpoints.userProfile);
      final data = res.data ?? {};
      await _cache.setJson(_profileCacheKey, data);
      return data;
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        final cached = _cache.getJson<Map<String, dynamic>>(_profileCacheKey);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  Future<void> upsertIncome({
    required String employerName,
    required int monthlyAmountKobo,
    required int paydayDay,
  }) async {
    await _api.put<dynamic>(
      ApiEndpoints.setupIncome,
      data: {
        'employerName': employerName.trim(),
        'monthlyAmount': monthlyAmountKobo,
        'paydayDay': paydayDay,
      },
    );
  }

  Future<void> updateNotificationPreferences(
      Map<String, dynamic> prefs) async {
    await _api.put<dynamic>(
      ApiEndpoints.notificationPreferences,
      data: prefs,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.changePassword,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
    final token = (res.data?['accessToken'] ?? res.data?['token'])?.toString();
    if (token != null && token.isNotEmpty) {
      await _storage.saveAccessToken(token);
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await _api.get<dynamic>(
      ApiEndpoints.notifications,
      queryParameters: {'limit': 50},
    );
    return extractList(res.data);
  }

  Future<void> markNotificationRead(String id) async {
    await _api.post<dynamic>(ApiEndpoints.markNotificationRead(id));
  }

  Future<void> markAllNotificationsRead() async {
    await _api.post<dynamic>(ApiEndpoints.markAllNotificationsRead);
  }
}
