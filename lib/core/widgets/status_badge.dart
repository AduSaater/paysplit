import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().trim();
    Color bg;
    Color fg;
    String label = status.replaceAll('_', ' ');

    switch (normalized) {
      case 'active':
      case 'success':
      case 'completed':
      case 'approved':
      case 'verified':
        bg = AppColors.successBg;
        fg = AppColors.success;
        break;
      case 'paused':
      case 'pending':
      case 'processing':
      case 'in_progress':
        bg = AppColors.warningBg;
        fg = AppColors.warning;
        break;
      case 'failed':
      case 'rejected':
      case 'reversed':
      case 'closed':
        bg = AppColors.errorBg;
        fg = AppColors.error;
        break;
      default:
        bg = AppColors.infoBg;
        fg = AppColors.info;
    }

    final display = label.isEmpty
        ? 'Unknown'
        : '${label[0].toUpperCase()}${label.substring(1)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        display,
        style: AppTextStyles.labelSmall.copyWith(color: fg),
      ),
    );
  }
}
