import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/app_scaffold.dart';
import 'package:mybike_showroom/common/screens/config_error_screen.dart';
import 'package:mybike_showroom/common/screens/foundation_screen.dart';
import 'package:mybike_showroom/common/screens/gallery_screen.dart';
import 'package:mybike_showroom/common/screens/module_placeholder_screen.dart';
import 'package:mybike_showroom/common/screens/not_found_screen.dart';
import 'package:mybike_showroom/core/constants/module_keys.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/presentation/access_blocked_screen.dart';
import 'package:mybike_showroom/features/auth/presentation/login_screen.dart';
import 'package:mybike_showroom/features/auth/presentation/select_showroom_screen.dart';
import 'package:mybike_showroom/features/auth/presentation/splash_screen.dart';
import 'package:mybike_showroom/features/inventory/presentation/inventory_screen.dart';
import 'package:mybike_showroom/features/roles/presentation/role_detail_screen.dart';
import 'package:mybike_showroom/features/roles/presentation/roles_screen.dart';
import 'package:mybike_showroom/features/showrooms/presentation/showroom_detail_screen.dart';
import 'package:mybike_showroom/features/showrooms/presentation/showrooms_screen.dart';
import 'package:mybike_showroom/features/users/presentation/user_detail_screen.dart';
import 'package:mybike_showroom/features/users/presentation/users_screen.dart';
import 'package:mybike_showroom/features/vehicles/presentation/vehicle_detail_screens.dart';
import 'package:mybike_showroom/features/vehicles/presentation/vehicles_screen.dart';

/// Centralised `go_router` configuration.
///
/// A [ShellRoute] wraps every module route in [AppScaffold] so the responsive
/// navigation shell persists across navigation. [guard] decides every
/// redirect from the session state; the route permissions it applies are UI
/// convenience — RLS enforces the data rules (G1).
abstract final class AppRouter {
  /// Routes reachable without a usable session.
  static const Set<String> authPaths = <String>{
    AppRoutes.splashPath,
    AppRoutes.loginPath,
    AppRoutes.accessBlockedPath,
  };

  /// Modules with real screens; the rest show [ModulePlaceholderScreen].
  static const Set<String> implementedModules = <String>{
    ModuleKeys.dashboard,
    ModuleKeys.showrooms,
    ModuleKeys.vehicles,
    ModuleKeys.inventory,
    ModuleKeys.users,
    ModuleKeys.roles,
  };

  static GoRouter createRouter({
    required GoRouterRedirect redirect,
    Listenable? refreshListenable,
    String initialLocation = AppRoutes.dashboardPath,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      refreshListenable: refreshListenable,
      redirect: redirect,
      routes: <RouteBase>[
        ShellRoute(
          builder: (BuildContext context, GoRouterState state, Widget child) {
            return AppScaffold(
              currentPath: state.matchedLocation,
              child: child,
            );
          },
          routes: <GoRoute>[
            GoRoute(
              path: AppRoutes.dashboardPath,
              name: AppRoutes.dashboardName,
              builder: (_, _) => const FoundationScreen(),
            ),
            GoRoute(
              path: AppRoutes.inventoryPath,
              name: AppRoutes.inventoryName,
              builder: (_, _) => const InventoryScreen(),
            ),
            GoRoute(
              path: AppRoutes.vehiclesPath,
              name: AppRoutes.vehiclesName,
              builder: (_, _) => const VehiclesScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: 'units/:id',
                  builder: (_, GoRouterState state) => VehicleUnitScreen(unitId: state.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'variants/:id',
                  builder: (_, GoRouterState state) => VariantDetailScreen(variantId: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.showroomsPath,
              name: AppRoutes.showroomsName,
              builder: (_, _) => const ShowroomsScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: ':id',
                  builder: (_, GoRouterState state) => ShowroomDetailScreen(showroomId: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.usersPath,
              name: AppRoutes.usersName,
              builder: (_, _) => const UsersScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: ':id',
                  builder: (_, GoRouterState state) => UserDetailScreen(profileId: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.rolesPath,
              name: AppRoutes.rolesName,
              builder: (_, _) => const RolesScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: ':id',
                  builder: (_, GoRouterState state) => RoleDetailScreen(roleId: state.pathParameters['id']!),
                ),
              ],
            ),
            for (final NavigationEntry entry in NavigationRegistry.entries)
              if (!implementedModules.contains(entry.moduleKey))
                GoRoute(
                  path: entry.path,
                  name: entry.moduleKey,
                  builder: (_, _) =>
                      ModulePlaceholderScreen(moduleKey: entry.moduleKey),
                ),
          ],
        ),
        GoRoute(path: AppRoutes.splashPath, builder: (_, _) => const SplashScreen()),
        GoRoute(path: AppRoutes.loginPath, builder: (_, _) => const LoginScreen()),
        GoRoute(path: AppRoutes.selectShowroomPath, builder: (_, _) => const SelectShowroomScreen()),
        GoRoute(path: AppRoutes.accessBlockedPath, builder: (_, _) => const AccessBlockedScreen()),
        GoRoute(
          path: AppRoutes.forbiddenPath,
          builder: (_, _) => const AccessBlockedScreen(forbidden: true),
        ),
        // Phase 2 design-system gallery — outside the shell so it fills the
        // viewport. Remove or guard before production in Phase 27.
        GoRoute(
          path: AppRoutes.galleryPath,
          name: AppRoutes.galleryName,
          builder: (_, _) => const GalleryScreen(),
        ),
        GoRoute(
          path: '/config-error',
          name: 'config_error',
          builder: (_, _) => const ConfigErrorScreen(),
        ),
        GoRoute(
          path: AppRoutes.notFoundPath,
          name: 'not_found',
          builder: (_, _) => const NotFoundScreen(),
        ),
      ],
      errorBuilder: (_, _) => const NotFoundScreen(),
    );
  }

  /// Where [location] must redirect for [session] (`null` = stay).
  static String? guard(AsyncValue<SessionState> session, String location) {
    String? goTo(String path) => location == path ? null : path;

    if (session.isLoading && !session.hasValue) {
      return goTo(AppRoutes.splashPath);
    }
    final SessionState? state = session.value;
    if (state is! SignedIn) {
      // Signed out, or the session could not be loaded (the login screen
      // offers a fresh start).
      return goTo(AppRoutes.loginPath);
    }
    if (state.blockReason != null) {
      return goTo(AppRoutes.accessBlockedPath);
    }
    if (state.needsShowroom) {
      return goTo(AppRoutes.selectShowroomPath);
    }
    if (authPaths.contains(location)) {
      return AppRoutes.dashboardPath;
    }
    final NavigationEntry? entry = NavigationRegistry.byPath(location);
    if (entry != null && !state.permissions.contains(entry.viewPermission)) {
      return AppRoutes.forbiddenPath;
    }
    return null;
  }
}

/// The app's router; re-runs [AppRouter.guard] whenever the session changes.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  ref
    ..listen<AsyncValue<SessionState>>(sessionControllerProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);
  final GoRouter router = AppRouter.createRouter(
    refreshListenable: refresh,
    redirect: (_, GoRouterState state) =>
        AppRouter.guard(ref.read(sessionControllerProvider), state.matchedLocation),
  );
  ref.onDispose(router.dispose);
  return router;
});
