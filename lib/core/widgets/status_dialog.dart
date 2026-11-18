import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Reusable dialog for displaying success or error messages across the app.
Future<void> showStatusDialog(
  BuildContext context, {
  required String message,
  String? title,
  bool isError = false,
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isError ? AppColors.errorBg : AppColors.successBg,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: isError ? AppColors.error : AppColors.success,
          size: 30,
        ),
      ),
      title: Text(
        title ?? (isError ? 'Error' : 'Success'),
        style: AppTextStyles.titleLarge,
        textAlign: TextAlign.center,
      ),
      content: Text(
        message,
        style: AppTextStyles.bodyMedium,
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isError ? AppColors.error : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('OK'),
          ),
        ),
      ],
    ),
  );
}
