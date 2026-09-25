import 'package:mybike_showroom/features/inventory/data/inventory_repository.dart';
import 'package:mybike_showroom/features/inventory/domain/stock.dart';

const StockSummary indoreSummary = StockSummary(
  showroomId: 's-ind',
  showroomCode: 'INDORE-MAIN',
  availableCount: 3,
  reservedCount: 1,
  inTransitCount: 0,
  damagedCount: 0,
  availableValue: '204000.00',
);

/// In-memory [InventoryRepository]: canned reads, recorded writes.
final class FakeInventoryRepository implements InventoryRepository {
  FakeInventoryRepository({
    this.reservation,
    List<StatusChange>? history,
    List<LedgerEntry>? ledgerEntries,
    List<StockTransfer>? transferList,
    List<StockAdjustment>? adjustmentList,
    List<StockSummary>? summaries,
    List<AgeingRow>? ageingRows,
  })  : history = history ?? const <StatusChange>[],
        ledgerEntries = ledgerEntries ?? const <LedgerEntry>[],
        transferList = transferList ?? const <StockTransfer>[],
        adjustmentList = adjustmentList ?? const <StockAdjustment>[],
        summaries = summaries ?? const <StockSummary>[indoreSummary],
        ageingRows = ageingRows ?? const <AgeingRow>[];

  ActiveReservation? reservation;
  List<StatusChange> history;
  List<LedgerEntry> ledgerEntries;
  List<StockTransfer> transferList;
  List<StockAdjustment> adjustmentList;
  List<StockSummary> summaries;
  List<AgeingRow> ageingRows;

  final List<String> calls = <String>[];
  Map<String, Object?>? lastAdjustmentItems;

  @override
  Future<List<StatusChange>> statusHistory(String vehicleId) async => history;

  @override
  Future<List<LedgerEntry>> ledger(String vehicleId) async => ledgerEntries;

  @override
  Future<ActiveReservation?> activeReservation(String vehicleId) async => reservation;

  @override
  Future<void> receiveVehicle(String vehicleId, String unitCost, {String? referenceNo, String? remarks}) async =>
      calls.add('receiveVehicle $vehicleId $unitCost');

  @override
  Future<void> reserveVehicle(String vehicleId, {String? reason}) async => calls.add('reserveVehicle $vehicleId');

  @override
  Future<void> releaseReservation(String vehicleId, String reason) async =>
      calls.add('releaseReservation $vehicleId $reason');

  @override
  Future<void> markDamaged(String vehicleId, String reason) async => calls.add('markDamaged $vehicleId $reason');

  @override
  Future<List<StockTransfer>> transfers({String? showroomId}) async => transferList;

  @override
  Future<String> createTransfer({
    required String sourceShowroomId,
    required String destinationShowroomId,
    required String transferDate,
    required List<String> vehicleIds,
    String? remarks,
  }) async {
    calls.add('createTransfer $sourceShowroomId->$destinationShowroomId ${vehicleIds.join(',')}');
    return 't-new';
  }

  @override
  Future<void> receiveTransfer(String transferId, {String? remarks}) async => calls.add('receiveTransfer $transferId');

  @override
  Future<List<StockAdjustment>> adjustments(String showroomId) async => adjustmentList;

  @override
  Future<String> createAdjustment({
    required String showroomId,
    required String adjustmentDate,
    required String reasonCode,
    required List<Map<String, Object?>> items,
    String? notes,
  }) async {
    calls.add('createAdjustment $showroomId $reasonCode ${items.length}');
    lastAdjustmentItems = items.first;
    return 'a-new';
  }

  @override
  Future<List<StockSummary>> currentStock() async => summaries;

  @override
  Future<List<AgeingRow>> ageing({String? showroomId}) async => ageingRows;
}
