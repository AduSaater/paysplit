import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../data/wallets_repository.dart';
import 'create_wallet_sheet.dart';

final walletActivityProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(walletsRepositoryProvider).getAllActivity();
});

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  final _pageCtrl = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsListProvider);
    final activityAsync = ref.watch(walletActivityProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(walletsListProvider);
        ref.invalidate(walletActivityProvider);
      },
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
          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              if (wallets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppCard(
                    child: EmptyStateView(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No savings wallets yet',
                      subtitle:
                          'Create goal-based wallets to automatically route a portion of your salary.',
                      actionLabel: '+ Create Wallet',
                      onAction: () async {
                        final created = await showWalletFormSheet(context);
                        if (created) ref.invalidate(walletsListProvider);
                      },
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  height: 176,
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: wallets.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) {
                      final w = wallets[i];
                      final id = w['id'].toString();
                      final name = w['name']?.toString() ?? 'Wallet';
                      final balance = (w['balance'] ?? 0) as num;
                      final target = w['targetAmount'] as num?;
                      final color =
                          AppColors.walletAccent(w['accentColor']?.toString());
                      final categoryName =
                          (w['category'] as Map<String, dynamic>?)?['name']
                                  ?.toString() ??
                              w['categoryName']?.toString() ??
                              'Savings';
                      final progress = (target != null && target > 0)
                          ? (balance / target).clamp(0.0, 1.0)
                          : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: AppCard(
                          onTap: () => context.push('/wallets/$id'),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: color,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: AppTextStyles.titleMedium
                                              .copyWith(fontSize: 15),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          categoryName,
                                          style: AppTextStyles.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatKobo(
                                      balance,
                                      showDecimals: false,
                                    ),
                                    style: AppTextStyles.titleMedium,
                                  ),
                                ],
                              ),
                              if (target != null && target > 0) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Target: ${CurrencyFormatter.formatKobo(target, showDecimals: false)}',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                    Text(
                                      '${(progress * 100).toStringAsFixed(0)}%',
                                      style: AppTextStyles.labelSmall,
                                    ),
                                  ],
                                ),
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: AppColors.surfaceSubtle,
                                  color: AppColors.textPrimary,
                                  minHeight: 7,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Created: ${DateFormatter.formatDate(w['createdAt']?.toString())}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                  Text(
                                    'View wallet →',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(wallets.length, (i) {
                    final active = i == _page;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 16 : 6,
                      height: 3,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primaryDark
                            : AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppPrimaryButton(
                    label: '+ Create Wallet',
                    onPressed: () async {
                      final created = await showWalletFormSheet(context);
                      if (created) ref.invalidate(walletsListProvider);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SectionHeader(
                      title: 'Recent Activity',
                      actionLabel: 'See all',
                      onAction: () => context.go('/history'),
                    ),
                    const SizedBox(height: 10),
                    activityAsync.when(
                      loading: () => const LoadingShimmerList(itemCount: 3),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (items) {
                        if (items.isEmpty) {
                          return const AppCard(
                            child: EmptyStateView(
                              icon: Icons.history_rounded,
                              title: 'No wallet activity yet',
                              subtitle:
                                  'Allocations and transfers across your wallets appear here.',
                            ),
                          );
                        }
                        return AppCard(
                          padding: EdgeInsets.zero,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.take(5).length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (_, i) {
                              final t = items[i];
                              final amt = (t['signedAmount'] ??
                                  t['amount'] ??
                                  0) as num;
                              return ListTile(
                                title: Text(
                                  (t['walletName'] ??
                                          t['description'] ??
                                          'Wallet Activity')
                                      .toString(),
                                  style: AppTextStyles.labelLarge
                                      .copyWith(fontSize: 14),
                                ),
                                subtitle: Text(
                                  DateFormatter.formatDate(
                                      t['createdAt']?.toString()),
                                  style: AppTextStyles.bodySmall,
                                ),
                                trailing: Text(
                                  CurrencyFormatter.formatSignedKobo(amt),
                                  style: AppTextStyles.labelLarge.copyWith(
                                    fontSize: 14,
                                    color: amt >= 0
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
