import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_dialog.dart';
import '../data/auth_repository.dart';
import 'auth_provider.dart';

class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = await ref.read(authRepositoryProvider).setPassword(
            password: _passCtrl.text,
            confirmPassword: _confirmCtrl.text,
          );
      await ref.read(authProvider.notifier).completeAuthFromSetPassword(data);
      if (!mounted) return;
      context.go('/account-success');
    } on ApiException catch (e) {
      if (!mounted) return;
      await showStatusDialog(context, message: e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Step 3 of 3 • Secure Your Account',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                const SizedBox(height: 8),
                Text('Create a strong password',
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Minimum 8 characters with uppercase, lowercase, a digit, and a special character.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 28),
                AppTextField(
                  label: 'Password',
                  controller: _passCtrl,
                  obscureText: _obscure1,
                  validator: Validators.strongPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure1
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm Password',
                  controller: _confirmCtrl,
                  obscureText: _obscure2,
                  validator: (v) {
                    if (v != _passCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(_obscure2
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
                const SizedBox(height: 28),
                AppPrimaryButton(
                  label: 'Complete Setup',
                  isLoading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
