import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:mybike_showroom/features/vehicles/domain/vehicle_master.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Vehicle catalogue (company-wide) and vehicle units (per showroom). RLS
/// decides every read and write; the unique indexes are the final duplicate
/// check.
abstract interface class VehiclesRepository {
  /// Brands with their models and variants.
  Future<List<VehicleBrand>> catalogue();
  Future<void> saveBrand(VehicleBrand brand);
  Future<void> saveModel(VehicleModel model);

  /// Returns the variant id.
  Future<String> saveVariant(VehicleVariant variant);

  Future<UnitsPage> units(UnitsQuery query);

  /// `null` when not visible.
  Future<VehicleUnit?> unit(String id);

  /// Returns the unit id.
  Future<String> saveUnit(VehicleUnit unit, {required String fuelType});

  /// Field names already used by a unit on the books in any showroom.
  Future<Set<String>> identifierConflicts(VehicleUnit unit, {required String fuelType});
}

final class SupabaseVehiclesRepository implements VehiclesRepository {
  SupabaseVehiclesRepository(this.client);

  final SupabaseClient client;

  static final RegExp filterSyntax = RegExp(r'[,()"\\*%]');

  @override
  Future<List<VehicleBrand>> catalogue() {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('vehicle_brands')
          .select('id, code, name, country, is_active, '
              'vehicle_models(id, brand_id, name, category, is_active, vehicle_variants(${VehicleVariant.columns}))')
          .order('name');
      return <VehicleBrand>[for (final Map<String, dynamic> row in rows) VehicleBrand.fromJson(row)];
    });
  }

  @override
  Future<void> saveBrand(VehicleBrand brand) => save('vehicle_brands', brand.id, brand.toJson());

  @override
  Future<void> saveModel(VehicleModel model) => save('vehicle_models', model.id, model.toJson());

  @override
  Future<String> saveVariant(VehicleVariant variant) => save('vehicle_variants', variant.id, variant.toJson());

  @override
  Future<UnitsPage> units(UnitsQuery query) {
    return ErrorMapper.guard(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> request = client.from('vehicles').select(VehicleUnit.columns);
      if (query.showroomId != null) {
        request = request.eq('showroom_id', query.showroomId!);
      }
      final String search = query.search.replaceAll(filterSyntax, '').replaceAll(RegExp(r'\s'), '').toUpperCase();
      if (search.isNotEmpty) {
        request = request.or(<String>[
          'vin.ilike.%$search%',
          'chassis_number.ilike.%$search%',
          'engine_number.ilike.%$search%',
          'motor_number.ilike.%$search%',
          'battery_number.ilike.%$search%',
        ].join(','));
      }
      final int from = (query.page - 1) * query.pageSize;
      final PostgrestResponse<List<Map<String, dynamic>>> response = await request
          .order('created_at', ascending: false)
          .range(from, from + query.pageSize - 1)
          .count(CountOption.exact);
      return UnitsPage(
        items: <VehicleUnit>[for (final Map<String, dynamic> row in response.data) VehicleUnit.fromJson(row)],
        total: response.count,
      );
    });
  }

  @override
  Future<VehicleUnit?> unit(String id) {
    return ErrorMapper.guard(() async {
      final Map<String, dynamic>? row = await client.from('vehicles').select(VehicleUnit.columns).eq('id', id).maybeSingle();
      return row == null ? null : VehicleUnit.fromJson(row);
    });
  }

  @override
  Future<String> saveUnit(VehicleUnit unit, {required String fuelType}) =>
      save('vehicles', unit.id, unit.toJson(forFuelType: fuelType, insert: unit.id == null));

  @override
  Future<Set<String>> identifierConflicts(VehicleUnit unit, {required String fuelType}) {
    return ErrorMapper.guard(() async {
      final Map<String, Object?> json = unit.toJson(forFuelType: fuelType, insert: true);
      final List<Object?> fields = await client.rpc<List<Object?>>(
        'rpc_vehicle_identifier_conflicts',
        params: <String, Object?>{
          'p_vin': json['vin'],
          'p_chassis_number': json['chassis_number'],
          'p_engine_number': json['engine_number'],
          'p_motor_number': json['motor_number'],
          'p_battery_number': json['battery_number'],
          'p_exclude_id': unit.id,
        },
      );
      return <String>{for (final Object? f in fields) f! as String};
    });
  }

  /// Inserts ([id] null) or updates a row and returns its id. An update that
  /// RLS filtered to nothing is reported as a permission failure.
  Future<String> save(String table, String? id, Map<String, Object?> values) {
    return ErrorMapper.guard(() async {
      if (id == null) {
        final Map<String, dynamic> row = await client.from(table).insert(values).select('id').single();
        return row['id']! as String;
      }
      final List<Map<String, dynamic>> rows = await client.from(table).update(values).eq('id', id).select('id');
      ErrorMapper.requireChanged(rows);
      return id;
    });
  }
}

final Provider<VehiclesRepository> vehiclesRepositoryProvider = Provider<VehiclesRepository>(
  (Ref ref) => SupabaseVehiclesRepository(Supabase.instance.client),
);
