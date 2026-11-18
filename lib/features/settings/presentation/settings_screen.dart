import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_modal.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/settings_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showIncomeSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? income,
  ) async {
    final employerCtrl = TextEditingController(
      text: income?['employerName']?.toString() ?? '',
    );
    final salaryCtrl = TextEditingController(
      text: CurrencyFormatter.koboToEditableNaira(
          income?['monthlyAmount'] as num?),
    );
    final paydayCtrl = TextEditingController(
      text: (income?['paydayDay'] ?? 28).toString(),
    );
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Salary Income Source', style: AppTextStyles.titleLarge),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Employer Name',
                controller: employerCtrl,
                hintText: 'e.g. Talent Nation',
                validator: (v) => Validators.requiredField(v, 'Employer'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Expected Monthly Salary (₦)',
                controller: salaryCtrl,
                hintText: '600000',
                keyboardType: TextInputType.number,
                validator: (v) {
                  final k = CurrencyFormatter.parseNairaToKobo(v ?? '');
                  if (k == null || k <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Payday (Day of Month, 1-31)',
                controller: paydayCtrl,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final d = int.tryParse(v ?? '');
                  if (d == null || d < 1 || d > 31) return 'Enter 1 to 31';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: 'Save Salary Source',
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final kobo =
                      CurrencyFormatter.parseNairaToKobo(salaryCtrl.text)!;
                  final day = int.parse(paydayCtrl.text.trim());
                  Navigator.of(ctx).pop();
                  try {
                    await ref.read(settingsRepositoryProvider).upsertIncome(
                          employerName: employerCtrl.text,
                          monthlyAmountKobo: kobo,
                          paydayDay: day,
                        );
                    ref.invalidate(userProfileProvider);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Salary income updated'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } on ApiException catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.message),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordSheet(
      BuildContext context, WidgetRef ref) async {
    final currCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Password', style: AppTextStyles.titleLarge),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Current Password',
                controller: currCtrl,
                obscureText: true,
                validator: (v) =>
                    Validators.requiredField(v, 'Current password'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'New Password',
                controller: newCtrl,
                obscureText: true,
                validator: Validators.strongPassword,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Confirm New Password',
                controller: confCtrl,
                obscureText: true,
                validator: (v) =>
                    v != newCtrl.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: 'Update Password',
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.of(ctx).pop();
                  try {
                    await ref.read(settingsRepositoryProvider).changePassword(
                          currentPassword: currCtrl.text,
                          newPassword: newCtrl.text,
                          confirmPassword: confCtrl.text,
                        );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } on ApiException catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.message),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(userProfileProvider),
        child: profileAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: LoadingShimmerList(),
          ),
          error: (err, _) => ListView(
            children: [
              ErrorStateView(
                message: err.toString(),
                isOffline: err is ApiException && err.isNetworkError,
                onRetry: () => ref.invalidate(userProfileProvider),
              ),
            ],
          ),
          data: (profile) {
            final user = (profile['user'] as Map<String, dynamic>?) ?? auth.user;
            final income = profile['income'] as Map<String, dynamic>?;
            final fullName = auth.fullName;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          fullName[0].toUpperCase(),
                          style: AppTextStyles.headlineMedium
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName, style: AppTextStyles.titleLarge),
                            Text(
                              user?['email']?.toString() ?? auth.email,
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            StatusBadge(status: auth.kycStatus),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.work_outline_rounded),
                        title: const Text('Salary Income Source'),
                        subtitle: Text(
                          income != null
                              ? '${income['employerName']} • ${CurrencyFormatter.formatKobo(income['monthlyAmount'] as num?)} (${DateFormatter.ordinalDay((income['paydayDay'] as num?)?.toInt())})'
                              : 'Tap to set your employer and monthly salary',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showIncomeSheet(context, ref, income),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: const Text('KYC & Identity Verification'),
                        subtitle: Text('Status: ${auth.kycStatus}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/kyc'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('Notifications'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/notifications'),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.lock_outline_rounded),
                        title: const Text('Change Password'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showChangePasswordSheet(context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppDestructiveButton(
                  label: 'Sign Out',
                  onPressed: () async {
                    final confirmed = await showConfirmationSheet(
                      context,
                      title: 'Sign out of PaySplit?',
                      message:
                          'You will need to sign in again to access your salary account and split rules.',
                      confirmLabel: 'Sign Out',
                      isDestructive: true,
                    );
                    if (confirmed) {
                      await ref.read(authProvider.notifier).logout();
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
