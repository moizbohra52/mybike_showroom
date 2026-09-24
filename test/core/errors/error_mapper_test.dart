import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/core/errors/app_failure.dart';
import 'package:mybike_showroom/core/errors/error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('wrong password becomes the friendly invalid-credentials message', () {
    final AppFailure failure = ErrorMapper.map(
      const AuthApiException('Invalid login credentials', statusCode: '400', code: 'invalid_credentials'),
    );
    expect(failure, isA<AuthFailure>());
    expect(failure.message, FailureMessages.invalidCredentials);
  });

  test('rate limiting is explained without technical text', () {
    final AppFailure failure = ErrorMapper.map(const AuthApiException('x', statusCode: '429'));
    expect(failure.message, contains('Too many attempts'));
  });

  test('offline sign-in is a network failure', () {
    expect(ErrorMapper.map(AuthRetryableFetchException()), isA<NetworkFailure>());
  });

  test('RLS / privilege denial is a permission failure', () {
    expect(
      ErrorMapper.map(const PostgrestException(message: 'permission denied for table showrooms', code: '42501')),
      isA<PermissionFailure>(),
    );
  });

  test('MyBike SQLSTATEs map to their business-rule message', () {
    final AppFailure failure = ErrorMapper.map(const PostgrestException(message: 'raw', code: 'MB002'));
    expect(failure, isA<BusinessRuleFailure>());
    expect(failure.message, 'This financial year is closed.');
    expect((failure as BusinessRuleFailure).ruleCode, 'MB002');
  });

  test('expired JWT asks for a new sign-in', () {
    final AppFailure failure = ErrorMapper.map(const PostgrestException(message: 'JWT expired', code: 'PGRST301'));
    expect(failure, isA<AuthFailure>());
    expect((failure as AuthFailure).isSessionExpired, isTrue);
  });

  test('timeouts and unknown errors are safe, the latter with a trace code', () {
    expect(ErrorMapper.map(TimeoutException('slow')), isA<TimeoutFailure>());
    final AppFailure unknown = ErrorMapper.map(StateError('select * from secrets'));
    expect(unknown, isA<UnknownFailure>());
    expect(unknown.message, isNot(contains('select')));
    expect(unknown.traceCode, isNotNull);
  });

  test('Edge Function errors map by status; only 4xx messages are shown', () {
    Map<String, Object?> body(String message) => <String, Object?>{
          'error': <String, Object?>{'code': 'x', 'message': message},
        };
    final AppFailure conflict = ErrorMapper.map(FunctionException(status: 409, details: body('Email already exists.')));
    expect(conflict, isA<ConflictFailure>());
    expect(conflict.message, 'Email already exists.');
    expect(ErrorMapper.map(FunctionException(status: 400, details: body('Weak password.'))).message, 'Weak password.');
    expect(ErrorMapper.map(const FunctionException(status: 403)), isA<PermissionFailure>());
    expect((ErrorMapper.map(const FunctionException(status: 401)) as AuthFailure).isSessionExpired, isTrue);
    final AppFailure server = ErrorMapper.map(FunctionException(status: 500, details: body('stack trace here')));
    expect(server, isA<ServerFailure>());
    expect(server.message, isNot(contains('stack')));
  });

  test('a referenced row (FK restrict) is explained as in use', () {
    final AppFailure failure = ErrorMapper.map(const PostgrestException(message: 'raw', code: '23001'));
    expect(failure.message, FailureMessages.inUse);
  });

  test('a delete that RLS filtered to nothing is a permission failure', () {
    expect(() => ErrorMapper.requireChanged(const <Object?>[]), throwsA(isA<PermissionFailure>()));
    ErrorMapper.requireChanged(const <Object?>[1]);
  });
}
