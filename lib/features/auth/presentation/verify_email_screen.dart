import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/circle_back_button.dart';
import '../../../core/widgets/otp_input_row.dart';
import '../../../core/widgets/status_dialog.dart';
import '../data/auth_repository.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

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
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text.trim()).join();

  Future<void> _verify() async {
    if (_code.length != 6) {
      await showStatusDialog(
        context,
        message: 'Enter the 6-digit verification code',
        isError: true,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).verifyEmail(
            email: widget.email,
            code: _code,
          );
      if (!mounted) return;
      context.push('/set-password');
    } on ApiException catch (e) {
      if (!mounted) return;
      await showStatusDialog(context, message: e.message, isError: true);
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
      await showStatusDialog(
        context,
        message: 'Verification code resent to ${widget.email}.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      await showStatusDialog(context, message: e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CircleBackButton(onTap: () => context.pop()),
              ),
              const SizedBox(height: 28),
              Text(
                'Check Your Email',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.bodyMedium,
                  children: [
                    const TextSpan(text: 'We have sent 6 digits code to '),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // 6 Individual OTP Digit Boxes
              OtpInputRow(
                controllers: _ctrls,
                focusNodes: _nodes,
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: _countdown == 0 ? _resend : null,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTextStyles.bodyMedium,
                    children: [
                      const TextSpan(text: "Didn't get a code? "),
                      TextSpan(
                        text: _countdown > 0
                            ? 'Resend in ${_countdown}s'
                            : 'Click to resend.',
                        style: TextStyle(
                          color: _countdown == 0
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          decoration: _countdown == 0
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),

              AppPrimaryButton(
                label: 'Verify Email',
                isLoading: _loading,
                onPressed: _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
