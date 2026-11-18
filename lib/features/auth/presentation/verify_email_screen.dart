import 'dart:async';
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

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer(60);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _countdown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        if (mounted) setState(() => _countdown = 0);
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).verifyEmail(
            email: widget.email,
            code: _codeCtrl.text,
          );
      if (!mounted) return;
      context.push('/set-password');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0) return;
    try {
      final secs =
          await ref.read(authRepositoryProvider).resendEmailCode(widget.email);
      if (!mounted) return;
      _startTimer(secs);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code resent!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Step 2 of 3 • Email Verification',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                const SizedBox(height: 8),
                Text('Check your inbox', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit verification code to ${widget.email}.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 28),
                AppTextField(
                  label: '6-digit verification code',
                  controller: _codeCtrl,
                  hintText: '123456',
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  validator: Validators.otpCode,
                ),
                const SizedBox(height: 24),
                AppPrimaryButton(
                  label: 'Verify Code',
                  isLoading: _loading,
                  onPressed: _verify,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _countdown == 0 ? _resend : null,
                    child: Text(
                      _countdown > 0
                          ? "Didn't get a code? Resend in ${_countdown}s"
                          : "Didn't get a code? Click to resend",
                      style: AppTextStyles.labelLarge.copyWith(
                        color: _countdown == 0
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
