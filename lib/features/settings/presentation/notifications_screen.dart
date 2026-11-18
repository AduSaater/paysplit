import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/state_views.dart';
import '../data/settings_repository.dart';

/// Matches Figma Notifications screen:
/// - Back arrow + "Notifications"
/// - Filter tabs: All | Unread | Read
/// - Date-grouped list (Today / Yesterday / Date)
/// - White cards with status circle indicator, bold title, and subtitle
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'all'; // 'all' | 'unread' | 'read'

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(settingsRepositoryProvider)
                  .markAllNotificationsRead();
              ref.invalidate(notificationsListProvider);
            },
            child: Text(
              'Mark all read',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs (All / Unread / Read)
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                _FilterPill(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Unread',
                  selected: _filter == 'unread',
                  onTap: () => setState(() => _filter = 'unread'),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Read',
                  selected: _filter == 'read',
                  onTap: () => setState(() => _filter = 'read'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
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
                      isOffline: err is ApiException && err.isNetworkError,
                      onRetry: () => ref.invalidate(notificationsListProvider),
                    ),
                  ],
                ),
                data: (items) {
                  final filtered = items.where((n) {
                    final isRead = n['isRead'] == true || n['readAt'] != null;
                    if (_filter == 'unread') return !isRead;
                    if (_filter == 'read') return isRead;
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        EmptyStateView(
                          icon: Icons.notifications_none_rounded,
                          title: _filter == 'unread'
                              ? 'No unread notifications'
                              : 'All caught up',
                          subtitle:
                              'Salary credits, wallet updates, and split alerts appear here.',
                        ),
                      ],
                    );
                  }

                  final grouped = _groupByDay(filtered);
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    itemCount: grouped.length,
                    itemBuilder: (_, idx) {
                      final entry = grouped[idx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, top: 4),
                            child: Text(
                              entry.key,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ...entry.value.map((n) {
                            final isRead =
                                n['isRead'] == true || n['readAt'] != null;
                            final type =
                                (n['type'] ?? '').toString().toLowerCase();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                padding: const EdgeInsets.all(14),
                                onTap: () async {
                                  if (!isRead && n['id'] != null) {
                                    await ref
                                        .read(settingsRepositoryProvider)
                                        .markNotificationRead(
                                            n['id'].toString());
                                    ref.invalidate(notificationsListProvider);
                                  }
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _NotificationDot(
                                        isRead: isRead, type: type),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (n['title'] ?? 'PaySplit Update')
                                                .toString(),
                                            style: AppTextStyles.titleMedium
                                                .copyWith(fontSize: 15),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            (n['message'] ?? n['body'] ?? '')
                                                .toString(),
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                              color: AppColors.textSecondary,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
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
    );
  }

  List<MapEntry<String, List<Map<String, dynamic>>>> _groupByDay(
      List<Map<String, dynamic>> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final rawDate = item['createdAt']?.toString();
      final dt = rawDate != null ? DateTime.tryParse(rawDate)?.toLocal() : null;
      String label;
      if (dt == null) {
        label = 'Recent';
      } else {
        final d = DateTime(dt.year, dt.month, dt.day);
        if (d == today) {
          label = 'Today';
        } else if (d == yesterday) {
          label = 'Yesterday';
        } else {
          label = DateFormatter.formatDate(rawDate);
        }
      }
      map.putIfAbsent(label, () => []).add(item);
    }
    return map.entries.toList();
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NotificationDot extends StatelessWidget {
  const _NotificationDot({required this.isRead, required this.type});

  final bool isRead;
  final String type;

  @override
  Widget build(BuildContext context) {
    if (type.contains('fail') || type.contains('alert')) {
      return Container(
        margin: const EdgeInsets.only(top: 3),
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: AppColors.error,
          shape: BoxShape.circle,
        ),
      );
    }

    if (!isRead) {
      return Container(
        margin: const EdgeInsets.only(top: 2),
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 3.5),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 3),
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
