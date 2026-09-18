import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';

void main() {
  group('AppRoutes', () {
    test('exposes the dashboard as the shell entry point', () {
      expect(AppRoutes.dashboardPath, '/dashboard');
    });

    test('module paths are unique and absolute', () {
      final Set<String> paths = AppRoutes.modulePaths.toSet();
      expect(paths.length, AppRoutes.modulePaths.length);
      for (final String path in AppRoutes.modulePaths) {
        expect(path.startsWith('/'), isTrue, reason: '$path must be absolute');
      }
    });
  });

  group('NavigationRegistry', () {
    test('every module route resolves to a registry entry', () {
      for (final String path in AppRoutes.modulePaths) {
        expect(NavigationRegistry.byPath(path), isNotNull, reason: path);
      }
    });

    test('dashboard is the first sidebar destination', () {
      expect(NavigationRegistry.sidebarEntries.first.label, 'Dashboard');
    });

    test('registry entry paths are unique', () {
      final Set<String> paths = NavigationRegistry.entries
          .map((NavigationEntry e) => e.path)
          .toSet();
      expect(paths.length, NavigationRegistry.entries.length);
    });

    test('mobile primary navigation stays compact (4–5 destinations)', () {
      expect(
        NavigationRegistry.mobilePrimary(null).length,
        inExclusiveRange(3, 6),
      );
    });

    test('permissions gate visibility only after they are loaded', () {
      final NavigationEntry entry = NavigationRegistry.entries.first;
      // Permissions not loaded yet → all destinations visible.
      expect(entry.isVisibleFor(null), isTrue);
      // Loaded but empty set → nothing visible (fail closed).
      expect(entry.isVisibleFor(const <String>{}), isFalse);
      // Granted the module's view permission → visible.
      expect(entry.isVisibleFor(<String>{entry.viewPermission}), isTrue);
    });

    test('labelForPath falls back to the brand name', () {
      expect(NavigationRegistry.labelForPath('/nope'), 'MyBike');
    });
  });

  group('Breakpoints', () {
    test('classify widths at the documented boundaries', () {
      expect(Breakpoints.fromWidth(0), Breakpoint.compact);
      expect(Breakpoints.fromWidth(599), Breakpoint.compact);
      expect(Breakpoints.fromWidth(600), Breakpoint.medium);
      expect(Breakpoints.fromWidth(1023), Breakpoint.medium);
      expect(Breakpoints.fromWidth(1024), Breakpoint.expanded);
      expect(Breakpoints.fromWidth(1439), Breakpoint.expanded);
      expect(Breakpoints.fromWidth(1440), Breakpoint.large);
    });

    test('map breakpoints to the intended navigation shells', () {
      expect(Breakpoint.compact.usesBottomNavigation, isTrue);
      expect(Breakpoint.medium.usesNavigationRail, isTrue);
      expect(Breakpoint.expanded.usesSidebar, isTrue);
      expect(Breakpoint.large.usesSidebar, isTrue);
    });
  });
}
