import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:mybike_showroom/features/inventory/domain/stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stock lifecycle: receive, reserve, transfer, damage, adjust. RLS decides
/// every read; every write goes through the RPCs in migration 0011 — there
/// is no direct table privilege at all (stock_ledger is closed to clients).
abstract interface class InventoryRepository {
  Future<List<StatusChange>> statusHistory(String vehicleId);
  Future<List<LedgerEntry>> ledger(String vehicleId);
  Future<ActiveReservation?> activeReservation(String vehicleId);

  Future<void> receiveVehicle(String vehicleId, String unitCost, {String? referenceNo, String? remarks});
  Future<void> reserveVehicle(String vehicleId, {String? reason});
  Future<void> releaseReservation(String vehicleId, String reason);
  Future<void> markDamaged(String vehicleId, String reason);

  Future<List<StockTransfer>> transfers({String? showroomId});
  Future<String> createTransfer({
    required String sourceShowroomId,
    required String destinationShowroomId,
    required String transferDate,
    required List<String> vehicleIds,
    String? remarks,
  });
  Future<void> receiveTransfer(String transferId, {String? remarks});

  Future<List<StockAdjustment>> adjustments(String showroomId);
  Future<String> createAdjustment({
    required String showroomId,
    required String adjustmentDate,
    required String reasonCode,
    required List<Map<String, Object?>> items,
    String? notes,
  });

  Future<List<StockSummary>> currentStock();
  Future<List<AgeingRow>> ageing({String? showroomId});
}

final class SupabaseInventoryRepository implements InventoryRepository {
  SupabaseInventoryRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<StatusChange>> statusHistory(String vehicleId) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('vehicle_status_history')
          .select('from_status, to_status, changed_at, reason')
          .eq('vehicle_id', vehicleId)
          .order('changed_at', ascending: false);
      return <StatusChange>[for (final Map<String, dynamic> row in rows) StatusChange.fromJson(row)];
    });
  }

  @override
  Future<List<LedgerEntry>> ledger(String vehicleId) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('stock_ledger')
          .select('movement_type, unit_cost::text, reference_no, remarks, created_at')
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false);
      return <LedgerEntry>[for (final Map<String, dynamic> row in rows) LedgerEntry.fromJson(row)];
    });
  }

  @override
  Future<ActiveReservation?> activeReservation(String vehicleId) {
    return ErrorMapper.guard(() async {
      final Map<String, dynamic>? row = await client
          .from('vehicle_reservations')
          .select('reserved_at, profiles(full_name)')
          .eq('vehicle_id', vehicleId)
          .isFilter('released_at', null)
          .maybeSingle();
      return row == null ? null : ActiveReservation.fromJson(row);
    });
  }

  @override
  Future<void> receiveVehicle(String vehicleId, String unitCost, {String? referenceNo, String? remarks}) {
    return ErrorMapper.guard(() => client.rpc<void>('rpc_receive_vehicle_stock', params: <String, Object?>{
          'p_vehicle_id': vehicleId,
          'p_unit_cost': unitCost,
          'p_reference_no': referenceNo,
          'p_remarks': remarks,
        }));
  }

  @override
  Future<void> reserveVehicle(String vehicleId, {String? reason}) {
    return ErrorMapper.guard(
      () => client.rpc<void>('rpc_reserve_vehicle', params: <String, Object?>{'p_vehicle_id': vehicleId, 'p_reason': reason}),
    );
  }

  @override
  Future<void> releaseReservation(String vehicleId, String reason) {
    return ErrorMapper.guard(() => client
        .rpc<void>('rpc_release_reservation', params: <String, Object?>{'p_vehicle_id': vehicleId, 'p_reason': reason}));
  }

  @override
  Future<void> markDamaged(String vehicleId, String reason) {
    return ErrorMapper.guard(() => client
        .rpc<void>('rpc_mark_vehicle_damaged', params: <String, Object?>{'p_vehicle_id': vehicleId, 'p_reason': reason}));
  }

  @override
  Future<List<StockTransfer>> transfers({String? showroomId}) {
    return ErrorMapper.guard(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> request = client.from('stock_transfers').select(StockTransfer.columns);
      if (showroomId != null) {
        request = request.or('source_showroom_id.eq.$showroomId,destination_showroom_id.eq.$showroomId');
      }
      final List<Map<String, dynamic>> rows = await request.order('created_at', ascending: false);
      return <StockTransfer>[for (final Map<String, dynamic> row in rows) StockTransfer.fromJson(row)];
    });
  }

  @override
  Future<String> createTransfer({
    required String sourceShowroomId,
    required String destinationShowroomId,
    required String transferDate,
    required List<String> vehicleIds,
    String? remarks,
  }) {
    return ErrorMapper.guard(() async {
      final String id = await client.rpc<String>('rpc_create_stock_transfer', params: <String, Object?>{
        'p_source_showroom_id': sourceShowroomId,
        'p_destination_showroom_id': destinationShowroomId,
        'p_transfer_date': transferDate,
        'p_vehicle_ids': vehicleIds,
        'p_remarks': remarks,
      });
      return id;
    });
  }

  @override
  Future<void> receiveTransfer(String transferId, {String? remarks}) {
    return ErrorMapper.guard(() => client
        .rpc<void>('rpc_receive_stock_transfer', params: <String, Object?>{'p_transfer_id': transferId, 'p_remarks': remarks}));
  }

  @override
  Future<List<StockAdjustment>> adjustments(String showroomId) {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('stock_adjustments')
          .select(StockAdjustment.columns)
          .eq('showroom_id', showroomId)
          .order('adjustment_date', ascending: false);
      return <StockAdjustment>[for (final Map<String, dynamic> row in rows) StockAdjustment.fromJson(row)];
    });
  }

  @override
  Future<String> createAdjustment({
    required String showroomId,
    required String adjustmentDate,
    required String reasonCode,
    required List<Map<String, Object?>> items,
    String? notes,
  }) {
    return ErrorMapper.guard(() async {
      final String id = await client.rpc<String>('rpc_create_stock_adjustment', params: <String, Object?>{
        'p_showroom_id': showroomId,
        'p_adjustment_date': adjustmentDate,
        'p_reason_code': reasonCode,
        'p_items': items,
        'p_notes': notes,
      });
      return id;
    });
  }

  @override
  Future<List<StockSummary>> currentStock() {
    return ErrorMapper.guard(() async {
      final List<Map<String, dynamic>> rows =
          await client.from('v_current_stock').select('showroom_id, showroom_code, available_count, reserved_count, '
              'in_transit_count, damaged_count, available_value::text');
      return <StockSummary>[for (final Map<String, dynamic> row in rows) StockSummary.fromJson(row)];
    });
  }

  @override
  Future<List<AgeingRow>> ageing({String? showroomId}) {
    return ErrorMapper.guard(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> request = client.from('v_stock_ageing').select(AgeingRow.columns);
      if (showroomId != null) {
        request = request.eq('showroom_id', showroomId);
      }
      final List<Map<String, dynamic>> rows = await request.order('days_in_stock', ascending: false);
      return <AgeingRow>[for (final Map<String, dynamic> row in rows) AgeingRow.fromJson(row)];
    });
  }
}

final Provider<InventoryRepository> inventoryRepositoryProvider = Provider<InventoryRepository>(
  (Ref ref) => SupabaseInventoryRepository(Supabase.instance.client),
);
