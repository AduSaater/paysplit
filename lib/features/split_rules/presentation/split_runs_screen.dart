import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/split_rules_repository.dart';

class SplitRunsScreen extends ConsumerWidget {
  const SplitRunsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(splitRunsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Split Run History')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(splitRunsListProvider),
        child: runsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: LoadingShimmerList(),
          ),
          error: (err, _) => ListView(
            children: [
              ErrorStateView(
                message: err.toString(),
                onRetry: () => ref.invalidate(splitRunsListProvider),
              ),
            ],
          ),
          data: (runs) {
            if (runs.isEmpty) {
              return ListView(
                children: const [
                  EmptyStateView(
                    icon: Icons.bolt_rounded,
                    title: 'No split runs yet',
                    subtitle:
                        'Automatic payday splits and manual "Run Now" executions appear here.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: runs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = runs[i];
                final total =
                    (r['totalDistributed'] ?? r['amount'] ?? 0) as num;
                final trigger = (r['trigger'] ?? 'automatic').toString();
                final status = (r['status'] ?? 'completed').toString();
                return AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${trigger[0].toUpperCase()}${trigger.substring(1)} Split Run',
                              style: AppTextStyles.titleMedium,
                            ),
                            Text(
                              DateFormatter.formatDateTime(
                                  r['createdAt']?.toString()),
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.formatKobo(total),
                            style: AppTextStyles.labelLarge,
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
    );
  }
}
