import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/widgets/app_card.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';

void main() {
  Widget buildHarness({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppCard', () {
    testWidgets('renders child content and executes onTap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildHarness(
          child: AppCard(
            onTap: () => tapped = true,
            child: const Text('Card Content'),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      expect(tapped, isTrue);
    });

    testWidgets('renders highlighted styling without throwing', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: const AppCard(
            highlighted: true,
            child: Text('Highlighted Card'),
          ),
        ),
      );

      expect(find.text('Highlighted Card'), findsOneWidget);
    });
  });
}
