import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/core/config/env_config.dart';

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
}
