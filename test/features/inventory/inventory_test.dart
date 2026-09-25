import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/inventory/domain/stock.dart';
import 'package:mybike_showroom/features/vehicles/domain/vehicle_master.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_inventory_repository.dart';
import '../../helpers/fake_vehicles_repository.dart';
import '../../helpers/pump_app.dart';

const Set<String> managerPermissions = <String>{
  'dashboard.view', 'vehicles.view', 'inventory.view', 'inventory.create', 'inventory.edit',
};
const Set<String> viewOnlyPermissions = <String>{'dashboard.view', 'vehicles.view', 'inventory.view'};

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 100));
}

const VehicleUnit purchasedUnit = VehicleUnit(
  id: 'u-purchased',
  showroomId: 's-ind',
  variantId: 'v-activa',
  chassisNumber: 'ME4JF508ARJ000999',
  variantLabel: 'Honda Activa 6G STD',
);
const VehicleUnit inStockUnit = VehicleUnit(
  id: 'u-instock',
  showroomId: 's-ind',
  variantId: 'v-activa',
  chassisNumber: 'ME4JF508ARJ000888',
  status: 'in_stock',
  variantLabel: 'Honda Activa 6G STD',
);
const VehicleUnit reservedUnit = VehicleUnit(
  id: 'u-reserved',
  showroomId: 's-ind',
  variantId: 'v-activa',
  chassisNumber: 'ME4JF508ARJ000777',
  status: 'reserved',
  variantLabel: 'Honda Activa 6G STD',
);

Future<GoRouter> openVehicleDetail(
  WidgetTester tester,
  VehicleUnit unit,
  Set<String> permissions, {
  FakeInventoryRepository? inventory,
}) async {
  final UserSession session = testSession(
    showrooms: <SessionShowroom>[testShowroom('s-ind', 'Indore Main', permissions: permissions)],
  );
  final (_, GoRouter router) = await pumpMyBikeApp(
    tester,
    size: const Size(1280, 2400),
    auth: FakeAuthRepository(session: session, signedIn: true),
    vehicles: FakeVehiclesRepository(units: <VehicleUnit>[unit]),
    inventory: inventory ?? FakeInventoryRepository(),
  );
  router.go(AppRoutes.vehicleUnitPath(unit.id!));
  await settle(tester);
  return router;
}

void main() {
  group('vehicle detail: stock actions follow status and permission', () {
    testWidgets('purchased + inventory.create shows Receive stock', (WidgetTester tester) async {
      await openVehicleDetail(tester, purchasedUnit, managerPermissions);
      expect(find.widgetWithText(AppButton, 'Receive stock'), findsOneWidget);
      expect(find.text('Reserve'), findsNothing);
    });

    testWidgets('purchased + view only shows no actions', (WidgetTester tester) async {
      await openVehicleDetail(tester, purchasedUnit, viewOnlyPermissions);
      expect(find.widgetWithText(AppButton, 'Receive stock'), findsNothing);
    });

    testWidgets('in_stock + inventory.edit shows Reserve and Mark damaged', (WidgetTester tester) async {
      await openVehicleDetail(tester, inStockUnit, managerPermissions);
      expect(find.widgetWithText(AppOutlinedButton, 'Reserve'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Mark damaged'), findsOneWidget);
      expect(find.text('Receive stock'), findsNothing);
    });

    testWidgets('reserved shows Release reservation and the reservation banner', (WidgetTester tester) async {
      final FakeInventoryRepository inventory = FakeInventoryRepository(
        reservation: ActiveReservation(reservedAt: DateTime(2026, 9), reservedByName: 'Imran Khan'),
      );
      await openVehicleDetail(tester, reservedUnit, managerPermissions, inventory: inventory);
      expect(find.widgetWithText(AppOutlinedButton, 'Release reservation'), findsOneWidget);
      expect(find.textContaining('Reserved by Imran Khan'), findsOneWidget);
    });
  });

  group('vehicle detail: stock action flows call the repository', () {
    testWidgets('receive stock sends the unit cost', (WidgetTester tester) async {
      final FakeInventoryRepository inventory = FakeInventoryRepository();
      await openVehicleDetail(tester, purchasedUnit, managerPermissions, inventory: inventory);

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Receive stock'));
      await settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Receive stock'));
      await settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Receive'));
      await settle(tester);
      expect(find.text('Unit cost is required.'), findsOneWidget);

      final Finder field = find.descendant(of: find.byType(Dialog), matching: find.byType(TextFormField)).first;
      await tester.enterText(field, '68000');
      await tester.tap(find.widgetWithText(AppButton, 'Receive'));
      await settle(tester);

      expect(inventory.calls, <String>['receiveVehicle u-purchased 68000']);
    });

    testWidgets('mark damaged requires a reason', (WidgetTester tester) async {
      final FakeInventoryRepository inventory = FakeInventoryRepository();
      await openVehicleDetail(tester, inStockUnit, managerPermissions, inventory: inventory);

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Mark damaged'));
      await settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Mark damaged'));
      await settle(tester);
      await tester.tap(find.widgetWithText(AppButton, 'Mark damaged').last);
      await settle(tester);
      expect(find.text('Reason is required.'), findsOneWidget);

      final Finder field = find.descendant(of: find.byType(Dialog), matching: find.byType(TextFormField)).first;
      await tester.enterText(field, 'Showroom fire');
      await tester.tap(find.widgetWithText(AppButton, 'Mark damaged').last);
      await settle(tester);

      expect(inventory.calls, <String>['markDamaged u-instock Showroom fire']);
    });

    testWidgets('status and movement history render', (WidgetTester tester) async {
      final FakeInventoryRepository inventory = FakeInventoryRepository(
        history: <StatusChange>[
          StatusChange(fromStatus: 'purchased', toStatus: 'in_stock', changedAt: DateTime(2026, 9), reason: 'Stock received'),
        ],
      );
      await openVehicleDetail(tester, inStockUnit, managerPermissions, inventory: inventory);
      expect(find.textContaining('Awaiting receipt → In stock'), findsOneWidget);
      expect(find.textContaining('Stock received'), findsOneWidget);
    });
  });

  group('Inventory screen', () {
    Future<GoRouter> openInventory(WidgetTester tester, Set<String> permissions, {FakeInventoryRepository? inventory}) async {
      final UserSession session = testSession(
        showrooms: <SessionShowroom>[testShowroom('s-ind', 'Indore Main', permissions: permissions)],
      );
      final (_, GoRouter router) = await pumpMyBikeApp(
        tester,
        size: const Size(1280, 2400),
        auth: FakeAuthRepository(session: session, signedIn: true),
        inventory: inventory ?? FakeInventoryRepository(),
      );
      router.go(AppRoutes.inventoryPath);
      await settle(tester);
      return router;
    }

    testWidgets('overview tab shows the stock summary and ageing', (WidgetTester tester) async {
      final FakeInventoryRepository inventory = FakeInventoryRepository(
        ageingRows: const <AgeingRow>[
          AgeingRow(vehicleId: 'u1', chassisNumber: 'ABC123', daysInStock: 95, ageingBucket: '90+', variantLabel: 'Honda Activa'),
        ],
      );
      await openInventory(tester, managerPermissions, inventory: inventory);
      expect(find.text('INDORE-MAIN'), findsOneWidget);
      expect(find.text('₹ 204000.00'), findsOneWidget);
      expect(find.text('Available: 3'), findsOneWidget);
      expect(find.text('Reserved: 1'), findsOneWidget);
      expect(find.text('Honda Activa'), findsOneWidget);
      expect(find.text('90+'), findsOneWidget);
    });

    testWidgets('transfers tab: New transfer needs inventory.create', (WidgetTester tester) async {
      await openInventory(tester, managerPermissions);
      await tester.tap(find.widgetWithText(Tab, 'Transfers'));
      await settle(tester);
      expect(find.widgetWithText(AppButton, 'New transfer'), findsOneWidget);
    });

    testWidgets('transfers tab: without inventory.create there is no New transfer', (WidgetTester tester) async {
      await openInventory(tester, viewOnlyPermissions);
      await tester.tap(find.widgetWithText(Tab, 'Transfers'));
      await settle(tester);
      expect(find.widgetWithText(AppButton, 'New transfer'), findsNothing);
    });

    testWidgets('transfers tab: an in-transit transfer offers Receive at the destination', (WidgetTester tester) async {
      const StockTransfer transfer = StockTransfer(
        id: 't1',
        transferNo: 'IND/26-27/00001',
        sourceShowroomId: 's-bpl',
        destinationShowroomId: 's-ind',
        sourceShowroomName: 'Bhopal',
        destinationShowroomName: 'Indore Main',
        transferDate: '2026-09-24',
        status: 'in_transit',
        items: <TransferLine>[TransferLine(vehicleId: 'u1', chassisNumber: 'ABC123', variantLabel: 'Honda Activa')],
      );
      final FakeInventoryRepository inventory = FakeInventoryRepository(transferList: const <StockTransfer>[transfer]);
      await openInventory(tester, managerPermissions, inventory: inventory);
      await tester.tap(find.widgetWithText(Tab, 'Transfers'));
      await settle(tester);

      expect(find.textContaining('IND/26-27/00001'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Receive'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Receive'));
      await settle(tester);
      expect(inventory.calls, <String>['receiveTransfer t1']);
    });

    testWidgets('adjustments tab: New adjustment needs inventory.create', (WidgetTester tester) async {
      await openInventory(tester, managerPermissions);
      await tester.tap(find.widgetWithText(Tab, 'Adjustments'));
      await settle(tester);
      expect(find.widgetWithText(AppButton, 'New adjustment'), findsOneWidget);
    });
  });

  test('MB040 passes the database''s own (already user-safe) message through', () {
    final AppFailure failure = ErrorMapper.map(const PostgrestException(
      message: 'This vehicle is not available to transfer.',
      code: 'MB040',
    ));
    expect(failure, isA<BusinessRuleFailure>());
    expect(failure.message, 'This vehicle is not available to transfer.');
  });

  test('single-meaning MB codes use their static message', () {
    expect(ErrorMapper.map(const PostgrestException(message: 'x', code: 'MB041')).message,
        'This vehicle has no active reservation.');
    expect(ErrorMapper.map(const PostgrestException(message: 'x', code: 'MB045')).message,
        'This transfer is not awaiting receipt.');
  });
}
