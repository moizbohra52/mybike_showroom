// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One page of the users list.

@ProviderFor(usersPage)
final usersPageProvider = UsersPageFamily._();

/// One page of the users list.

final class UsersPageProvider
    extends
        $FunctionalProvider<
          AsyncValue<UsersPage>,
          UsersPage,
          FutureOr<UsersPage>
        >
    with $FutureModifier<UsersPage>, $FutureProvider<UsersPage> {
  /// One page of the users list.
  UsersPageProvider._({
    required UsersPageFamily super.from,
    required UsersQuery super.argument,
  }) : super(
         retry: null,
         name: r'usersPageProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$usersPageHash();

  @override
  String toString() {
    return r'usersPageProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UsersPage> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<UsersPage> create(Ref ref) {
    final argument = this.argument as UsersQuery;
    return usersPage(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UsersPageProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$usersPageHash() => r'406a502205daa25caf4adc3043ee4668ffa81dd4';

/// One page of the users list.

final class UsersPageFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UsersPage>, UsersQuery> {
  UsersPageFamily._()
    : super(
        retry: null,
        name: r'usersPageProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One page of the users list.

  UsersPageProvider call(UsersQuery query) =>
      UsersPageProvider._(argument: query, from: this);

  @override
  String toString() => r'usersPageProvider';
}

/// A user's detail with what the caller may change.

@ProviderFor(userAccess)
final userAccessProvider = UserAccessFamily._();

/// A user's detail with what the caller may change.

final class UserAccessProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserAccess?>,
          UserAccess?,
          FutureOr<UserAccess?>
        >
    with $FutureModifier<UserAccess?>, $FutureProvider<UserAccess?> {
  /// A user's detail with what the caller may change.
  UserAccessProvider._({
    required UserAccessFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'userAccessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$userAccessHash();

  @override
  String toString() {
    return r'userAccessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<UserAccess?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UserAccess?> create(Ref ref) {
    final argument = this.argument as String;
    return userAccess(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserAccessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userAccessHash() => r'b3aaddc5ec0398f565dd4adcb09afb7e63b11d9b';

/// A user's detail with what the caller may change.

final class UserAccessFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<UserAccess?>, String> {
  UserAccessFamily._()
    : super(
        retry: null,
        name: r'userAccessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A user's detail with what the caller may change.

  UserAccessProvider call(String profileId) =>
      UserAccessProvider._(argument: profileId, from: this);

  @override
  String toString() => r'userAccessProvider';
}

/// Roles the caller may grant in a showroom (`null` = globally).

@ProviderFor(grantableRoles)
final grantableRolesProvider = GrantableRolesFamily._();

/// Roles the caller may grant in a showroom (`null` = globally).

final class GrantableRolesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RoleOption>>,
          List<RoleOption>,
          FutureOr<List<RoleOption>>
        >
    with $FutureModifier<List<RoleOption>>, $FutureProvider<List<RoleOption>> {
  /// Roles the caller may grant in a showroom (`null` = globally).
  GrantableRolesProvider._({
    required GrantableRolesFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'grantableRolesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$grantableRolesHash();

  @override
  String toString() {
    return r'grantableRolesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<RoleOption>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RoleOption>> create(Ref ref) {
    final argument = this.argument as String?;
    return grantableRoles(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GrantableRolesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$grantableRolesHash() => r'ddfefa7d746a4930631a9a909300a01408729133';

/// Roles the caller may grant in a showroom (`null` = globally).

final class GrantableRolesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<RoleOption>>, String?> {
  GrantableRolesFamily._()
    : super(
        retry: null,
        name: r'grantableRolesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Roles the caller may grant in a showroom (`null` = globally).

  GrantableRolesProvider call(String? showroomId) =>
      GrantableRolesProvider._(argument: showroomId, from: this);

  @override
  String toString() => r'grantableRolesProvider';
}

/// User-administration commands. Each one refreshes the affected views;
/// failures surface as AppFailure with a user-safe message.

@ProviderFor(userAdminActions)
final userAdminActionsProvider = UserAdminActionsProvider._();

/// User-administration commands. Each one refreshes the affected views;
/// failures surface as AppFailure with a user-safe message.

final class UserAdminActionsProvider
    extends
        $FunctionalProvider<
          UserAdminActions,
          UserAdminActions,
          UserAdminActions
        >
    with $Provider<UserAdminActions> {
  /// User-administration commands. Each one refreshes the affected views;
  /// failures surface as AppFailure with a user-safe message.
  UserAdminActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userAdminActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userAdminActionsHash();

  @$internal
  @override
  $ProviderElement<UserAdminActions> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserAdminActions create(Ref ref) {
    return userAdminActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserAdminActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserAdminActions>(value),
    );
  }
}

String _$userAdminActionsHash() => r'3001727ae4e05a7e47a09b64489bfd89d1016fb3';
