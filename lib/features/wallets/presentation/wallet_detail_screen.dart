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
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_modal.dart';
import '../../../core/widgets/state_views.dart';
import '../../dashboard/presentation/dashboard_provider.dart';
import '../data/wallets_repository.dart';
import 'create_wallet_sheet.dart';

class WalletDetailScreen extends ConsumerStatefulWidget {
  const WalletDetailScreen({super.key, required this.walletId});
  final String walletId;

  @override
  ConsumerState<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends ConsumerState<WalletDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _wallet = {};
  List<Map<String, dynamic>> _txs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(walletsRepositoryProvider);
      final res = await Future.wait([
        repo.getWalletDetail(widget.walletId),
        repo.getWalletTransactions(widget.walletId),
      ]);
      setState(() {
        _wallet = res[0] as Map<String, dynamic>;
        _txs = res[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _moveFunds() async {
    final ctrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Move to Salary Account', style: AppTextStyles.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Available: ${CurrencyFormatter.formatKobo(_wallet['balance'] as num?)}',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Amount (₦)',
              controller: ctrl,
              keyboardType: TextInputType.number,
              hintText: 'e.g. 25000',
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Move Funds',
              onPressed: () async {
                final kobo = CurrencyFormatter.parseNairaToKobo(ctrl.text);
                if (kobo == null || kobo <= 0) return;
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(walletsRepositoryProvider)
                      .moveToSalaryAccount(widget.walletId, kobo);
                  ref.invalidate(walletsListProvider);
                  ref.invalidate(dashboardProvider);
                  await _load();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Funds moved to salary account'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } on ApiException catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteWallet() async {
    final ok = await showConfirmationSheet(
      context,
      title: 'Delete Wallet?',
      message:
          'Empty wallets and any linked split rule will be permanently deleted.',
      confirmLabel: 'Delete Wallet',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(walletsRepositoryProvider).deleteWallet(widget.walletId);
      ref.invalidate(walletsListProvider);
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_wallet['name']?.toString() ?? 'Wallet Details'),
        actions: [
          if (!_loading && _error == null) ...[
            IconButton(
              tooltip: 'Edit wallet',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final updated =
                    await showWalletFormSheet(context, existing: _wallet);
                if (updated) {
                  ref.invalidate(walletsListProvider);
                  _load();
                }
              },
            ),
            IconButton(
              tooltip: 'Delete wallet',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _deleteWallet,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorStateView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Available Balance',
                                style: AppTextStyles.bodySmall),
                            const SizedBox(height: 6),
                            Text(
                              CurrencyFormatter.formatKobo(
                                  _wallet['balance'] as num?),
                              style: AppTextStyles.displayLarge,
                            ),
                            const SizedBox(height: 16),
                            AppPrimaryButton(
                              label: 'Move to Salary Account',
                              icon: Icons.swap_horiz_rounded,
                              onPressed: _moveFunds,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Wallet Transactions',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 10),
                      if (_txs.isEmpty)
                        const AppCard(
                          child: EmptyStateView(
                            icon: Icons.history_rounded,
                            title: 'No wallet activity',
                            subtitle:
                                'Allocations and withdrawals for this wallet appear here.',
                          ),
                        )
                      else
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _txs.length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (_, i) {
                              final t = _txs[i];
                              final amt = (t['signedAmount'] ??
                                  t['amount'] ??
                                  0) as num;
                              return ListTile(
                                title: Text(
                                  (t['description'] ?? t['type'] ?? 'Movement')
                                      .toString(),
                                  style: AppTextStyles.labelLarge,
                                ),
                                subtitle: Text(
                                  DateFormatter.formatDateTime(
                                      t['createdAt']?.toString()),
                                  style: AppTextStyles.bodySmall,
                                ),
                                trailing: Text(
                                  CurrencyFormatter.formatSignedKobo(amt),
                                  style: AppTextStyles.labelLarge,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
