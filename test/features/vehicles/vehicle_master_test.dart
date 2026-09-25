import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/widgets/widgets.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:mybike_showroom/core/routes/app_routes.dart';
import 'package:mybike_showroom/core/validators/validators.dart';
import 'package:mybike_showroom/features/auth/application/session_controller.dart';
import 'package:mybike_showroom/features/auth/domain/user_session.dart';
import 'package:mybike_showroom/features/vehicles/domain/vehicle_master.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/fake_vehicles_repository.dart';
import '../../helpers/pump_app.dart';

const Set<String> managerPermissions = <String>{'dashboard.view', 'vehicles.view', 'vehicles.create', 'vehicles.edit'};
const Set<String> cashierPermissions = <String>{'dashboard.view', 'vehicles.view'};

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<GoRouter> openVehicles(
  WidgetTester tester,
  Set<String> permissions, {
  FakeVehiclesRepository? vehicles,
  String path = AppRoutes.vehiclesPath,
  bool allShowrooms = false,
}) async {
  final UserSession session = testSession(
    showrooms: <SessionShowroom>[testShowroom('s-ind', 'Indore Main', permissions: permissions)],
    globalPermissions: allShowrooms ? <String>{UserSession.viewAllPermission, ...permissions} : const <String>{},
  );
  final (_, GoRouter router) = await pumpMyBikeApp(
    tester,
    size: const Size(1280, 900),
    auth: FakeAuthRepository(session: session, signedIn: true),
    vehicles: vehicles ?? FakeVehiclesRepository(),
  );
  router.go(path);
  await settle(tester);
  return router;
}

Finder dialogFields() => find.descendant(of: find.byType(Dialog), matching: find.byType(TextFormField));

Future<void> pickFromDropdown(WidgetTester tester, Finder dropdown, String item) async {
  await tester.ensureVisible(dropdown);
  await settle(tester);
  await tester.tap(dropdown);
  await settle(tester);
  await tester.tap(find.text(item).last);
  await settle(tester);
}

void main() {
  testWidgets('register: the showroom register lists units; staff with vehicles.create may register', (WidgetTester tester) async {
    final FakeVehiclesRepository vehicles = FakeVehiclesRepository();
    await openVehicles(tester, managerPermissions, vehicles: vehicles);

    expect(find.text('TVS Motor iQube 2.2 kWh'), findsOneWidget);
    expect(find.text('Awaiting receipt'), findsOneWidget);
    expect(vehicles.queries.first.showroomId, 's-ind');
    expect(find.widgetWithText(AppButton, 'Register vehicle'), findsOneWidget);
  });

  testWidgets('register: view-only staff (cashier) cannot register or edit', (WidgetTester tester) async {
    await openVehicles(tester, cashierPermissions);
    expect(find.widgetWithText(AppButton, 'Register vehicle'), findsNothing);

    await tester.tap(find.text('TVS Motor iQube 2.2 kWh'));
    await settle(tester);
    expect(find.text('IQB22K0100201'), findsOneWidget, reason: 'EV units show their battery number');
    expect(find.text('At delivery'), findsOneWidget, reason: 'warranty of a new unit starts at delivery');
    expect(find.widgetWithText(AppOutlinedButton, 'Edit'), findsNothing);
  });

  testWidgets('register: ALL SHOWROOMS shows every showroom''s units and hides Register vehicle', (WidgetTester tester) async {
    final FakeVehiclesRepository vehicles = FakeVehiclesRepository();
    await openVehicles(tester, managerPermissions, vehicles: vehicles, allShowrooms: true);

    final ProviderContainer container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await container.read(sessionControllerProvider.notifier).selectShowroom(const ShowroomSelection.all());
    await settle(tester);

    expect(vehicles.queries.last.showroomId, isNull);
    expect(find.widgetWithText(AppButton, 'Register vehicle'), findsNothing);
  });

  testWidgets('register: the identifiers asked for follow the fuel type; duplicates are named per field', (WidgetTester tester) async {
    final FakeVehiclesRepository vehicles = FakeVehiclesRepository(conflicts: <String>{'chassis_number'});
    await openVehicles(tester, managerPermissions, vehicles: vehicles);

    await tester.tap(find.widgetWithText(AppButton, 'Register vehicle'));
    await settle(tester);
    await pickFromDropdown(tester, find.byType(DropdownButtonFormField<String>).first, 'TVS Motor iQube 2.2 kWh · Electric');
    expect(find.text('Motor number'), findsOneWidget);
    expect(find.text('Battery number'), findsOneWidget);
    expect(find.text('Engine number'), findsNothing);

    await tester.enterText(dialogFields().at(1), 'md6evb9a2r1000201');
    await tester.enterText(dialogFields().at(2), 'IQM24100299');
    await tester.enterText(dialogFields().at(3), 'IQB22K0100299');
    await tester.tap(find.widgetWithText(AppButton, 'Register'));
    await settle(tester);

    expect(find.text('Already registered: Chassis number.'), findsOneWidget);
    expect(find.text('Already registered.'), findsOneWidget, reason: 'the chassis field is marked');
    expect(vehicles.calls, <String>['conflicts'], reason: 'nothing saved');

    vehicles.conflicts = const <String>{};
    await tester.tap(find.widgetWithText(AppButton, 'Register'));
    await settle(tester);
    expect(vehicles.calls.last, 'saveUnit md6evb9a2r1000201');
    expect(vehicles.savedJson?['engine_number'], isNull);
    expect(vehicles.savedJson?['showroom_id'], 's-ind');
  });

  testWidgets('catalogue: brands with models and variants; the variant form follows the fuel type', (WidgetTester tester) async {
    final FakeVehiclesRepository vehicles = FakeVehiclesRepository();
    await openVehicles(tester, managerPermissions, vehicles: vehicles);
    await tester.tap(find.widgetWithText(Tab, 'Catalogue'));
    await settle(tester);
    expect(find.text('Honda'), findsOneWidget);

    await tester.tap(find.text('Honda'));
    await settle(tester);
    expect(find.text('Activa 6G'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Add variant'));
    await settle(tester);
    expect(find.text('Engine (cc)'), findsOneWidget);
    expect(find.text('Battery capacity (kWh)'), findsNothing);

    await pickFromDropdown(tester, find.byType(DropdownButtonFormField<String>).first, 'Electric');
    expect(find.text('Engine (cc)'), findsNothing);
    expect(find.text('Battery capacity (kWh)'), findsOneWidget);

    await tester.enterText(dialogFields().at(0), '3.4 kWh');
    await tester.tap(find.widgetWithText(AppButton, 'Save'));
    await settle(tester);
    expect(find.text('Battery capacity (kWh) is required.'), findsOneWidget);
    expect(vehicles.calls, isEmpty);
  });

  testWidgets('catalogue: without vehicles.create there is no Add brand', (WidgetTester tester) async {
    await openVehicles(tester, cashierPermissions);
    await tester.tap(find.widgetWithText(Tab, 'Catalogue'));
    await settle(tester);
    expect(find.text('Honda'), findsOneWidget);
    expect(find.text('Add brand'), findsNothing);
  });

  testWidgets('variant page shows the engine or the EV section only', (WidgetTester tester) async {
    await openVehicles(tester, managerPermissions, path: AppRoutes.vehicleVariantPath('v-iqube'));
    expect(find.text('Motor and battery'), findsOneWidget);
    expect(find.text('Engine'), findsNothing);
    expect(find.text('2.20 kWh'), findsOneWidget);
  });

  test('a variant switched to electric drops its engine data', () {
    const VehicleVariant switched = VehicleVariant(
      modelId: 'm',
      name: 'X',
      fuelType: FuelTypes.electric,
      engineCc: '110',
      motorPowerKw: '4',
      batteryCapacityKwh: '3',
    );
    expect(switched.toJson()['engine_cc'], isNull);
    expect(switched.toJson()['battery_capacity_kwh'], '3');
  });

  test('a duplicate index is reported by name and field', () {
    final AppFailure failure = ErrorMapper.map(const PostgrestException(
      message: 'duplicate key value violates unique constraint "uq_vehicles_engine_active"',
      code: '23505',
    ));
    expect(failure.message, 'This engine number is already registered.');
    expect((failure as ConflictFailure).field, 'engine_number');
  });

  test('vehicle identifier validators match the database formats', () {
    expect(Validators.vin('ME4JF508ARJ000101'), isNull);
    expect(Validators.vin('me4jf508arj 000101'), isNull, reason: 'case and spaces are normalised');
    expect(Validators.vin('ME4JF508ORJ000101'), isNotNull, reason: 'no O in a VIN');
    expect(Validators.vin('ME4JF508ARJ00010'), isNotNull);
    expect(Validators.vehicleIdentifier('JF50E7000101'), isNull);
    expect(Validators.vehicleIdentifier('AB'), isNotNull);
    expect(Validators.number('109.5', digits: 5, decimals: 1), isNull);
    expect(Validators.number('109.55', digits: 5, decimals: 1), isNotNull);
    expect(Validators.number('0', decimals: 0), isNotNull);
  });
}
