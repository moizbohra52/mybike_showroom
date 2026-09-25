// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicles_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Brands → models → variants.

@ProviderFor(vehicleCatalogue)
final vehicleCatalogueProvider = VehicleCatalogueProvider._();

/// Brands → models → variants.

final class VehicleCatalogueProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VehicleBrand>>,
          List<VehicleBrand>,
          FutureOr<List<VehicleBrand>>
        >
    with
        $FutureModifier<List<VehicleBrand>>,
        $FutureProvider<List<VehicleBrand>> {
  /// Brands → models → variants.
  VehicleCatalogueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleCatalogueProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleCatalogueHash();

  @$internal
  @override
  $FutureProviderElement<List<VehicleBrand>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VehicleBrand>> create(Ref ref) {
    return vehicleCatalogue(ref);
  }
}

String _$vehicleCatalogueHash() => r'ea5dce49fc03859be093cc3ad337859af3ee6c5a';

/// Active variants with brand and model names (pickers).

@ProviderFor(variantOptions)
final variantOptionsProvider = VariantOptionsProvider._();

/// Active variants with brand and model names (pickers).

final class VariantOptionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VariantOption>>,
          List<VariantOption>,
          FutureOr<List<VariantOption>>
        >
    with
        $FutureModifier<List<VariantOption>>,
        $FutureProvider<List<VariantOption>> {
  /// Active variants with brand and model names (pickers).
  VariantOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'variantOptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$variantOptionsHash();

  @$internal
  @override
  $FutureProviderElement<List<VariantOption>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VariantOption>> create(Ref ref) {
    return variantOptions(ref);
  }
}

String _$variantOptionsHash() => r'a40532dc119a09f4b58c522a86de60cf394f8aed';

@ProviderFor(vehicleUnits)
final vehicleUnitsProvider = VehicleUnitsFamily._();

final class VehicleUnitsProvider
    extends
        $FunctionalProvider<
          AsyncValue<UnitsPage>,
          UnitsPage,
          FutureOr<UnitsPage>
        >
    with $FutureModifier<UnitsPage>, $FutureProvider<UnitsPage> {
  VehicleUnitsProvider._({
    required VehicleUnitsFamily super.from,
    required UnitsQuery super.argument,
  }) : super(
         retry: null,
         name: r'vehicleUnitsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vehicleUnitsHash();

  @override
  String toString() {
    return r'vehicleUnitsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UnitsPage> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<UnitsPage> create(Ref ref) {
    final argument = this.argument as UnitsQuery;
    return vehicleUnits(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleUnitsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vehicleUnitsHash() => r'0b003005d193a0974477202c755acaf706458bc1';

final class VehicleUnitsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UnitsPage>, UnitsQuery> {
  VehicleUnitsFamily._()
    : super(
        retry: null,
        name: r'vehicleUnitsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VehicleUnitsProvider call(UnitsQuery query) =>
      VehicleUnitsProvider._(argument: query, from: this);

  @override
  String toString() => r'vehicleUnitsProvider';
}

@ProviderFor(vehicleUnit)
final vehicleUnitProvider = VehicleUnitFamily._();

final class VehicleUnitProvider
    extends
        $FunctionalProvider<
          AsyncValue<VehicleUnit?>,
          VehicleUnit?,
          FutureOr<VehicleUnit?>
        >
    with $FutureModifier<VehicleUnit?>, $FutureProvider<VehicleUnit?> {
  VehicleUnitProvider._({
    required VehicleUnitFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'vehicleUnitProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vehicleUnitHash();

  @override
  String toString() {
    return r'vehicleUnitProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<VehicleUnit?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<VehicleUnit?> create(Ref ref) {
    final argument = this.argument as String;
    return vehicleUnit(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleUnitProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vehicleUnitHash() => r'477de4cc6aeba4ec1ab867a16b94dd0dc79f969a';

final class VehicleUnitFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<VehicleUnit?>, String> {
  VehicleUnitFamily._()
    : super(
        retry: null,
        name: r'vehicleUnitProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  VehicleUnitProvider call(String id) =>
      VehicleUnitProvider._(argument: id, from: this);

  @override
  String toString() => r'vehicleUnitProvider';
}

@ProviderFor(vehicleAdminActions)
final vehicleAdminActionsProvider = VehicleAdminActionsProvider._();

final class VehicleAdminActionsProvider
    extends
        $FunctionalProvider<
          VehicleAdminActions,
          VehicleAdminActions,
          VehicleAdminActions
        >
    with $Provider<VehicleAdminActions> {
  VehicleAdminActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vehicleAdminActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vehicleAdminActionsHash();

  @$internal
  @override
  $ProviderElement<VehicleAdminActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VehicleAdminActions create(Ref ref) {
    return vehicleAdminActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VehicleAdminActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VehicleAdminActions>(value),
    );
  }
}

String _$vehicleAdminActionsHash() =>
    r'390a1d5ff9e54cb7d8f4f5abeca515a9c9362d41';
