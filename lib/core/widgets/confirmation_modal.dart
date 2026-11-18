import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

Future<bool> showConfirmationSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text(message, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 24),
            if (isDestructive)
              AppDestructiveButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              )
            else
              AppPrimaryButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            const SizedBox(height: 10),
            AppSecondaryButton(
              label: cancelLabel,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
