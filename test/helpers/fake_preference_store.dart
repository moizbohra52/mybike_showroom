import 'package:mybike_showroom/core/storage/preference_store.dart';

/// In-memory [PreferenceStore] for tests.
///
/// Mirrors what `main()` overrides with the real device store, letting tests
/// observe exactly what the app persists (theme mode, session cache in Phase
/// 5, ...) without touching platform channels.
final class FakePreferenceStore implements PreferenceStore {
  final Map<String, String> _strings = <String, String>{};
  final Map<String, bool> _bools = <String, bool>{};

  /// Read-only view of persisted string values (test assertions).
  Map<String, String> get strings => Map<String, String>.unmodifiable(_strings);

  /// Read-only view of persisted bool values (test assertions).
  Map<String, bool> get bools => Map<String, bool>.unmodifiable(_bools);

  @override
  Future<String?> readString(String key) async => _strings[key];

  @override
  Future<void> writeString(String key, String value) async {
    _strings[key] = value;
  }

  @override
  Future<bool?> readBool(String key) async => _bools[key];

  @override
  Future<void> writeBool(String key, bool value) async {
    _bools[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _strings.remove(key);
    _bools.remove(key);
  }
}
