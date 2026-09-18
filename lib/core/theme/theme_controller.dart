import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mybike_showroom/core/constants/storage_keys.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_controller.g.dart';

/// Theme mode restored during bootstrap, before the first frame.
///
/// `main()` reads the persisted value from [PreferenceStore] and overrides this
/// provider, which keeps [ThemeController] synchronous — `MaterialApp` needs a
/// resolved [AppThemeMode] immediately (no flash of the wrong theme).
final Provider<AppThemeMode> bootstrapThemeModeProvider =
    Provider<AppThemeMode>((Ref ref) {
      throw StateError(
        'bootstrapThemeModeProvider must be overridden in ProviderScope '
        '(see lib/main.dart) before it is read.',
      );
    });

/// Owns the light/dark/system selection and persists every change.
@Riverpod(keepAlive: true)
class ThemeController extends _$ThemeController {
  @override
  AppThemeMode build() => ref.watch(bootstrapThemeModeProvider);

  /// Applies a mode and persists it locally.
  Future<void> setMode(AppThemeMode mode) async {
    if (mode != state) {
      state = mode;
    }
    await ref
        .read(preferenceStoreProvider)
        .writeString(StorageKeys.themeMode, mode.storageValue);
  }

  /// Cycles system → light → dark → system (used by the compact switcher).
  Future<void> cycleMode() => setMode(state.next);

  /// Reloads the persisted value (used after a settings import, Phase 6+).
  Future<void> reloadFromStorage() async {
    final String? stored = await ref
        .read(preferenceStoreProvider)
        .readString(StorageKeys.themeMode);
    state = AppThemeMode.fromStorage(stored);
  }
}
