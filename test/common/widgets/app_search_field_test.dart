import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/widgets/app_search_field.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';

void main() {
  Widget buildHarness({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppSearchField', () {
    testWidgets('triggers onChanged and clear action', (WidgetTester tester) async {
      String currentQuery = '';
      final TextEditingController controller = TextEditingController();

      await tester.pumpWidget(
        buildHarness(
          child: AppSearchField(
            controller: controller,
            hint: 'Search vehicles...',
            onChanged: (String val) => currentQuery = val,
          ),
        ),
      );

      expect(find.text('Search vehicles...'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.enterText(find.byType(TextField), 'Splendor');
      await tester.pump();

      expect(currentQuery, equals('Splendor'));
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(currentQuery, isEmpty);
    });
  });
}
