import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../storage/local_cache_service.dart';

final lookupRepositoryProvider = Provider<LookupRepository>((ref) {
  return LookupRepository(
    ref.watch(apiClientProvider),
    ref.watch(localCacheProvider),
  );
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(lookupRepositoryProvider).getCategories();
});

final banksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(lookupRepositoryProvider).getBanks();
});

class LookupRepository {
  LookupRepository(this._api, this._cache);

  final ApiClient _api;
  final LocalCacheService _cache;

  static const _categoriesKey = 'categories_v1';
  static const _banksKey = 'banks_v1';

  Future<List<Map<String, dynamic>>> getCategories() async {
    final cached = _cache.getJson<List<dynamic>>(
      _categoriesKey,
      maxAge: const Duration(hours: 24),
    );
    if (cached != null) {
      return cached.cast<Map<String, dynamic>>();
    }
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.categories);
      final list = (res.data ?? []).cast<Map<String, dynamic>>();
      await _cache.setJson(_categoriesKey, list);
      return list;
    } on ApiException {
      final stale = _cache.getJson<List<dynamic>>(_categoriesKey);
      if (stale != null) return stale.cast<Map<String, dynamic>>();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getBanks() async {
    final cached = _cache.getJson<List<dynamic>>(
      _banksKey,
      maxAge: const Duration(hours: 24),
    );
    if (cached != null) {
      return cached.cast<Map<String, dynamic>>();
    }
    try {
      final res = await _api.get<List<dynamic>>(ApiEndpoints.banks);
      final list = (res.data ?? []).cast<Map<String, dynamic>>();
      await _cache.setJson(_banksKey, list);
      return list;
    } on ApiException {
      final stale = _cache.getJson<List<dynamic>>(_banksKey);
      if (stale != null) return stale.cast<Map<String, dynamic>>();
      rethrow;
    }
  }
}
