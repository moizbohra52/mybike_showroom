import 'dart:async';

import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates SDK / database errors into [AppFailure]s with user-safe messages.
///
/// Raw technical text (SQL, stack traces, URLs) never reaches the UI; anything
/// unrecognised becomes an [UnknownFailure] carrying a trace code.
abstract final class ErrorMapper {
  /// Friendly messages for the MyBike SQLSTATEs (docs/phase-03/README.md §5).
  static const Map<String, String> databaseRuleMessages = <String, String>{
    'MB001': 'No financial year is set up for this date.',
    'MB002': 'This financial year is closed.',
    'MB003': 'Document numbering is not set up for this showroom yet.',
    'MB004': 'The numbering series for this document is full. Ask an administrator to start a new series.',
    'MB010': 'The accounting period does not match its financial year.',
    'MB011': 'Document numbering cannot be changed this way.',
    'MB020': 'System roles cannot be renamed, deactivated or deleted.',
    'MB021': 'This permission cannot be granted to that role.',
    'MB022': 'Super Admin can only be assigned for all showrooms.',
  };

  static AppFailure map(Object error, [StackTrace? stackTrace]) {
    if (error is AppFailure) {
      return error;
    }
    if (error is TimeoutException) {
      return TimeoutFailure(cause: error, stackTrace: stackTrace);
    }
    if (error is AuthRetryableFetchException) {
      return NetworkFailure(cause: error, stackTrace: stackTrace);
    }
    if (error is AuthException) {
      return mapAuth(error, stackTrace);
    }
    if (error is PostgrestException) {
      return mapPostgrest(error, stackTrace);
    }
    return UnknownFailure(cause: error, stackTrace: stackTrace);
  }

  static AppFailure mapAuth(AuthException error, [StackTrace? stackTrace]) {
    final String code = error.code ?? '';
    final String message = switch (code) {
      'invalid_credentials' => FailureMessages.invalidCredentials,
      'email_not_confirmed' => 'Your email address is not confirmed yet. Contact your administrator.',
      'user_banned' => FailureMessages.accountDisabled,
      'over_request_rate_limit' || 'over_email_send_rate_limit' =>
        'Too many attempts. Wait a minute and try again.',
      _ when error.statusCode == '429' => 'Too many attempts. Wait a minute and try again.',
      _ => FailureMessages.auth,
    };
    return AuthFailure(
      message: message,
      isSessionExpired: code == 'session_not_found' ||
          code == 'refresh_token_not_found' ||
          code == 'session_expired',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static AppFailure mapPostgrest(PostgrestException error, [StackTrace? stackTrace]) {
    final String code = error.code ?? '';
    if (databaseRuleMessages.containsKey(code)) {
      return BusinessRuleFailure(
        message: databaseRuleMessages[code]!,
        ruleCode: code,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return switch (code) {
      '42501' => PermissionFailure(cause: error, stackTrace: stackTrace),
      'PGRST301' || 'PGRST303' =>
        AuthFailure(isSessionExpired: true, cause: error, stackTrace: stackTrace),
      '23505' => ConflictFailure(cause: error, stackTrace: stackTrace),
      '23514' || '23502' || '22P02' => ValidationFailure(cause: error, stackTrace: stackTrace),
      'PGRST116' => NotFoundFailure(cause: error, stackTrace: stackTrace),
      _ => UnknownFailure(cause: error, stackTrace: stackTrace),
    };
  }
}
