import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/common/widgets/app_data_table.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';

class TestRow {
  const TestRow(this.id, this.name, this.price);
  final String id;
  final String name;
  final String price;
}

void main() {
  Widget buildHarness({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  final List<AppDataTableColumn<TestRow>> columns = <AppDataTableColumn<TestRow>>[
    AppDataTableColumn<TestRow>(
      title: 'ID',
      width: 100,
      cellBuilder: (BuildContext ctx, TestRow item) => Text(item.id),
    ),
    AppDataTableColumn<TestRow>(
      title: 'Name',
      flex: 2,
      cellBuilder: (BuildContext ctx, TestRow item) => Text(item.name),
    ),
    AppDataTableColumn<TestRow>(
      title: 'Price',
      cellBuilder: (BuildContext ctx, TestRow item) => Text(item.price),
    ),
  ];

  group('AppDataTable', () {
    testWidgets('renders headers and items', (WidgetTester tester) async {
      TestRow? clickedRow;
      final List<TestRow> rows = <TestRow>[
        const TestRow('1', 'Pulsar 150', '₹ 1,15,000'),
        const TestRow('2', 'Ather 450X', '₹ 1,45,000'),
      ];

      await tester.pumpWidget(
        buildHarness(
          child: AppDataTable<TestRow>(
            columns: columns,
            items: rows,
            onRowTap: (TestRow row) => clickedRow = row,
          ),
        ),
      );

      expect(find.text('ID'), findsOneWidget);
      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('PRICE'), findsOneWidget);
      expect(find.text('Pulsar 150'), findsOneWidget);
      expect(find.text('Ather 450X'), findsOneWidget);

      await tester.tap(find.text('Pulsar 150'));
      expect(clickedRow?.name, equals('Pulsar 150'));
    });

    testWidgets('renders empty state when items list is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: AppDataTable<TestRow>(
            columns: columns,
            items: const <TestRow>[],
            emptyMessage: 'No vehicles found',
          ),
        ),
      );

      expect(find.text('No vehicles found'), findsOneWidget);
    });

    testWidgets('renders loading state when loading is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildHarness(
          child: AppDataTable<TestRow>(
            columns: columns,
            items: const <TestRow>[],
            loading: true,
          ),
        ),
      );

      expect(find.text('Loading data...'), findsOneWidget);
    });
  });
}
