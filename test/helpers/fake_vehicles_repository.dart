import 'package:mybike_showroom/features/vehicles/data/vehicles_repository.dart';
import 'package:mybike_showroom/features/vehicles/domain/vehicle_master.dart';

const VehicleVariant activaStd = VehicleVariant(
  id: 'v-activa',
  modelId: 'm-activa',
  name: 'STD',
  fuelType: FuelTypes.petrol,
  exShowroomPrice: '76684.00',
  engineCc: '109.5',
  warrantyMonths: '36',
  warrantyKm: '42000',
);

const VehicleVariant iqube = VehicleVariant(
  id: 'v-iqube',
  modelId: 'm-iqube',
  name: '2.2 kWh',
  fuelType: FuelTypes.electric,
  motorPowerKw: '4.40',
  batteryCapacityKwh: '2.20',
  batteryWarrantyMonths: '36',
);

const List<VehicleBrand> testCatalogue = <VehicleBrand>[
  VehicleBrand(id: 'b-honda', code: 'HONDA', name: 'Honda', models: <VehicleModel>[
    VehicleModel(id: 'm-activa', brandId: 'b-honda', name: 'Activa 6G', category: 'scooter', variants: <VehicleVariant>[activaStd]),
  ]),
  VehicleBrand(id: 'b-tvs', code: 'TVS', name: 'TVS Motor', models: <VehicleModel>[
    VehicleModel(id: 'm-iqube', brandId: 'b-tvs', name: 'iQube', category: 'scooter', variants: <VehicleVariant>[iqube]),
  ]),
];

const VehicleUnit iqubeUnit = VehicleUnit(
  id: 'u-iqube',
  showroomId: 's-ind',
  variantId: 'v-iqube',
  fuelType: FuelTypes.electric,
  chassisNumber: 'MD6EVB9A2R1000201',
  motorNumber: 'IQM24100201',
  batteryNumber: 'IQB22K0100201',
  color: 'Titanium Grey',
  variantLabel: 'TVS Motor iQube 2.2 kWh',
);

/// In-memory [VehiclesRepository].
final class FakeVehiclesRepository implements VehiclesRepository {
  FakeVehiclesRepository({List<VehicleUnit>? units, this.conflicts = const <String>{}})
      : unitList = units ?? <VehicleUnit>[iqubeUnit];

  final List<VehicleUnit> unitList;

  /// What the server duplicate check answers.
  Set<String> conflicts;
  final List<String> calls = <String>[];
  final List<UnitsQuery> queries = <UnitsQuery>[];
  Map<String, Object?>? savedJson;

  @override
  Future<List<VehicleBrand>> catalogue() async => testCatalogue;

  @override
  Future<void> saveBrand(VehicleBrand brand) async => calls.add('saveBrand ${brand.toJson()['code']}');

  @override
  Future<void> saveModel(VehicleModel model) async => calls.add('saveModel ${model.name}');

  @override
  Future<String> saveVariant(VehicleVariant variant) async {
    savedJson = variant.toJson();
    calls.add('saveVariant ${variant.name}');
    return 'v-new';
  }

  @override
  Future<UnitsPage> units(UnitsQuery query) async {
    queries.add(query);
    return UnitsPage(items: unitList, total: unitList.length);
  }

  @override
  Future<VehicleUnit?> unit(String id) async => unitList.where((VehicleUnit u) => u.id == id).firstOrNull;

  @override
  Future<String> saveUnit(VehicleUnit unit, {required String fuelType}) async {
    savedJson = unit.toJson(forFuelType: fuelType, insert: unit.id == null);
    calls.add('saveUnit ${unit.chassisNumber}');
    return 'u-new';
  }

  @override
  Future<Set<String>> identifierConflicts(VehicleUnit unit, {required String fuelType}) async {
    calls.add('conflicts');
    return conflicts;
  }
}
