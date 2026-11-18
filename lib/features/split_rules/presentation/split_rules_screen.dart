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
import '../../../core/widgets/status_badge.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundleAsync = ref.watch(splitRulesBundleProvider(_status));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Rules'),
        actions: [
          IconButton(
            tooltip: 'Split run history',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push('/split-runs'),
          ),
          IconButton(
            tooltip: 'Add split rule',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () async {
              final created = await showSplitRuleFormSheet(context);
              if (created) ref.invalidate(splitRulesBundleProvider(_status));
            },
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
            final ratio =
                salary > 0 ? (allocated / salary).clamp(0.0, 1.0) : 0.0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                // Summary Allocation Bar Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monthly Salary Allocation',
                          style: AppTextStyles.bodySmall),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            CurrencyFormatter.formatKobo(allocated),
                            style: AppTextStyles.titleLarge
                                .copyWith(color: AppColors.primary),
                          ),
                          Text(
                            'of ${CurrencyFormatter.formatKobo(salary)}',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: AppColors.surfaceSubtle,
                        color: ratio >= 1.0
                            ? AppColors.warning
                            : AppColors.primary,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unallocated remainder: ${CurrencyFormatter.formatKobo(remainder)}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: ['all', 'active', 'paused'].map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s[0].toUpperCase() + s.substring(1)),
                        selected: _status == s,
                        selectedColor: AppColors.primaryLight,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                if (bundle.rules.isEmpty)
                  AppCard(
                    child: EmptyStateView(
                      icon: Icons.call_split_rounded,
                      title: 'No split rules yet',
                      subtitle:
                          'Define rules by fixed amount or percentage to automatically route every salary.',
                      actionLabel: 'Create Rule',
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
                    final value = (r['value'] ?? 0) as num;
                    final displayVal = method == 'fixed'
                        ? CurrencyFormatter.formatKobo(value)
                        : '$value%';
                    final destType =
                        (r['destinationType'] ?? 'wallet').toString();
                    final destName = (r['destinationName'] ??
                            (r['wallet'] as Map<String, dynamic>?)?['name'] ??
                            (r['beneficiary']
                                as Map<String, dynamic>?)?['accountName'] ??
                            destType)
                        .toString();
                    final status = (r['status'] ?? 'active').toString();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
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
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                '#${r['priority'] ?? 1}',
                                style: AppTextStyles.labelSmall
                                    .copyWith(color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['name']?.toString() ?? 'Rule',
                                    style: AppTextStyles.titleMedium,
                                  ),
                                  Text(
                                    '$destName • $displayVal',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: status),
                            PopupMenuButton<String>(
                              onSelected: (action) {
                                if (action == 'toggle') _togglePause(r);
                                if (action == 'delete') _deleteRule(r);
                              },
                              itemBuilder: (_) => [
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
