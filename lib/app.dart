import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';
import 'features/auth/presentation/account_success_screen.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/set_password_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';
import 'features/beneficiaries/presentation/beneficiaries_screen.dart';
import 'features/beneficiaries/presentation/beneficiary_detail_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/kyc/presentation/kyc_flow_screen.dart';
import 'features/settings/presentation/notifications_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/split_rules/presentation/split_rules_screen.dart';
import 'features/split_rules/presentation/split_runs_screen.dart';
import 'features/transactions/presentation/transaction_detail_screen.dart';
import 'features/transactions/presentation/transactions_screen.dart';
import 'features/wallets/presentation/destination_screen.dart';
import 'features/wallets/presentation/wallet_detail_screen.dart';
import 'features/wallets/presentation/wallets_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authProvider.select((s) => s.status));

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      if (authStatus == AuthStatus.unknown) return null;

      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' ||
          loc == '/signup' ||
          loc == '/verify-email' ||
          loc == '/set-password' ||
          loc == '/forgot-password';

      if (authStatus == AuthStatus.unauthenticated && !isAuthRoute) {
        return '/login';
      }
      if (authStatus == AuthStatus.authenticated &&
          isAuthRoute &&
          loc != '/account-success') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) =>
            VerifyEmailScreen(email: (state.extra as String?) ?? ''),
      ),
      GoRoute(
        path: '/set-password',
        builder: (_, _) => const SetPasswordScreen(),
      ),
      GoRoute(
        path: '/account-success',
        builder: (_, _) => const AccountSuccessScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/kyc', builder: (_, _) => const KycFlowScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/split-runs',
        builder: (_, _) => const SplitRunsScreen(),
      ),
      GoRoute(
        path: '/wallets/:id',
        builder: (_, state) =>
            WalletDetailScreen(walletId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/beneficiaries/:id',
        builder: (_, state) => BeneficiaryDetailScreen(
            beneficiaryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/transactions',
        builder: (_, _) => const TransactionsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/wallets',
        builder: (_, _) => const WalletsScreen(),
      ),
      GoRoute(
        path: '/beneficiaries',
        builder: (_, _) => const BeneficiariesScreen(),
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (_, state) =>
            TransactionDetailScreen(transactionId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/history',
              builder: (_, _) => const TransactionsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/destination',
              builder: (_, _) => const DestinationScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/rules',
              builder: (_, _) => const SplitRulesScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

class PaySplitApp extends ConsumerWidget {
  const PaySplitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    final authStatus = ref.watch(authProvider.select((s) => s.status));

    if (authStatus == AuthStatus.unknown) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      );
    }

    return MaterialApp.router(
      title: 'PaySplit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return Column(
          children: [
            const OfflineBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (idx) => navigationShell.goBranch(
          idx,
          initialLocation: idx == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: SvgPicture.asset(
              'assets/icons/nav_home.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                  AppColors.textMuted, BlendMode.srcIn),
            ),
            selectedIcon: SvgPicture.asset(
              'assets/icons/nav_home.svg',
              width: 22,
              height: 22,
              colorFilter:
                  const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: SvgPicture.asset(
              'assets/icons/nav_split.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                  AppColors.textMuted, BlendMode.srcIn),
            ),
            selectedIcon: SvgPicture.asset(
              'assets/icons/nav_split.svg',
              width: 22,
              height: 22,
              colorFilter:
                  const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
            ),
            label: 'History',
          ),
          NavigationDestination(
            icon: SvgPicture.asset(
              'assets/icons/nav_wallet.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                  AppColors.textMuted, BlendMode.srcIn),
            ),
            selectedIcon: SvgPicture.asset(
              'assets/icons/nav_wallet.svg',
              width: 22,
              height: 22,
              colorFilter:
                  const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
            ),
            label: 'Destination',
          ),
          NavigationDestination(
            icon: SvgPicture.asset(
              'assets/icons/nav_history.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                  AppColors.textMuted, BlendMode.srcIn),
            ),
            selectedIcon: SvgPicture.asset(
              'assets/icons/nav_history.svg',
              width: 22,
              height: 22,
              colorFilter:
                  const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
            ),
            label: 'Split Rules',
          ),
        ],
      ),
    );
  }
}
