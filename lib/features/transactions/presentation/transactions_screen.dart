import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/transactions_repository.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _type = 'all';
  String _search = '';
  bool _exporting = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final file = await ref
          .read(transactionsRepositoryProvider)
          .exportStatementCsv(type: _type);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'PaySplit Statement',
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsListProvider(_type));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: 'Export statement CSV',
            onPressed: _exporting ? null : _exportCsv,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              children: [
                AppSearchField(
                  controller: _searchCtrl,
                  hintText: 'Search reference or destination...',
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'wallet', 'beneficiary', 'salary'].map((t) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(t[0].toUpperCase() + t.substring(1)),
                          selected: _type == t,
                          selectedColor: AppColors.primaryLight,
                          onSelected: (_) => setState(() => _type = t),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(transactionsListProvider(_type)),
              child: txAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: LoadingShimmerList(),
                ),
                error: (err, _) => ListView(
                  children: [
                    ErrorStateView(
                      message: err.toString(),
                      isOffline: err is ApiException && err.isNetworkError,
                      onRetry: () =>
                          ref.invalidate(transactionsListProvider(_type)),
                    ),
                  ],
                ),
                data: (items) {
                  final filtered = _search.isEmpty
                      ? items
                      : items.where((tx) {
                          final str = tx.values.join(' ').toLowerCase();
                          return str.contains(_search);
                        }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      children: const [
                        EmptyStateView(
                          icon: Icons.receipt_long_outlined,
                          title: 'No matching transactions',
                          subtitle:
                              'Try changing your filter or search query.',
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final tx = filtered[i];
                      final id = tx['id'].toString();
                      final signed =
                          (tx['signedAmount'] ?? tx['amount'] ?? 0) as num;
                      final isCredit = signed > 0;
                      final title = (tx['title'] ??
                              tx['description'] ??
                              tx['destinationName'] ??
                              'Transaction')
                          .toString();
                      final status = (tx['status'] ?? 'success').toString();

                      return AppCard(
                        onTap: () => context.push('/transactions/$id'),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isCredit
                                  ? AppColors.successBg
                                  : AppColors.surfaceSubtle,
                              child: Icon(
                                isCredit
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                color: isCredit
                                    ? AppColors.success
                                    : AppColors.textPrimary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AppTextStyles.labelLarge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    DateFormatter.formatDateTime(
                                        tx['createdAt']?.toString()),
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatSignedKobo(signed),
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: isCredit
                                        ? AppColors.success
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                StatusBadge(status: status),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
