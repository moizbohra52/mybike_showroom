import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/widgets/app_button.dart';
import 'package:mybike_showroom/common/widgets/app_confirm_dialog.dart';
import 'package:mybike_showroom/common/widgets/app_dialog.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';

void main() {
  Widget buildHarness({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppDialog', () {
    testWidgets('renders title, content and actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: const AppDialog(
            title: 'Test Dialog',
            content: Text('Dialog body content'),
            actions: <Widget>[
              AppButton(text: 'OK'),
            ],
          ),
        ),
      );

      expect(find.text('Test Dialog'), findsOneWidget);
      expect(find.text('Dialog body content'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('AppConfirmDialog show returns true when confirmed', (WidgetTester tester) async {
      bool? result;

      await tester.pumpWidget(
        buildHarness(
          child: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await AppConfirmDialog.show(
                    context: context,
                    title: 'Delete Vehicle',
                    message: 'Are you sure you want to delete?',
                    confirmLabel: 'Yes, Delete',
                    isDestructive: true,
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Vehicle'), findsOneWidget);
      expect(find.text('Are you sure you want to delete?'), findsOneWidget);
      expect(find.text('Yes, Delete'), findsOneWidget);

      await tester.tap(find.text('Yes, Delete'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
