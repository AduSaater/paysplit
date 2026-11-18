import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  int _step = 0; // 0 = email, 1 = code, 2 = new password
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_step == 0) {
        await repo.forgotPassword(_emailCtrl.text);
        if (mounted) setState(() => _step = 1);
      } else if (_step == 1) {
        await repo.verifyResetCode(
          email: _emailCtrl.text,
          code: _codeCtrl.text,
        );
        if (mounted) setState(() => _step = 2);
      } else {
        await repo.resetPassword(
          email: _emailCtrl.text,
          newPassword: _passCtrl.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset! Please sign in.')),
        );
        context.go('/login');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _step == 0
                      ? 'Enter your email'
                      : _step == 1
                          ? 'Enter verification code'
                          : 'Set a new password',
                  style: AppTextStyles.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _step == 0
                      ? "We'll send a 6-digit code to reset your password."
                      : _step == 1
                          ? 'Check ${_emailCtrl.text} for the 6-digit code.'
                          : 'Choose a strong password for your account.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (_step == 0)
                  AppTextField(
                    label: 'Email Address',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                if (_step == 1)
                  AppTextField(
                    label: '6-digit Code',
                    controller: _codeCtrl,
                    maxLength: 6,
                    keyboardType: TextInputType.number,
                    validator: Validators.otpCode,
                  ),
                if (_step == 2)
                  AppTextField(
                    label: 'New Password',
                    controller: _passCtrl,
                    obscureText: true,
                    validator: Validators.strongPassword,
                  ),
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: _step == 2 ? 'Reset Password' : 'Continue',
                  isLoading: _loading,
                  onPressed: _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
