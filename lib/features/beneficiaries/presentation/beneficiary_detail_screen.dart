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
import '../../../core/widgets/confirmation_modal.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/beneficiaries_repository.dart';

class BeneficiaryDetailScreen extends ConsumerStatefulWidget {
  const BeneficiaryDetailScreen({super.key, required this.beneficiaryId});
  final String beneficiaryId;

  @override
  ConsumerState<BeneficiaryDetailScreen> createState() =>
      _BeneficiaryDetailScreenState();
}

class _BeneficiaryDetailScreenState
    extends ConsumerState<BeneficiaryDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
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
      final repo = ref.read(beneficiariesRepositoryProvider);
      final res = await Future.wait([
        repo.getDetail(widget.beneficiaryId),
        repo.getTransactions(widget.beneficiaryId),
      ]);
      setState(() {
        _data = res[0] as Map<String, dynamic>;
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

  Future<void> _toggleStatus() async {
    final current = (_data['status'] ?? 'active').toString().toLowerCase();
    final next = current == 'active' ? 'paused' : 'active';
    try {
      await ref
          .read(beneficiariesRepositoryProvider)
          .updateBeneficiary(widget.beneficiaryId, status: next);
      ref.invalidate(beneficiariesListProvider);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmationSheet(
      context,
      title: 'Delete Beneficiary?',
      message: 'This recipient and any linked split rule will be removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(beneficiariesRepositoryProvider)
          .deleteBeneficiary(widget.beneficiaryId);
      ref.invalidate(beneficiariesListProvider);
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
    final status = (_data['status'] ?? 'active').toString();
    final isPaused = status.toLowerCase() == 'paused';

    return Scaffold(
      appBar: AppBar(
        title: Text(_data['accountName']?.toString() ?? 'Beneficiary'),
        actions: [
          if (!_loading && _error == null)
            IconButton(
              tooltip: 'Delete beneficiary',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _data['accountName']?.toString() ?? '',
                                  style: AppTextStyles.titleLarge,
                                ),
                                StatusBadge(status: status),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_data['bankName'] ?? ''} • ${_data['accountNumber'] ?? ''}',
                              style: AppTextStyles.bodyMedium,
                            ),
                            if (_data['totalAllocated'] != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Total Sent: ${CurrencyFormatter.formatKobo(_data['totalAllocated'] as num)}',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: AppColors.primary),
                              ),
                            ],
                            const SizedBox(height: 16),
                            AppSecondaryButton(
                              label: isPaused
                                  ? 'Resume Beneficiary'
                                  : 'Pause Beneficiary',
                              onPressed: _toggleStatus,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Transfer History', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 10),
                      if (_txs.isEmpty)
                        const AppCard(
                          child: EmptyStateView(
                            icon: Icons.send_outlined,
                            title: 'No transfers yet',
                            subtitle:
                                'Transfers routed to this beneficiary will appear here.',
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
                              return ListTile(
                                title: Text(
                                  CurrencyFormatter.formatKobo(
                                      (t['amount'] ?? 0) as num),
                                  style: AppTextStyles.labelLarge,
                                ),
                                subtitle: Text(
                                  DateFormatter.formatDateTime(
                                      t['createdAt']?.toString()),
                                  style: AppTextStyles.bodySmall,
                                ),
                                trailing: StatusBadge(
                                    status:
                                        (t['status'] ?? 'success').toString()),
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
