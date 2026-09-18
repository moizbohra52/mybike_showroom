import 'package:flutter/material.dart';

/// User-selectable theme mode.
///
/// `system` follows the OS; the choice persists locally (see `ThemeController`
/// and `PreferenceStore`) so it survives restarts on every platform.
enum AppThemeMode {
  light('light', 'Light'),
  dark('dark', 'Dark'),
  system('system', 'System');

  const AppThemeMode(this.storageValue, this.label);

  /// Value persisted in preferences.
  final String storageValue;

  /// Human readable label for the theme switcher.
  final String label;

  /// Maps to Flutter's [ThemeMode].
  ThemeMode get materialThemeMode => switch (this) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  /// Icon used in the compact theme switcher.
  IconData get icon => switch (this) {
    AppThemeMode.light => Icons.light_mode_outlined,
    AppThemeMode.dark => Icons.dark_mode_outlined,
    AppThemeMode.system => Icons.brightness_auto_outlined,
  };

  /// Resolves a persisted value; unknown or missing values fall back to
  /// [AppThemeMode.system].
  static AppThemeMode fromStorage(String? value) {
    if (value == null || value.isEmpty) {
      return AppThemeMode.system;
    }
    for (final AppThemeMode mode in AppThemeMode.values) {
      if (mode.storageValue == value.toLowerCase()) {
        return mode;
      }
    }
    return AppThemeMode.system;
  }

  /// Next mode in the switcher cycle (system → light → dark → system).
  AppThemeMode get next => switch (this) {
    AppThemeMode.system => AppThemeMode.light,
    AppThemeMode.light => AppThemeMode.dark,
    AppThemeMode.dark => AppThemeMode.system,
  };
}
