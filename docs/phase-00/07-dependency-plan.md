# PHASE 0 — 07 Dependency & Version Plan

Verified against pub.dev / flutter.dev at the time of writing (Phase 0).
Local toolchain: **Flutter 3.44.8 stable · Dart 3.12.2** (confirmed with `flutter --version`).

## 1. Runtime dependencies (added phase by phase, never all at once)

| Package | Verified latest | Why it is required | Platforms | Maintained | Notes |
|---------|-----------------|--------------------|-----------|------------|-------|
| `supabase_flutter` | **2.17.2** | Auth, Postgres/PostgREST, RPC, Storage, Realtime, Edge Function invocation — the backbone of the backend contract | Android, iOS, web, Windows, macOS, Linux | Yes (supabase.io), frequent releases | Pulls in `supabase`, `postgrest`, `gotrue`, `realtime_client`, `storage_client`, `functions_client` — **no separate installs needed** |
| `flutter_riverpod` | **3.4.3** | State management + DI with compile-safe providers and async/error primitives | all | Yes (dash-overflow.net) | The single state solution (no second framework) |
| `riverpod_annotation` | **4.0.7** | `@riverpod` annotations for code generation | all | Yes | paired with a compatible `riverpod_generator`; resolver decides the exact minor |
| `go_router` | **18.0.1** | Routing, redirect guards, web deep links, shell routes for sidebar/bottom-nav | all | Yes (flutter.dev; feature-complete, maintained) | Official Flutter-team package |
| `dio` | **5.11.1** | Raw HTTP for Edge-HTTP endpoints, third-party APIs, upload/download with progress, interceptors | all | Yes (flutter.cn) | Exactly one shared instance |
| `json_annotation` | 4.9.x | Annotations for `json_serializable` DTOs | all | Yes (google.dev) | added together with `json_serializable` |
| `intl` | **0.20.3** | Date/number formatting incl. Indian digit grouping for reports | all | Yes (dart.dev) | Locale data initialised for `en_IN` |
| `shared_preferences` | **2.5.5** | Persist theme mode, selected showroom, last filters (non-sensitive) | all | Yes (flutter.dev) | Use `SharedPreferencesAsync`, not the legacy API |
| `flutter_secure_storage` | **11.2.0** | Secure storage for short-lived sensitive flags/device identifiers | Android, iOS, web (HTTPS/localhost), Windows, macOS, Linux | Yes (steenbakker.dev) | Session is owned by the Supabase SDK; Android SDK 23+ |
| `connectivity_plus` | **7.3.1** | Offline banner + retry gating | all | Yes (fluttercommunity.dev) | UX only — never used as a freshness guarantee |
| `uuid` | **4.6.0** | Client ids for idempotency keys and optimistic entities | all | Yes (yuli.dev) | v4 for idempotency |
| `fl_chart` | **1.2.0** | Dashboard charts (line/bar/pie) | all | Yes (flchart.dev) | Only charting library used (Phase 15) |
| `pdf` | **3.13.0** | Pure-Dart PDF generation (invoices, receipts, reports) | all | Yes (nfet.net) | Works on web |
| `printing` | **5.15.0** | PDF preview, system print dialog, share | Android, iOS, web, Windows, macOS, Linux | Yes (nfet.net) | iOS needs `use_frameworks!` (Phase 27 Podfile step) |
| `excel` | **4.0.6** | XLSX export/import for reports and masters | all (pure Dart) | Stable; older release but Dart-3 compatible | Re-evaluated in Phase 17 if a better maintained option exists |
| `file_saver` | **0.4.0** | Save exported PDF/XLSX/CSV everywhere (browser download, Downloads folder, app docs) | all | Yes (hassanansari.dev) | Replaces manual `dart:html`/`dart:io` code |
| `firebase_core` | **4.15.0** | Firebase bootstrap required by messaging | Android, iOS, macOS, web, Windows | Yes (firebase.google.com) | Initialised only where supported (platform-guarded) |
| `firebase_messaging` | **16.7.0** | FCM push notifications | Android, iOS, macOS, **web** | Yes (firebase.google.com) | **No Windows support** → realtime in-app notification centre there |

Flutter SDK packages used: `flutter_localizations` (date pickers/locale), `flutter_test`, `integration_test`.

## 2. Dev dependencies

| Package | Verified latest | Purpose |
|---------|-----------------|---------|
| `flutter_lints` | **6.0.0** | Baseline lint set (already present) + project lint additions |
| `build_runner` | **2.16.1** | Runs `riverpod_generator` + `json_serializable` |
| `riverpod_generator` | **4.0.9** | Generates providers from `@riverpod` |
| `json_serializable` | **6.14.1** | DTO `fromJson`/`toJson` generation |
| `mocktail` | **1.0.5** | Mocks for unit tests, no code generation |

## 3. Version policy

1. Packages are added with `flutter pub add <pkg>` (caret constraints) and then verified with
   `flutter pub deps --style=compact` and `flutter pub outdated` — the resolver picks compatible versions
   instead of hand-pinned numbers copied from old examples.
2. `pubspec.lock` is committed, so every machine and CI build gets an identical dependency graph.
3. Before adding anything mid-project, confirm: (a) latest stable version, (b) last publish date,
   (c) maintenance signals (pub points, likes, issue activity), (d) platform badges vs our four targets,
   (e) whether Flutter/Dart can already do it. Any negative answer → do not add it.
4. Never two packages for one job: one HTTP client, one state framework, one router, one chart library,
   one PDF engine, one export saver.

## 4. Packages deliberately **rejected**

| Rejected | Used instead | Reason |
|----------|--------------|--------|
| `flutter_bloc` / `provider` / `get_it` | `flutter_riverpod` (+ `riverpod_generator`) | One state/DI solution instead of three overlapping ones |
| `google_fonts` | bundled Inter TTF in `assets/fonts` (SIL OFL) | Avoids runtime font downloads (poor offline/desktop behaviour) and gives the `pdf` package direct TTF bytes for invoices |
| `flutter_dotenv` | `--dart-define` + `EnvConfig` | No asset parsing at startup, no secrets shipped as a readable asset, one less dependency |
| `hive` / `isar` / `sqflite` | Supabase + `shared_preferences` cache | v1 is online-first; a second store would create sync/conflict risk for financial data |
| `freezed` | `json_serializable` + hand-written immutable entities | Avoids a second generator and the `invalid_annotation_target` lint workaround for ~40 entities; revisit if the model count grows substantially |
| `http` | `dio` | Dio already offers interceptors, cancel tokens, retry, progress |
| `syncfusion_flutter_*` | `fl_chart`, `pdf`, `excel`, `file_saver` | Syncfusion requires a commercial licence for production |
| `open_filex`, `url_launcher` (for exports) | `file_saver` + `printing` | Single code path for save/share/print on all four targets |
| `path_provider` (direct) | handled inside `file_saver`/`printing` | No need until a concrete requirement appears |
| `window_manager` | deferred decision (Phase 26) | Windows window sizing is a nice-to-have, not a functional requirement |
| `flutter_native_splash` (early) | manual splash config in Phase 27 | Only worth adding once the branding assets exist |
| Server-side Supabase helpers in the app | Edge Functions | Server-side logic must never live in the client |

## 5. Environment & secrets

```powershell
# dev.json (git-ignored) — template only, placeholders committed
{
  "SUPABASE_URL": "https://<project>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon/publishable key>",
  "APP_ENV": "dev",
  "API_BASE_URL": "https://<project>.functions.supabase.co",
  "FCM_VAPID_KEY": "<web push public key>"
}
```
```powershell
flutter run -d windows  --dart-define-from-file=config/dev.json
flutter build web --release --dart-define-from-file=config/prod.json
```
Rules: only the anon/publishable key ever reaches the client; `service_role`, FCM server credentials and
third-party keys live exclusively in Edge Function secrets; `EnvConfig.validate()` fails fast with a clear
message when a define is missing.

## 6. Font strategy (Inter, all four platforms)

- Bundle **static** Inter TTFs (`Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`,
  `Inter-Bold.ttf`) in `assets/fonts/`, sourced from the official Inter release (latest stable tag
  **v4.1**, SIL Open Font License — free for commercial use, no attribution required in the UI).
- Static instances (not the variable font) are chosen deliberately: they behave identically on
  Android/iOS/web/Windows and the `pdf` package can embed them directly for invoices and reports.
- `pubspec.yaml` declares the `Inter` family with weights 400/500/600/700; `AppTypography` maps it to the
  Material 3 text scale. No runtime network fetch, no `google_fonts` dependency.
- Phase 1 includes a short `docs/...`-referenced step to download the font archive and copy the four TTFs
  into `assets/fonts/`; the build verifies their presence.