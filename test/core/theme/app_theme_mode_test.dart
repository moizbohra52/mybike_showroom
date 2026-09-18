import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';

void main() {
  group('AppThemeMode.fromStorage', () {
    test('missing value falls back to system', () {
      expect(AppThemeMode.fromStorage(null), AppThemeMode.system);
      expect(AppThemeMode.fromStorage(''), AppThemeMode.system);
    });

    test('parses persisted values case-insensitively', () {
      expect(AppThemeMode.fromStorage('light'), AppThemeMode.light);
      expect(AppThemeMode.fromStorage('DARK'), AppThemeMode.dark);
      expect(AppThemeMode.fromStorage('System'), AppThemeMode.system);
    });

    test('unknown value falls back to system', () {
      expect(AppThemeMode.fromStorage('neon'), AppThemeMode.system);
    });
  });

  group('AppThemeMode cycle', () {
    test('cycles system → light → dark → system', () {
      AppThemeMode mode = AppThemeMode.system;
      mode = mode.next;
      expect(mode, AppThemeMode.light);
      mode = mode.next;
      expect(mode, AppThemeMode.dark);
      mode = mode.next;
      expect(mode, AppThemeMode.system);
    });
  });

  group('AppThemeMode mapping', () {
    test('maps to material ThemeMode', () {
      expect(AppThemeMode.light.materialThemeMode, ThemeMode.light);
      expect(AppThemeMode.dark.materialThemeMode, ThemeMode.dark);
      expect(AppThemeMode.system.materialThemeMode, ThemeMode.system);
    });

    test('storage values are unique and non-empty', () {
      final Set<String> values = AppThemeMode.values
          .map((AppThemeMode mode) => mode.storageValue)
          .toSet();
      expect(values.length, AppThemeMode.values.length);
      for (final AppThemeMode mode in AppThemeMode.values) {
        expect(mode.storageValue, isNotEmpty);
        expect(mode.label, isNotEmpty);
      }
    });

    test('icons are unique per mode', () {
      final Set<IconData> icons = AppThemeMode.values
          .map((AppThemeMode mode) => mode.icon)
          .toSet();
      expect(icons.length, AppThemeMode.values.length);
    });
  });
}
