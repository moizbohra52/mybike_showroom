import 'dart:convert';

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
/// Templates for the define files live in `config/*.example.json` (see
/// `config/README.md`); the real `config/<env>.json` files are git-ignored.
///
/// Only the Supabase anon/publishable key may reach the client — the
/// `service_role` / secret key lives exclusively in Edge Function secrets
/// (ground rule G4, docs/phase-00/04-multishowroom-security.md §9).
/// [validate] rejects a build that was given one by mistake.
class EnvConfig {
  const EnvConfig({
    required this.environment,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.apiBaseUrl = '',
    this.gitSha = 'local',
    this.enableNetworkLogs = false,
  });

  /// Reads the defines compiled into this build:
  ///
  /// | Define              | Field               | Default   |
  /// |---------------------|---------------------|-----------|
  /// | `APP_ENV`           | [environment]       | `dev`     |
  /// | `SUPABASE_URL`      | [supabaseUrl]       | empty     |
  /// | `SUPABASE_ANON_KEY` | [supabaseAnonKey]   | empty     |
  /// | `API_BASE_URL`      | [apiBaseUrl]        | empty     |
  /// | `GIT_SHA`           | [gitSha]            | `local`   |
  /// | `LOG_NETWORK`       | [enableNetworkLogs] | `false`   |
  ///
  /// Every value is a compile-time constant (`String.fromEnvironment` /
  /// `bool.fromEnvironment`), so nothing is parsed from a bundled asset at
  /// runtime. Normalisation is delegated to [EnvConfig.fromDefines].
  factory EnvConfig.fromEnvironment() {
    return EnvConfig.fromDefines(
      appEnv: const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
      gitSha: const String.fromEnvironment('GIT_SHA', defaultValue: 'local'),
      logNetwork: const bool.fromEnvironment('LOG_NETWORK'),
    );
  }

  /// Builds a configuration from raw define values (testable without
  /// `--dart-define`). String values are trimmed so a stray space or newline
  /// pasted into `config/<env>.json` cannot break the Supabase connection,
  /// `APP_ENV` is parsed by [AppEnvironment.fromName], and a blank `GIT_SHA`
  /// falls back to `local`.
  factory EnvConfig.fromDefines({
    required String appEnv,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String apiBaseUrl,
    required String gitSha,
    required bool logNetwork,
  }) {
    final String sha = gitSha.trim();
    return EnvConfig(
      environment: AppEnvironment.fromName(appEnv),
      supabaseUrl: supabaseUrl.trim(),
      supabaseAnonKey: supabaseAnonKey.trim(),
      apiBaseUrl: apiBaseUrl.trim(),
      gitSha: sha.isEmpty ? 'local' : sha,
      enableNetworkLogs: logNetwork,
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
  /// from Phase 5 onward (auth + data); validate() blocks startup without it.
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

    // The key itself is never echoed: the message is shown on screen.
    if (hasKey && isServiceRoleKey(supabaseAnonKey)) {
      problems.add(
        'SUPABASE_ANON_KEY holds a service_role / secret key. Never ship the '
        'service role / secret key in Flutter (ground rule G4): it bypasses '
        'Row Level Security. Use the anon or publishable key from Supabase '
        'Dashboard → Project Settings → API, and rotate the leaked key.',
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

    // Sign-in and all data need Supabase (Phase 5 onward) in every environment.
    if (!isSupabaseConfigured) {
      problems.add(
        'SUPABASE_URL and SUPABASE_ANON_KEY are required. Copy config/dev.example.json '
        'to config/dev.json and run with --dart-define-from-file=config/dev.json.',
      );
    }

    if (supabaseUrl.contains('<') || supabaseAnonKey.contains('<')) {
      problems.add(
        'The Supabase configuration still contains template placeholders (<...>). '
        'Fill in the real project URL and anon/publishable key.',
      );
    }

    if (environment.isProduction && enableNetworkLogs) {
      problems.add(
        'LOG_NETWORK must be disabled in production: request payloads may '
        'contain customer and financial data.',
      );
    }

    return EnvValidation(problems: problems, warnings: warnings);
  }

  /// True when [key] looks like a Supabase key that must never reach a client
  /// (ground rule G4):
  ///
  /// * a new-style secret key (`sb_secret_…`; client builds use
  ///   `sb_publishable_…`), or
  /// * a legacy JWT key whose payload (the base64url middle segment) is a JSON
  ///   object with `"role": "service_role"` (the anon JWT has `"role": "anon"`).
  ///
  /// Only the payload is inspected — the signature is not verified, this is a
  /// classification, not authentication. Never throws: anything that is not a
  /// decodable JWT (garbage, empty, truncated) is reported as `false`.
  static bool isServiceRoleKey(String key) {
    final String trimmed = key.trim();
    if (trimmed.startsWith('sb_secret_')) {
      return true;
    }

    final List<String> segments = trimmed.split('.');
    if (segments.length != 3 || segments[1].isEmpty) {
      return false;
    }

    try {
      final String payloadJson = utf8.decode(
        base64Url.decode(base64Url.normalize(segments[1])),
      );
      final Object? payload = jsonDecode(payloadJson);
      return payload is Map<String, Object?> &&
          payload['role'] == 'service_role';
    } on FormatException {
      return false;
    }
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
