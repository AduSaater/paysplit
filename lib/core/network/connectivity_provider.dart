import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield _isConnected(initial);

  await for (final results in connectivity.onConnectivityChanged) {
    yield _isConnected(results);
  }
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).value ?? true;
});

bool _isConnected(List<ConnectivityResult> results) {
  if (results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
}
