import 'package:flutter/foundation.dart';

/// Centralises platform capability questions so features never branch on
/// `dart:io` or scattered `kIsWeb` checks (docs/phase-00/03-architecture.md §10).
abstract final class PlatformTarget {
  /// Web (compiled to JavaScript/WASM).
  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// Phone/tablet form factors (touch-first UI, bottom navigation).
  static bool get isMobile => isAndroid || isIOS;

  /// Desktop form factors (pointer + keyboard, sidebar navigation).
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  /// Firebase Cloud Messaging is unavailable on Windows desktop.
  ///
  /// The in-app realtime notification centre is therefore the source of truth
  /// on every platform, with FCM as an additional delivery channel here.
  static bool get supportsPushNotifications => isAndroid || isIOS || isWeb;

  /// Secure storage is available on all four targets; on web the page must be
  /// served over HTTPS (or localhost) for it to function.
  static bool get secureStorageRequiresHttps => isWeb;

  /// Human readable platform name used in audit/error records.
  static String get label {
    if (isWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  /// Short form used in compact UI badges.
  static String get shortLabel => switch (label) {
    'windows' => 'WIN',
    'android' => 'AND',
    'ios' => 'iOS',
    'macos' => 'MAC',
    'linux' => 'LNX',
    _ => 'WEB',
  };
}
