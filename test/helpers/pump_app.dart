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
import 'package:mybike_showroom/features/inventory/data/inventory_repository.dart';
import 'package:mybike_showroom/features/roles/data/roles_repository.dart';
import 'package:mybike_showroom/features/showrooms/data/showrooms_repository.dart';
import 'package:mybike_showroom/features/users/data/users_repository.dart';
import 'package:mybike_showroom/features/vehicles/data/vehicles_repository.dart';

import 'fake_admin_repositories.dart';
import 'fake_auth_repository.dart';
import 'fake_inventory_repository.dart';
import 'fake_preference_store.dart';
import 'fake_showrooms_repository.dart';
import 'fake_vehicles_repository.dart';

/// Pumps the whole app (guarded router + shell) at [size] with fakes.
///
/// The dashboard has perpetual animations (shimmer, loading button), so this
/// pumps a fixed second instead of pumpAndSettle.
Future<(FakePreferenceStore, GoRouter)> pumpMyBikeApp(
  WidgetTester tester, {
  required Size size,
  required FakeAuthRepository auth,
  FakePreferenceStore? store,
  FakeUsersRepository? users,
  FakeRolesRepository? roles,
  FakeShowroomsRepository? showrooms,
  FakeVehiclesRepository? vehicles,
  FakeInventoryRepository? inventory,
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
      if (users != null) usersRepositoryProvider.overrideWithValue(users),
      if (roles != null) rolesRepositoryProvider.overrideWithValue(roles),
      if (showrooms != null) showroomsRepositoryProvider.overrideWithValue(showrooms),
      if (vehicles != null) vehiclesRepositoryProvider.overrideWithValue(vehicles),
      if (inventory != null) inventoryRepositoryProvider.overrideWithValue(inventory),
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
