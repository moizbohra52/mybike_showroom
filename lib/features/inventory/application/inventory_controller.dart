import 'package:mybike_showroom/features/inventory/data/inventory_repository.dart';
import 'package:mybike_showroom/features/inventory/domain/stock.dart';
import 'package:mybike_showroom/features/vehicles/application/vehicles_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inventory_controller.g.dart';

@riverpod
Future<List<StatusChange>> vehicleStatusHistory(Ref ref, String vehicleId) =>
    ref.watch(inventoryRepositoryProvider).statusHistory(vehicleId);

@riverpod
Future<List<LedgerEntry>> vehicleLedger(Ref ref, String vehicleId) =>
    ref.watch(inventoryRepositoryProvider).ledger(vehicleId);

@riverpod
Future<ActiveReservation?> vehicleActiveReservation(Ref ref, String vehicleId) =>
    ref.watch(inventoryRepositoryProvider).activeReservation(vehicleId);

@riverpod
Future<List<StockTransfer>> stockTransfers(Ref ref, String? showroomId) =>
    ref.watch(inventoryRepositoryProvider).transfers(showroomId: showroomId);

@riverpod
Future<List<StockAdjustment>> stockAdjustments(Ref ref, String showroomId) =>
    ref.watch(inventoryRepositoryProvider).adjustments(showroomId);

@riverpod
Future<List<StockSummary>> currentStockSummary(Ref ref) => ref.watch(inventoryRepositoryProvider).currentStock();

@riverpod
Future<List<AgeingRow>> stockAgeing(Ref ref, String? showroomId) =>
    ref.watch(inventoryRepositoryProvider).ageing(showroomId: showroomId);

/// Stock-lifecycle commands; each refreshes the vehicle (and its history) plus
/// the showroom-wide views that summarise it.
@Riverpod(keepAlive: true)
InventoryActions inventoryActions(Ref ref) => InventoryActions(ref);

class InventoryActions {
  InventoryActions(this.ref);

  final Ref ref;

  InventoryRepository get repository => ref.read(inventoryRepositoryProvider);

  Future<void> receiveVehicle(String vehicleId, String unitCost, {String? referenceNo, String? remarks}) async {
    await repository.receiveVehicle(vehicleId, unitCost, referenceNo: referenceNo, remarks: remarks);
    refreshVehicle(vehicleId);
  }

  Future<void> reserveVehicle(String vehicleId, {String? reason}) async {
    await repository.reserveVehicle(vehicleId, reason: reason);
    refreshVehicle(vehicleId);
  }

  Future<void> releaseReservation(String vehicleId, String reason) async {
    await repository.releaseReservation(vehicleId, reason);
    refreshVehicle(vehicleId);
  }

  Future<void> markDamaged(String vehicleId, String reason) async {
    await repository.markDamaged(vehicleId, reason);
    refreshVehicle(vehicleId);
  }

  Future<String> createTransfer({
    required String sourceShowroomId,
    required String destinationShowroomId,
    required String transferDate,
    required List<String> vehicleIds,
    String? remarks,
  }) async {
    final String id = await repository.createTransfer(
      sourceShowroomId: sourceShowroomId,
      destinationShowroomId: destinationShowroomId,
      transferDate: transferDate,
      vehicleIds: vehicleIds,
      remarks: remarks,
    );
    refreshLists();
    for (final String vehicleId in vehicleIds) {
      refreshVehicle(vehicleId);
    }
    return id;
  }

  Future<void> receiveTransfer(String transferId, List<String> vehicleIds, {String? remarks}) async {
    await repository.receiveTransfer(transferId, remarks: remarks);
    refreshLists();
    for (final String vehicleId in vehicleIds) {
      refreshVehicle(vehicleId);
    }
  }

  Future<String> createAdjustment({
    required String showroomId,
    required String adjustmentDate,
    required String reasonCode,
    required List<Map<String, Object?>> items,
    String? notes,
  }) async {
    final String id = await repository.createAdjustment(
      showroomId: showroomId,
      adjustmentDate: adjustmentDate,
      reasonCode: reasonCode,
      items: items,
      notes: notes,
    );
    refreshLists();
    for (final Map<String, Object?> item in items) {
      refreshVehicle(item['vehicle_id']! as String);
    }
    return id;
  }

  void refreshVehicle(String vehicleId) {
    ref
      ..invalidate(vehicleUnitProvider(vehicleId))
      ..invalidate(vehicleUnitsProvider)
      ..invalidate(vehicleStatusHistoryProvider(vehicleId))
      ..invalidate(vehicleLedgerProvider(vehicleId))
      ..invalidate(vehicleActiveReservationProvider(vehicleId));
    refreshLists();
  }

  void refreshLists() {
    ref
      ..invalidate(stockTransfersProvider)
      ..invalidate(stockAdjustmentsProvider)
      ..invalidate(currentStockSummaryProvider)
      ..invalidate(stockAgeingProvider);
  }
}
