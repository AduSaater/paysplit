import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/local_cache_service.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository(
    ref.watch(apiClientProvider),
    ref.watch(localCacheProvider),
  );
});

final transactionsListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, type) async {
  return ref.watch(transactionsRepositoryProvider).getTransactions(type: type);
});

class TransactionsRepository {
  TransactionsRepository(this._api, this._cache);

  final ApiClient _api;
  final LocalCacheService _cache;

  static const _cacheKey = 'transactions_all_v1';

  Future<List<Map<String, dynamic>>> getTransactions({
    String type = 'all',
    String? search,
  }) async {
    try {
      final res = await _api.get<dynamic>(
        ApiEndpoints.transactions,
        queryParameters: {
          'type': type,
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': 100,
        },
      );
      final list = extractList(res.data);
      if (type == 'all' && (search == null || search.isEmpty)) {
        await _cache.setJson(_cacheKey, list);
      }
      return list;
    } on ApiException catch (e) {
      if (e.isNetworkError && type == 'all') {
        final cached = _cache.getJson<List<dynamic>>(_cacheKey);
        if (cached != null) return cached.cast<Map<String, dynamic>>();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTransactionDetail(String id) async {
    final res =
        await _api.get<Map<String, dynamic>>(ApiEndpoints.transactionById(id));
    return res.data ?? {};
  }

  Future<File> exportStatementCsv({String type = 'all'}) async {
    final res = await _api.get<String>(
      ApiEndpoints.transactionsExport,
      queryParameters: {'type': type},
      options: Options(responseType: ResponseType.plain),
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/paysplit_statement_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(res.data ?? '');
    return file;
  }
}
