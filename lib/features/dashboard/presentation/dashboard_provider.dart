import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dashboard_repository.dart';

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardBundle>(
  DashboardNotifier.new,
);

class DashboardNotifier extends AsyncNotifier<DashboardBundle> {
  @override
  Future<DashboardBundle> build() async {
    return ref.read(dashboardRepositoryProvider).fetchDashboard();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(dashboardRepositoryProvider).fetchDashboard(),
    );
  }
}
