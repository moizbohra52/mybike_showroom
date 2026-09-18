import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/widgets/app_button.dart';
import 'package:mybike_showroom/common/widgets/app_outlined_button.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';

void main() {
  Widget buildHarness({required Widget child, ThemeMode mode = ThemeMode.light}) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppButton', () {
    testWidgets('renders label and handles tap', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildHarness(
          child: AppButton(
            text: 'Submit',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.text('Submit'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows loading spinner and ignores tap while loading', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildHarness(
          child: AppButton(
            text: 'Save',
            loading: true,
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('renders icons when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: const AppButton(
            text: 'Add New',
            icon: Icons.add,
            trailingIcon: Icons.arrow_forward,
          ),
        ),
      );

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('renders correctly in dark mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          mode: ThemeMode.dark,
          child: const AppButton(
            text: 'Dark Button',
          ),
        ),
      );

      expect(find.text('Dark Button'), findsOneWidget);
    });
  });

  group('AppOutlinedButton', () {
    testWidgets('renders outlined button with label', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildHarness(
          child: AppOutlinedButton(
            text: 'Cancel',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      expect(tapped, isTrue);
    });
  });
}
