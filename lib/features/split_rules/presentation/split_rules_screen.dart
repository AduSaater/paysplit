import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/confirmation_modal.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_dialog.dart';
import '../data/split_rules_repository.dart';
import 'split_rule_form_sheet.dart';

class SplitRulesScreen extends ConsumerStatefulWidget {
  const SplitRulesScreen({super.key});

  @override
  ConsumerState<SplitRulesScreen> createState() => _SplitRulesScreenState();
}

class _SplitRulesScreenState extends ConsumerState<SplitRulesScreen> {
  String _status = 'all';

  Future<void> _togglePause(Map<String, dynamic> rule) async {
    final current = (rule['status'] ?? 'active').toString().toLowerCase();
    final next = current == 'active' ? 'paused' : 'active';
    try {
      await ref
          .read(splitRulesRepositoryProvider)
          .updateRule(rule['id'].toString(), status: next);
      ref.invalidate(splitRulesBundleProvider(_status));
    } on ApiException catch (e) {
      if (!mounted) return;
      await showStatusDialog(context, message: e.message, isError: true);
    }
  }

  Future<void> _deleteRule(Map<String, dynamic> rule) async {
    final ok = await showConfirmationSheet(
      context,
      title: 'Delete Split Rule?',
      message: 'Remove "${rule['name']}" from your automated pay-cycle splits?',
      confirmLabel: 'Delete Rule',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(splitRulesRepositoryProvider)
          .deleteRule(rule['id'].toString());
      ref.invalidate(splitRulesBundleProvider(_status));
    } on ApiException catch (e) {
      if (!mounted) return;
      await showStatusDialog(context, message: e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundleAsync = ref.watch(splitRulesBundleProvider(_status));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Split Rules'),
        actions: [
          IconButton(
            tooltip: 'Split run history',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push('/split-runs'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(splitRulesBundleProvider(_status)),
        child: bundleAsync.when(
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
                    ref.invalidate(splitRulesBundleProvider(_status)),
              ),
            ],
          ),
          data: (bundle) {
            final summary = bundle.summary;
            final salary =
                (summary['monthlySalary'] ?? summary['baseline'] ?? 0) as num;
            final allocated =
                (summary['totalAllocated'] ?? summary['allocated'] ?? 0) as num;
            final remainder =
                (summary['remainder'] ?? (salary - allocated)) as num;
            final pct = salary > 0
                ? ((allocated / salary) * 100).clamp(0, 100).toInt()
                : 0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              children: [
                // Allocation Progress Card (matches Figma 2x2 grid)
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Allocation Progress',
                              style: AppTextStyles.bodyMedium),
                          Text(
                            '$pct% of Salary',
                            style: AppTextStyles.labelLarge
                                .copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: salary > 0
                              ? (allocated / salary).clamp(0.0, 1.0)
                              : 0.0,
                          backgroundColor: AppColors.surfaceSubtle,
                          color: AppColors.primary,
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Monthly Salary Baseline',
                              value: CurrencyFormatter.formatKobo(
                                salary,
                                showDecimals: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricTile(
                              label: 'Spend Account Remainder',
                              value: CurrencyFormatter.formatKobo(
                                remainder,
                                showDecimals: false,
                              ),
                              valueColor: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Total Allocated',
                              value: CurrencyFormatter.formatKobo(
                                allocated,
                                showDecimals: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricTile(
                              label: 'Total Unallocated',
                              value: CurrencyFormatter.formatKobo(
                                remainder,
                                showDecimals: false,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text('Salary Rules', style: AppTextStyles.titleMedium),
                const SizedBox(height: 10),

                // Filter Pills + "+ Add New Rule" Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: ['all', 'active', 'paused'].map((s) {
                        final selected = _status == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _status = s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: selected
                                    ? Border.all(color: AppColors.border)
                                    : null,
                              ),
                              child: Text(
                                s[0].toUpperCase() + s.substring(1),
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: selected
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final created = await showSplitRuleFormSheet(context);
                        if (created) {
                          ref.invalidate(splitRulesBundleProvider(_status));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(
                        'Add New Rule',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (bundle.rules.isEmpty)
                  AppCard(
                    child: EmptyStateView(
                      icon: Icons.call_split_rounded,
                      title: 'No split rules yet',
                      subtitle:
                          'Define rules by fixed amount or percentage to automatically route every salary.',
                      actionLabel: '+ Add New Rule',
                      onAction: () async {
                        final created = await showSplitRuleFormSheet(context);
                        if (created) {
                          ref.invalidate(splitRulesBundleProvider(_status));
                        }
                      },
                    ),
                  )
                else
                  ...bundle.rules.map((r) {
                    final method = (r['method'] ?? 'fixed').toString();
                    final destType =
                        (r['destinationType'] ?? 'wallet').toString();
                    final destLabel = destType == 'wallet'
                        ? 'Emergency Wallet'
                        : 'Beneficiary Account';
                    final status = (r['status'] ?? 'active').toString();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        onTap: () async {
                          final updated = await showSplitRuleFormSheet(
                              context,
                              existing: r);
                          if (updated) {
                            ref.invalidate(splitRulesBundleProvider(_status));
                          }
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['name']?.toString() ?? 'Rule',
                                    style: AppTextStyles.titleMedium
                                        .copyWith(fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (r['destinationName'] ?? destLabel)
                                        .toString(),
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                method == 'fixed'
                                    ? 'Fixed Amount'
                                    : 'Percentage',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.success,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.textMuted),
                              onSelected: (action) {
                                if (action == 'edit') {
                                  showSplitRuleFormSheet(context, existing: r)
                                      .then((updated) {
                                    if (updated) {
                                      ref.invalidate(
                                          splitRulesBundleProvider(_status));
                                    }
                                  });
                                }
                                if (action == 'toggle') _togglePause(r);
                                if (action == 'delete') _deleteRule(r);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit rule'),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    status == 'active'
                                        ? 'Pause rule'
                                        : 'Resume rule',
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete rule',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
