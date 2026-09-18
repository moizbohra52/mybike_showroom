import 'package:flutter_test/flutter_test.dart';
import 'package:mybike_showroom/core/config/env_config.dart';

void main() {
  group('AppEnvironment.fromName', () {
    test('parses known names and falls back to dev', () {
      expect(AppEnvironment.fromName('prod'), AppEnvironment.prod);
      expect(AppEnvironment.fromName('PRODUCTION'), AppEnvironment.prod);
      expect(AppEnvironment.fromName('staging'), AppEnvironment.staging);
      expect(AppEnvironment.fromName('dev'), AppEnvironment.dev);
      expect(AppEnvironment.fromName('nonsense'), AppEnvironment.dev);
    });
  });

  group('EnvConfig URL validation', () {
    test('accepts https and localhost http only', () {
      expect(EnvConfig.isSecureHttpUrl('https://abc.supabase.co'), isTrue);
      expect(EnvConfig.isSecureHttpUrl('http://localhost:54321'), isTrue);
      expect(EnvConfig.isSecureHttpUrl('http://abc.supabase.co'), isFalse);
      expect(EnvConfig.isSecureHttpUrl('ftp://x'), isFalse);
      expect(EnvConfig.isSecureHttpUrl('not a url'), isFalse);
    });

    test('dev build with missing Supabase warns instead of failing', () {
      const EnvConfig config = EnvConfig(environment: AppEnvironment.dev);
      final EnvValidation validation = config.validate();
      expect(validation.isValid, isTrue);
      expect(validation.hasWarnings, isTrue);
    });

    test('prod build without Supabase is blocking', () {
      const EnvConfig config = EnvConfig(environment: AppEnvironment.prod);
      final EnvValidation validation = config.validate();
      expect(validation.isValid, isFalse);
      expect(validation.problems, isNotEmpty);
    });

    test('network logging is forbidden in production', () {
      const EnvConfig config = EnvConfig(
        environment: AppEnvironment.prod,
        supabaseUrl: 'https://abc.supabase.co',
        supabaseAnonKey: 'anon',
        enableNetworkLogs: true,
      );
      expect(config.validate().isValid, isFalse);
    });
  });
}
