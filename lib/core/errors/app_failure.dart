import 'package:mybike_showroom/core/utils/trace_code.dart';

/// Stable failure categories mapped from transport/database errors.
///
/// Technical detail (PostgREST codes, Dio error types) is translated into these
/// categories by `core/errors/error_mapper.dart` in Phase 3; the UI only ever
/// sees a friendly message plus a trace code.
enum AppFailureCode {
  network,
  timeout,
  server,
  auth,
  permission,
  notFound,
  validation,
  conflict,
  businessRule,
  cancelled,
  unknown,
}

/// Base class for every expected failure in the app.
sealed class AppFailure implements Exception {
  const AppFailure({
    required this.code,
    required this.message,
    this.traceCode,
    this.cause,
    this.stackTrace,
  });

  final AppFailureCode code;

  /// User-safe message — never contains stack traces, SQL or URLs.
  final String message;

  /// Short correlation id (also written to `app_error_log` from Phase 3).
  final String? traceCode;

  final Object? cause;
  final StackTrace? stackTrace;

  /// True when retrying the same action may succeed.
  bool get isRetryable =>
      code == AppFailureCode.network ||
      code == AppFailureCode.timeout ||
      code == AppFailureCode.server;

  /// Detailed description for logs and developer tooling.
  String get developerDescription =>
      '$runtimeType: $message (trace: ${traceCode ?? '-'})';

  @override
  String toString() => developerDescription;
}

/// Connectivity / DNS / socket problems.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.message = FailureMessages.network,
    super.traceCode,
    super.cause,
    super.stackTrace,
  }) : super(code: AppFailureCode.network);
}

/// The request exceeded the configured timeout.
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({
    super.message = FailureMessages.timeout,
    super.traceCode,
    super.cause,
    super.stackTrace,
  }) : super(code: AppFailureCode.timeout);
}

/// 5xx responses from Supabase / Edge Functions.
final class ServerFailure extends AppFailure {
  const ServerFailure({
    super.message = FailureMessages.server,
    this.statusCode,
    super.traceCode,
    super.cause,
    super.stackTrace,
  }) : super(code: AppFailureCode.server);

  final int? statusCode;
}

/// Authentication problems: bad credentials, expired or invalid session.
final class AuthFailure extends AppFailure {
  const AuthFailure({
    super.message = FailureMessages.auth,
    this.isSessionExpired = false,
    super.traceCode,
    super.cause,
    super.stackTrace,
  }) : super(code: AppFailureCode.auth);

  final bool isSessionExpired;
}

/// Authorisation problems: missing permission or RLS denied the row.
final class PermissionFailure extends AppFailure {
  const PermissionFailure({
    super.message = FailureMessages.permission,
    this.module,
    this.action,
    super.traceCode,
    super.cause,
    super.stackTrace,
  }) : super(code: AppFailureCode.permission);

  final String? module;
  final String? action;
}

/// The record/document does not exist (or is not visible to this user).
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    super.message = FailureMessages.notFound,
    super.traceCode,
    super.cause,
    super.stackTrace,
  }) : super(code: AppFailureCode.notFound);
}

/// Field-level validation problem. `fieldErrors` keys are form field names so
/// the form layer can render errors inline next to the offending input.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    super.message = FailureMessages.validation,
    this.fieldErrors = const <String, String>{},
    super.traceCode,
    super.cause,
    super.stackTrace,
  }) : super(code: AppFailureCode.validation);

  final Map<String, String> fieldErrors;

  /// True when specific fields carry errors.
  bool get hasFieldErrors => fieldErrors.isNotEmpty;
}

/// Unique-constraint / duplicate-record problem (e.g. duplicate VIN or invoice
/// number). `field` names the offending column when known.
final class ConflictFailure extends AppFailure {
  const ConflictFailure({
    super.message = FailureMessages.duplicate,
    this.field,
    super.traceCode,
    super.cause,
    super.stackTrace,
  }) : super(code: AppFailureCode.conflict);

  final String? field;
}

/// A business rule refused the operation (insufficient stock, locked period,
/// already reversed, …). These are expected outcomes, not bugs.
final class BusinessRuleFailure extends AppFailure {
  const BusinessRuleFailure({
    required super.message,
    this.ruleCode,
    super.traceCode,
    super.cause,
    super.stackTrace,
  }) : super(code: AppFailureCode.businessRule);

  final String? ruleCode;
}

/// The operation was cancelled (navigation away, CancelToken, dialog dismiss).
final class CancelledFailure extends AppFailure {
  const CancelledFailure({
    super.message = 'The operation was cancelled.',
    super.traceCode,
    super.cause,
    super.stackTrace,
  }) : super(code: AppFailureCode.cancelled);
}

/// Anything not classified above. Always carries a trace code so support can
/// correlate it with an `app_error_log` row.
final class UnknownFailure extends AppFailure {
  UnknownFailure({
    super.message = FailureMessages.unknown,
    super.cause,
    super.stackTrace,
    String? traceCode,
  }) : super(
         code: AppFailureCode.unknown,
         traceCode: traceCode ?? TraceCode.generate(),
       );
}

/// User-safe fallback messages per failure category.
abstract final class FailureMessages {
  static const String network =
      'No internet connection. Check your network and try again.';
  static const String timeout = 'The request took too long. Please try again.';
  static const String server =
      'The server could not process the request. Please try again in a moment.';
  static const String auth = 'Your session has expired. Please sign in again.';
  static const String invalidCredentials =
      'The email or password you entered is incorrect.';
  static const String permission =
      'You do not have permission to perform this action.';
  static const String showroomAccess =
      'You do not have access to this showroom.';
  static const String notFound = 'The requested record could not be found.';
  static const String validation = 'Please correct the highlighted fields.';
  static const String duplicate = 'This record already exists.';
  static const String unknown = 'Something went wrong. Please try again.';
  static const String insufficientStock =
      'Not enough stock available for this operation.';
  static const String periodLocked =
      'The accounting period is locked. Reopen it or choose another date.';
  static const String recordImmutable =
      'Posted entries cannot be changed. Create a reversal instead.';
}
