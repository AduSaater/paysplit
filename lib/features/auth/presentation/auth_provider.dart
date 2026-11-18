import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.onboarding,
    this.isLoading = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? onboarding;
  final bool isLoading;
  final String? errorMessage;

  String get fullName {
    final first = user?['firstName']?.toString() ?? '';
    final last = user?['lastName']?.toString() ?? '';
    final combined = '$first $last'.trim();
    return combined.isEmpty ? 'PaySplit User' : combined;
  }

  String get email => user?['email']?.toString() ?? '';

  String get kycStatus =>
      (user?['kycStatus'] ?? onboarding?['kycStatus'] ?? 'not_started')
          .toString();

  bool get isKycApproved =>
      kycStatus.toLowerCase() == 'approved' ||
      kycStatus.toLowerCase() == 'verified';

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    Map<String, dynamic>? onboarding,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      onboarding: onboarding ?? this.onboarding,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(restoreSession);
    return const AuthState(status: AuthStatus.unknown);
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> restoreSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final hasToken = await _repo.hasToken();
    if (!hasToken) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final me = await _repo.getMe();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: (me['user'] as Map<String, dynamic>?) ?? me,
        onboarding: me['onboarding'] as Map<String, dynamic>?,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _repo.logout();
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _repo.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: (data['user'] as Map<String, dynamic>?) ?? data,
        onboarding: data['onboarding'] as Map<String, dynamic>?,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.code == 'ACCOUNT_SETUP_INCOMPLETE'
            ? 'ACCOUNT_SETUP_INCOMPLETE'
            : e.message,
      );
      return false;
    }
  }

  Future<void> completeAuthFromSetPassword(Map<String, dynamic> data) async {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: (data['user'] as Map<String, dynamic>?) ?? data,
      onboarding: data['onboarding'] as Map<String, dynamic>?,
    );
  }

  Future<void> refreshMe() async {
    try {
      final me = await _repo.getMe();
      state = state.copyWith(
        user: (me['user'] as Map<String, dynamic>?) ?? me,
        onboarding: me['onboarding'] as Map<String, dynamic>?,
      );
    } catch (_) {}
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
