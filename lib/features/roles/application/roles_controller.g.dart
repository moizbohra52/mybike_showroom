// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roles_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(roleList)
final roleListProvider = RoleListProvider._();

final class RoleListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AppRole>>,
          List<AppRole>,
          FutureOr<List<AppRole>>
        >
    with $FutureModifier<List<AppRole>>, $FutureProvider<List<AppRole>> {
  RoleListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roleListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roleListHash();

  @$internal
  @override
  $FutureProviderElement<List<AppRole>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<AppRole>> create(Ref ref) {
    return roleList(ref);
  }
}

String _$roleListHash() => r'04c7eed41eacfec818375279bdd8fecc9e92ce28';

/// The permission catalogue (code-defined; changes only with migrations).

@ProviderFor(permissionCatalogue)
final permissionCatalogueProvider = PermissionCatalogueProvider._();

/// The permission catalogue (code-defined; changes only with migrations).

final class PermissionCatalogueProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PermissionEntry>>,
          List<PermissionEntry>,
          FutureOr<List<PermissionEntry>>
        >
    with
        $FutureModifier<List<PermissionEntry>>,
        $FutureProvider<List<PermissionEntry>> {
  /// The permission catalogue (code-defined; changes only with migrations).
  PermissionCatalogueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'permissionCatalogueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$permissionCatalogueHash();

  @$internal
  @override
  $FutureProviderElement<List<PermissionEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PermissionEntry>> create(Ref ref) {
    return permissionCatalogue(ref);
  }
}

String _$permissionCatalogueHash() =>
    r'6b46df3b24ebc025aea314bce986723aae90fc68';

@ProviderFor(roleDetail)
final roleDetailProvider = RoleDetailFamily._();

final class RoleDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<RoleDetail>,
          RoleDetail,
          FutureOr<RoleDetail>
        >
    with $FutureModifier<RoleDetail>, $FutureProvider<RoleDetail> {
  RoleDetailProvider._({
    required RoleDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'roleDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$roleDetailHash();

  @override
  String toString() {
    return r'roleDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<RoleDetail> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RoleDetail> create(Ref ref) {
    final argument = this.argument as String;
    return roleDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RoleDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$roleDetailHash() => r'525af8110a08555ffa763659e56ffacda9f2c080';

final class RoleDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RoleDetail>, String> {
  RoleDetailFamily._()
    : super(
        retry: null,
        name: r'roleDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RoleDetailProvider call(String roleId) =>
      RoleDetailProvider._(argument: roleId, from: this);

  @override
  String toString() => r'roleDetailProvider';
}

/// Role and matrix commands; each refreshes the affected views.

@ProviderFor(roleAdminActions)
final roleAdminActionsProvider = RoleAdminActionsProvider._();

/// Role and matrix commands; each refreshes the affected views.

final class RoleAdminActionsProvider
    extends
        $FunctionalProvider<
          RoleAdminActions,
          RoleAdminActions,
          RoleAdminActions
        >
    with $Provider<RoleAdminActions> {
  /// Role and matrix commands; each refreshes the affected views.
  RoleAdminActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'roleAdminActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$roleAdminActionsHash();

  @$internal
  @override
  $ProviderElement<RoleAdminActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RoleAdminActions create(Ref ref) {
    return roleAdminActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoleAdminActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoleAdminActions>(value),
    );
  }
}

String _$roleAdminActionsHash() => r'e8f12099e6febf7e5d6792cb379336741aa381ce';
