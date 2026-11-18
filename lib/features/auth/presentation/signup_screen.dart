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

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signup(
            firstName: _firstCtrl.text,
            lastName: _lastCtrl.text,
            email: _emailCtrl.text,
          );
      if (!mounted) return;
      context.push('/verify-email', extra: _emailCtrl.text.trim());
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
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Step 1 of 3 • Your Details',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                const SizedBox(height: 8),
                Text('Start splitting your salary automatically',
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Use your legal name so it matches your BVN, NIN, or ID during verification.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 28),
                AppTextField(
                  label: 'First Name',
                  controller: _firstCtrl,
                  hintText: 'e.g. Paul',
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.requiredField(v, 'First name'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Last Name',
                  controller: _lastCtrl,
                  hintText: 'e.g. Obi',
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.requiredField(v, 'Last name'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Email Address',
                  controller: _emailCtrl,
                  hintText: 'paul@paysplit.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 28),
                AppPrimaryButton(
                  label: 'Continue',
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
