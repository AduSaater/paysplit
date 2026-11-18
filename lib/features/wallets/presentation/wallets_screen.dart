import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../data/wallets_repository.dart';
import 'create_wallet_sheet.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(walletsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallets'),
        actions: [
          IconButton(
            tooltip: 'Create wallet',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () async {
              final created = await showWalletFormSheet(context);
              if (created) ref.invalidate(walletsListProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(walletsListProvider),
        child: walletsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: LoadingShimmerList(),
          ),
          error: (err, _) => ListView(
            children: [
              ErrorStateView(
                message: err.toString(),
                isOffline: err is ApiException && err.isNetworkError,
                onRetry: () => ref.invalidate(walletsListProvider),
              ),
            ],
          ),
          data: (wallets) {
            if (wallets.isEmpty) {
              return ListView(
                children: [
                  EmptyStateView(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No savings wallets yet',
                    subtitle:
                        'Create goal-based wallets to automatically route a portion of your salary.',
                    actionLabel: 'Create Wallet',
                    onAction: () async {
                      final created = await showWalletFormSheet(context);
                      if (created) ref.invalidate(walletsListProvider);
                    },
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: wallets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final w = wallets[i];
                final id = w['id'].toString();
                final name = w['name']?.toString() ?? 'Wallet';
                final balance = (w['balance'] ?? 0) as num;
                final target = w['targetAmount'] as num?;
                final color = AppColors.walletAccent(w['accentColor']?.toString());
                final categoryName =
                    (w['category'] as Map<String, dynamic>?)?['name']
                            ?.toString() ??
                        w['categoryName']?.toString() ??
                        'Savings';
                final progress = (target != null && target > 0)
                    ? (balance / target).clamp(0.0, 1.0)
                    : null;

                return AppCard(
                  onTap: () => context.push('/wallets/$id'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: AppTextStyles.titleMedium),
                                Text(categoryName, style: AppTextStyles.bodySmall),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatKobo(balance),
                            style: AppTextStyles.titleMedium,
                          ),
                        ],
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.surfaceSubtle,
                          color: color,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}% of goal',
                              style: AppTextStyles.bodySmall,
                            ),
                            Text(
                              'Target: ${CurrencyFormatter.formatKobo(target)}',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
