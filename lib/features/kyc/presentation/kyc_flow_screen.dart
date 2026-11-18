import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/kyc_repository.dart';

class KycFlowScreen extends ConsumerStatefulWidget {
  const KycFlowScreen({super.key});

  @override
  ConsumerState<KycFlowScreen> createState() => _KycFlowScreenState();
}

class _KycFlowScreenState extends ConsumerState<KycFlowScreen> {
  final _picker = ImagePicker();
  final _phoneCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  bool _initializing = true;
  bool _submitting = false;
  String? _loadError;

  int _currentStep = 0; // 0: Profile, 1: Identity, 2: Liveness
  List<Map<String, dynamic>> _countries = [];
  Map<String, dynamic>? _selectedCountry;

  // Nigeria identity
  String _ngMethod = 'bvn';

  // International identity
  String _intlDocType = 'passport';
  File? _frontDoc;
  File? _backDoc;

  // Liveness
  File? _selfie;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _idNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initializing = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(kycRepositoryProvider);
      final results = await Future.wait([
        repo.getCountries(),
        repo.getStatus(),
      ]);
      final countries = results[0] as List<Map<String, dynamic>>;
      final status = results[1] as Map<String, dynamic>;

      final stepStr = (status['currentStep'] ?? '').toString().toLowerCase();
      int step = 0;
      if (stepStr.contains('identity')) {
        step = 1;
      } else if (stepStr.contains('liveness')) {
        step = 2;
      }

      setState(() {
        _countries = countries;
        _selectedCountry = countries.isNotEmpty ? countries.first : null;
        _currentStep = step;
        _initializing = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _loadError = e.message;
        _initializing = false;
      });
    }
  }

  bool get _isNigeria =>
      (_selectedCountry?['region']?.toString().toLowerCase() ?? 'nigeria') ==
          'nigeria' ||
      (_selectedCountry?['code']?.toString().toUpperCase() ?? 'NG') == 'NG';

  Future<void> _submitStep1() async {
    if (!_step1Key.currentState!.validate() || _selectedCountry == null) return;
    setState(() => _submitting = true);
    try {
      final dial = _selectedCountry!['dialCode']?.toString() ?? '+234';
      var phone = _phoneCtrl.text.trim();
      if (!phone.startsWith('+')) {
        phone = '$dial${phone.startsWith('0') ? phone.substring(1) : phone}';
      }
      await ref.read(kycRepositoryProvider).updateProfile(
            countryCode: _selectedCountry!['code'].toString(),
            phoneNumber: phone,
          );
      setState(() => _currentStep = 1);
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitStep2() async {
    if (_isNigeria) {
      if (!_step2Key.currentState!.validate()) return;
      setState(() => _submitting = true);
      try {
        await ref.read(kycRepositoryProvider).verifyNigeriaIdentity(
              method: _ngMethod,
              idNumber: _idNumberCtrl.text,
            );
        setState(() => _currentStep = 2);
      } on ApiException catch (e) {
        _showError(e.message);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    } else {
      if (_frontDoc == null) {
        _showError('Please upload the front of your document.');
        return;
      }
      setState(() => _submitting = true);
      try {
        await ref.read(kycRepositoryProvider).uploadInternationalIdentity(
              documentType: _intlDocType,
              frontFile: _frontDoc!,
              backFile: _backDoc,
            );
        setState(() => _currentStep = 2);
      } on ApiException catch (e) {
        _showError(e.message);
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    }
  }

  Future<void> _submitStep3() async {
    if (_selfie == null) {
      _showError('Please take or select a selfie first.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(kycRepositoryProvider).submitLiveness(_selfie!);
      await ref.read(authProvider.notifier).refreshMe();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.verified_rounded,
              color: AppColors.success, size: 48),
          title: const Text('Identity Approved!'),
          content: const Text(
            'Your KYC verification is complete. Your dedicated PaySplit salary account is being activated.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/dashboard');
              },
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickImage(ImageSource source, ValueChanged<File> onPicked) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1400,
      imageQuality: 85,
    );
    if (picked != null) {
      onPicked(File(picked.path));
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete KYC')),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? ErrorStateView(message: _loadError!, onRetry: _loadInitial)
              : SafeArea(
                  child: Column(
                    children: [
                      _KycStepperHeader(currentStep: _currentStep),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _currentStep == 0
                              ? _buildStep1()
                              : _currentStep == 1
                                  ? _buildStep2()
                                  : _buildStep3(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile Basics', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Select your country of residence and enter your mobile phone number.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text('Country',
              style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: _selectedCountry,
            items: _countries
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text('${c['name']} (${c['dialCode']})'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedCountry = v),
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Mobile Phone Number',
            controller: _phoneCtrl,
            hintText: '8031234567',
            prefixText: '${_selectedCountry?['dialCode'] ?? '+234'} ',
            keyboardType: TextInputType.phone,
            validator: (v) => Validators.requiredField(v, 'Phone number'),
          ),
          const SizedBox(height: 28),
          AppPrimaryButton(
            label: 'Save & Continue',
            isLoading: _submitting,
            onPressed: _submitStep1,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Identity Verification', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            _isNigeria
                ? 'Verify using your 11-digit BVN or NIN.'
                : 'Upload a clear photo of your valid government ID.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 24),
          if (_isNigeria) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'bvn', label: Text('BVN')),
                ButtonSegment(value: 'nin', label: Text('NIN')),
              ],
              selected: {_ngMethod},
              onSelectionChanged: (s) => setState(() => _ngMethod = s.first),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: _ngMethod == 'bvn'
                  ? 'Bank Verification Number (BVN)'
                  : 'National Identity Number (NIN)',
              controller: _idNumberCtrl,
              hintText: '22234918239',
              maxLength: 11,
              keyboardType: TextInputType.number,
              validator: Validators.bvnOrNin,
            ),
          ] else ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'passport', label: Text('Passport')),
                ButtonSegment(
                    value: 'drivers_license', label: Text("Driver's License")),
              ],
              selected: {_intlDocType},
              onSelectionChanged: (s) => setState(() => _intlDocType = s.first),
            ),
            const SizedBox(height: 16),
            _FileUploadTile(
              title: 'Front of Document',
              file: _frontDoc,
              onTap: () => _pickImage(
                  ImageSource.gallery, (f) => setState(() => _frontDoc = f)),
            ),
            const SizedBox(height: 12),
            if (_intlDocType == 'drivers_license')
              _FileUploadTile(
                title: 'Back of Document (Optional)',
                file: _backDoc,
                onTap: () => _pickImage(
                    ImageSource.gallery, (f) => setState(() => _backDoc = f)),
              ),
          ],
          const SizedBox(height: 28),
          AppPrimaryButton(
            label: 'Verify Identity',
            isLoading: _submitting,
            onPressed: _submitStep2,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Biometric Liveness', style: AppTextStyles.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Take a clear selfie in good lighting to match your identity record.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: () => _pickImage(
                ImageSource.camera, (f) => setState(() => _selfie = f)),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
                image: _selfie != null
                    ? DecorationImage(
                        image: FileImage(_selfie!), fit: BoxFit.cover)
                    : null,
              ),
              child: _selfie == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            size: 42, color: AppColors.primary),
                        SizedBox(height: 8),
                        Text('Tap to take shot'),
                      ],
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () => _pickImage(
                ImageSource.gallery, (f) => setState(() => _selfie = f)),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Or choose from gallery'),
          ),
        ),
        const SizedBox(height: 28),
        AppPrimaryButton(
          label: 'Submit Liveness Check',
          isLoading: _submitting,
          onPressed: _submitStep3,
        ),
      ],
    );
  }
}

class _KycStepperHeader extends StatelessWidget {
  const _KycStepperHeader({required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Profile', 'Identity', 'Liveness'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppColors.surface,
      child: Row(
        children: List.generate(labels.length, (i) {
          final done = i < currentStep;
          final active = i == currentStep;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: done || active
                      ? AppColors.primary
                      : AppColors.surfaceSubtle,
                  child: done
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    labels[i],
                    style: AppTextStyles.labelSmall.copyWith(
                      color: active || done
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _FileUploadTile extends StatelessWidget {
  const _FileUploadTile({
    required this.title,
    required this.file,
    required this.onTap,
  });

  final String title;
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            file != null
                ? Icons.check_circle_rounded
                : Icons.upload_file_rounded,
            color: file != null ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                Text(
                  file != null
                      ? file!.path.split('/').last
                      : 'Tap to select PNG or JPG (max 2MB)',
                  style: AppTextStyles.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
