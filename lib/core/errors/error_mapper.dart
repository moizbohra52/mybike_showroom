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
    'MB012': 'The invoice prefix cannot change: document numbers were already issued with it.',
    'MB020': 'System roles cannot be renamed, deactivated or deleted.',
    'MB021': 'This permission cannot be changed for that role.',
    'MB022': 'Super Admin can only be assigned for all showrooms.',
    'MB030': 'The fuel type of this variant cannot change: vehicles of it are registered.',
    'MB041': 'This vehicle has no active reservation.',
    'MB045': 'This transfer is not awaiting receipt.',
    'MB046': 'This stock movement is not supported yet.',
  };

  /// Unique constraints with a message that names the duplicate
  /// (`field` = the form field to highlight).
  static const Map<String, ({String field, String message})> uniqueConstraints = <String, ({String field, String message})>{
    'vehicle_brands_name_key': (field: 'name', message: 'A brand with this name already exists.'),
    'vehicle_brands_code_key': (field: 'code', message: 'A brand with this code already exists.'),
    'vehicle_models_brand_name_key': (field: 'name', message: 'This brand already has a model with this name.'),
    'vehicle_variants_model_name_key': (field: 'name', message: 'This model already has a variant with this name.'),
    'uq_vehicles_vin_active': (field: 'vin', message: 'This VIN is already registered.'),
    'uq_vehicles_chassis_active': (field: 'chassis_number', message: 'This chassis number is already registered.'),
    'uq_vehicles_engine_active': (field: 'engine_number', message: 'This engine number is already registered.'),
    'uq_vehicles_motor_active': (field: 'motor_number', message: 'This motor number is already registered.'),
    'uq_vehicles_battery_active': (field: 'battery_number', message: 'This battery number is already registered.'),
    'showrooms_code_key': (field: 'code', message: 'Another showroom already uses this code.'),
    'showrooms_invoice_prefix_key': (field: 'invoice_prefix', message: 'Another showroom already uses this invoice prefix.'),
    'bank_accounts_showroom_number_key': (field: 'account_number', message: 'This account number is already added.'),
    'profiles_employee_code_key': (field: 'employee_code', message: 'Another user already has this employee code.'),
  };

  /// Runs [call] and converts every SDK error into an [AppFailure].
  static Future<T> guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (error, stackTrace) {
      throw map(error, stackTrace);
    }
  }

  /// RLS turns a refused UPDATE / DELETE into "0 rows": report it as denied.
  static void requireChanged(List<Object?> rows) {
    if (rows.isEmpty) {
      throw const PermissionFailure();
    }
  }

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
    if (error is FunctionException) {
      return mapFunction(error, stackTrace);
    }
    return UnknownFailure(cause: error, stackTrace: stackTrace);
  }

  /// Edge Function errors. MyBike functions answer `{error: {code, message}}`
  /// with messages written for the user; only 4xx messages are shown.
  static AppFailure mapFunction(FunctionException error, [StackTrace? stackTrace]) {
    final Object? details = error.details;
    final Object? body = details is Map ? details['error'] : null;
    final String? message = body is Map && body['message'] is String ? body['message'] as String : null;
    return switch (error.status) {
      400 || 422 => ValidationFailure(message: message ?? FailureMessages.validation, cause: error, stackTrace: stackTrace),
      401 => AuthFailure(isSessionExpired: true, cause: error, stackTrace: stackTrace),
      403 => PermissionFailure(cause: error, stackTrace: stackTrace),
      404 => NotFoundFailure(cause: error, stackTrace: stackTrace),
      409 => ConflictFailure(message: message ?? FailureMessages.duplicate, cause: error, stackTrace: stackTrace),
      >= 500 => ServerFailure(statusCode: error.status, cause: error, stackTrace: stackTrace),
      _ => UnknownFailure(cause: error, stackTrace: stackTrace),
    };
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
    if (code == 'MB040') {
      // One code, many scenarios (receive/reserve/transfer/damage/adjust each
      // has its own precise, already user-safe message written in SQL) — pass
      // it through instead of blurring every case into one static string.
      return BusinessRuleFailure(message: error.message, ruleCode: code, cause: error, stackTrace: stackTrace);
    }
    return switch (code) {
      '42501' => PermissionFailure(cause: error, stackTrace: stackTrace),
      'PGRST301' || 'PGRST303' =>
        AuthFailure(isSessionExpired: true, cause: error, stackTrace: stackTrace),
      '23505' => mapUnique(error, stackTrace),
      // Foreign key RESTRICT / NO ACTION: the row is still referenced.
      '23001' || '23503' => BusinessRuleFailure(message: FailureMessages.inUse, ruleCode: code, cause: error, stackTrace: stackTrace),
      '23514' || '23502' || '22P02' => ValidationFailure(cause: error, stackTrace: stackTrace),
      'PGRST116' => NotFoundFailure(cause: error, stackTrace: stackTrace),
      _ => UnknownFailure(cause: error, stackTrace: stackTrace),
    };
  }

  /// Names the duplicate when the constraint is known (PostgreSQL puts its
  /// name in the message); otherwise the generic duplicate message.
  static ConflictFailure mapUnique(PostgrestException error, [StackTrace? stackTrace]) {
    for (final MapEntry<String, ({String field, String message})> entry in uniqueConstraints.entries) {
      if (error.message.contains('"${entry.key}"')) {
        return ConflictFailure(message: entry.value.message, field: entry.value.field, cause: error, stackTrace: stackTrace);
      }
    }
    return ConflictFailure(cause: error, stackTrace: stackTrace);
  }
}
