// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'showrooms_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(showroomList)
final showroomListProvider = ShowroomListProvider._();

final class ShowroomListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Showroom>>,
          List<Showroom>,
          FutureOr<List<Showroom>>
        >
    with $FutureModifier<List<Showroom>>, $FutureProvider<List<Showroom>> {
  ShowroomListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showroomListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showroomListHash();

  @$internal
  @override
  $FutureProviderElement<List<Showroom>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Showroom>> create(Ref ref) {
    return showroomList(ref);
  }
}

String _$showroomListHash() => r'bf00e66e16b59d25fcf2fafb06720168f29af4c5';

@ProviderFor(showroom)
final showroomProvider = ShowroomFamily._();

final class ShowroomProvider
    extends
        $FunctionalProvider<
          AsyncValue<Showroom?>,
          Showroom?,
          FutureOr<Showroom?>
        >
    with $FutureModifier<Showroom?>, $FutureProvider<Showroom?> {
  ShowroomProvider._({
    required ShowroomFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'showroomProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$showroomHash();

  @override
  String toString() {
    return r'showroomProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Showroom?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Showroom?> create(Ref ref) {
    final argument = this.argument as String;
    return showroom(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ShowroomProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$showroomHash() => r'989666d6c7d2d37095973dbd16d6e7ca9a33c0c3';

final class ShowroomFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Showroom?>, String> {
  ShowroomFamily._()
    : super(
        retry: null,
        name: r'showroomProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ShowroomProvider call(String id) =>
      ShowroomProvider._(argument: id, from: this);

  @override
  String toString() => r'showroomProvider';
}

@ProviderFor(showroomSettings)
final showroomSettingsProvider = ShowroomSettingsFamily._();

final class ShowroomSettingsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ShowroomSettings>,
          ShowroomSettings,
          FutureOr<ShowroomSettings>
        >
    with $FutureModifier<ShowroomSettings>, $FutureProvider<ShowroomSettings> {
  ShowroomSettingsProvider._({
    required ShowroomSettingsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'showroomSettingsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$showroomSettingsHash();

  @override
  String toString() {
    return r'showroomSettingsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ShowroomSettings> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ShowroomSettings> create(Ref ref) {
    final argument = this.argument as String;
    return showroomSettings(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ShowroomSettingsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$showroomSettingsHash() => r'4a992038d0adff4ee15304a31edd73f546be94b8';

final class ShowroomSettingsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ShowroomSettings>, String> {
  ShowroomSettingsFamily._()
    : super(
        retry: null,
        name: r'showroomSettingsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ShowroomSettingsProvider call(String showroomId) =>
      ShowroomSettingsProvider._(argument: showroomId, from: this);

  @override
  String toString() => r'showroomSettingsProvider';
}

@ProviderFor(numberingSeries)
final numberingSeriesProvider = NumberingSeriesFamily._();

final class NumberingSeriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<NumberingSeries>>,
          List<NumberingSeries>,
          FutureOr<List<NumberingSeries>>
        >
    with
        $FutureModifier<List<NumberingSeries>>,
        $FutureProvider<List<NumberingSeries>> {
  NumberingSeriesProvider._({
    required NumberingSeriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'numberingSeriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$numberingSeriesHash();

  @override
  String toString() {
    return r'numberingSeriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<NumberingSeries>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<NumberingSeries>> create(Ref ref) {
    final argument = this.argument as String;
    return numberingSeries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NumberingSeriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$numberingSeriesHash() => r'1759c96c4b62613bef07a7e155d8d2118b3a8e7d';

final class NumberingSeriesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<NumberingSeries>>, String> {
  NumberingSeriesFamily._()
    : super(
        retry: null,
        name: r'numberingSeriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NumberingSeriesProvider call(String showroomId) =>
      NumberingSeriesProvider._(argument: showroomId, from: this);

  @override
  String toString() => r'numberingSeriesProvider';
}

@ProviderFor(bankAccounts)
final bankAccountsProvider = BankAccountsFamily._();

final class BankAccountsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BankAccount>>,
          List<BankAccount>,
          FutureOr<List<BankAccount>>
        >
    with
        $FutureModifier<List<BankAccount>>,
        $FutureProvider<List<BankAccount>> {
  BankAccountsProvider._({
    required BankAccountsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'bankAccountsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bankAccountsHash();

  @override
  String toString() {
    return r'bankAccountsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<BankAccount>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BankAccount>> create(Ref ref) {
    final argument = this.argument as String;
    return bankAccounts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BankAccountsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bankAccountsHash() => r'e01393e074f3183dfb95850f4f5d59626bdc4b04';

final class BankAccountsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<BankAccount>>, String> {
  BankAccountsFamily._()
    : super(
        retry: null,
        name: r'bankAccountsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BankAccountsProvider call(String showroomId) =>
      BankAccountsProvider._(argument: showroomId, from: this);

  @override
  String toString() => r'bankAccountsProvider';
}

/// GST state list (reference data).

@ProviderFor(indianStates)
final indianStatesProvider = IndianStatesProvider._();

/// GST state list (reference data).

final class IndianStatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<IndianState>>,
          List<IndianState>,
          FutureOr<List<IndianState>>
        >
    with
        $FutureModifier<List<IndianState>>,
        $FutureProvider<List<IndianState>> {
  /// GST state list (reference data).
  IndianStatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'indianStatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$indianStatesHash();

  @$internal
  @override
  $FutureProviderElement<List<IndianState>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<IndianState>> create(Ref ref) {
    return indianStates(ref);
  }
}

String _$indianStatesHash() => r'6112ccc897b77407ce2a35b00b4c3f3f719f5e54';

/// Showroom commands. Changes that alter which showrooms the caller works in
/// (create, activate, deactivate) also reload the session, so the switcher
/// and the router follow at once.

@ProviderFor(showroomAdminActions)
final showroomAdminActionsProvider = ShowroomAdminActionsProvider._();

/// Showroom commands. Changes that alter which showrooms the caller works in
/// (create, activate, deactivate) also reload the session, so the switcher
/// and the router follow at once.

final class ShowroomAdminActionsProvider
    extends
        $FunctionalProvider<
          ShowroomAdminActions,
          ShowroomAdminActions,
          ShowroomAdminActions
        >
    with $Provider<ShowroomAdminActions> {
  /// Showroom commands. Changes that alter which showrooms the caller works in
  /// (create, activate, deactivate) also reload the session, so the switcher
  /// and the router follow at once.
  ShowroomAdminActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showroomAdminActionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showroomAdminActionsHash();

  @$internal
  @override
  $ProviderElement<ShowroomAdminActions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShowroomAdminActions create(Ref ref) {
    return showroomAdminActions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShowroomAdminActions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShowroomAdminActions>(value),
    );
  }
}

String _$showroomAdminActionsHash() =>
    r'319acff60887a1266476c354da89559c641fdb3e';
