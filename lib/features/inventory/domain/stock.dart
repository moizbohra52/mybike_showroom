import 'package:flutter/foundation.dart';

/// `stock_movement_type` enum labels (docs/phase-00/06-business-flows.md §2).
abstract final class MovementTypes {
  static const Map<String, String> labels = <String, String>{
    'purchase_receipt': 'Received',
    'sale_issue': 'Sold',
    'transfer_out': 'Transferred out',
    'transfer_in': 'Transferred in',
    'adjustment_in': 'Adjustment (in)',
    'adjustment_out': 'Adjustment (out)',
    'return_in': 'Return (in)',
    'return_out': 'Return (out)',
    'damage': 'Marked damaged',
    'opening': 'Opening balance',
  };

  static String label(String type) => labels[type] ?? type;
}

abstract final class AdjustmentReasons {
  static const Map<String, String> labels = <String, String>{
    'physical_count': 'Physical count',
    'damage': 'Damage',
    'theft': 'Theft',
    'expiry': 'Expiry',
    'correction': 'Correction',
    'opening': 'Opening balance',
  };
}

/// One `vehicle_status_history` row.
@immutable
class StatusChange {
  const StatusChange({
    required this.fromStatus,
    required this.toStatus,
    required this.changedAt,
    this.reason,
  });

  factory StatusChange.fromJson(Map<String, Object?> json) => StatusChange(
        fromStatus: json['from_status'] as String?,
        toStatus: json['to_status']! as String,
        changedAt: DateTime.parse(json['changed_at']! as String),
        reason: json['reason'] as String?,
      );

  final String? fromStatus;
  final String toStatus;
  final DateTime changedAt;
  final String? reason;
}

/// One `stock_ledger` row.
@immutable
class LedgerEntry {
  const LedgerEntry({
    required this.movementType,
    required this.createdAt,
    this.unitCost,
    this.referenceNo,
    this.remarks,
  });

  factory LedgerEntry.fromJson(Map<String, Object?> json) => LedgerEntry(
        movementType: json['movement_type']! as String,
        unitCost: json['unit_cost'] as String?,
        referenceNo: json['reference_no'] as String?,
        remarks: json['remarks'] as String?,
        createdAt: DateTime.parse(json['created_at']! as String),
      );

  final String movementType;
  final String? unitCost;
  final String? referenceNo;
  final String? remarks;
  final DateTime createdAt;
}

/// The vehicle's active reservation, if any.
@immutable
class ActiveReservation {
  const ActiveReservation({required this.reservedAt, this.reservedByName});

  factory ActiveReservation.fromJson(Map<String, Object?> json) {
    final Map<Object?, Object?>? profile = json['profiles'] as Map<Object?, Object?>?;
    return ActiveReservation(
      reservedAt: DateTime.parse(json['reserved_at']! as String),
      reservedByName: profile?['full_name'] as String?,
    );
  }

  final DateTime reservedAt;
  final String? reservedByName;
}

/// One vehicle line of a transfer, joined with its variant label.
@immutable
class TransferLine {
  const TransferLine({required this.vehicleId, this.chassisNumber, this.variantLabel, this.unitCost});

  factory TransferLine.fromJson(Map<String, Object?> json) {
    final Map<Object?, Object?>? vehicle = json['vehicles'] as Map<Object?, Object?>?;
    final Map<Object?, Object?>? variant = vehicle?['vehicle_variants'] as Map<Object?, Object?>?;
    final Map<Object?, Object?>? model = variant?['vehicle_models'] as Map<Object?, Object?>?;
    final Map<Object?, Object?>? brand = model?['vehicle_brands'] as Map<Object?, Object?>?;
    return TransferLine(
      vehicleId: json['vehicle_id']! as String,
      chassisNumber: vehicle?['chassis_number'] as String?,
      unitCost: json['unit_cost'] as String?,
      variantLabel: variant == null ? null : '${brand?['name'] ?? ''} ${model?['name'] ?? ''} ${variant['name']}'.trim(),
    );
  }

  final String vehicleId;
  final String? chassisNumber;
  final String? variantLabel;
  final String? unitCost;
}

/// A `stock_transfers` row with its lines.
@immutable
class StockTransfer {
  const StockTransfer({
    required this.id,
    required this.transferNo,
    required this.sourceShowroomId,
    required this.destinationShowroomId,
    required this.transferDate,
    required this.status,
    this.sourceShowroomName,
    this.destinationShowroomName,
    this.remarks,
    this.items = const <TransferLine>[],
  });

  factory StockTransfer.fromJson(Map<String, Object?> json) {
    final Map<Object?, Object?>? source = json['source']! as Map<Object?, Object?>?;
    final Map<Object?, Object?>? destination = json['destination']! as Map<Object?, Object?>?;
    return StockTransfer(
      id: json['id']! as String,
      transferNo: json['transfer_no']! as String,
      sourceShowroomId: json['source_showroom_id']! as String,
      destinationShowroomId: json['destination_showroom_id']! as String,
      sourceShowroomName: source?['name'] as String?,
      destinationShowroomName: destination?['name'] as String?,
      transferDate: json['transfer_date']! as String,
      status: json['status']! as String,
      remarks: json['remarks'] as String?,
      items: <TransferLine>[
        for (final Object? row in (json['stock_transfer_items'] as List<Object?>?) ?? const <Object?>[])
          TransferLine.fromJson((row! as Map<Object?, Object?>).cast<String, Object?>()),
      ],
    );
  }

  static const String columns = 'id, transfer_no, source_showroom_id, destination_showroom_id, transfer_date, '
      'status, remarks, source:showrooms!stock_transfers_source_showroom_id_fkey(name), '
      'destination:showrooms!stock_transfers_destination_showroom_id_fkey(name), '
      'stock_transfer_items(vehicle_id, unit_cost, vehicles(chassis_number, '
      'vehicle_variants(name, vehicle_models(name, vehicle_brands(name)))))';

  final String id;
  final String transferNo;
  final String sourceShowroomId;
  final String destinationShowroomId;
  final String? sourceShowroomName;
  final String? destinationShowroomName;
  final String transferDate;
  final String status;
  final String? remarks;
  final List<TransferLine> items;
}

/// One vehicle line of a stock adjustment.
@immutable
class AdjustmentLine {
  const AdjustmentLine({required this.vehicleId, required this.direction, this.chassisNumber, this.unitCost});

  factory AdjustmentLine.fromJson(Map<String, Object?> json) {
    final Map<Object?, Object?>? vehicle = json['vehicles'] as Map<Object?, Object?>?;
    return AdjustmentLine(
      vehicleId: json['vehicle_id']! as String,
      direction: json['direction']! as String,
      unitCost: json['unit_cost'] as String?,
      chassisNumber: vehicle?['chassis_number'] as String?,
    );
  }

  final String vehicleId;
  final String direction;
  final String? chassisNumber;
  final String? unitCost;
}

/// A `stock_adjustments` row with its lines.
@immutable
class StockAdjustment {
  const StockAdjustment({
    required this.id,
    required this.adjustmentNo,
    required this.adjustmentDate,
    required this.reasonCode,
    required this.totalValue,
    this.notes,
    this.items = const <AdjustmentLine>[],
  });

  factory StockAdjustment.fromJson(Map<String, Object?> json) => StockAdjustment(
        id: json['id']! as String,
        adjustmentNo: json['adjustment_no']! as String,
        adjustmentDate: json['adjustment_date']! as String,
        reasonCode: json['reason_code']! as String,
        totalValue: json['total_value']! as String,
        notes: json['notes'] as String?,
        items: <AdjustmentLine>[
          for (final Object? row in (json['stock_adjustment_items'] as List<Object?>?) ?? const <Object?>[])
            AdjustmentLine.fromJson((row! as Map<Object?, Object?>).cast<String, Object?>()),
        ],
      );

  static const String columns = 'id, adjustment_no, adjustment_date, reason_code, total_value::text, notes, '
      'stock_adjustment_items(vehicle_id, direction, unit_cost::text, vehicles(chassis_number))';

  final String id;
  final String adjustmentNo;
  final String adjustmentDate;
  final String reasonCode;
  final String totalValue;
  final String? notes;
  final List<AdjustmentLine> items;
}

/// One row of `v_current_stock`.
@immutable
class StockSummary {
  const StockSummary({
    required this.showroomId,
    required this.showroomCode,
    required this.availableCount,
    required this.reservedCount,
    required this.inTransitCount,
    required this.damagedCount,
    required this.availableValue,
  });

  factory StockSummary.fromJson(Map<String, Object?> json) => StockSummary(
        showroomId: json['showroom_id']! as String,
        showroomCode: json['showroom_code']! as String,
        availableCount: json['available_count']! as int,
        reservedCount: json['reserved_count']! as int,
        inTransitCount: json['in_transit_count']! as int,
        damagedCount: json['damaged_count']! as int,
        availableValue: json['available_value']! as String,
      );

  final String showroomId;
  final String showroomCode;
  final int availableCount;
  final int reservedCount;
  final int inTransitCount;
  final int damagedCount;
  final String availableValue;
}

/// One row of `v_stock_ageing`.
@immutable
class AgeingRow {
  const AgeingRow({
    required this.vehicleId,
    required this.chassisNumber,
    required this.daysInStock,
    required this.ageingBucket,
    this.variantLabel,
  });

  factory AgeingRow.fromJson(Map<String, Object?> json) => AgeingRow(
        vehicleId: json['vehicle_id']! as String,
        chassisNumber: json['chassis_number']! as String,
        daysInStock: json['days_in_stock']! as int,
        ageingBucket: json['ageing_bucket']! as String,
        variantLabel: json['variant_label'] as String?,
      );

  static const String columns = 'vehicle_id, chassis_number, days_in_stock, ageing_bucket, variant_label';

  final String vehicleId;
  final String chassisNumber;
  final int daysInStock;
  final String ageingBucket;
  final String? variantLabel;
}
