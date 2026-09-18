import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/layouts/app_scaffold.dart';
import 'package:mybike_showroom/common/screens/config_error_screen.dart';
import 'package:mybike_showroom/common/screens/foundation_screen.dart';
import 'package:mybike_showroom/common/screens/module_placeholder_screen.dart';
import 'package:mybike_showroom/common/screens/not_found_screen.dart';
import 'package:mybike_showroom/core/constants/module_keys.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';

/// Centralised `go_router` configuration.
///
/// A [ShellRoute] wraps every module route in [AppScaffold] so the responsive
/// navigation shell (desktop sidebar / tablet rail / mobile bottom bar) persists
/// across navigation.  Authentication guards are added in Phase 5.
abstract final class AppRouter {
  /// Builds the [GoRouter] so tests can supply an initial location.
  static GoRouter createRouter({
    String initialLocation = AppRoutes.dashboardPath,
  }) {
    return GoRouter(
      initialLocation: initialLocation,
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
            for (final NavigationEntry entry in NavigationRegistry.entries)
              if (entry.moduleKey != ModuleKeys.dashboard)
                GoRoute(
                  path: entry.path,
                  name: entry.moduleKey,
                  builder: (_, _) =>
                      ModulePlaceholderScreen(moduleKey: entry.moduleKey),
                ),
          ],
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
      // Phase 1: no auth guard.  Phase 5 injects session checks here.
      redirect: (_, _) => null,
      errorBuilder: (_, _) => const NotFoundScreen(),
    );
  }

  /// Shared instance used by [MaterialApp.router].
  static final GoRouter routerConfig = createRouter();
}
