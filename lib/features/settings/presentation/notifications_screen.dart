import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../data/settings_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(settingsRepositoryProvider)
                  .markAllNotificationsRead();
              ref.invalidate(notificationsListProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsListProvider),
        child: notifsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: LoadingShimmerList(),
          ),
          error: (err, _) => ListView(
            children: [
              ErrorStateView(
                message: err.toString(),
                onRetry: () => ref.invalidate(notificationsListProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  EmptyStateView(
                    icon: Icons.notifications_none_rounded,
                    title: 'All caught up',
                    subtitle: 'Salary credits and split alerts appear here.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final n = items[i];
                final isRead = n['isRead'] == true || n['readAt'] != null;
                return AppCard(
                  backgroundColor:
                      isRead ? AppColors.surface : AppColors.primaryLight,
                  onTap: () async {
                    if (!isRead && n['id'] != null) {
                      await ref
                          .read(settingsRepositoryProvider)
                          .markNotificationRead(n['id'].toString());
                      ref.invalidate(notificationsListProvider);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (n['title'] ?? 'PaySplit Update').toString(),
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (n['message'] ?? n['body'] ?? '').toString(),
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormatter.formatRelative(
                            n['createdAt']?.toString()),
                        style: AppTextStyles.bodySmall,
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
