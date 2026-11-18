import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
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
    final amount =
        CurrencyFormatter.formatKobo((_tx['amount'] ?? _tx['signedAmount'] ?? 0) as num);
    final refCode = (_tx['reference'] ?? _tx['id'] ?? '').toString();
    final date = DateFormatter.formatDateTime(_tx['createdAt']?.toString());
    final status = (_tx['status'] ?? 'success').toString();
    final dest = (_tx['destinationName'] ?? _tx['title'] ?? 'PaySplit').toString();

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
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Receipt')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorStateView(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    AppCard(
                      child: Column(
                        children: [
                          Text(
                            (_tx['title'] ??
                                    _tx['destinationName'] ??
                                    'Transaction')
                                .toString(),
                            style: AppTextStyles.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyFormatter.formatSignedKobo(
                                (_tx['signedAmount'] ?? _tx['amount'] ?? 0)
                                    as num),
                            style: AppTextStyles.displayLarge,
                          ),
                          const SizedBox(height: 10),
                          StatusBadge(
                              status: (_tx['status'] ?? 'success').toString()),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          _RowItem(
                            'Reference',
                            (_tx['reference'] ?? _tx['id'] ?? '—').toString(),
                          ),
                          _RowItem(
                            'Type',
                            (_tx['type'] ?? '—').toString().toUpperCase(),
                          ),
                          _RowItem(
                            'Date',
                            DateFormatter.formatDateTime(
                                _tx['createdAt']?.toString()),
                          ),
                          if (_tx['narration'] != null)
                            _RowItem('Narration', _tx['narration'].toString()),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
