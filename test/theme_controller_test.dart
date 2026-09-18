import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/core/constants/storage_keys.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:mybike_showroom/core/theme/theme_controller.dart';

/// In-memory [PreferenceStore] so tests never touch real SharedPreferences.
class InMemoryPreferenceStore implements PreferenceStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> readString(String key) async => values[key];

  @override
  Future<void> writeString(String key, String value) async =>
      values[key] = value;

  @override
  Future<bool?> readBool(String key) async =>
      values.containsKey(key) ? values[key]!.toLowerCase() == 'true' : null;

  @override
  Future<void> writeBool(String key, bool value) async =>
      values[key] = value.toString();

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  group('AppThemeMode', () {
    test('storage round-trip and cycle order', () {
      expect(
        AppThemeMode.fromStorage(AppThemeMode.dark.storageValue),
        AppThemeMode.dark,
      );
      expect(AppThemeMode.fromStorage(null), AppThemeMode.system);
      expect(AppThemeMode.fromStorage('garbage'), AppThemeMode.system);
      expect(AppThemeMode.system.next, AppThemeMode.light);
      expect(AppThemeMode.light.next, AppThemeMode.dark);
      expect(AppThemeMode.dark.next, AppThemeMode.system);
    });
  });

  testWidgets('ThemeController cycles and persists', (
    WidgetTester tester,
  ) async {
    final InMemoryPreferenceStore store = InMemoryPreferenceStore();
    await store.writeString(
      StorageKeys.themeMode,
      AppThemeMode.system.storageValue,
    );

    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapThemeModeProvider.overrideWithValue(AppThemeMode.system),
          preferenceStoreProvider.overrideWithValue(store),
        ],
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, _) {
            capturedRef = ref;
            final AppThemeMode mode = ref.watch(themeControllerProvider);
            return MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode.materialThemeMode,
              home: Text(mode.label),
            );
          },
        ),
      ),
    );

    expect(find.text('System'), findsOneWidget);

    await capturedRef.read(themeControllerProvider.notifier).cycleMode();
    await tester.pumpAndSettle();
    expect(find.text('Light'), findsOneWidget);
    expect(
      await store.readString(StorageKeys.themeMode),
      AppThemeMode.light.storageValue,
    );

    await capturedRef.read(themeControllerProvider.notifier).cycleMode();
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
  });
}
