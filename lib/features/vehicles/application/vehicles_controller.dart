import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/features/vehicles/data/vehicles_repository.dart';
import 'package:mybike_showroom/features/vehicles/domain/vehicle_master.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vehicles_controller.g.dart';

/// Brands → models → variants.
@riverpod
Future<List<VehicleBrand>> vehicleCatalogue(Ref ref) => ref.watch(vehiclesRepositoryProvider).catalogue();

/// Active variants with brand and model names (pickers).
@riverpod
Future<List<VariantOption>> variantOptions(Ref ref) async {
  final List<VehicleBrand> brands = await ref.watch(vehicleCatalogueProvider.future);
  return <VariantOption>[
    for (final VehicleBrand b in brands)
      if (b.isActive)
        for (final VehicleModel m in b.models)
          if (m.isActive)
            for (final VehicleVariant v in m.variants)
              if (v.isActive) VariantOption(variant: v, brandName: b.name, modelName: m.name),
  ];
}

@riverpod
Future<UnitsPage> vehicleUnits(Ref ref, UnitsQuery query) => ref.watch(vehiclesRepositoryProvider).units(query);

@riverpod
Future<VehicleUnit?> vehicleUnit(Ref ref, String id) => ref.watch(vehiclesRepositoryProvider).unit(id);

/// Labels of the identifier fields, for duplicate messages.
const Map<String, String> identifierLabels = <String, String>{
  'vin': 'VIN',
  'chassis_number': 'Chassis number',
  'engine_number': 'Engine number',
  'motor_number': 'Motor number',
  'battery_number': 'Battery number',
};

@Riverpod(keepAlive: true)
VehicleAdminActions vehicleAdminActions(Ref ref) => VehicleAdminActions(ref);

class VehicleAdminActions {
  VehicleAdminActions(this.ref);

  final Ref ref;

  VehiclesRepository get repository => ref.read(vehiclesRepositoryProvider);

  Future<void> saveBrand(VehicleBrand brand) async {
    await repository.saveBrand(brand);
    ref.invalidate(vehicleCatalogueProvider);
  }

  Future<void> saveModel(VehicleModel model) async {
    await repository.saveModel(model);
    ref.invalidate(vehicleCatalogueProvider);
  }

  Future<String> saveVariant(VehicleVariant variant) async {
    final String id = await repository.saveVariant(variant);
    ref.invalidate(vehicleCatalogueProvider);
    return id;
  }

  /// Checks the identifiers against every showroom first and throws a
  /// [ValidationFailure] naming each taken field (keys = column names); the
  /// unique indexes still decide if two people save at the same moment.
  Future<String> saveUnit(VehicleUnit unit, {required String fuelType}) async {
    final Set<String> taken = await repository.identifierConflicts(unit, fuelType: fuelType);
    if (taken.isNotEmpty) {
      throw ValidationFailure(
        message: 'Already registered: ${taken.map((String f) => identifierLabels[f] ?? f).join(', ')}.',
        fieldErrors: <String, String>{for (final String f in taken) f: 'Already registered.'},
      );
    }
    final String id = await repository.saveUnit(unit, fuelType: fuelType);
    ref
      ..invalidate(vehicleUnitsProvider)
      ..invalidate(vehicleUnitProvider(id));
    return id;
  }
}
