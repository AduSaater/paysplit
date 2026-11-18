import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});

final localCacheProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService(ref.watch(sharedPreferencesProvider));
});

/// Lightweight JSON cache for offline resilience and fast cold starts.
/// Sensitive tokens NEVER go here — they live in [SecureStorageService].
class LocalCacheService {
  LocalCacheService(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'ps_cache_';
  static const _tsPrefix = 'ps_cache_ts_';

  Future<void> setJson(String key, dynamic data) async {
    await _prefs.setString('$_prefix$key', jsonEncode(data));
    await _prefs.setInt('$_tsPrefix$key', DateTime.now().millisecondsSinceEpoch);
  }

  T? getJson<T>(String key, {Duration? maxAge}) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;

    if (maxAge != null) {
      final ts = _prefs.getInt('$_tsPrefix$key');
      if (ts != null) {
        final age = DateTime.now().millisecondsSinceEpoch - ts;
        if (age > maxAge.inMilliseconds) return null;
      }
    }

    try {
      return jsonDecode(raw) as T;
    } catch (_) {
      return null;
    }
  }

  DateTime? getTimestamp(String key) {
    final ts = _prefs.getInt('$_tsPrefix$key');
    if (ts == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ts);
  }

  Future<void> remove(String key) async {
    await _prefs.remove('$_prefix$key');
    await _prefs.remove('$_tsPrefix$key');
  }

  Future<void> clearAll() async {
    final keys = _prefs.getKeys().where(
          (k) => k.startsWith(_prefix) || k.startsWith(_tsPrefix),
        );
    for (final k in keys.toList()) {
      await _prefs.remove(k);
    }
  }
}
