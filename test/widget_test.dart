import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/screens/foundation_screen.dart';
import 'package:mybike_showroom/common/screens/module_placeholder_screen.dart';
import 'package:mybike_showroom/common/screens/not_found_screen.dart';
import 'package:mybike_showroom/core/constants/storage_keys.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/fake_preference_store.dart';
import 'helpers/pump_app.dart';

/// Pumps the app shell signed in as a single-showroom user holding every
/// permission, so these tests exercise layout and navigation (the auth
/// flows live in test/features/auth/).
Future<(FakePreferenceStore, GoRouter)> pumpApp(
  WidgetTester tester, {
  required Size size,
  AppThemeMode themeMode = AppThemeMode.system,
}) {
  return pumpMyBikeApp(
    tester,
    size: size,
    themeMode: themeMode,
    auth: FakeAuthRepository(session: testSession(), signedIn: true),
  );
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
