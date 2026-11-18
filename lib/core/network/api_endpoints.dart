class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl =
      'https://paysplit-be-dev-14573850302.europe-west1.run.app/api/v1';

  // Health
  static const String health = '/health';

  // Auth
  static const String signup = '/auth/signup';
  static const String verifyEmail = '/auth/email/verify';
  static const String resendEmail = '/auth/email/resend';
  static const String setPassword = '/auth/password/set';
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String changePassword = '/auth/password/change';
  static const String forgotPassword = '/auth/password/forgot';
  static const String verifyResetCode = '/auth/password/verify-code';
  static const String resetPassword = '/auth/password/reset';

  // KYC
  static const String kycCountries = '/kyc/countries';
  static const String kycStatus = '/kyc/status';
  static const String kycProfile = '/kyc/profile';
  static const String kycIdentityNigeria = '/kyc/identity/nigeria';
  static const String kycIdentityInternational = '/kyc/identity/international';
  static const String kycLiveness = '/kyc/liveness';

  // Salary Account
  static const String salaryAccount = '/salary-account';
  static const String salaryAccountIdentity = '/salary-account/identity';
  static const String simulateCredit = '/salary-account/simulate-credit';

  // Setup & Categories
  static const String setupIncome = '/setup/income';
  static const String setupProgress = '/setup/progress';
  static const String categories = '/categories';

  // Dashboard
  static const String dashboardSummary = '/dashboard/summary';
  static const String dashboardCashFlow = '/dashboard/cash-flow';

  // Wallets
  static const String wallets = '/wallets';
  static const String walletAccentColors = '/wallets/accent-colors';
  static const String walletActivity = '/wallets/activity';
  static String walletById(String id) => '/wallets/$id';
  static String walletTransactions(String id) => '/wallets/$id/transactions';
  static String walletMove(String id) => '/wallets/$id/move';

  // Beneficiaries & Banks
  static const String banks = '/banks';
  static const String resolveBeneficiary = '/beneficiaries/resolve';
  static const String beneficiaries = '/beneficiaries';
  static String beneficiaryById(String id) => '/beneficiaries/$id';
  static String beneficiaryTransactions(String id) =>
      '/beneficiaries/$id/transactions';

  // Split Rules & Runs
  static const String splitRules = '/split-rules';
  static const String splitRulesSummary = '/split-rules/summary';
  static String splitRuleById(String id) => '/split-rules/$id';
  static const String splitRuns = '/split-runs';
  static String splitRunById(String id) => '/split-runs/$id';

  // Transactions
  static const String transactions = '/transactions';
  static const String transactionsExport = '/transactions/export';
  static String transactionById(String id) => '/transactions/$id';

  // Notifications
  static const String notifications = '/notifications';
  static String markNotificationRead(String id) => '/notifications/$id/read';
  static const String markAllNotificationsRead = '/notifications/read-all';

  // User Profile & Settings
  static const String userProfile = '/users/me/profile';
  static const String updateUser = '/users/me';
  static const String notificationPreferences =
      '/users/me/notification-preferences';
  static const String profileImage = '/users/me/profile-image';
}
