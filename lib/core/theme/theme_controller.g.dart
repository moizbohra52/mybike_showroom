// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the light/dark/system selection and persists every change.

@ProviderFor(ThemeController)
final themeControllerProvider = ThemeControllerProvider._();

/// Owns the light/dark/system selection and persists every change.
final class ThemeControllerProvider
    extends $NotifierProvider<ThemeController, AppThemeMode> {
  /// Owns the light/dark/system selection and persists every change.
  ThemeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeControllerHash();

  @$internal
  @override
  ThemeController create() => ThemeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppThemeMode>(value),
    );
  }
}

String _$themeControllerHash() => r'2eeba623d05c8749d0a325fff9daacd02a75335e';

/// Owns the light/dark/system selection and persists every change.

abstract class _$ThemeController extends $Notifier<AppThemeMode> {
  AppThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppThemeMode, AppThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppThemeMode, AppThemeMode>,
              AppThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
