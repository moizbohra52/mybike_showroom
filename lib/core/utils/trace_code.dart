import 'dart:math';

/// Generates short, human-readable correlation codes (e.g. `MB-7F3A2C91`).
///
/// Used to link a user-visible error to an `app_error_log` row without exposing
/// internals. Never used for security decisions.
abstract final class TraceCode {
  static const String prefix = 'MB';

  static final Random random = Random();

  /// Creates a new non-sequential trace code.
  static String generate() {
    final int value = random.nextInt(0x7FFFFFFF);
    return '$prefix-${value.toRadixString(16).toUpperCase().padLeft(8, '0')}';
  }
}
