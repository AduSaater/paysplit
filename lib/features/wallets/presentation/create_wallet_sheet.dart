import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/data/lookup_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_dialog.dart';
import '../data/wallets_repository.dart';

Future<bool> showWalletFormSheet(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _WalletFormSheet(existing: existing),
  );
  return res ?? false;
}

class _WalletFormSheet extends ConsumerStatefulWidget {
  const _WalletFormSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  ConsumerState<_WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends ConsumerState<_WalletFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  String? _categoryId;
  String _accentColor = 'green';
  bool _saving = false;

  static const _colors = [
    'green',
    'orange',
    'purple',
    'blue',
    'red',
    'yellow',
    'teal',
    'pink',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name']?.toString() ?? '');
    final target = e?['targetAmount'] as num?;
    _targetCtrl = TextEditingController(
      text: CurrencyFormatter.koboToEditableNaira(target),
    );
    _categoryId = e?['categoryId']?.toString() ??
        (e?['category'] as Map<String, dynamic>?)?['id']?.toString();
    _accentColor = e?['accentColor']?.toString() ?? 'green';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null || _categoryId!.isEmpty) {
      await showStatusDialog(
        context,
        message: 'Please wait for categories to load or select a category.',
        isError: true,
      );
      return;
    }

    int? targetKobo;
    if (_targetCtrl.text.trim().isNotEmpty) {
      targetKobo = CurrencyFormatter.parseNairaToKobo(_targetCtrl.text);
      if (targetKobo == null || targetKobo <= 0) {
        await showStatusDialog(
          context,
          message: 'Enter a valid target amount in Naira.',
          isError: true,
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(walletsRepositoryProvider);
      if (widget.existing == null) {
        await repo.createWallet(
          name: _nameCtrl.text,
          categoryId: _categoryId!,
          accentColor: _accentColor,
          targetAmountKobo: targetKobo,
        );
      } else {
        await repo.updateWallet(
          widget.existing!['id'].toString(),
          name: _nameCtrl.text,
          categoryId: _categoryId,
          accentColor: _accentColor,
          targetAmountKobo: targetKobo,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      await showStatusDialog(
        context,
        title: widget.existing == null
            ? 'Wallet Created Successfully'
            : 'Wallet Updated',
        message: widget.existing == null
            ? 'Your wallet has been created successfully!'
            : 'Your wallet changes have been saved.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      await showStatusDialog(context, message: e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      await showStatusDialog(
        context,
        message: 'Unable to save wallet. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                widget.existing == null ? 'Create New Wallet' : 'Edit Wallet',
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Wallet Name',
                controller: _nameCtrl,
                hintText: 'e.g. Emergency Fund',
                maxLength: 60,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),
              Text('Category',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
              const SizedBox(height: 6),
              catsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load categories: $e'),
                data: (cats) {
                  final validIds =
                      cats.map((c) => c['id'].toString()).toSet();
                  if (_categoryId == null || !validIds.contains(_categoryId)) {
                    _categoryId =
                        cats.isNotEmpty ? cats.first['id'].toString() : null;
                  }
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
              Text('Accent Color',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _colors.map((c) {
                  final selected = _accentColor == c;
                  final color = AppColors.walletAccent(c);
                  return GestureDetector(
                    onTap: () => setState(() => _accentColor = c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: AppColors.textPrimary, width: 3)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Target Goal (₦, Optional)',
                controller: _targetCtrl,
                hintText: 'Leave blank for no targeted amount',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 22),
              AppPrimaryButton(
                label: widget.existing == null ? 'Create Wallet' : 'Save Changes',
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
