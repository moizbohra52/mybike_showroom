// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Permissions in the current showroom context; empty unless signed in with a
/// showroom (or ALL SHOWROOMS) selected. UI gating only — RLS decides.

@ProviderFor(currentPermissions)
final currentPermissionsProvider = CurrentPermissionsProvider._();

/// Permissions in the current showroom context; empty unless signed in with a
/// showroom (or ALL SHOWROOMS) selected. UI gating only — RLS decides.

final class CurrentPermissionsProvider
    extends $FunctionalProvider<Set<String>, Set<String>, Set<String>>
    with $Provider<Set<String>> {
  /// Permissions in the current showroom context; empty unless signed in with a
  /// showroom (or ALL SHOWROOMS) selected. UI gating only — RLS decides.
  CurrentPermissionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentPermissionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentPermissionsHash();

  @$internal
  @override
  $ProviderElement<Set<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<String> create(Ref ref) {
    return currentPermissions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$currentPermissionsHash() =>
    r'2cc534a84734af9c2c692d76eed5972582944833';

/// The working showroom (or ALL SHOWROOMS); `null` until chosen. Showroom-
/// scoped screens watch this so switching showroom reloads their data.

@ProviderFor(currentSelection)
final currentSelectionProvider = CurrentSelectionProvider._();

/// The working showroom (or ALL SHOWROOMS); `null` until chosen. Showroom-
/// scoped screens watch this so switching showroom reloads their data.

final class CurrentSelectionProvider
    extends
        $FunctionalProvider<
          ShowroomSelection?,
          ShowroomSelection?,
          ShowroomSelection?
        >
    with $Provider<ShowroomSelection?> {
  /// The working showroom (or ALL SHOWROOMS); `null` until chosen. Showroom-
  /// scoped screens watch this so switching showroom reloads their data.
  CurrentSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSelectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSelectionHash();

  @$internal
  @override
  $ProviderElement<ShowroomSelection?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShowroomSelection? create(Ref ref) {
    return currentSelection(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShowroomSelection? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShowroomSelection?>(value),
    );
  }
}

String _$currentSelectionHash() => r'e11f3a5c8b0d1bef01cbd2d2cdee1e9247e54474';

/// Loads the session after sign-in / app start, keeps the showroom choice and
/// clears everything on sign-out.

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerProvider._();

/// Loads the session after sign-in / app start, keeps the showroom choice and
/// clears everything on sign-out.
final class SessionControllerProvider
    extends $AsyncNotifierProvider<SessionController, SessionState> {
  /// Loads the session after sign-in / app start, keeps the showroom choice and
  /// clears everything on sign-out.
  SessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionControllerHash();

  @$internal
  @override
  SessionController create() => SessionController();
}

String _$sessionControllerHash() => r'04cb867c44d5c87ddda761790eaff0c6605f02f5';

/// Loads the session after sign-in / app start, keeps the showroom choice and
/// clears everything on sign-out.

abstract class _$SessionController extends $AsyncNotifier<SessionState> {
  FutureOr<SessionState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<SessionState>, SessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<SessionState>, SessionState>,
              AsyncValue<SessionState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
