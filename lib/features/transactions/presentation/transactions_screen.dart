import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_dialog.dart';
import '../data/transactions_repository.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _type = 'all'; // 'all' | 'wallet' | 'beneficiary'
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
      await showStatusDialog(context, message: e.message, isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsListProvider(_type));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search + Filter Tabs + Export Button (matches Figma History)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _search = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(13),
                        child: SvgPicture.asset(
                          'assets/icons/search.svg',
                          width: 18,
                          height: 18,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _SegmentTab(
                              label: 'All',
                              selected: _type == 'all',
                              onTap: () => setState(() => _type = 'all'),
                            ),
                            _SegmentTab(
                              label: 'Wallets',
                              selected: _type == 'wallet',
                              onTap: () => setState(() => _type = 'wallet'),
                            ),
                            _SegmentTab(
                              label: 'Transfer',
                              selected: _type == 'beneficiary',
                              onTap: () =>
                                  setState(() => _type = 'beneficiary'),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _exporting ? null : _exportCsv,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _exporting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : SvgPicture.asset(
                                'assets/icons/export.svg',
                                width: 16,
                                height: 16,
                                colorFilter: const ColorFilter.mode(
                                    Colors.white, BlendMode.srcIn),
                              ),
                        label: Text(
                          'Export',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Month-Grouped Transaction List
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
                            return tx.values
                                .join(' ')
                                .toLowerCase()
                                .contains(_search);
                          }).toList();

                    if (filtered.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 80),
                          EmptyStateView(
                            icon: Icons.receipt_long_outlined,
                            title: 'No Transaction Yet',
                            subtitle:
                                'Your salary credits, wallet allocations, and transfers will appear here.',
                          ),
                        ],
                      );
                    }

                    final grouped = _groupByMonth(filtered);
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      itemCount: grouped.length,
                      itemBuilder: (_, idx) {
                        final entry = grouped[idx];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8, top: 4),
                              child: Text(
                                entry.key,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            AppCard(
                              padding: EdgeInsets.zero,
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: entry.value.length,
                                separatorBuilder: (_, _) => const Divider(),
                                itemBuilder: (_, i) {
                                  final tx = entry.value[i];
                                  return _TransactionRowTile(
                                    tx: tx,
                                    onTap: () => context
                                        .push('/transactions/${tx['id']}'),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, List<Map<String, dynamic>>>> _groupByMonth(
      List<Map<String, dynamic>> items) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final tx in items) {
      final raw = tx['createdAt']?.toString();
      final dt = raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
      final label =
          dt != null ? DateFormat('MMMM').format(dt) : 'Recent';
      map.putIfAbsent(label, () => []).add(tx);
    }
    return map.entries.toList();
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TransactionRowTile extends StatelessWidget {
  const _TransactionRowTile({required this.tx, required this.onTap});
  final Map<String, dynamic> tx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final signed = (tx['signedAmount'] ?? tx['amount'] ?? 0) as num;
    final isCredit = signed > 0;
    final title = (tx['title'] ??
            tx['description'] ??
            tx['destinationName'] ??
            'Transaction')
        .toString();
    final status = (tx['status'] ?? 'success').toString();
    final type = (tx['type'] ?? '').toString().toLowerCase();

    Color iconBg;
    Color iconFg;
    IconData iconData;
    if (type.contains('wallet')) {
      iconBg = const Color(0xFF16A34A);
      iconFg = Colors.white;
      iconData = Icons.send_rounded;
    } else if (isCredit) {
      iconBg = AppColors.errorBg;
      iconFg = AppColors.error;
      iconData = Icons.arrow_downward_rounded;
    } else {
      iconBg = AppColors.textPrimary;
      iconFg = Colors.white;
      iconData = Icons.send_rounded;
    }

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(iconData, color: iconFg, size: 17),
      ),
      title: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DateFormatter.formatDate(tx['createdAt']?.toString()),
        style: AppTextStyles.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            CurrencyFormatter.formatSignedKobo(signed, ),
            style: AppTextStyles.labelLarge.copyWith(
              fontSize: 14,
              color: isCredit ? AppColors.success : AppColors.error,
            ),
          ),
          Text(
            '${status[0].toUpperCase()}${status.substring(1)}',
            style: AppTextStyles.bodySmall.copyWith(
              color: status.toLowerCase() == 'success' ||
                      status.toLowerCase() == 'completed'
                  ? AppColors.success
                  : AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
