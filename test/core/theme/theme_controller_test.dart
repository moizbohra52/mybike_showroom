import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/core/constants/storage_keys.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:mybike_showroom/core/theme/theme_controller.dart';

import '../../helpers/fake_preference_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ThemeController cycles and persists the mode', (
    WidgetTester tester,
  ) async {
    final FakePreferenceStore store = FakePreferenceStore();

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
    expect(store.strings[StorageKeys.themeMode], 'light');

    await capturedRef.read(themeControllerProvider.notifier).cycleMode();
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
    expect(store.strings[StorageKeys.themeMode], 'dark');
  });
}
