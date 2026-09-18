import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/widgets/app_status_badge.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';

void main() {
  Widget buildHarness({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppStatusBadge', () {
    testWidgets('renders custom label and intent', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: const AppStatusBadge(
            label: 'In Stock',
            intent: AppStatusIntent.success,
          ),
        ),
      );

      expect(find.text('In Stock'), findsOneWidget);
    });

    test('intentFor resolves known domains correctly', () {
      expect(AppStatusBadge.intentFor('active'), equals(AppStatusIntent.success));
      expect(AppStatusBadge.intentFor('available'), equals(AppStatusIntent.success));
      expect(AppStatusBadge.intentFor('pending'), equals(AppStatusIntent.warning));
      expect(AppStatusBadge.intentFor('low_stock'), equals(AppStatusIntent.warning));
      expect(AppStatusBadge.intentFor('cancelled'), equals(AppStatusIntent.danger));
      expect(AppStatusBadge.intentFor('draft'), equals(AppStatusIntent.info));
      expect(AppStatusBadge.intentFor('unknown_xyz'), equals(AppStatusIntent.neutral));
    });

    testWidgets('fromKey constructor sets intent appropriately', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: AppStatusBadge.fromKey(statusKey: 'delivered'),
        ),
      );

      expect(find.text('delivered'), findsOneWidget);
    });
  });
}
