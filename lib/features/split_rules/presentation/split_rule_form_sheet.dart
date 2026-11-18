import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../beneficiaries/data/beneficiaries_repository.dart';
import '../../wallets/data/wallets_repository.dart';
import '../data/split_rules_repository.dart';

Future<bool> showSplitRuleFormSheet(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SplitRuleFormSheet(existing: existing),
  );
  return res ?? false;
}

class _SplitRuleFormSheet extends ConsumerStatefulWidget {
  const _SplitRuleFormSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  ConsumerState<_SplitRuleFormSheet> createState() =>
      _SplitRuleFormSheetState();
}

class _SplitRuleFormSheetState extends ConsumerState<_SplitRuleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priorityCtrl;
  late final TextEditingController _valueCtrl;

  String _destType = 'wallet';
  String? _walletId;
  String? _beneficiaryId;
  String _method = 'fixed';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name']?.toString() ?? '');
    _priorityCtrl =
        TextEditingController(text: (e?['priority'] ?? 10).toString());
    _destType = e?['destinationType']?.toString() ?? 'wallet';
    _walletId = e?['walletId']?.toString() ??
        (e?['wallet'] as Map<String, dynamic>?)?['id']?.toString();
    _beneficiaryId = e?['beneficiaryId']?.toString() ??
        (e?['beneficiary'] as Map<String, dynamic>?)?['id']?.toString();
    _method = e?['method']?.toString() ?? 'fixed';

    final rawVal = e?['value'] as num?;
    if (rawVal != null) {
      _valueCtrl = TextEditingController(
        text: _method == 'fixed'
            ? CurrencyFormatter.koboToEditableNaira(rawVal)
            : rawVal.toString(),
      );
    } else {
      _valueCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priorityCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_destType == 'wallet' && _walletId == null) {
      _showErr('Please select a wallet');
      return;
    }
    if (_destType == 'beneficiary' && _beneficiaryId == null) {
      _showErr('Please select a beneficiary');
      return;
    }

    final priority = int.tryParse(_priorityCtrl.text.trim()) ?? 10;
    num apiValue;
    if (_method == 'fixed') {
      final kobo = CurrencyFormatter.parseNairaToKobo(_valueCtrl.text);
      if (kobo == null || kobo <= 0) {
        _showErr('Enter a valid amount');
        return;
      }
      apiValue = kobo;
    } else {
      final pct = double.tryParse(_valueCtrl.text.trim());
      if (pct == null || pct <= 0 || pct > 100) {
        _showErr('Percentage must be between 0.01 and 100');
        return;
      }
      apiValue = pct;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(splitRulesRepositoryProvider);
      if (widget.existing == null) {
        await repo.createRule(
          name: _nameCtrl.text,
          priority: priority,
          destinationType: _destType,
          walletId: _walletId,
          beneficiaryId: _beneficiaryId,
          method: _method,
          value: apiValue,
        );
      } else {
        await repo.updateRule(
          widget.existing!['id'].toString(),
          name: _nameCtrl.text,
          priority: priority,
          destinationType: _destType,
          walletId: _destType == 'wallet' ? _walletId : null,
          beneficiaryId: _destType == 'beneficiary' ? _beneficiaryId : null,
          method: _method,
          value: apiValue,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _showErr(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsListProvider);
    final benAsync = ref.watch(beneficiariesListProvider('all'));

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
                widget.existing == null
                    ? 'Create Split Rule'
                    : 'Edit Split Rule',
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Rule Name',
                controller: _nameCtrl,
                hintText: 'e.g. Mom Monthly Support',
                maxLength: 80,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Rule name required' : null,
              ),
              const SizedBox(height: 14),
              Text('Destination Type',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'wallet', label: Text('Move to Wallet')),
                  ButtonSegment(
                      value: 'beneficiary', label: Text('Send to Beneficiary')),
                ],
                selected: {_destType},
                onSelectionChanged: (s) => setState(() => _destType = s.first),
              ),
              const SizedBox(height: 14),
              if (_destType == 'wallet') ...[
                Text('Select Wallet',
                    style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                walletsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Unable to load wallets: $e'),
                  data: (wallets) {
                    if (wallets.isEmpty) {
                      return const Text(
                        'No wallets yet. Create a wallet first.',
                        style: TextStyle(color: AppColors.error),
                      );
                    }
                    _walletId ??= wallets.first['id'].toString();
                    return DropdownButtonFormField<String>(
                      initialValue: _walletId,
                      items: wallets
                          .map((w) => DropdownMenuItem(
                                value: w['id'].toString(),
                                child: Text(w['name'].toString()),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _walletId = v),
                      decoration: const InputDecoration(),
                    );
                  },
                ),
              ] else ...[
                Text('Select Beneficiary',
                    style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
                const SizedBox(height: 6),
                benAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Unable to load beneficiaries: $e'),
                  data: (bens) {
                    if (bens.isEmpty) {
                      return const Text(
                        'No beneficiaries yet. Add a beneficiary first.',
                        style: TextStyle(color: AppColors.error),
                      );
                    }
                    _beneficiaryId ??= bens.first['id'].toString();
                    return DropdownButtonFormField<String>(
                      initialValue: _beneficiaryId,
                      items: bens
                          .map((b) => DropdownMenuItem(
                                value: b['id'].toString(),
                                child: Text(
                                  '${b['accountName']} (${b['bankName']})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _beneficiaryId = v),
                      decoration: const InputDecoration(),
                    );
                  },
                ),
              ],
              const SizedBox(height: 14),
              Text('Allocation Method',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'fixed', label: Text('Fixed Amount (₦)')),
                  ButtonSegment(
                      value: 'percentage', label: Text('Percentage (%)')),
                ],
                selected: {_method},
                onSelectionChanged: (s) {
                  setState(() {
                    _method = s.first;
                    _valueCtrl.clear();
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      label: _method == 'fixed' ? 'Amount (₦)' : 'Percentage (%)',
                      controller: _valueCtrl,
                      hintText: _method == 'fixed' ? '50000' : '10',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        if (_method == 'fixed') {
                          final k = CurrencyFormatter.parseNairaToKobo(v);
                          if (k == null || k <= 0) return 'Invalid amount';
                        } else {
                          final p = double.tryParse(v.trim());
                          if (p == null || p <= 0 || p > 100) {
                            return '0.01 - 100%';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      label: 'Priority (1-100)',
                      controller: _priorityCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final p = int.tryParse(v ?? '');
                        if (p == null || p < 1 || p > 100) return '1-100';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              AppPrimaryButton(
                label: widget.existing == null
                    ? 'Activate Split Rule'
                    : 'Save Changes',
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
