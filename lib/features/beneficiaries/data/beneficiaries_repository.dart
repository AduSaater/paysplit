import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/local_cache_service.dart';

final beneficiariesRepositoryProvider = Provider<BeneficiariesRepository>((ref) {
  return BeneficiariesRepository(
    ref.watch(apiClientProvider),
    ref.watch(localCacheProvider),
  );
});

final beneficiariesListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, status) async {
  return ref
      .watch(beneficiariesRepositoryProvider)
      .getBeneficiaries(status: status);
});

class BeneficiariesRepository {
  BeneficiariesRepository(this._api, this._cache);

  final ApiClient _api;
  final LocalCacheService _cache;

  static const _cacheKey = 'beneficiaries_list_v1';

  Future<List<Map<String, dynamic>>> getBeneficiaries({
    String status = 'all',
    String? search,
  }) async {
    try {
      final res = await _api.get<dynamic>(
        ApiEndpoints.beneficiaries,
        queryParameters: {
          'status': status,
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': 50,
        },
      );
      final list = extractList(res.data);
      if (status == 'all' && (search == null || search.isEmpty)) {
        await _cache.setJson(_cacheKey, list);
      }
      return list;
    } on ApiException catch (e) {
      if (e.isNetworkError && status == 'all') {
        final cached = _cache.getJson<List<dynamic>>(_cacheKey);
        if (cached != null) return cached.cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resolveAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.resolveBeneficiary,
      data: {'bankCode': bankCode, 'accountNumber': accountNumber.trim()},
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> createBeneficiary({
    required String bankCode,
    required String accountNumber,
    required String categoryId,
    String? narration,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.beneficiaries,
      data: {
        'bankCode': bankCode,
        'accountNumber': accountNumber.trim(),
        'categoryId': categoryId,
        if (narration != null && narration.trim().isNotEmpty)
          'narration': narration.trim(),
      },
    );
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> getDetail(String id) async {
    final res =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.beneficiaryById(id));
    return res.data ?? {};
  }

  Future<List<Map<String, dynamic>>> getTransactions(String id) async {
    final res = await _api.get<dynamic>(
      ApiEndpoints.beneficiaryTransactions(id),
      queryParameters: {'limit': 50},
    );
    return extractList(res.data);
  }

  Future<void> updateBeneficiary(
    String id, {
    String? status,
    String? categoryId,
    String? narration,
  }) async {
    await _api.patch<dynamic>(
      ApiEndpoints.beneficiaryById(id),
      data: {
        'status': ?status,
        'categoryId': ?categoryId,
        'narration': ?narration,
      },
    );
  }

  Future<void> deleteBeneficiary(String id) async {
    await _api.delete<dynamic>(ApiEndpoints.beneficiaryById(id));
  }
}
