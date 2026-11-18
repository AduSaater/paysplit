import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/local_cache_service.dart';

final walletsRepositoryProvider = Provider<WalletsRepository>((ref) {
  return WalletsRepository(
    ref.watch(apiClientProvider),
    ref.watch(localCacheProvider),
  );
});

final walletsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(walletsRepositoryProvider).getWallets();
});

class WalletsRepository {
  WalletsRepository(this._api, this._cache);

  final ApiClient _api;
  final LocalCacheService _cache;

  static const _cacheKey = 'wallets_list_v1';

  Future<List<Map<String, dynamic>>> getWallets() async {
    try {
      final res = await _api.get<dynamic>(ApiEndpoints.wallets);
      final list = extractList(res.data);
      await _cache.setJson(_cacheKey, list);
      return list;
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        final cached = _cache.getJson<List<dynamic>>(_cacheKey);
        if (cached != null) return cached.cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getWalletDetail(String id) async {
    final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.walletById(id));
    return res.data ?? {};
  }

  Future<List<Map<String, dynamic>>> getWalletTransactions(
    String id, {
    String filter = 'all',
  }) async {
    final res = await _api.get<dynamic>(
      ApiEndpoints.walletTransactions(id),
      queryParameters: {'filter': filter, 'limit': 50},
    );
    return extractList(res.data);
  }

  Future<List<Map<String, dynamic>>> getAllActivity({
    String direction = 'all',
  }) async {
    final res = await _api.get<dynamic>(
      ApiEndpoints.walletActivity,
      queryParameters: {'direction': direction, 'limit': 50},
    );
    return extractList(res.data);
  }

  Future<Map<String, dynamic>> createWallet({
    required String name,
    required String categoryId,
    required String accentColor,
    int? targetAmountKobo,
  }) async {
    final res = await _api.post<dynamic>(
      ApiEndpoints.wallets,
      data: {
        'name': name.trim(),
        'categoryId': categoryId,
        'accentColor': accentColor,
        'targetAmount': ?targetAmountKobo,
      },
    );
    return (res.data is Map<String, dynamic>)
        ? res.data as Map<String, dynamic>
        : {};
  }

  Future<Map<String, dynamic>> updateWallet(
    String id, {
    String? name,
    String? categoryId,
    String? accentColor,
    int? targetAmountKobo,
  }) async {
    final res = await _api.patch<Map<String, dynamic>>(
      ApiEndpoints.walletById(id),
      data: {
        if (name != null) 'name': name.trim(),
        'categoryId': ?categoryId,
        'accentColor': ?accentColor,
        'targetAmount': targetAmountKobo,
      },
    );
    return res.data ?? {};
  }

  Future<void> deleteWallet(String id) async {
    await _api.delete<dynamic>(ApiEndpoints.walletById(id));
  }

  Future<void> moveToSalaryAccount(String id, int amountKobo) async {
    await _api.post<dynamic>(
      ApiEndpoints.walletMove(id),
      data: {'amount': amountKobo},
    );
  }
}
