import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/core/routes/app_router.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:mybike_showroom/core/theme/theme_controller.dart';
import 'package:mybike_showroom/features/auth/data/auth_repository.dart';

import 'fake_auth_repository.dart';
import 'fake_preference_store.dart';

/// Pumps the whole app (guarded router + shell) at [size] with fakes.
///
/// The dashboard has perpetual animations (shimmer, loading button), so this
/// pumps a fixed second instead of pumpAndSettle.
Future<(FakePreferenceStore, GoRouter)> pumpMyBikeApp(
  WidgetTester tester, {
  required Size size,
  required FakeAuthRepository auth,
  FakePreferenceStore? store,
  AppThemeMode themeMode = AppThemeMode.system,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final FakePreferenceStore preferences = store ?? FakePreferenceStore();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      bootstrapThemeModeProvider.overrideWithValue(themeMode),
      preferenceStoreProvider.overrideWithValue(preferences),
      authRepositoryProvider.overrideWithValue(auth),
    ],
  );
  addTearDown(container.dispose);
  final GoRouter router = container.read(routerProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode.materialThemeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  return (preferences, router);
}
