# Phase 5 — Authentication

## Flow

```
app start ─► Supabase.initialize (SDK restores + refreshes the stored session)
          ─► SessionController.build
               no session ─────────────────────────► /login
               session ─► rpc_get_my_session() ─┬─ NULL (no profile) ──► /access-blocked
                                                ├─ deactivated / no showroom ──► /access-blocked
                                                ├─ 1 showroom ─► auto-select ─► /dashboard
                                                └─ N showrooms ─► last used still valid? ─► /dashboard
                                                                     └─ otherwise ─► /select-showroom
sign-out (header / picker / blocked screen) ─► state = SignedOut ─► supabase.auth.signOut() ─► /login
SDK signedOut event (refresh failure, revoked) ─► /login
```

Every redirect is decided by `AppRouter.guard(session, location)` (pure, unit-tested) and re-run on each
session change. A module route without `module.view` in the current showroom goes to `/forbidden`; the
sidebar, rail and bottom bar hide those modules. All of this is UI convenience — RLS decides the data.

## Pieces

| File | Role |
|------|------|
| `supabase/migrations/20260924000007_session_rpc.sql` | `rpc_get_my_session()`: profile, `is_super_admin`, global permissions, accessible showrooms with roles + effective permissions (same rules as the RLS helpers). NULL without a profile; deactivated → profile only |
| `lib/features/auth/domain/user_session.dart` | `UserSession`, `SessionShowroom`, `ShowroomSelection`, block reasons, initial-showroom rule |
| `lib/features/auth/data/auth_repository.dart` | `AuthRepository` + `SupabaseAuthRepository` (sign-in, sign-out, session RPC, SDK sign-out events) |
| `lib/features/auth/application/session_controller.dart` | `SessionController` (Riverpod): `signIn`, `signOut`, `selectShowroom` (persisted per user: `StorageKeys.lastShowroomFor`) |
| `lib/features/auth/presentation/*` | splash, login, showroom picker, access-blocked / forbidden screens (shared `AuthCardLayout`) |
| `lib/core/errors/error_mapper.dart` | SDK / PostgREST errors → `AppFailure` (friendly text; MB SQLSTATEs → business-rule messages; unknown → trace code) |
| `lib/core/validators/validators.dart` | `Validators.required`, `Validators.email` |
| `lib/core/routes/app_router.dart` | `routerProvider` + `AppRouter.guard` |
| `lib/common/layouts/app_scaffold.dart` | permission-filtered navigation, `ShellSessionActions` (showroom switcher + sign-out) in every layout |

## Decisions

- **Showroom choice:** one showroom → automatic; several → the picker, unless the last used showroom (stored
  per user) is still accessible. ALL SHOWROOMS appears only with `showrooms.view_all`; it uses the global
  permission set.
- **Session storage:** owned by `supabase_flutter` (secure refresh, persisted per platform). The app stores
  only the non-sensitive last-showroom id; sign-out drops the in-memory session and the SDK session.
- **Config:** `EnvConfig.validate()` now blocks startup without `SUPABASE_URL` / `SUPABASE_ANON_KEY` in every
  environment, rejects unfilled `<placeholder>` values and service-role / secret keys. The key is passed as
  `publishableKey` (legacy anon JWTs still work).
- **Android:** `INTERNET` permission added to the main manifest (Flutter adds it to debug builds only).
- **No self sign-up / password reset screen:** accounts come from administrators (Phase 6 `admin-users` Edge
  Function, which also lets an administrator set a new password); email reset links need SMTP on the project.

## Remote project settings (not covered by `config.toml`, which is local only)

Supabase Dashboard → Authentication → Providers → Email: **disable "Allow new users to sign up"**, minimum
password length 10 with lower/upper/digits, enable "Secure password change". Project Settings → API: expose
only `public` (not `graphql_public`).

## Tests

- DB: `supabase/tests/database/07_session_rpc.test.sql` (16) — single / multi / global / deactivated /
  role-less / no-profile / anon callers.
- Flutter: `test/features/auth/` — session model, guard, full flows (wrong password, empty form, single
  showroom, multi showroom + remembered choice, deactivated, no showroom, sign-out, SDK sign-out, forbidden
  module); `test/core/errors/error_mapper_test.dart`.

Try it (dev project with `supabase/seed.sql`, password `MyBike@Dev2026`): `manager.indore@mybike.test`
(single), `accountant@mybike.test` (multi), `superadmin@mybike.test` (ALL SHOWROOMS), `inactive@mybike.test`
(blocked), `norole@mybike.test` (no showroom).
