import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/screens/foundation_screen.dart';
import 'package:mybike_showroom/common/screens/module_placeholder_screen.dart';
import 'package:mybike_showroom/core/constants/storage_keys.dart';
import 'package:mybike_showroom/core/routes/app_router.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/core/theme/theme_controller.dart';

import 'helpers/fake_preference_store.dart';

/// Pumps the Phase 1 app shell at a fixed physical size with a fresh router.
///
/// Every test builds its own router via [AppRouter.createRouter] so navigation
/// state never leaks between tests, and overrides the theme bootstrap with an
/// explicit value exactly like `main()` does.
Future<FakePreferenceStore> pumpApp(
  WidgetTester tester, {
  required Size size,
  AppThemeMode themeMode = AppThemeMode.system,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final FakePreferenceStore store = FakePreferenceStore();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Object>[
        bootstrapThemeModeProvider.overrideWithValue(themeMode),
        preferenceStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode.materialThemeMode,
        routerConfig: AppRouter.createRouter(),
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('desktop shell renders dashboard, navigates and persists theme', (
    WidgetTester tester,
  ) async {
    final FakePreferenceStore store = await pumpApp(
      tester,
      size: const Size(1280, 800),
      themeMode: AppThemeMode.system,
    );

    // Dashboard content is visible inside the desktop shell.
    expect(find.byType(FoundationScreen), findsOneWidget);
    // The sidebar shows the brand and the current theme mode.
    expect(find.text('MyBike'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    // Navigate via the sidebar tile (ListTile avoids matching the module
    // card that carries the same label).
    await tester.tap(find.widgetWithText(ListTile, 'Inventory'));
    await tester.pumpAndSettle();

    expect(find.byType(ModulePlaceholderScreen), findsOneWidget);
    expect(find.text('Planned in Phase 9'), findsOneWidget);

    // The compact theme switcher cycles system â†’ light and persists it.
    await tester.tap(find.widgetWithText(TextButton, 'System'));
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget);
    expect(store.strings[StorageKeys.themeMode], 'light');
  });

  testWidgets('mobile shell renders bottom navigation and navigates', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(390, 844));

    expect(find.byType(FoundationScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Mobile primary navigation shows exactly the flagged destinations.
    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(bar.destinations.length, 4);

    // Tap the Finance destination inside the bar (the dashboard module grid
    // also contains the same label).
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Finance'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ModulePlaceholderScreen), findsOneWidget);
    expect(find.text('Planned in Phase 13'), findsOneWidget);
  });

  testWidgets('desktop shell keeps placeholder in sync with module', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, size: const Size(1280, 800));

    // Sidebar â†’ Showrooms (Phase 7 module).
    await tester.tap(find.widgetWithText(ListTile, 'Showrooms'));
    await tester.pumpAndSettle();

    expect(find.text('Planned in Phase 7'), findsOneWidget);
  });
}
