import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/transactions_repository.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});
  final String transactionId;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _tx = {};

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
      final data = await ref
          .read(transactionsRepositoryProvider)
          .getTransactionDetail(widget.transactionId);
      setState(() {
        _tx = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _shareReceipt() {
    final amount = CurrencyFormatter.formatKobo(
      (_tx['amount'] ?? _tx['signedAmount'] ?? 0) as num,
      showDecimals: false,
    );
    final refCode = (_tx['reference'] ?? _tx['id'] ?? '').toString();
    final date = DateFormatter.formatDateTime(_tx['createdAt']?.toString());
    final status = (_tx['status'] ?? 'success').toString();
    final dest =
        (_tx['destinationName'] ?? _tx['title'] ?? 'PaySplit').toString();

    SharePlus.instance.share(
      ShareParams(
        text: 'PaySplit Receipt\n'
            'Destination: $dest\n'
            'Amount: $amount\n'
            'Status: $status\n'
            'Reference: $refCode\n'
            'Date: $date',
        subject: 'PaySplit Receipt - $refCode',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = (_tx['categoryName'] ?? _tx['type'] ?? 'Savings').toString();
    final status = (_tx['status'] ?? 'success').toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorStateView(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          CircleBackButton(onTap: () => context.pop()),
                          const SizedBox(width: 12),
                          Text('Details', style: AppTextStyles.titleLarge),
                        ],
                      ),
                      const SizedBox(height: 20),
                      AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                category,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  CurrencyFormatter.formatKobo(
                                    (_tx['amount'] ??
                                            _tx['signedAmount'] ??
                                            0)
                                        .abs() as num,
                                    showDecimals: false,
                                  ),
                                  style: AppTextStyles.displayLarge.copyWith(
                                    fontSize: 26,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                StatusBadge(status: status),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            _RowItem(
                              'Settlement Reference',
                              (_tx['reference'] ?? _tx['id'] ?? '—').toString(),
                            ),
                            _RowItem(
                              'Recipient/Destination',
                              (_tx['destinationName'] ?? _tx['title'] ?? '—')
                                  .toString(),
                            ),
                            _RowItem(
                              'Time Stamp',
                              DateFormatter.formatDateTime(
                                  _tx['createdAt']?.toString()),
                            ),
                            _RowItem(
                              'Destination Type',
                              (_tx['type'] ?? 'Wallet').toString(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppPrimaryButton(
                        label: 'Share Receipt',
                        icon: Icons.share_outlined,
                        onPressed: _shareReceipt,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
