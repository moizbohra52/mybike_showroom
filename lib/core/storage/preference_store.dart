import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin, testable abstraction over device-local preferences.
///
/// Feature code depends on this interface, never on `SharedPreferences`
/// directly, so tests can inject an in-memory implementation and the storage
/// backend can change without touching features.
abstract interface class PreferenceStore {
  Future<String?> readString(String key);

  Future<void> writeString(String key, String value);

  Future<bool?> readBool(String key);

  Future<void> writeBool(String key, bool value);

  Future<void> remove(String key);
}

/// Production implementation backed by the platform preference store.
///
/// Uses the modern `SharedPreferencesAsync` API (no hidden in-memory cache), so
/// values written by other isolates/engines are always observed.
final class SharedPreferencesStore implements PreferenceStore {
  SharedPreferencesStore(this._preferences);

  final SharedPreferencesAsync _preferences;

  /// Creates a store bound to the platform implementation.
  static Future<SharedPreferencesStore> create() async {
    final SharedPreferencesAsync preferences = SharedPreferencesAsync();
    // Touch the store once so the platform channel is ready before first paint.
    await preferences.getKeys();
    return SharedPreferencesStore(preferences);
  }

  @override
  Future<String?> readString(String key) => _preferences.getString(key);

  @override
  Future<void> writeString(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<bool?> readBool(String key) => _preferences.getBool(key);

  @override
  Future<void> writeBool(String key, bool value) =>
      _preferences.setBool(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}

/// Provides the active [PreferenceStore].
///
/// Overridden in `main()` with the bootstrapped instance and in tests with an
/// in-memory store; the default throws so a missing override fails loudly
/// instead of silently losing user preferences.
final Provider<PreferenceStore> preferenceStoreProvider =
    Provider<PreferenceStore>((Ref ref) {
      throw StateError(
        'preferenceStoreProvider must be overridden in ProviderScope '
        '(see lib/main.dart) before it is read.',
      );
    });
