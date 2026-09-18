import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/layouts/app_scaffold.dart';
import 'package:mybike_showroom/common/screens/foundation_screen.dart';
import 'package:mybike_showroom/common/screens/not_found_screen.dart';
import 'package:mybike_showroom/core/routes/app_router.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:mybike_showroom/core/theme/theme_controller.dart';

import 'theme_controller_test.dart' show InMemoryPreferenceStore;

/// Boots the real router with overridden providers (no Supabase needed).
Widget buildTestApp() {
  return ProviderScope(
    overrides: [
      bootstrapThemeModeProvider.overrideWithValue(AppThemeMode.light),
      preferenceStoreProvider.overrideWithValue(InMemoryPreferenceStore()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.routerConfig,
    ),
  );
}

void main() {
  testWidgets('dashboard renders brand header and module grid', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byType(FoundationScreen), findsOneWidget);
    expect(find.byType(AppScaffold), findsOneWidget);
    // Brand mark + welcome title from AppStrings.
    expect(find.text('MyBike'), findsWidgets);
    expect(find.text('Welcome to MyBike'), findsOneWidget);
  });

  testWidgets('sidebar navigation opens a module placeholder and returns', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    // Tap the Vehicles module in the sidebar.
    await tester.tap(find.text('Vehicles').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Phase 8'), findsOneWidget);
    expect(find.text('Back to dashboard'), findsOneWidget);

    await tester.tap(find.text('Back to dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MyBike'), findsOneWidget);
  });

  testWidgets('unknown route renders the 404 screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    AppRouter.routerConfig.go('/definitely-not-a-route');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsOneWidget);
    expect(find.textContaining('404'), findsOneWidget);
  });
}
