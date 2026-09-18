import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/screens/foundation_screen.dart';
import 'package:mybike_showroom/common/screens/module_placeholder_screen.dart';
import 'package:mybike_showroom/common/screens/not_found_screen.dart';
import 'package:mybike_showroom/core/constants/storage_keys.dart';
import 'package:mybike_showroom/core/routes/app_router.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:mybike_showroom/core/theme/theme_controller.dart';

import 'helpers/fake_preference_store.dart';

/// Pumps the Phase 1/2 app shell at a fixed physical size with a fresh router.
///
/// Every test builds its own router via [AppRouter.createRouter] so navigation
/// state never leaks between tests, and overrides the theme bootstrap with an
/// explicit value exactly like `main()` does.
///
/// [FoundationScreen] contains perpetual animations — the [AppShimmer] pulse
/// loop and the [AppButton] `loading: true` spinner in the design-system
/// showcase — that prevent [WidgetTester.pumpAndSettle] from ever resolving.
/// We therefore pump a fixed duration (1 s) so the router initialises and the
/// first frame renders, then proceed without waiting for animations to stop.
/// This is the standard Flutter approach for screens with infinite animations.
///
/// Post-navigation [pumpAndSettle] calls are fine because [ModulePlaceholderScreen]
/// and [NotFoundScreen] have no perpetual animations.
///
/// Returns the store and router so tests can inspect state and navigate.
Future<(FakePreferenceStore, GoRouter)> pumpApp(
  WidgetTester tester, {
  required Size size,
  AppThemeMode themeMode = AppThemeMode.system,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final FakePreferenceStore store = FakePreferenceStore();
  final GoRouter router = AppRouter.createRouter();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bootstrapThemeModeProvider.overrideWithValue(themeMode),
        preferenceStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode.materialThemeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
  // FoundationScreen has perpetual animations (shimmer pulse + loading button
  // showcase). pump(duration) advances the clock enough to build the first
  // frame without hanging on an animation that never settles.
  await tester.pump(const Duration(seconds: 1));
  return (store, router);
}

void main() {
  testWidgets('desktop shell renders dashboard, navigates and persists theme', (
    WidgetTester tester,
  ) async {
    final (FakePreferenceStore store, _) = await pumpApp(
      tester,
      size: const Size(1280, 800),
    );

    // Dashboard content is visible inside the desktop shell.
    expect(find.byType(FoundationScreen), findsOneWidget);
    // The sidebar shows the brand and the current theme mode.
    expect(find.text('MyBike'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    // Navigate via the sidebar tile (ListTile avoids matching the module
    // card that carries the same label).
    await tester.tap(find.widgetWithText(ListTile, 'Inventory'));
    // ModulePlaceholderScreen has no infinite animations — pumpAndSettle is safe.
    await tester.pumpAndSettle();

    expect(find.byType(ModulePlaceholderScreen), findsOneWidget);
    expect(find.text('Planned in Phase 9'), findsOneWidget);

    // The compact theme switcher cycles system → light and persists it.
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

    // Sidebar → Showrooms (Phase 7 module).
    await tester.tap(find.widgetWithText(ListTile, 'Showrooms'));
    await tester.pumpAndSettle();

    expect(find.text('Planned in Phase 7'), findsOneWidget);
  });

  testWidgets('unknown route renders the 404 screen', (
    WidgetTester tester,
  ) async {
    final (_, GoRouter router) = await pumpApp(
      tester,
      size: const Size(1280, 800),
    );

    router.go('/definitely-not-a-route');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsOneWidget);
    expect(find.textContaining('404'), findsOneWidget);
  });
}
