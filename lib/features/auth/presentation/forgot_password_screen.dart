import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/otp_input_row.dart';
import '../../../core/widgets/status_dialog.dart';
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
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());

  int _step = 0; // 0 = email, 1 = 6-digit code, 2 = new password
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _otpCtrls.map((c) => c.text.trim()).join();

  Future<void> _next() async {
    if (_step != 1 && !_formKey.currentState!.validate()) return;
    if (_step == 1 && _otpCode.length != 6) {
      await showStatusDialog(
        context,
        message: 'Enter the 6-digit verification code',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_step == 0) {
        await repo.forgotPassword(_emailCtrl.text);
        if (mounted) setState(() => _step = 1);
      } else if (_step == 1) {
        await repo.verifyResetCode(
          email: _emailCtrl.text,
          code: _otpCode,
        );
        if (mounted) setState(() => _step = 2);
      } else {
        await repo.resetPassword(
          email: _emailCtrl.text,
          newPassword: _passCtrl.text,
        );
        if (!mounted) return;
        await showStatusDialog(
          context,
          message: 'Password reset! Please sign in with your new password.',
        );
        if (mounted) context.go('/login');
      }
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: CircleBackButton(
                    onTap: () {
                      if (_step > 0) {
                        setState(() => _step--);
                      } else {
                        context.pop();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _step == 0
                      ? 'Forgot Password'
                      : _step == 1
                          ? 'Check Your Email'
                          : 'Reset Password',
                  style: AppTextStyles.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                if (_step == 1)
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppTextStyles.bodyMedium,
                      children: [
                        const TextSpan(text: 'We have sent 6 digits code to '),
                        TextSpan(
                          text: _emailCtrl.text.trim(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    _step == 0
                        ? "Enter your email and we'll send you a 6-digit reset code."
                        : 'Create a strong new password for your account.',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 36),
                if (_step == 0)
                  AppTextField(
                    label: 'Email Address',
                    controller: _emailCtrl,
                    hintText: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                if (_step == 1) ...[
                  OtpInputRow(
                    controllers: _otpCtrls,
                    focusNodes: _otpNodes,
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      try {
                        await ref
                            .read(authRepositoryProvider)
                            .forgotPassword(_emailCtrl.text);
                        if (!context.mounted) return;
                        await showStatusDialog(
                          context,
                          message: 'Reset code resent!',
                        );
                      } on ApiException catch (e) {
                        if (!context.mounted) return;
                        await showStatusDialog(
                          context,
                          message: e.message,
                          isError: true,
                        );
                      }
                    },
                    child: RichText(
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium,
                        children: const [
                          TextSpan(text: "Didn't get a code? "),
                          TextSpan(
                            text: 'Click to resend.',
                            style: TextStyle(
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_step == 2) ...[
                  AppTextField(
                    label: 'New Password',
                    controller: _passCtrl,
                    hintText: 'Enter new password',
                    obscureText: _obscure1,
                    validator: Validators.strongPassword,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure1 = !_obscure1),
                      icon: SvgPicture.asset(
                        'assets/icons/eye.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(
                          _obscure1 ? AppColors.textTertiary : AppColors.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Confirm Password',
                    controller: _confirmCtrl,
                    hintText: 'Confirm new password',
                    obscureText: _obscure2,
                    validator: (v) =>
                        v != _passCtrl.text ? 'Passwords do not match' : null,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure2 = !_obscure2),
                      icon: SvgPicture.asset(
                        'assets/icons/eye.svg',
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(
                          _obscure2 ? AppColors.textTertiary : AppColors.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 36),
                AppPrimaryButton(
                  label: _step == 2
                      ? 'Reset Password'
                      : _step == 1
                          ? 'Verify Code'
                          : 'Continue',
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
