import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/widgets/app_stat_card.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';

void main() {
  Widget buildHarness({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppStatCard', () {
    testWidgets('renders label, value, icon, and positive delta chip', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildHarness(
          child: AppStatCard(
            label: 'Total Sales',
            value: '₹ 45,20,000',
            icon: Icons.payments_outlined,
            deltaText: '+12.5%',
            deltaPositive: true,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('TOTAL SALES'), findsOneWidget);
      expect(find.text('₹ 45,20,000'), findsOneWidget);
      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
      expect(find.text('+12.5%'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);

      await tester.tap(find.text('₹ 45,20,000'));
      expect(tapped, isTrue);
    });

    testWidgets('renders negative delta chip with trending_down icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: const AppStatCard(
            label: 'Expenses',
            value: '₹ 3,40,000',
            deltaText: '-4.2%',
            deltaPositive: false,
          ),
        ),
      );

      expect(find.text('-4.2%'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down), findsOneWidget);
    });
  });
}
