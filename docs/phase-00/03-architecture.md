# PHASE 0 — 03 Application Architecture

## 1. Layered architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│ PRESENTATION       screens · widgets · layouts · dialogs             │
│                    (no Supabase/Dio imports here, ever)              │
├──────────────────────────────────────────────────────────────────────┤
│ STATE / CONTROLLER Riverpod Notifier / AsyncNotifier (per feature)    │
│                    UI state, loading/error, form state, filters      │
├──────────────────────────────────────────────────────────────────────┤
│ DOMAIN             entities · value objects · repository interfaces   │
│                    (pure Dart, no Flutter/network imports)           │
├──────────────────────────────────────────────────────────────────────┤
│ DATA               repository implementations · remote/local sources  │
│                    DTO ⇄ entity mappers                              │
├──────────────────────────────────────────────────────────────────────┤
│ SERVICE            AuthService · SessionService · PermissionService   │
│                    ShowroomService · StorageService · Notification…   │
│                    (Supabase, Dio, FCM, PDF, export)                  │
├──────────────────────────────────────────────────────────────────────┤
│ PLATFORM           Supabase (Postgres/RLS/RPC/Storage/Realtime)        │
│                    Dio HTTP (Edge Functions, 3rd-party) · FCM         │
└──────────────────────────────────────────────────────────────────────┘
```

Dependency direction is strictly downward. Cross-cutting concerns (config,
theme, routing, errors, validators, formatters, extensions) live in `core/`
and may be imported by any layer.

**Money-critical rule:** transactions spanning several tables (stock + invoice +
journal) are performed by a **single PostgreSQL function** (`SECURITY DEFINER`,
one transaction) invoked from a repository method — never as a chain of
client-side inserts. This guarantees atomicity, server-side permission
validation and audit consistency.

## 2. Data flow examples

```
Login:
  LoginScreen → AuthController.login → AuthRepository → AuthService(Supabase Auth)
             → ProfileRepository (profile + roles + permissions + showrooms)
             → ShowroomController.select → Dashboard

Create sale (money-critical):
  SaleFormScreen → SaleController.save → SaleRepository.createSale(dto)
     → supabase.rpc('rpc_create_sale', params)  // validate → invoice → stock → COGS → journal
     → invalidate dashboard / sales / stock / journal providers
     → NotificationService.emit(targeted event)

Report export:
  ReportScreen → ReportController.exportPdf → ExportService → PDFService(pdf)
              → FileSaveGateway (platform-conditional) → saved / downloaded / printed
```

## 3. State management, routing, DI

| Concern | Decision | Why |
|---------|----------|-----|
| State + DI | **Riverpod 3** (`flutter_riverpod`) + `riverpod_generator` | Compile-safe providers, `autoDispose`, `family` params, test overrides, no `BuildContext` DI, first-class async/error handling |
| Routing | **go_router 18** with central route constants + `redirect` guards | Web deep links, declarative auth/permission guards, `ShellRoute` for sidebar/bottom-nav |
| Forms | Flutter `Form` + controllers wrapped by `AppTextField`/`AppDropdown`, rules in `ValidationService` | No extra dependency; validation reusable + unit-testable |
| Local persistence | `shared_preferences` (theme, selected showroom, last filters); `flutter_secure_storage` only for short-lived sensitive flags (Supabase session is owned by the SDK) | Minimal dependencies |
| Models | `json_serializable` DTOs + hand-written immutable domain entities | Boilerplate removal without an extra annotation framework |
| Server-derived state | Supabase Realtime streams + RPC/views, exposed via `StreamProvider`/`FutureProvider` with TTL caching | Database stays the single source of truth |

Router guard chain (Phase 5, extended later):

1. no session → `/login`
2. session present, profile still loading → `/splash`
3. profile inactive → `/access-denied`
4. no showroom assigned → `/no-showroom`
5. multi-showroom user without selection → `/select-showroom`
6. missing `module.view` permission → `/forbidden` (never a blank screen)

## 4. Networking architecture

| Transport | Used for | Notes |
|-----------|----------|-------|
| **Supabase client** (`supabase_flutter`) | Auth, Postgres reads/writes, RPC, Storage, Realtime, Edge Function invocation | SDK handles token refresh; RLS is authoritative; errors: `PostgrestException`, `AuthException`, `StorageException` |
| **Dio** (`DioClient`) | (a) own Edge-HTTP endpoints needing raw HTTP/streaming, (b) third-party APIs (SMS/WhatsApp, GST/e-invoice when enabled, finance partners, vehicle/RTO lookups), (c) file upload/download with progress | Exactly **one** shared instance created in `core/network/dio_client.dart`; features must not create `Dio()` |

`DioClient` configuration:
- `BaseOptions` from `EnvConfig`: base URL, `connectTimeout` 20 s, `receiveTimeout` 45 s (uploads override), `sendTimeout` 45 s, JSON headers, app version header.
- Interceptors in order: `AuthInterceptor` (attaches the **current Supabase access token**, refreshed by the SDK — never a separately stored token) → `LoggingInterceptor` (debug only; redacts `authorization`, `apikey`, passwords, tokens) → `ErrorInterceptor` (`DioException` → `AppFailure`, exponential-backoff retry for idempotent GETs, honours `Retry-After`).
- Request bodies for auth/payment/document endpoints are never logged.
- Per-screen `CancelToken` so navigation cancels in-flight requests.
- Idempotency: money-writing HTTP calls send `Idempotency-Key` (uuid v4); the receiving endpoint/table stores it to make retries safe.

## 5. Error architecture

```
AppFailure (sealed)
├── NetworkFailure      (offline, DNS, socket, timeout)
├── ServerFailure       (5xx, edge function 5xx)
├── AuthFailure         (invalid credentials, expired session, email not confirmed)
├── PermissionFailure   (403 / RLS denial / missing permission)
├── NotFoundFailure     (PGRST116, 404)
├── ValidationFailure   (field → message map, incl. DB constraints)
├── ConflictFailure     (23505 unique violation → duplicate VIN / invoice number)
├── BusinessRuleFailure (insufficient stock, period locked, already reversed)
└── UnknownFailure      (fallback, logged with a short code only)
```

Mapping rules:
- `PostgrestException.code` / SQLSTATE and `AuthException.statusCode` map to `AppFailure` in `core/errors/error_mapper.dart`.
- **Raw technical messages are never rendered.** `AppErrorState` shows a friendly message, a short trace code and a retry action.
- Validation failures carry `Map<String, String>` so forms can show field-level errors; DB violations are translated (e.g. `23505 vehicles_vin_key` → "This VIN already exists in stock").
- Each failure carries a `traceCode` (short uuid) written to `app_error_log` in production for support correlation without exposing internals.
- `FlutterError.onError` + `PlatformDispatcher.instance.onError` are wired in `core/services/app_error_handler.dart` and funnel into the same pipeline (crash reporting is Phase 18/27, platform-guarded).

## 6. Folder structure (feature-sliced)

```
lib/
├── main.dart                        # bootstrap only: env check, Supabase init, runApp
├── app.dart                         # MaterialApp.router + theme + ProviderScope wiring
├── core/
│   ├── config/                      # EnvConfig, AppConfig, FeatureFlags, PlatformTarget
│   ├── constants/                   # ApiPaths, DbTables, DbRpc, ModuleKeys, ActionKeys, AppStrings, AppAssets
│   ├── theme/                       # AppColors, AppTypography, AppDimensions, AppShadows, AppTheme (light/dark), AppThemeMode
│   ├── routes/                      # AppRoutes (names+paths), AppRouter (go_router), guards, RouteTransitions
│   ├── network/                     # DioClient, SupabaseClientFactory, ApiService, interceptors/, PaginatedResponse
│   ├── services/                    # AuthService, SessionService, PermissionService, ShowroomService, StorageService,
│   │                                # NotificationService, ValidationService, FormattingService, ConnectivityService,
│   │                                # PDFService, ExportService, AuditTrailService, AppErrorHandler
│   ├── storage/                     # PreferenceStore, SecureStore, CacheStore (TTL), LastFiltersStore
│   ├── utils/                       # DateTimeX, MoneyX, StringX, ListX, ResponsiveX, Debouncer, IdGenerator
│   ├── validators/                  # ValidationRules (GSTIN, PAN, mobile, email, VIN, chassis, GST math)
│   ├── errors/                      # AppFailure hierarchy, ErrorMapper, FailureMessages
│   └── extensions/                  # BuildContextX (snackbars, dialogs), AsyncValueX, NumX
│
├── common/
│   ├── widgets/                     # AppButton, AppOutlinedButton, AppTextField, AppDropdown, AppSearchField,
│   │                                # AppDatePicker, AppCard, AppStatCard, AppDashboardCard, AppStatusBadge,
│   │                                # AppCurrencyText, AppEmptyState, AppErrorState, AppLoading, AppShimmer,
│   │                                # AppDataTable, AppPagination, AppFilterBar, AppSectionHeader, AppFormSection,
│   │                                # AppPermissionWidget, AppConfirmDialog, AppBottomSheet, AppAvatar, AppLogo
│   ├── dialogs/                     # showConfirmDialog, showFormDialog, showMasterPickerDialog
│   ├── loaders/                     # AppLoading, AppShimmer, AppButtonLoader, AppRefreshIndicator
│   ├── components/                  # AppAsyncBuilder, AppAsyncList, AppPermissionGate, AppMoneyField, AppEntityPicker
│   └── layouts/                     # ResponsiveLayout, DesktopShell (sidebar+header), TabletShell, MobileShell (bottom nav),
│                                    # AppScaffold, AppSidebar, AppTopHeader, AppBottomNavigation, AppPageHeader
│
└── features/                        # auth, dashboard, showroom, users, roles, permissions, vehicles, inventory,
    └── <feature>/                   # customers, suppliers, purchases, sales, bookings, finance, accounting,
        ├── data/                    # expenses, income, reports, notifications, documents, audit_logs, settings
        │   ├── models/              #   DTOs (+ generated .g.dart) and mappers
        │   ├── sources/             #   remote_data_source.dart / local cache
        │   └── repositories/        #   <feature>_repository_impl.dart (PostgREST + RPC calls)
        ├── domain/
        │   ├── entities/            #   pure Dart entities / value objects
        │   ├── repositories/        #   abstract repository interfaces
        │   └── usecases/            #   only where logic is non-trivial (e.g. sale_totals_calculator.dart)
        └── presentation/
            ├── controllers/         #   Riverpod notifiers (state + commands)
            ├── providers/           #   provider declarations (or *.g.dart generated)
            ├── screens/             #   thin screens; compose widgets + controllers
            └── widgets/             #   feature-specific widgets built from common/ widgets
```

Rules enforced by review + lint:
1. `presentation/` never imports `supabase_flutter`, `dio`, or `data/`.
2. `domain/` imports only Dart core + `core/utils`.
3. Table/RPC names are string constants in `core/constants/db_tables.dart` — no magic strings inline.
4. Common widget count must grow, not duplicate — a new screen reusing an existing pattern adds a parameter, not a copy.

## 7. Responsive architecture

| Breakpoint | Width | Shell | Content strategy |
|------------|-------|-------|------------------|
| `compact` (mobile) | < 600 | Bottom navigation (`Home, Inventory, Sales, Finance, More`) + `AppBottomSheet` actions | Single column; forms as full pages; tables become card lists; KPI cards 2-up; charts stacked |
| `medium` (tablet / small window) | 600–1024 | Collapsible navigation rail + top header | 2-column grids; master–detail side by side for lists; KPI cards 3-up |
| `expanded` (desktop/web) | > 1024 | Persistent left sidebar (permission-filtered) + top header + main content | Multi-column dashboards (3–4 KPI per row), real data tables with sticky header, inline filters, master–detail panes, modals instead of full pages |
| `large` | > 1440 | Same as expanded with capped content width (`maxWidth 1600`) | Prevents over-stretched forms/tables |

Implementation:
- `ResponsiveLayout` (in `common/layouts/`) exposes `Breakpoint` + `isMobile/isTablet/isDesktop` via a `LayoutBuilder`-based context extension (`ResponsiveX`) — widgets read the breakpoint instead of raw `MediaQuery`.
- `AppDataTable` renders a real table on desktop, a 2-line card list on mobile, and horizontally scrollable table with frozen first column on tablet — **one widget**, three presentations.
- Navigation shells are separate widgets (`DesktopShell`, `TabletShell`, `MobileShell`) selected once in `AppRouter`; screens do not build their own chrome.
- Sidebar entries come from a single `NavigationRegistry` (module key → route → icon → permission) so mobile "More" and desktop sidebar never drift apart.
- Windows-specific: minimum window size enforcement (e.g. 900×600) plus remembering window state is deferred to Phase 26 (needs a window-management decision — see open questions).

## 8. Theme & design system architecture

Centralised, no hardcoded colours/sizes in screens:

| Layer | File(s) | Responsibility |
|-------|---------|----------------|
| Brand tokens | `core/theme/app_colors.dart` | Yellow `#F9C846`, Black `#171717`, White, Light bg `#F7F7F5`, Surface, Border `#E8E8E5`, text scale, dark set (`#101010`, `#181818`, `#202020`, `#333333`, `#B5B5B5`) as `Color` constants + semantic aliases (`AppColors.brandPrimary`, `.textSecondary`, `.surfaceCard`, …) |
| Spacing/radius | `core/theme/app_dimensions.dart` | 4-pt spacing scale, radius tokens (8/12/16/20), control heights, sidebar width, header height, breakpoints |
| Typography | `core/theme/app_typography.dart` | Inter-based `TextTheme` mapped to Display / Headline / Title / Subtitle / Body / Label / Caption with weights + line heights; `tabular figures` for money columns |
| Elevation | `core/theme/app_shadows.dart` | Soft shadows (low-opacity, large blur) for the premium minimal look |
| Theme assembly | `core/theme/app_theme.dart` | `AppTheme.light` / `AppTheme.dark` built from the tokens → Material 3 `ColorScheme` (yellow as primary accent, black/white as surfaces), component themes (AppBar, Card, Input, Button, Dialog, Table, Chip, NavigationBar) so widgets look consistent without per-widget styling |
| Mode | `core/theme/app_theme_mode.dart` + `ThemeController` | `light / dark / system` persisted via `PreferenceStore`; resolved at `MaterialApp.router` |

Design direction applied: premium minimal automotive + fintech —
large whitespace, rounded cards (16–20 radius), soft shadows, thin borders
instead of heavy elevation, minimal iconography, yellow reserved for primary
CTA/active states/highlights/selected nav item, never as a full background.

Dark mode keeps yellow as the accent; surfaces use the `#101010/#181818/#202020`
scale with white text — implemented as a second `ColorScheme` and verified in
Phase 2 (light + dark widget tests).

## 9. Configuration & environment

- Values are injected at build time with `--dart-define` / `--dart-define-from-file`
  and read once into `EnvConfig` (a plain class with `static const` values via
  `String.fromEnvironment`) — no runtime `.env` parsing, so nothing can be swapped
  on a rooted device, and no dependency is needed (`flutter_dotenv` rejected — see
  `07-dependency-plan.md`).
- Keys exposed to the client: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (publishable key),
  `APP_ENV` (`dev|staging|prod`), `API_BASE_URL` (Dio), `FCM_VAPID_KEY` (web push).
- **Never** in the client bundle: `service_role` key, FCM server key, DB password,
  any third-party secret. Those live only in Edge Function secrets.
- `main.dart` startup order: `WidgetsFlutterBinding.ensureInitialized()` →
  validate env (`EnvConfig.validate()` throws a clear error if a define is missing)
  → `Supabase.initialize(url, anonKey, authOptions)` → restore preferences →
  optional platform-guarded Firebase bootstrap → `runApp`.
- Build commands per environment are documented in `08-roadmap.md`; production
  builds use a separate Supabase project + separate Firebase project.

## 10. Cross-platform strategy

| Concern | Android | iOS | Web | Windows |
|---------|---------|-----|-----|---------|
| Flutter core/UI (Material 3, Riverpod, go_router, Dio, Supabase) | ✅ | ✅ | ✅ | ✅ |
| Supabase Auth session storage | SDK (encrypted prefs) | SDK (Keychain) | SDK (localStorage — HTTPS only) | SDK (prefs) |
| `flutter_secure_storage` | ✅ | ✅ | ✅ HTTPS/localhost only | ✅ |
| FCM push (`firebase_messaging`) | ✅ | ✅ | ✅ (web push/VAPID) | ❌ not supported → in-app realtime notification centre |
| `printing` (PDF preview/print) | ✅ | ✅ | ✅ (browser print) | ✅ |
| `file_saver` (PDF/Excel/CSV export) | ✅ (app docs) | ✅ (app docs, `UIFileSharingEnabled`) | ✅ (browser download) | ✅ (Downloads folder) |
| Charts (`fl_chart`), Excel (`excel`), `pdf` | ✅ | ✅ | ✅ | ✅ |

Platform isolation pattern (mandatory for anything with gaps):
```dart
// core/services/notification_gateway.dart
abstract interface class NotificationGateway {
  Future<void> initialize();
  Future<String?> getToken();
  Stream<AppNotification> incomingMessages();
}

// notification_gateway_stub.dart / notification_gateway_firebase.dart
// resolved with conditional import:
import 'notification_gateway_stub.dart'
    if (dart.library.io) 'notification_gateway_native.dart'
    if (dart.library.js_interop) 'notification_gateway_web.dart';
```
Rules:
1. Any capability that is not available on all four platforms sits behind an
   interface with a nullable/stub implementation — features never call plugin APIs directly.
2. `PlatformTarget` (in `core/config`) centralises `isMobile/isWeb/isDesktop` checks
   (`kIsWeb`, `defaultTargetPlatform`), so no `dart:io` import leaks into shared code.
3. Every phase that touches UI/plugins must be verified on Android, iOS (simulator or
   device), Web (Chrome/Edge) and Windows — recorded in the phase test checklist.
4. Notification source of truth = `notifications` table streamed over Supabase
   Realtime (works on all 4 platforms); FCM is an *additional* delivery channel on
   mobile/web only.

## 11. Performance, caching & data-volume strategy

| Technique | Where | Detail |
|-----------|-------|--------|
| Pagination | all list screens | `range()` paging, 25/50/100 page sizes, `count: exact` only when a total is displayed, else `planned/estimated` |
| Keyset (seek) paging | `stock_ledger`, `journal_entry_lines`, `audit_logs`, `payments` | cursor on `(created_at, id)` for cheap deep pages |
| Debounced search | search fields | 350 ms `Debouncer`, minimum 3 chars, trigram-backed (`pg_trgm`) indexed columns |
| Indexes | DB | every FK indexed + composite indexes on hot filters (`showroom_id, status, created_at`) — listed in `05-database-plan.md` |
| Aggregates | dashboard/reports | SQL views + `SECURITY INVOKER` RPCs; materialised views for heavy KPI sets refreshed on schedule (pg_cron) with `CONCURRENTLY` where possible |
| Realtime discipline | notifications, approvals, selected counters | subscribe only to filtered channels (`user_id=eq.x`, `showroom_id=eq.y`); never subscribe to whole tables |
| Riverpod caching | providers | `autoDispose` + `keepAlive` for master data (brands, showroom settings, CoA) with TTL; invalidation on mutation, not on every rebuild |
| Widget rebuild hygiene | UI | `const` constructors, `select()` on providers, `RepaintBoundary` around charts, list builders with `itemExtent` where fixed |
| Images | vehicle photos | Supabase Storage image transforms (resize) + cached network image decoding; compression before upload |
| Startup | app boot | keep `main()` free of network calls; splash shows while profile loads; fonts bundled (no runtime font fetch) |
| Measurement | Phase 23 | Flutter DevTools timeline/rebuild counters, `EXPLAIN ANALYZE` on top 20 queries, web bundle size check |

## 12. Logging & observability

- `AppLogger` (debug: console with redaction; release: only warnings/errors + trace code).
- Production error records go to `app_error_log` (showroom, user, module, trace code, app version, platform) — readable by Super Admin only.
- `audit_logs` is the business observability layer (see `04-.../06-...` docs); it is written by triggers, not by UI code.
- Build metadata (`app_version`, `build_number`, `git_sha`, `APP_ENV`) is attached to every error/audit record for support.