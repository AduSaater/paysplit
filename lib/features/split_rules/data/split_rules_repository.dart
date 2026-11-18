import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/local_cache_service.dart';

final splitRulesRepositoryProvider = Provider<SplitRulesRepository>((ref) {
  return SplitRulesRepository(
    ref.watch(apiClientProvider),
    ref.watch(localCacheProvider),
  );
});

class SplitRulesBundle {
  const SplitRulesBundle({
    required this.summary,
    required this.rules,
  });

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> rules;
}

final splitRulesBundleProvider =
    FutureProvider.family<SplitRulesBundle, String>((ref, status) async {
  return ref.watch(splitRulesRepositoryProvider).fetchBundle(status: status);
});

final splitRunsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(splitRulesRepositoryProvider).getSplitRuns();
});

class SplitRulesRepository {
  SplitRulesRepository(this._api, this._cache);

  final ApiClient _api;
  final LocalCacheService _cache;

  static const _cacheKey = 'split_rules_bundle_v1';

  Future<SplitRulesBundle> fetchBundle({String status = 'all'}) async {
    try {
      final results = await Future.wait([
        _api.get<Map<String, dynamic>>(ApiEndpoints.splitRulesSummary),
        _api.get<dynamic>(
          ApiEndpoints.splitRules,
          queryParameters: {'status': status, 'limit': 100},
        ),
      ]);
      final summary = results[0].data as Map<String, dynamic>? ?? {};
      final rules = extractList(results[1].data);

      if (status == 'all') {
        await _cache.setJson(_cacheKey, {'summary': summary, 'rules': rules});
      }
      return SplitRulesBundle(summary: summary, rules: rules);
    } on ApiException catch (e) {
      if (e.isNetworkError && status == 'all') {
        final cached = _cache.getJson<Map<String, dynamic>>(_cacheKey);
        if (cached != null) {
          return SplitRulesBundle(
            summary: (cached['summary'] as Map<String, dynamic>?) ?? {},
            rules: ((cached['rules'] as List<dynamic>?) ?? [])
                .cast<Map<String, dynamic>>(),
          );
        }
      }
      rethrow;
    }
  }

  Future<void> createRule({
    required String name,
    required int priority,
    required String destinationType,
    String? walletId,
    String? beneficiaryId,
    required String method,
    required num value,
  }) async {
    await _api.post<dynamic>(
      ApiEndpoints.splitRules,
      data: {
        'name': name.trim(),
        'priority': priority,
        'destinationType': destinationType,
        if (destinationType == 'wallet') 'walletId': walletId,
        if (destinationType == 'beneficiary') 'beneficiaryId': beneficiaryId,
        'method': method,
        'value': value,
        'status': 'active',
      },
    );
  }

  Future<void> updateRule(
    String id, {
    String? name,
    int? priority,
    String? destinationType,
    String? walletId,
    String? beneficiaryId,
    String? method,
    num? value,
    String? status,
  }) async {
    await _api.patch<dynamic>(
      ApiEndpoints.splitRuleById(id),
      data: {
        if (name != null) 'name': name.trim(),
        'priority': ?priority,
        'destinationType': ?destinationType,
        'walletId': ?walletId,
        'beneficiaryId': ?beneficiaryId,
        if (method != null && value != null) ...{
          'method': method,
          'value': value,
        },
        'status': ?status,
      },
    );
  }

  Future<void> deleteRule(String id) async {
    await _api.delete<dynamic>(ApiEndpoints.splitRuleById(id));
  }

  Future<Map<String, dynamic>> runSplitNow() async {
    final res = await _api.post<Map<String, dynamic>>(ApiEndpoints.splitRuns);
    return res.data ?? {};
  }

  Future<List<Map<String, dynamic>>> getSplitRuns() async {
    final res = await _api.get<dynamic>(
      ApiEndpoints.splitRuns,
      queryParameters: {'limit': 50},
    );
    return extractList(res.data);
  }
}
