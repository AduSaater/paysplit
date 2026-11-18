import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/local_cache_service.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    ref.watch(apiClientProvider),
    ref.watch(localCacheProvider),
  );
});

class DashboardBundle {
  const DashboardBundle({
    required this.summary,
    required this.salaryAccount,
    required this.setupProgress,
    required this.recentTransactions,
    required this.unreadNotifications,
    this.fromCache = false,
  });

  final Map<String, dynamic> summary;
  final Map<String, dynamic> salaryAccount;
  final Map<String, dynamic> setupProgress;
  final List<Map<String, dynamic>> recentTransactions;
  final int unreadNotifications;
  final bool fromCache;
}

class DashboardRepository {
  DashboardRepository(this._api, this._cache);

  final ApiClient _api;
  final LocalCacheService _cache;

  static const _cacheKey = 'dashboard_bundle_v1';

  Future<DashboardBundle> fetchDashboard() async {
    try {
      final results = await Future.wait([
        _api.get<Map<String, dynamic>>(ApiEndpoints.dashboardSummary),
        _api.get<Map<String, dynamic>>(ApiEndpoints.salaryAccount),
        _api.get<Map<String, dynamic>>(ApiEndpoints.setupProgress),
        _api.get<dynamic>(
          ApiEndpoints.transactions,
          queryParameters: {'limit': 5, 'page': 1},
        ),
        _api.get<Map<String, dynamic>>(
          ApiEndpoints.notifications,
          queryParameters: {'limit': 1, 'unreadOnly': true},
        ),
      ]);

      final summary = results[0].data as Map<String, dynamic>? ?? {};
      final salaryAccount = results[1].data as Map<String, dynamic>? ?? {};
      final setupProgress = results[2].data as Map<String, dynamic>? ?? {};
      final txList = extractList(results[3].data);
      final notifData = results[4].data as Map<String, dynamic>? ?? {};
      final unread = (notifData['unreadCount'] as num?)?.toInt() ?? 0;

      await _cache.setJson(_cacheKey, {
        'summary': summary,
        'salaryAccount': salaryAccount,
        'setupProgress': setupProgress,
        'recentTransactions': txList,
        'unreadNotifications': unread,
      });

      return DashboardBundle(
        summary: summary,
        salaryAccount: salaryAccount,
        setupProgress: setupProgress,
        recentTransactions: txList,
        unreadNotifications: unread,
      );
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        final cached = _cache.getJson<Map<String, dynamic>>(_cacheKey);
        if (cached != null) {
          return DashboardBundle(
            summary: (cached['summary'] as Map<String, dynamic>?) ?? {},
            salaryAccount:
                (cached['salaryAccount'] as Map<String, dynamic>?) ?? {},
            setupProgress:
                (cached['setupProgress'] as Map<String, dynamic>?) ?? {},
            recentTransactions:
                ((cached['recentTransactions'] as List<dynamic>?) ?? [])
                    .cast<Map<String, dynamic>>(),
            unreadNotifications:
                (cached['unreadNotifications'] as num?)?.toInt() ?? 0,
            fromCache: true,
          );
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> simulateSalaryCredit({
    required int amountKobo,
    String? senderName,
    String? narration,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.simulateCredit,
      data: {
        'amount': amountKobo,
        if (senderName != null && senderName.isNotEmpty)
          'senderName': senderName,
        if (narration != null && narration.isNotEmpty) 'narration': narration,
      },
    );
    return res.data ?? {};
  }
}
