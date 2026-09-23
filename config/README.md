# Build-time configuration

MyBike reads its environment from `--dart-define-from-file` JSON files, which
`lib/core/config/env_config.dart` (`EnvConfig`) loads. Only the
`*.example.json` templates are committed. The real `dev.json`, `staging.json`
and `prod.json` files are git-ignored.

## Set up a local environment

1. Copy the template for your environment:

   ```powershell
   Copy-Item config/dev.example.json config/dev.json
   ```

2. Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` from the Supabase Dashboard
   under **Project Settings → API**. Use the project URL and the **anon** (legacy)
   or **publishable** (`sb_publishable_…`) key.

   **Never use the `service_role` or secret (`sb_secret_…`) key.** That key
   bypasses Row Level Security, so it must never be shipped in a Flutter build
   (ground rule G4). It belongs only in Edge Function secrets.
   `EnvConfig.validate()` refuses to start the app if it finds one.

3. Run the app:

   ```powershell
   flutter run -d windows --dart-define-from-file=config/dev.json
   ```

## Keys

| Key                 | Meaning                                              |
|---------------------|------------------------------------------------------|
| `SUPABASE_URL`      | `https://<project-ref>.supabase.co` (https only; `http://localhost` is allowed in dev) |
| `SUPABASE_ANON_KEY` | anon / publishable key only                          |
| `APP_ENV`           | `dev`, `staging` or `prod`                           |
| `API_BASE_URL`      | Edge Functions base URL used by Dio                  |
| `FCM_VAPID_KEY`     | Web push public key (used once push notifications are added) |
| `GIT_SHA`           | Build commit shown in About/debug banners. Defaults to `local` |
| `LOG_NETWORK`       | `true` enables network logs outside production. Must be `false` for prod |

If a service_role or secret key ever ends up in one of these files, a commit
or a build, rotate it in the Supabase Dashboard right away.
