import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/lookup_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_dialog.dart';
import '../data/beneficiaries_repository.dart';

Future<bool> showAddBeneficiarySheet(BuildContext context) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _AddBeneficiarySheet(),
  );
  return res ?? false;
}

class _AddBeneficiarySheet extends ConsumerStatefulWidget {
  const _AddBeneficiarySheet();

  @override
  ConsumerState<_AddBeneficiarySheet> createState() =>
      _AddBeneficiarySheetState();
}

class _AddBeneficiarySheetState extends ConsumerState<_AddBeneficiarySheet> {
  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();

  String? _bankCode;
  String? _categoryId;
  String? _resolvedName;
  String? _resolveError;
  bool _resolving = false;
  bool _saving = false;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryResolve() async {
    final acc = _accountCtrl.text.trim();
    if (_bankCode == null || acc.length != 10) {
      setState(() {
        _resolvedName = null;
        _resolveError = null;
      });
      return;
    }
    setState(() {
      _resolving = true;
      _resolveError = null;
      _resolvedName = null;
    });
    try {
      final res = await ref
          .read(beneficiariesRepositoryProvider)
          .resolveAccount(bankCode: _bankCode!, accountNumber: acc);
      if (!mounted) return;
      setState(() {
        _resolvedName = res['accountName']?.toString();
        _resolving = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _resolveError = e.message;
        _resolving = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _bankCode == null ||
        _categoryId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(beneficiariesRepositoryProvider).createBeneficiary(
            bankCode: _bankCode!,
            accountNumber: _accountCtrl.text,
            categoryId: _categoryId!,
            narration: _narrationCtrl.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showStatusDialog(context, message: e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final banksAsync = ref.watch(banksProvider);
    final catsAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Beneficiary', style: AppTextStyles.titleLarge),
              const SizedBox(height: 16),
              Text('Bank Name',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
              const SizedBox(height: 6),
              banksAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load banks: $e'),
                data: (banks) {
                  _bankCode ??=
                      banks.isNotEmpty ? banks.first['code'].toString() : null;
                  return DropdownButtonFormField<String>(
                    initialValue: _bankCode,
                    isExpanded: true,
                    items: banks
                        .map(
                          (b) => DropdownMenuItem(
                            value: b['code'].toString(),
                            child: Text(
                              b['name'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _bankCode = v);
                      _tryResolve();
                    },
                    decoration: const InputDecoration(),
                  );
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Account Number (10 digits)',
                controller: _accountCtrl,
                hintText: '0123456789',
                maxLength: 10,
                keyboardType: TextInputType.number,
                validator: Validators.nuban,
                onChanged: (_) => _tryResolve(),
              ),
              const SizedBox(height: 8),
              if (_resolving)
                const Row(
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Resolving account name...'),
                  ],
                )
              else if (_resolvedName != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resolvedName!,
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.success),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_resolveError != null)
                Text(
                  _resolveError!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
              const SizedBox(height: 14),
              Text('Category',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
              const SizedBox(height: 6),
              catsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load categories: $e'),
                data: (cats) {
                  _categoryId ??=
                      cats.isNotEmpty ? cats.first['id'].toString() : null;
                  return DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    items: cats
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text(c['name'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    decoration: const InputDecoration(),
                  );
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Default Narration (Optional)',
                controller: _narrationCtrl,
                hintText: 'e.g. Monthly upkeep',
                maxLength: 100,
              ),
              const SizedBox(height: 22),
              AppPrimaryButton(
                label: 'Save Beneficiary',
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
