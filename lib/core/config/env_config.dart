/// Build environment classification.
enum AppEnvironment {
  dev,
  staging,
  prod;

  /// Parses the `APP_ENV` build define. Unknown values fall back to [dev] so a
  /// mis-typed define can never silently enable production behaviour.
  static AppEnvironment fromName(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'prod' || 'production' => AppEnvironment.prod,
      'staging' || 'stage' => AppEnvironment.staging,
      _ => AppEnvironment.dev,
    };
  }

  bool get isDev => this == AppEnvironment.dev;
  bool get isStaging => this == AppEnvironment.staging;
  bool get isProduction => this == AppEnvironment.prod;

  String get label => switch (this) {
    AppEnvironment.dev => 'Development',
    AppEnvironment.staging => 'Staging',
    AppEnvironment.prod => 'Production',
  };
}

/// Outcome of [EnvConfig.validate]: blocking [problems] and non-blocking
/// [warnings]. The app refuses to start when `problems` is not empty so a
/// misconfigured build can never reach a user.
class EnvValidation {
  const EnvValidation({required this.problems, required this.warnings});

  final List<String> problems;
  final List<String> warnings;

  bool get isValid => problems.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// Runtime configuration read from build-time defines.
///
/// Values are injected with `--dart-define` / `--dart-define-from-file` so no
/// secret is ever parsed from a bundled asset:
///
/// ```bash
/// flutter run -d windows --dart-define-from-file=config/dev.json
/// ```
///
/// Only the Supabase anon/publishable key may reach the client — the
/// `service_role` key lives exclusively in Edge Function secrets
/// (see docs/phase-00/04-multishowroom-security.md §9).
class EnvConfig {
  const EnvConfig({
    required this.environment,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.apiBaseUrl = '',
    this.gitSha = 'local',
    this.enableNetworkLogs = false,
  });

  /// Reads the defines compiled into this build.
  factory EnvConfig.fromEnvironment() {
    return EnvConfig(
      environment: AppEnvironment.fromName(
        const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
      ),
    );
  }

  /// The configuration of the running app.
  static final EnvConfig current = EnvConfig.fromEnvironment();

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String apiBaseUrl;
  final String gitSha;
  final bool enableNetworkLogs;

  /// True when both Supabase values are present. Supabase is only *required*
  /// from Phase 3/5 onward (database + auth); Phase 1 runs without it.
  bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Network logging is allowed only outside production builds.
  bool get canLogNetwork => enableNetworkLogs && !environment.isProduction;

  /// True when a Dio base URL has been provided.
  bool get hasApiBaseUrl => apiBaseUrl.isNotEmpty;

  /// Short label used in the About screen and debug banners.
  String get describe =>
      '${environment.label} · ${gitSha.substring(0, gitSha.length > 7 ? 7 : gitSha.length)}';

  /// Validates the configuration for the active environment.
  EnvValidation validate() {
    final List<String> problems = <String>[];
    final List<String> warnings = <String>[];

    final bool hasUrl = supabaseUrl.isNotEmpty;
    final bool hasKey = supabaseAnonKey.isNotEmpty;

    if (hasUrl != hasKey) {
      problems.add(
        'Incomplete Supabase configuration: both SUPABASE_URL and '
        'SUPABASE_ANON_KEY must be provided together.',
      );
    }

    if (hasUrl && !isSecureHttpUrl(supabaseUrl)) {
      problems.add(
        'SUPABASE_URL must be an https:// URL (localhost is allowed for local '
        'development). Received: $supabaseUrl',
      );
    }

    if (hasApiBaseUrl && !isHttpUrl(apiBaseUrl)) {
      problems.add(
        'API_BASE_URL must be an http(s):// URL. Received: $apiBaseUrl',
      );
    }

    if (!isSupabaseConfigured) {
      if (environment.isProduction) {
        problems.add(
          'SUPABASE_URL and SUPABASE_ANON_KEY are required for production builds.',
        );
      } else {
        warnings.add(
          'Supabase is not configured yet. Database, auth and storage phases '
          '(3–5) require SUPABASE_URL and SUPABASE_ANON_KEY.',
        );
      }
    }

    if (environment.isProduction && enableNetworkLogs) {
      problems.add(
        'LOG_NETWORK must be disabled in production: request payloads may '
        'contain customer and financial data.',
      );
    }

    return EnvValidation(problems: problems, warnings: warnings);
  }

  /// Accepts `https://` URLs plus `http://localhost` for local development.
  static bool isSecureHttpUrl(String value) {
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }
    if (uri.scheme == 'https') {
      return true;
    }
    return uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
  }

  /// Accepts any well-formed `http`/`https` URL.
  static bool isHttpUrl(String value) {
    final Uri? uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
