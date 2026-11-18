import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirmation_modal.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../split_rules/data/split_rules_repository.dart';
import '../data/dashboard_repository.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _hideBalance = false;
  bool _runningSplit = false;

  Future<void> _runSplitNow() async {
    final confirmed = await showConfirmationSheet(
      context,
      title: 'Run Split Now?',
      message:
          'PaySplit will immediately distribute your available salary account balance according to your active split rules.',
      confirmLabel: 'Run Split Now',
    );
    if (!confirmed || !mounted) return;

    setState(() => _runningSplit = true);
    try {
      await ref.read(splitRulesRepositoryProvider).runSplitNow();
      await ref.read(dashboardProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Split run completed!'),
          backgroundColor: AppColors.success,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _runningSplit = false);
    }
  }

  Future<void> _showSimulateCreditSheet() async {
    final amountCtrl = TextEditingController(text: '600000');
    final senderCtrl = TextEditingController(text: 'Acme Ltd');
    final narrationCtrl = TextEditingController(text: 'Monthly Salary');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Simulate Salary Credit (QA)', style: AppTextStyles.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Credits your salary account in sandbox mode and triggers automatic split rules.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Amount (₦)',
              controller: amountCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppTextField(label: 'Sender Name', controller: senderCtrl),
            const SizedBox(height: 12),
            AppTextField(label: 'Narration', controller: narrationCtrl),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Credit Salary Account',
              onPressed: () async {
                final kobo =
                    CurrencyFormatter.parseNairaToKobo(amountCtrl.text);
                if (kobo == null || kobo <= 0) return;
                Navigator.of(ctx).pop();
                try {
                  await ref
                      .read(dashboardRepositoryProvider)
                      .simulateSalaryCredit(
                        amountKobo: kobo,
                        senderName: senderCtrl.text.trim(),
                        narration: narrationCtrl.text.trim(),
                      );
                  await ref.read(dashboardProvider.notifier).refresh();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Salary credited!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } on ApiException catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final dashAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${auth.user?['firstName'] ?? 'there'} 👋',
              style: AppTextStyles.titleLarge,
            ),
            Text(
              'Automated salary routing',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        actions: [
          dashAsync.whenOrNull(
                data: (b) => Stack(
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => context.push('/notifications'),
                    ),
                    if (b.unreadNotifications > 0)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ) ??
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
              ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: dashAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: LoadingShimmerList(itemCount: 5),
          ),
          error: (err, _) => ListView(
            children: [
              ErrorStateView(
                message: err.toString(),
                isOffline: err is ApiException && err.isNetworkError,
                onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
              ),
            ],
          ),
          data: (bundle) => _buildContent(context, bundle, auth),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DashboardBundle bundle,
    AuthState auth,
  ) {
    final summary = bundle.summary;
    final salaryAcc = bundle.salaryAccount;
    final setup = bundle.setupProgress;

    final salaryBalance = (salaryAcc['balance'] ??
        summary['salaryBalance'] ??
        summary['balance'] ??
        0) as num;
    final walletsTotal =
        (summary['walletsTotal'] ?? summary['totalWalletBalance'] ?? 0) as num;
    final allocatedPct =
        (summary['allocatedPercent'] ?? summary['splitAllocationPercent'] ?? 0)
            as num;
    final nextSplit = summary['nextSplitRun'] as Map<String, dynamic>?;
    final accountStatus = (salaryAcc['status'] ?? 'not_issued').toString();
    final accountNumber = salaryAcc['accountNumber']?.toString();
    final bankName = salaryAcc['bankName']?.toString();

    final progressPct =
        ((setup['progress'] as Map<String, dynamic>?)?['percent'] as num?) ??
            100;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        // 1. Salary Balance Hero Card (Figma #0F324A / #17415D + balance_ring.png)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDeep, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            image: const DecorationImage(
              image: AssetImage('assets/images/balance_ring.png'),
              alignment: Alignment.centerRight,
              opacity: 0.16,
              fit: BoxFit.contain,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Salary Account Balance',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  Row(
                    children: [
                      StatusBadge(status: accountStatus),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip:
                            _hideBalance ? 'Show balance' : 'Hide balance',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        icon: Icon(
                          _hideBalance
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _hideBalance = !_hideBalance),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _hideBalance
                    ? '••••••••'
                    : CurrencyFormatter.formatKobo(salaryBalance),
                style: AppTextStyles.displayLarge.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 14),
              if (accountNumber != null && accountNumber.isNotEmpty)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: accountNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account number copied')),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${bankName ?? 'Salary Account'} • $accountNumber',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded,
                            size: 14, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _runningSplit ? null : _runSplitNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        minimumSize: const Size(0, 44),
                      ),
                      icon: _runningSplit
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('Run Split Now'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _showSimulateCreditSheet,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('+ Simulate'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. KYC Verification Status Banner (if not approved)
        if (!auth.isKycApproved) ...[
          AppCard(
            backgroundColor: AppColors.warningBg,
            borderColor: AppColors.warning.withValues(alpha: 0.3),
            onTap: () => context.push('/kyc'),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    color: AppColors.warning, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Complete KYC Verification',
                          style: AppTextStyles.titleMedium
                              .copyWith(color: AppColors.warning)),
                      Text(
                        'Verify your identity to issue your salary account and enable payouts.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.warning),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 3. Setup Progress Card (if < 100%)
        if (progressPct < 100) ...[
          AppCard(
            onTap: () => context.go('/rules'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Complete your account setup',
                        style: AppTextStyles.titleMedium),
                    Text('${progressPct.toInt()}%',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (progressPct / 100).clamp(0.0, 1.0),
                  backgroundColor: AppColors.surfaceSubtle,
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 7,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your salary income, create a wallet, add a beneficiary, and activate a split rule.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 4. Summary Metrics Row (Wallets Total & Next Split)
        Row(
          children: [
            Expanded(
              child: AppCard(
                onTap: () => context.go('/wallets'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallets Total', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      _hideBalance
                          ? '••••••'
                          : CurrencyFormatter.formatKobo(walletsTotal),
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${allocatedPct.toStringAsFixed(0)}% salary routed',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppCard(
                onTap: () => context.go('/rules'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Next Scheduled Split', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      nextSplit?['scheduledFor'] != null
                          ? DateFormatter.formatDate(
                              nextSplit!['scheduledFor'].toString())
                          : 'On payday',
                      style: AppTextStyles.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextSplit?['estimatedAmount'] != null
                          ? CurrencyFormatter.formatKobo(
                              nextSplit!['estimatedAmount'] as num)
                          : 'View split rules →',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // 5. Recent Activity & Splits
        SectionHeader(
          title: 'Recent Activity & Splits',
          actionLabel: 'See all',
          onAction: () => context.go('/transactions'),
        ),
        const SizedBox(height: 10),
        if (bundle.recentTransactions.isEmpty)
          const AppCard(
            child: EmptyStateView(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              subtitle:
                  'When your salary arrives or you run a split, every movement appears here.',
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bundle.recentTransactions.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (ctx, i) {
                final tx = bundle.recentTransactions[i];
                final signed =
                    (tx['signedAmount'] ?? tx['amount'] ?? 0) as num;
                final isCredit = signed > 0;
                final title = (tx['title'] ??
                        tx['description'] ??
                        tx['destinationName'] ??
                        'Transaction')
                    .toString();
                final status = (tx['status'] ?? 'success').toString();

                return ListTile(
                  onTap: () {
                    final id = tx['id']?.toString();
                    if (id != null) context.push('/transactions/$id');
                  },
                  leading: CircleAvatar(
                    backgroundColor:
                        isCredit ? AppColors.successBg : AppColors.surfaceSubtle,
                    child: Icon(
                      isCredit
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: isCredit ? AppColors.success : AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    title,
                    style: AppTextStyles.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    DateFormatter.formatRelative(tx['createdAt']?.toString()),
                    style: AppTextStyles.bodySmall,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.formatSignedKobo(signed),
                        style: AppTextStyles.labelLarge.copyWith(
                          color:
                              isCredit ? AppColors.success : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      StatusBadge(status: status),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
