// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vehicleStatusHistory)
final vehicleStatusHistoryProvider = VehicleStatusHistoryFamily._();

final class VehicleStatusHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StatusChange>>,
          List<StatusChange>,
          FutureOr<List<StatusChange>>
        >
    with
        $FutureModifier<List<StatusChange>>,
        $FutureProvider<List<StatusChange>> {
  VehicleStatusHistoryProvider._({
    required VehicleStatusHistoryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'vehicleStatusHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vehicleStatusHistoryHash();

  @override
  String toString() {
    return r'vehicleStatusHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<StatusChange>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StatusChange>> create(Ref ref) {
    final argument = this.argument as String;
    return vehicleStatusHistory(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleStatusHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vehicleStatusHistoryHash() =>
    r'd75b5aadfef9596254710033bea35ed577357d39';

final class VehicleStatusHistoryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<StatusChange>>, String> {
  VehicleStatusHistoryFamily._()
    : super(
        retry: null,
        name: r'vehicleStatusHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VehicleStatusHistoryProvider call(String vehicleId) =>
      VehicleStatusHistoryProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'vehicleStatusHistoryProvider';
}

@ProviderFor(vehicleLedger)
final vehicleLedgerProvider = VehicleLedgerFamily._();

final class VehicleLedgerProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LedgerEntry>>,
          List<LedgerEntry>,
          FutureOr<List<LedgerEntry>>
        >
    with
        $FutureModifier<List<LedgerEntry>>,
        $FutureProvider<List<LedgerEntry>> {
  VehicleLedgerProvider._({
    required VehicleLedgerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'vehicleLedgerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vehicleLedgerHash();

  @override
  String toString() {
    return r'vehicleLedgerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<LedgerEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<LedgerEntry>> create(Ref ref) {
    final argument = this.argument as String;
    return vehicleLedger(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleLedgerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vehicleLedgerHash() => r'5bdc972dd7d4dbbd4641ff3e5f1cd2fa334a603c';

final class VehicleLedgerFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<LedgerEntry>>, String> {
  VehicleLedgerFamily._()
    : super(
        retry: null,
        name: r'vehicleLedgerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VehicleLedgerProvider call(String vehicleId) =>
      VehicleLedgerProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'vehicleLedgerProvider';
}

@ProviderFor(vehicleActiveReservation)
final vehicleActiveReservationProvider = VehicleActiveReservationFamily._();

final class VehicleActiveReservationProvider
    extends
        $FunctionalProvider<
          AsyncValue<ActiveReservation?>,
          ActiveReservation?,
          FutureOr<ActiveReservation?>
        >
    with
        $FutureModifier<ActiveReservation?>,
        $FutureProvider<ActiveReservation?> {
  VehicleActiveReservationProvider._({
    required VehicleActiveReservationFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'vehicleActiveReservationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vehicleActiveReservationHash();

  @override
  String toString() {
    return r'vehicleActiveReservationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ActiveReservation?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ActiveReservation?> create(Ref ref) {
    final argument = this.argument as String;
    return vehicleActiveReservation(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleActiveReservationProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vehicleActiveReservationHash() =>
    r'2ded461fb5ac06f16689f7dc4896100d413aba5f';

final class VehicleActiveReservationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ActiveReservation?>, String> {
  VehicleActiveReservationFamily._()
    : super(
        retry: null,
        name: r'vehicleActiveReservationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VehicleActiveReservationProvider call(String vehicleId) =>
      VehicleActiveReservationProvider._(argument: vehicleId, from: this);

  @override
  String toString() => r'vehicleActiveReservationProvider';
}

@ProviderFor(stockTransfers)
final stockTransfersProvider = StockTransfersFamily._();

final class StockTransfersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StockTransfer>>,
          List<StockTransfer>,
          FutureOr<List<StockTransfer>>
        >
    with
        $FutureModifier<List<StockTransfer>>,
        $FutureProvider<List<StockTransfer>> {
  StockTransfersProvider._({
    required StockTransfersFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'stockTransfersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$stockTransfersHash();

  @override
  String toString() {
    return r'stockTransfersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<StockTransfer>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StockTransfer>> create(Ref ref) {
    final argument = this.argument as String?;
    return stockTransfers(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StockTransfersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$stockTransfersHash() => r'963a132d98fcff57d53b7e4f9f9656149a72312f';

final class StockTransfersFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<StockTransfer>>, String?> {
  StockTransfersFamily._()
    : super(
        retry: null,
        name: r'stockTransfersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StockTransfersProvider call(String? showroomId) =>
      StockTransfersProvider._(argument: showroomId, from: this);

  @override
  String toString() => r'stockTransfersProvider';
}

@ProviderFor(stockAdjustments)
final stockAdjustmentsProvider = StockAdjustmentsFamily._();

final class StockAdjustmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StockAdjustment>>,
          List<StockAdjustment>,
          FutureOr<List<StockAdjustment>>
        >
    with
        $FutureModifier<List<StockAdjustment>>,
        $FutureProvider<List<StockAdjustment>> {
  StockAdjustmentsProvider._({
    required StockAdjustmentsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'stockAdjustmentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$stockAdjustmentsHash();

  @override
  String toString() {
    return r'stockAdjustmentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<StockAdjustment>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StockAdjustment>> create(Ref ref) {
    final argument = this.argument as String;
    return stockAdjustments(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StockAdjustmentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$stockAdjustmentsHash() => r'0f4d4cc29d8b257fe68d8b20df0ce0c3de11f2d8';

final class StockAdjustmentsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<StockAdjustment>>, String> {
  StockAdjustmentsFamily._()
    : super(
        retry: null,
        name: r'stockAdjustmentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StockAdjustmentsProvider call(String showroomId) =>
      StockAdjustmentsProvider._(argument: showroomId, from: this);

  @override
  String toString() => r'stockAdjustmentsProvider';
}

@ProviderFor(currentStockSummary)
final currentStockSummaryProvider = CurrentStockSummaryProvider._();

final class CurrentStockSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<StockSummary>>,
          List<StockSummary>,
          FutureOr<List<StockSummary>>
        >
    with
        $FutureModifier<List<StockSummary>>,
        $FutureProvider<List<StockSummary>> {
  CurrentStockSummaryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentStockSummaryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentStockSummaryHash();

  @$internal
  @override
  $FutureProviderElement<List<StockSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<StockSummary>> create(Ref ref) {
    return currentStockSummary(ref);
  }
}

String _$currentStockSummaryHash() =>
    r'470a368378cbd181ec5e4d87925b755c461d10ac';

@ProviderFor(stockAgeing)
final stockAgeingProvider = StockAgeingFamily._();

final class StockAgeingProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AgeingRow>>,
          List<AgeingRow>,
          FutureOr<List<AgeingRow>>
        >
    with $FutureModifier<List<AgeingRow>>, $FutureProvider<List<AgeingRow>> {
  StockAgeingProvider._({
    required StockAgeingFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'stockAgeingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$stockAgeingHash();

  @override
  String toString() {
    return r'stockAgeingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<AgeingRow>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AgeingRow>> create(Ref ref) {
    final argument = this.argument as String?;
    return stockAgeing(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StockAgeingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$stockAgeingHash() => r'620870e3b110d6a54dfbeaa82a535f048f87dad1';

final class StockAgeingFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<AgeingRow>>, String?> {
  StockAgeingFamily._()
    : super(
        retry: null,
        name: r'stockAgeingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  StockAgeingProvider call(String? showroomId) =>
      StockAgeingProvider._(argument: showroomId, from: this);

  @override
  String toString() => r'stockAgeingProvider';
}

/// Stock-lifecycle commands; each refreshes the vehicle (and its history) plus
/// the showroom-wide views that summarise it.

@ProviderFor(inventoryActions)
final inventoryActionsProvider = InventoryActionsProvider._();

/// Stock-lifecycle commands; each refreshes the vehicle (and its history) plus
/// the showroom-wide views that summarise it.

final class InventoryActionsProvider
    extends
        $FunctionalProvider<
          InventoryActions,
          InventoryActions,
          InventoryActions
        >
    with $Provider<InventoryActions> {
  /// Stock-lifecycle commands; each refreshes the vehicle (and its history) plus
  /// the showroom-wide views that summarise it.
  InventoryActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inventoryActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inventoryActionsHash();

  @$internal
  @override
  $ProviderElement<InventoryActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InventoryActions create(Ref ref) {
    return inventoryActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InventoryActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InventoryActions>(value),
    );
  }
}

String _$inventoryActionsHash() => r'b81ea0d426a2a137d1a699bef02d11029d2fcf3a';
