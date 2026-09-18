import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';

void main() {
  group('Breakpoints.fromWidth', () {
    test('classifies widths at the documented boundaries', () {
      expect(Breakpoints.fromWidth(0), Breakpoint.compact);
      expect(Breakpoints.fromWidth(599), Breakpoint.compact);
      expect(Breakpoints.fromWidth(600), Breakpoint.medium);
      expect(Breakpoints.fromWidth(1023), Breakpoint.medium);
      expect(Breakpoints.fromWidth(1024), Breakpoint.expanded);
      expect(Breakpoints.fromWidth(1439), Breakpoint.expanded);
      expect(Breakpoints.fromWidth(1440), Breakpoint.large);
    });
  });

  group('Breakpoint shell mapping', () {
    test('compact uses bottom navigation only', () {
      expect(Breakpoint.compact.usesBottomNavigation, isTrue);
      expect(Breakpoint.compact.usesSidebar, isFalse);
      expect(Breakpoint.compact.usesNavigationRail, isFalse);
    });

    test('medium uses the navigation rail only', () {
      expect(Breakpoint.medium.usesNavigationRail, isTrue);
      expect(Breakpoint.medium.usesSidebar, isFalse);
      expect(Breakpoint.medium.usesBottomNavigation, isFalse);
    });

    test('expanded and large use the sidebar', () {
      expect(Breakpoint.expanded.usesSidebar, isTrue);
      expect(Breakpoint.large.usesSidebar, isTrue);
      expect(Breakpoint.expanded.usesNavigationRail, isFalse);
      expect(Breakpoint.large.usesBottomNavigation, isFalse);
    });
  });
}
