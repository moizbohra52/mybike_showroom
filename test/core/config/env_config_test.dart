import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/core/config/env_config.dart';

/// Base64url without padding, the encoding JWT segments use.
String base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

/// Builds an unsigned, JWT-shaped string with [payload] as its claims.
/// Only the shape matters to [EnvConfig.isServiceRoleKey]; these are not real
/// Supabase keys and are signed with nothing.
String fakeJwt(Map<String, Object?> payload) {
  final String header = base64UrlNoPad(
    utf8.encode(jsonEncode(<String, Object?>{'alg': 'HS256', 'typ': 'JWT'})),
  );
  final String claims = base64UrlNoPad(utf8.encode(jsonEncode(payload)));
  final String signature = base64UrlNoPad(utf8.encode('not-a-signature'));
  return '$header.$claims.$signature';
}

/// Claims shaped like a Supabase legacy API key for [role].
Map<String, Object?> legacyKeyClaims(String role) => <String, Object?>{
  'iss': 'supabase',
  'ref': 'test-project-ref',
  'role': role,
  'iat': 1700000000,
  'exp': 2000000000,
};

void main() {
  group('AppEnvironment.fromName', () {
    test('parses known names case-insensitively', () {
      expect(AppEnvironment.fromName('prod'), AppEnvironment.prod);
      expect(AppEnvironment.fromName('Production'), AppEnvironment.prod);
      expect(AppEnvironment.fromName('staging'), AppEnvironment.staging);
      expect(AppEnvironment.fromName('STAGE'), AppEnvironment.staging);
      expect(AppEnvironment.fromName('dev'), AppEnvironment.dev);
    });

    test('falls back to dev for unknown or empty values', () {
      expect(AppEnvironment.fromName(''), AppEnvironment.dev);
      expect(AppEnvironment.fromName('weird'), AppEnvironment.dev);
      expect(AppEnvironment.fromName('  dev  '), AppEnvironment.dev);
    });
  });

  group('EnvConfig.validate (development)', () {
    test('missing Supabase is a warning, not a blocker', () {
      final EnvValidation validation = const EnvConfig(
        environment: AppEnvironment.dev,
      ).validate();

      expect(validation.isValid, isTrue);
      expect(validation.hasWarnings, isTrue);
      expect(validation.warnings.join(' '), contains('SUPABASE_URL'));
      expect(validation.problems, isEmpty);
    });

    test('half-configured Supabase blocks startup', () {
      final EnvValidation validation = const EnvConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: 'https://abc.supabase.co',
      ).validate();

      expect(validation.isValid, isFalse);
      expect(validation.problems.join(' '), contains('together'));
    });

    test('https URL and paired key validate cleanly', () {
      final EnvValidation validation = const EnvConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: 'https://abc.supabase.co',
        supabaseAnonKey: 'anon-key',
      ).validate();

      expect(validation.isValid, isTrue);
      expect(validation.hasWarnings, isFalse);
    });

    test('remote plain-http Supabase URL is rejected', () {
      final EnvValidation validation = const EnvConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: 'http://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      ).validate();

      expect(validation.isValid, isFalse);
      expect(validation.problems.join(' '), contains('https://'));
    });

    test('localhost http is accepted for local development', () {
      final EnvValidation validation = const EnvConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: 'http://localhost:54321',
        supabaseAnonKey: 'anon-key',
      ).validate();

      expect(validation.isValid, isTrue);
    });

    test('malformed API base URL is rejected', () {
      final EnvValidation validation = const EnvConfig(
        environment: AppEnvironment.dev,
        apiBaseUrl: 'not-a-url',
      ).validate();

      expect(validation.isValid, isFalse);
      expect(validation.problems.join(' '), contains('API_BASE_URL'));
    });
  });

  group('EnvConfig.validate (production)', () {
    test('missing Supabase blocks startup', () {
      final EnvValidation validation = const EnvConfig(
        environment: AppEnvironment.prod,
      ).validate();

      expect(validation.isValid, isFalse);
      expect(
        validation.problems.join(' '),
        contains('required for production'),
      );
    });

    test('network logging is forbidden in production', () {
      final EnvValidation validation = const EnvConfig(
        environment: AppEnvironment.prod,
        supabaseUrl: 'https://abc.supabase.co',
        supabaseAnonKey: 'anon-key',
        enableNetworkLogs: true,
      ).validate();

      expect(validation.isValid, isFalse);
      expect(validation.problems.join(' '), contains('LOG_NETWORK'));
    });

    test('fully configured quiet build is valid', () {
      final EnvValidation validation = const EnvConfig(
        environment: AppEnvironment.prod,
        supabaseUrl: 'https://abc.supabase.co',
        supabaseAnonKey: 'anon-key',
        gitSha: 'a1b2c3d4e5f6',
      ).validate();

      expect(validation.isValid, isTrue);
      expect(validation.hasWarnings, isFalse);
    });
  });

  group('EnvConfig helpers', () {
    test('isSupabaseConfigured requires url and key together', () {
      const EnvConfig empty = EnvConfig(environment: AppEnvironment.dev);
      const EnvConfig full = EnvConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: 'https://abc.supabase.co',
        supabaseAnonKey: 'anon-key',
      );

      expect(empty.isSupabaseConfigured, isFalse);
      expect(full.isSupabaseConfigured, isTrue);
    });

    test('canLogNetwork is always false in production', () {
      const EnvConfig prod = EnvConfig(
        environment: AppEnvironment.prod,
        enableNetworkLogs: true,
      );

      expect(prod.canLogNetwork, isFalse);
    });

    test('describe contains environment label and short sha', () {
      const EnvConfig config = EnvConfig(
        environment: AppEnvironment.dev,
        gitSha: 'a1b2c3d4e5f6',
      );

      expect(config.describe, contains('Development'));
      expect(config.describe, contains('a1b2c3d'));
    });

    test('isSecureHttpUrl accepts only https and localhost http', () {
      expect(EnvConfig.isSecureHttpUrl('https://abc.supabase.co'), isTrue);
      expect(EnvConfig.isSecureHttpUrl('http://localhost:54321'), isTrue);
      expect(EnvConfig.isSecureHttpUrl('http://127.0.0.1:54321'), isTrue);
      expect(EnvConfig.isSecureHttpUrl('http://example.com'), isFalse);
      expect(EnvConfig.isSecureHttpUrl('ftp://example.com'), isFalse);
      expect(EnvConfig.isSecureHttpUrl('not a url'), isFalse);
    });
  });

  group('EnvConfig.fromDefines / fromEnvironment', () {
    test('fromDefines trims values and parses APP_ENV', () {
      final EnvConfig config = EnvConfig.fromDefines(
        appEnv: ' Production ',
        supabaseUrl: ' https://abc.supabase.co\n',
        supabaseAnonKey: '\tanon-key ',
        apiBaseUrl: ' https://abc.functions.supabase.co ',
        gitSha: ' a1b2c3d ',
        logNetwork: true,
      );

      expect(config.environment, AppEnvironment.prod);
      expect(config.supabaseUrl, 'https://abc.supabase.co');
      expect(config.supabaseAnonKey, 'anon-key');
      expect(config.apiBaseUrl, 'https://abc.functions.supabase.co');
      expect(config.gitSha, 'a1b2c3d');
      expect(config.enableNetworkLogs, isTrue);
    });

    test('fromDefines falls back to local for a blank GIT_SHA', () {
      final EnvConfig config = EnvConfig.fromDefines(
        appEnv: 'dev',
        supabaseUrl: '',
        supabaseAnonKey: '',
        apiBaseUrl: '',
        gitSha: '   ',
        logNetwork: false,
      );

      expect(config.gitSha, 'local');
    });

    // `flutter test` is run without --dart-define, so every define takes its
    // declared default. This pins those defaults to the safe values.
    test('fromEnvironment uses safe defaults when no define is passed', () {
      final EnvConfig config = EnvConfig.fromEnvironment();

      expect(config.environment, AppEnvironment.dev);
      expect(config.supabaseUrl, isEmpty);
      expect(config.supabaseAnonKey, isEmpty);
      expect(config.apiBaseUrl, isEmpty);
      expect(config.gitSha, 'local');
      expect(config.enableNetworkLogs, isFalse);
      expect(config.isSupabaseConfigured, isFalse);
    });
  });

  group('EnvConfig.isServiceRoleKey', () {
    test('legacy JWT with role service_role is detected', () {
      expect(
        EnvConfig.isServiceRoleKey(fakeJwt(legacyKeyClaims('service_role'))),
        isTrue,
      );
    });

    test('detection tolerates surrounding whitespace and padded payloads', () {
      final String header = base64UrlNoPad(utf8.encode('{"alg":"HS256"}'));
      final String paddedClaims = base64Url.encode(
        utf8.encode(jsonEncode(<String, Object?>{'role': 'service_role'})),
      );

      expect(paddedClaims, endsWith('='));
      expect(EnvConfig.isServiceRoleKey('$header.$paddedClaims.sig'), isTrue);
      expect(
        EnvConfig.isServiceRoleKey(
          '  ${fakeJwt(legacyKeyClaims('service_role'))}\n',
        ),
        isTrue,
      );
    });

    test('legacy anon JWT is allowed', () {
      expect(
        EnvConfig.isServiceRoleKey(fakeJwt(legacyKeyClaims('anon'))),
        isFalse,
      );
    });

    test('JWT without a service_role claim is allowed', () {
      expect(
        EnvConfig.isServiceRoleKey(
          fakeJwt(<String, Object?>{'sub': 'service_role'}),
        ),
        isFalse,
      );
      expect(
        EnvConfig.isServiceRoleKey(
          fakeJwt(<String, Object?>{
            'role': <String>['service_role'],
          }),
        ),
        isFalse,
      );
    });

    test('sb_secret_ keys are detected', () {
      expect(EnvConfig.isServiceRoleKey('sb_secret_testOnlyValue123'), isTrue);
      expect(
        EnvConfig.isServiceRoleKey(' sb_secret_testOnlyValue123 '),
        isTrue,
      );
    });

    test('sb_publishable_ keys are allowed', () {
      expect(
        EnvConfig.isServiceRoleKey('sb_publishable_testOnlyValue123'),
        isFalse,
      );
    });

    test('garbage input is allowed and never throws', () {
      final String header = base64UrlNoPad(utf8.encode('{"alg":"HS256"}'));
      final List<String> garbage = <String>[
        '',
        '   ',
        'anon-key',
        'not.a.jwt',
        'a.b',
        'a.b.c.d',
        '$header..sig',
        '$header.%%%not-base64%%%.sig',
        // length % 4 == 1 can never be valid base64.
        '$header.abcde.sig',
        // Valid base64, invalid UTF-8.
        '$header.${base64UrlNoPad(<int>[0xff, 0xfe, 0xfd])}.sig',
        // Valid UTF-8, not JSON.
        '$header.${base64UrlNoPad(utf8.encode('role=service_role'))}.sig',
        // JSON, but not an object.
        '$header.${base64UrlNoPad(utf8.encode('["service_role"]'))}.sig',
        '$header.${base64UrlNoPad(utf8.encode('"service_role"'))}.sig',
        '$header.${base64UrlNoPad(utf8.encode('null'))}.sig',
      ];

      for (final String value in garbage) {
        expect(
          () => EnvConfig.isServiceRoleKey(value),
          returnsNormally,
          reason: value,
        );
        expect(EnvConfig.isServiceRoleKey(value), isFalse, reason: value);
      }
    });
  });

  group('EnvConfig.validate (service role / secret key guard)', () {
    test('legacy service_role JWT blocks startup without echoing the key', () {
      final String serviceRoleJwt = fakeJwt(legacyKeyClaims('service_role'));
      final EnvValidation validation = EnvConfig(
        environment: AppEnvironment.dev,
        supabaseUrl: 'https://abc.supabase.co',
        supabaseAnonKey: serviceRoleJwt,
      ).validate();

      expect(validation.isValid, isFalse);
      final String problems = validation.problems.join(' ');
      expect(problems, contains('service_role'));
      expect(problems, contains('Never ship'));
      expect(problems, contains('G4'));
      expect(problems, isNot(contains(serviceRoleJwt)));
    });

    test('sb_secret_ key blocks startup in every environment', () {
      for (final AppEnvironment environment in AppEnvironment.values) {
        final EnvValidation validation = EnvConfig(
          environment: environment,
          supabaseUrl: 'https://abc.supabase.co',
          supabaseAnonKey: 'sb_secret_testOnlyValue123',
        ).validate();

        expect(validation.isValid, isFalse, reason: environment.name);
        expect(
          validation.problems.join(' '),
          contains('G4'),
          reason: environment.name,
        );
      }
    });

    test('legacy anon JWT validates cleanly', () {
      final EnvValidation validation = EnvConfig(
        environment: AppEnvironment.prod,
        supabaseUrl: 'https://abc.supabase.co',
        supabaseAnonKey: fakeJwt(legacyKeyClaims('anon')),
      ).validate();

      expect(validation.isValid, isTrue);
      expect(validation.problems, isEmpty);
    });

    test('sb_publishable_ key validates cleanly', () {
      final EnvValidation validation = const EnvConfig(
        environment: AppEnvironment.prod,
        supabaseUrl: 'https://abc.supabase.co',
        supabaseAnonKey: 'sb_publishable_testOnlyValue123',
      ).validate();

      expect(validation.isValid, isTrue);
      expect(validation.problems, isEmpty);
    });
  });
}
