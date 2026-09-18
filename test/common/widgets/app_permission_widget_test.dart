import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/widgets/app_permission_widget.dart';
import 'package:mybike_showroom/core/constants/module_keys.dart';

void main() {
  group('AppPermissionWidget', () {
    Widget buildUnderTest({
      required String permission,
      Set<String>? permissions,
      Widget? fallback,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AppPermissionWidget(
            permission: permission,
            permissions: permissions,
            fallback: fallback,
            child: const Text('child'),
          ),
        ),
      );
    }

    testWidgets('shows child when permissions is null (permissive mode)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest(
          permission: ModuleKeys.sales,
        ),
      );
      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('shows child when permission is present in set', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest(
          permission: ModuleKeys.sales,
          permissions: const <String>{ModuleKeys.sales},
        ),
      );
      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('hides child when permission is absent — no fallback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest(
          permission: ModuleKeys.sales,
          permissions: const <String>{ModuleKeys.inventory},
        ),
      );
      // Child is gone; SizedBox.shrink renders nothing visible.
      expect(find.text('child'), findsNothing);
    });

    testWidgets('shows fallback when permission is absent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest(
          permission: ModuleKeys.sales,
          permissions: const <String>{ModuleKeys.inventory},
          fallback: const Text('no-access'),
        ),
      );
      expect(find.text('child'), findsNothing);
      expect(find.text('no-access'), findsOneWidget);
    });

    testWidgets('empty set hides child and shows fallback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest(
          permission: ModuleKeys.accounting,
          permissions: const <String>{},
          fallback: const Text('forbidden'),
        ),
      );
      expect(find.text('child'), findsNothing);
      expect(find.text('forbidden'), findsOneWidget);
    });

    testWidgets('multiple permissions — shows child when one matches', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildUnderTest(
          permission: ModuleKeys.reports,
          permissions: <String>{ModuleKeys.inventory, ModuleKeys.reports},
        ),
      );
      expect(find.text('child'), findsOneWidget);
    });
  });
}
