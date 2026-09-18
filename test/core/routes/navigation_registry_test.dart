import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/core/constants/module_keys.dart';
import 'package:mybike_showroom/core/routes/navigation_registry.dart';

void main() {
  group('NavigationRegistry integrity', () {
    test('has a meaningful module list', () {
      expect(NavigationRegistry.entries, isNotEmpty);
      expect(NavigationRegistry.entries.length, greaterThan(10));
    });

    test('module keys and paths are unique', () {
      final Set<String> keys = NavigationRegistry.entries
          .map((NavigationEntry e) => e.moduleKey)
          .toSet();
      final Set<String> paths = NavigationRegistry.entries
          .map((NavigationEntry e) => e.path)
          .toSet();

      expect(keys.length, NavigationRegistry.entries.length);
      expect(paths.length, NavigationRegistry.entries.length);
    });

    test('every entry is fully specified', () {
      for (final NavigationEntry entry in NavigationRegistry.entries) {
        expect(entry.label, isNotEmpty, reason: entry.moduleKey);
        expect(entry.path, startsWith('/'), reason: entry.moduleKey);
        expect(entry.plannedPhase, isNotNull, reason: entry.moduleKey);
        expect(
          entry.viewPermission,
          endsWith('.view'),
          reason: entry.moduleKey,
        );
      }
    });

    test('entries are sorted by sortOrder', () {
      final List<int> orders = NavigationRegistry.entries
          .map((NavigationEntry e) => e.sortOrder)
          .toList();
      final List<int> sorted = List<int>.of(orders)..sort();
      expect(orders, sorted);
    });

    test('dashboard is the first entry and a mobile primary tab', () {
      final NavigationEntry first = NavigationRegistry.entries.first;
      expect(first.moduleKey, ModuleKeys.dashboard);
      expect(first.inMobilePrimary, isTrue);
    });

    test('mobile primary set matches the flagged entries', () {
      final Set<String> primaryKeys = NavigationRegistry.mobilePrimary(
        null,
      ).map((NavigationEntry e) => e.moduleKey).toSet();
      final Set<String> flagged = NavigationRegistry.entries
          .where((NavigationEntry e) => e.inMobilePrimary)
          .map((NavigationEntry e) => e.moduleKey)
          .toSet();

      expect(primaryKeys, flagged);
      expect(primaryKeys.length, lessThanOrEqualTo(5));
      expect(primaryKeys, contains(ModuleKeys.dashboard));
    });
  });

  group('NavigationRegistry permissions', () {
    test('null permission set shows everything (Phase 1 behaviour)', () {
      expect(
        NavigationRegistry.visibleFor(null).length,
        NavigationRegistry.entries.length,
      );
    });

    test('empty permission set hides everything', () {
      expect(NavigationRegistry.visibleFor(const <String>[]), isEmpty);
      expect(NavigationRegistry.mobilePrimary(const <String>[]), isEmpty);
    });

    test('a single grant shows only the matching module', () {
      final List<NavigationEntry> visible = NavigationRegistry.visibleFor(
        const <String>['sales.view'],
      );

      expect(visible.length, 1);
      expect(visible.first.moduleKey, ModuleKeys.sales);
    });

    test('secondary excludes mobile primary entries', () {
      final Set<String> secondaryKeys = NavigationRegistry.secondary(
        null,
      ).map((NavigationEntry e) => e.moduleKey).toSet();
      final Set<String> primaryKeys = NavigationRegistry.mobilePrimary(
        null,
      ).map((NavigationEntry e) => e.moduleKey).toSet();

      expect(secondaryKeys.intersection(primaryKeys), isEmpty);
      expect(
        secondaryKeys.length + primaryKeys.length,
        NavigationRegistry.entries.length,
      );
    });
  });

  group('NavigationRegistry lookups', () {
    test('byPath resolves registered paths', () {
      final NavigationEntry? entry = NavigationRegistry.byPath(
        NavigationRegistry.entries.first.path,
      );
      expect(entry, isNotNull);
      expect(entry!.moduleKey, ModuleKeys.dashboard);
    });

    test('byPath returns null for unknown paths', () {
      expect(NavigationRegistry.byPath('/does-not-exist'), isNull);
    });

    test('labelForPath falls back to the app name', () {
      expect(NavigationRegistry.labelForPath('/does-not-exist'), 'MyBike');
      expect(
        NavigationRegistry.labelForPath(NavigationRegistry.entries.first.path),
        'Dashboard',
      );
    });
  });
}
