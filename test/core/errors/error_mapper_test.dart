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
}
