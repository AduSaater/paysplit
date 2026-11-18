import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import '../../../core/widgets/status_dialog.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../split_rules/data/split_rules_repository.dart';
import '../data/dashboard_repository.dart';
import 'dashboard_provider.dart';
import 'widgets/cash_flow_chart_card.dart';
import 'widgets/salary_partition_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _balancePageCtrl = PageController(viewportFraction: 0.92);
  int _balancePage = 0;
  bool _hideBalance = false;
  bool _runningSplit = false;

  @override
  void dispose() {
    _balancePageCtrl.dispose();
    super.dispose();
  }

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
      await showStatusDialog(
        context,
        message: 'Split run completed!',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      await showStatusDialog(context, message: e.message, isError: true);
    } finally {
      if (mounted) setState(() => _runningSplit = false);
    }
  }

  Future<void> _showSimulateCreditSheet() async {
    final amountCtrl = TextEditingController(text: '850000');
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
                  await showStatusDialog(
                    context,
                    message: 'Salary credited!',
                  );
                } on ApiException catch (e) {
                  if (!mounted) return;
                  await showStatusDialog(
                    context,
                    message: e.message,
                    isError: true,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountDetailsSheet(Map<String, dynamic> salaryAcc, String fullName) {
    final accountNumber = salaryAcc['accountNumber']?.toString() ?? 'Not issued yet';
    final bankName = salaryAcc['bankName']?.toString() ?? 'PaySplit Salary Bank';
    final status = (salaryAcc['status'] ?? 'not_issued').toString();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Account Details', style: AppTextStyles.titleLarge),
                  StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 16),
              Text('Account Name', style: AppTextStyles.bodySmall),
              Text(fullName, style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              Text('Bank', style: AppTextStyles.bodySmall),
              Text(bankName, style: AppTextStyles.titleMedium),
              const SizedBox(height: 12),
              Text('Account Number', style: AppTextStyles.bodySmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(accountNumber, style: AppTextStyles.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: accountNumber));
                      Navigator.of(ctx).pop();
                      showStatusDialog(
                        context,
                        message: 'Account number copied to clipboard.',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppPrimaryButton(
                      label: _runningSplit ? 'Running...' : 'Run Split Now',
                      icon: Icons.bolt_rounded,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _runSplitNow();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppSecondaryButton(
                      label: '+ Simulate Credit',
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showSimulateCreditSheet();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final dashAsync = ref.watch(dashboardProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: dashAsync.when(
          loading: () => const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: LoadingShimmerList(itemCount: 5),
            ),
          ),
          error: (err, _) => ListView(
            children: [
              const SizedBox(height: 60),
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
    final partition = (summary['partition'] as Map<String, dynamic>?) ?? {};

    final firstName = auth.user?['firstName']?.toString() ?? '';
    final greeting = firstName.isNotEmpty ? 'Hello, $firstName!' : 'Hello!';
    final todayStr = DateFormat('EEEE, MMM d, y').format(DateTime.now());

    final salaryBalance = (salaryAcc['balance'] ??
        summary['salaryBalance'] ??
        summary['balance'] ??
        0) as num;
    final walletsTotal = (partition['wallets'] ??
        summary['walletsTotal'] ??
        summary['totalWalletBalance'] ??
        0) as num;
    final beneficiariesTotal = (partition['beneficiaries'] ??
        summary['beneficiariesTotal'] ??
        0) as num;
    final remainderKobo = (partition['remainder'] ??
        summary['remainder'] ??
        salaryBalance) as num;
    final remainderPct = (partition['remainderPercent'] ??
        (salaryBalance > 0 ? 28 : 0)) as num;
    final monthlySalary =
        (summary['monthlySalary'] ?? salaryBalance) as num;

    final accountNumber = salaryAcc['accountNumber']?.toString() ?? '';
    final maskedAcct = accountNumber.length >= 4
        ? '*****${accountNumber.substring(accountNumber.length - 4)}'
        : 'Account not issued';

    final latestNotifBody = bundle.latestNotification?['message']?.toString() ??
        bundle.latestNotification?['body']?.toString() ??
        'No notifications yet.';

    final progressPct =
        ((setup['progress'] as Map<String, dynamic>?)?['percent'] as num?) ??
            100;

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        // 1. Dark Top Header + Overlapping White Balance Carousel (matches Figma 181)
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 12,
                16,
                84,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A131A), Color(0xFF0F2634)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting Row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/settings'),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            firstName.isNotEmpty
                                ? firstName[0].toUpperCase()
                                : 'P',
                            style: AppTextStyles.titleMedium
                                .copyWith(color: AppColors.primaryDark),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/settings'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                todayStr,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Stack(
                        children: [
                          InkWell(
                            onTap: () => context.push('/notifications'),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          if (bundle.unreadNotifications > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notification Banner Card
                  InkWell(
                    onTap: () => context.push('/notifications'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.notifications_none_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Notification',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    'View',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            latestNotifBody,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Overlapping White Balance Card Carousel
            Positioned(
              left: 0,
              right: 0,
              bottom: -58,
              child: SizedBox(
                height: 132,
                child: PageView(
                  controller: _balancePageCtrl,
                  onPageChanged: (i) => setState(() => _balancePage = i),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Salary Account Balance',
                              style: AppTextStyles.bodySmall,
                            ),
                            Row(
                              children: [
                                Text(
                                  _hideBalance
                                      ? '••••••••'
                                      : CurrencyFormatter.formatKobo(
                                          salaryBalance,
                                          showDecimals: false,
                                        ),
                                  style: AppTextStyles.displayLarge.copyWith(
                                    fontSize: 26,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () => setState(
                                      () => _hideBalance = !_hideBalance),
                                  child: SvgPicture.asset(
                                    'assets/icons/eye.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: ColorFilter.mode(
                                      _hideBalance
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$maskedAcct ${auth.fullName}',
                                  style: AppTextStyles.bodySmall,
                                ),
                                InkWell(
                                  onTap: () => _showAccountDetailsSheet(
                                      salaryAcc, auth.fullName),
                                  child: Text(
                                    'View Account Details',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        onTap: () => context.go('/destination'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Wallets Balance',
                                style: AppTextStyles.bodySmall),
                            Text(
                              _hideBalance
                                  ? '••••••••'
                                  : CurrencyFormatter.formatKobo(
                                      walletsTotal,
                                      showDecimals: false,
                                    ),
                              style: AppTextStyles.displayLarge.copyWith(
                                fontSize: 26,
                              ),
                            ),
                            Text(
                              'Tap to manage savings wallets →',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 68),

        // Carousel Page Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (i) {
            final active = i == _balancePage;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 8,
              height: 3,
              decoration: BoxDecoration(
                color: active ? AppColors.primaryDark : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Complete Onboarding Card (matches Figma white card with blue title)
              if (!auth.isKycApproved) ...[
                AppCard(
                  onTap: () =>
                      _showOnboardingModal(context, progressPct, auth.isKycApproved),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.rocket_launch_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Complete Onboarding',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Verify your account to unlock splitting and get a dedicated account number',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Setup Progress Banner (if < 100%)
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Salary Partition Card (Figma dual-arc gauge)
              SalaryPartitionCard(
                walletsKobo: walletsTotal,
                beneficiariesKobo: beneficiariesTotal,
                remainderKobo: remainderKobo,
                remainderPercent: remainderPct,
                hideBalance: _hideBalance,
                onSeeRules: () => context.go('/rules'),
              ),
              const SizedBox(height: 20),

              // 3. Salary Allocation & Split Cash Flow Card (Figma bar chart)
              CashFlowChartCard(
                cashFlow: bundle.cashFlow,
                monthlySalaryKobo: monthlySalary,
                hideBalance: _hideBalance,
              ),
              const SizedBox(height: 22),

              // 4. Recent Activity & Splits
              SectionHeader(
                title: 'Recent Activity & Splits',
                actionLabel: 'See all',
                onAction: () => context.go('/history'),
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
                          backgroundColor: isCredit
                              ? AppColors.successBg
                              : AppColors.surfaceSubtle,
                          child: Icon(
                            isCredit
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color: isCredit
                                ? AppColors.success
                                : AppColors.textPrimary,
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
                          DateFormatter.formatRelative(
                              tx['createdAt']?.toString()),
                          style: AppTextStyles.bodySmall,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatSignedKobo(signed),
                              style: AppTextStyles.labelLarge.copyWith(
                                color: isCredit
                                    ? AppColors.success
                                    : AppColors.textPrimary,
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
          ),
        ),
      ],
    );
  }

  void _showOnboardingModal(
      BuildContext context, num progressPct, bool kycDone) {
    final step2Done = kycDone;
    final step3Done = kycDone && progressPct >= 100;
    final pct = !step2Done ? 34 : (!step3Done ? 50 : 100);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      clipBehavior: Clip.antiAlias,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Stack(
            children: [
              Positioned.fill(
                top: 0,
                bottom: 240,
                child: ClipRect(
                  child: CustomPaint(painter: _SunburstPainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.highlight_off_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: (pct / 100).clamp(0.0, 1.0),
                            strokeWidth: 9,
                            strokeCap: StrokeCap.round,
                            backgroundColor: AppColors.primarySoft,
                            color: AppColors.primary,
                          ),
                          Center(
                            child: Text(
                              '$pct%',
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Complete Account Setup',
                        style: AppTextStyles.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Verify your account to upgrade to a Tier 2. Unlock splitting and get a dedicated account number.',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    const _OnboardingStepTile(
                      step: 'Step 1',
                      title: 'Sign up Account',
                      subtitle: 'Create your PaySplit account',
                      done: true,
                    ),
                    const _DottedStepConnector(),
                    _OnboardingStepTile(
                      step: 'Step 2',
                      title: 'Profile & Identity Verification',
                      subtitle: 'Verify using a government-issued ID',
                      done: step2Done,
                    ),
                    const _DottedStepConnector(),
                    _OnboardingStepTile(
                      step: 'Step 3',
                      title: 'Setup Checklist',
                      subtitle: 'Add salary source and set your first rule.',
                      done: step3Done,
                    ),
                    const SizedBox(height: 20),
                    AppPrimaryButton(
                      label: !step2Done
                          ? 'Continue to KYC'
                          : (!step3Done
                              ? 'Continue to Setup Checklist'
                              : 'Go To Dashboard'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        if (!step2Done) {
                          context.push('/kyc');
                        } else if (!step3Done) {
                          context.go('/rules');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DottedStepConnector extends StatelessWidget {
  const _DottedStepConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
          (_) => Container(
            width: 2,
            height: 3,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _SunburstPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final center = Offset(size.width / 2, 72);
    final paint = Paint()
      ..color = AppColors.background.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 12; i++) {
      final angle = (i * 3.14159 * 2) / 12;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: size.width),
          angle,
          0.14,
          false,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingStepTile extends StatelessWidget {
  const _OnboardingStepTile({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.done,
  });

  final String step;
  final String title;
  final String subtitle;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: done ? AppColors.primary : const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      step,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (done)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Done',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
