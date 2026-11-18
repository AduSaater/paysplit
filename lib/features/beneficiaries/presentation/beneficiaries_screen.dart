import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/beneficiaries_repository.dart';
import 'add_beneficiary_sheet.dart';

class BeneficiariesScreen extends ConsumerStatefulWidget {
  const BeneficiariesScreen({super.key});

  @override
  ConsumerState<BeneficiariesScreen> createState() =>
      _BeneficiariesScreenState();
}

class _BeneficiariesScreenState extends ConsumerState<BeneficiariesScreen> {
  String _status = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(beneficiariesListProvider(_status));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beneficiaries'),
        actions: [
          IconButton(
            tooltip: 'Add beneficiary',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () async {
              final added = await showAddBeneficiarySheet(context);
              if (added) ref.invalidate(beneficiariesListProvider(_status));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              children: [
                AppSearchField(
                  controller: _searchCtrl,
                  hintText: 'Search by name or bank...',
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: ['all', 'active', 'paused'].map((s) {
                    final selected = _status == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s[0].toUpperCase() + s.substring(1)),
                        selected: selected,
                        selectedColor: AppColors.primaryLight,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(beneficiariesListProvider(_status)),
              child: listAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: LoadingShimmerList(),
                ),
                error: (err, _) => ListView(
                  children: [
                    ErrorStateView(
                      message: err.toString(),
                      isOffline: err is ApiException && err.isNetworkError,
                      onRetry: () =>
                          ref.invalidate(beneficiariesListProvider(_status)),
                    ),
                  ],
                ),
                data: (items) {
                  final filtered = _search.isEmpty
                      ? items
                      : items.where((b) {
                          final name =
                              (b['accountName'] ?? '').toString().toLowerCase();
                          final bank =
                              (b['bankName'] ?? '').toString().toLowerCase();
                          return name.contains(_search) ||
                              bank.contains(_search);
                        }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        EmptyStateView(
                          icon: Icons.people_outline_rounded,
                          title: 'No beneficiaries found',
                          subtitle:
                              'Add recipients like family, rent, or staff to automate transfers on payday.',
                          actionLabel: 'Add Beneficiary',
                          onAction: () async {
                            final added =
                                await showAddBeneficiarySheet(context);
                            if (added) {
                              ref.invalidate(
                                  beneficiariesListProvider(_status));
                            }
                          },
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final b = filtered[i];
                      final id = b['id'].toString();
                      final name =
                          (b['accountName'] ?? 'Recipient').toString();
                      final bank = (b['bankName'] ?? '').toString();
                      final acct = (b['accountNumber'] ?? '').toString();
                      final status = (b['status'] ?? 'active').toString();

                      return AppCard(
                        onTap: () => context.push('/beneficiaries/$id'),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'B',
                                style: AppTextStyles.labelLarge
                                    .copyWith(color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: AppTextStyles.titleMedium),
                                  Text(
                                    '$bank • $acct',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: status),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
