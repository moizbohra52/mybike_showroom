import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/widgets/app_empty_state.dart';
import 'package:mybike_showroom/common/widgets/app_error_state.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';

void main() {
  Widget buildHarness({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppEmptyState', () {
    testWidgets('renders title, message, and action CTA', (WidgetTester tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        buildHarness(
          child: AppEmptyState(
            title: 'No Customers Found',
            message: 'Create a new customer profile to get started.',
            actionText: 'Add Customer',
            onAction: () => actionTriggered = true,
          ),
        ),
      );

      expect(find.text('No Customers Found'), findsOneWidget);
      expect(find.text('Create a new customer profile to get started.'), findsOneWidget);
      expect(find.text('Add Customer'), findsOneWidget);

      await tester.tap(find.text('Add Customer'));
      expect(actionTriggered, isTrue);
    });
  });

  group('AppErrorState', () {
    testWidgets('renders error title and triggers retry', (WidgetTester tester) async {
      bool retried = false;

      await tester.pumpWidget(
        buildHarness(
          child: AppErrorState(
            title: 'Failed to load stock',
            message: 'Network timeout while fetching inventory records.',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Failed to load stock'), findsOneWidget);
      expect(find.text('Network timeout while fetching inventory records.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });
}
