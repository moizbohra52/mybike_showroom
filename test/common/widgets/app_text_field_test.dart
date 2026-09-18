import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/widgets/app_text_field.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';

void main() {
  Widget buildHarness({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppTextField', () {
    testWidgets('renders label, hint and enters text', (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();

      await tester.pumpWidget(
        buildHarness(
          child: AppTextField(
            controller: controller,
            label: 'Customer Name',
            hint: 'Enter full name',
            prefixIcon: Icons.person,
          ),
        ),
      );

      expect(find.text('Customer Name'), findsOneWidget);
      expect(find.text('Enter full name'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Rajesh Sharma');
      expect(controller.text, equals('Rajesh Sharma'));
    });

    testWidgets('toggles obscureText on visibility icon click', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: const AppTextField(
            label: 'Password',
            obscureText: true,
          ),
        ),
      );

      // Initially visibility_outlined icon is shown
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Tap icon to toggle
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      // Now visibility_off_outlined icon is shown
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('displays error text', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: const AppTextField(
            label: 'Mobile',
            errorText: 'Invalid phone number',
          ),
        ),
      );

      expect(find.text('Invalid phone number'), findsOneWidget);
    });
  });
}
