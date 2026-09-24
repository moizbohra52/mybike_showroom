# Phase 6 — Users, roles and permissions

## What an administrator can do

| Screen | Actions |
|--------|---------|
| **Users** (`/users`) | Search by name / email / employee code, filter by showroom (starts at the current one) and status, page through; **New user** (email, name, phone, designation, employee code, initial password, showroom, first role) |
| **User detail** (`/users/:id`) | Edit profile, set a new password, deactivate / activate; global roles; per showroom: add / remove roles, remove the showroom; add a showroom (with a first role) |
| **Roles & permissions** (`/roles`) | List with rank and type; **New role** |
| **Role detail** (`/roles/:id`) | Edit name, description, rank, active; delete an unused custom role; the permission matrix (module × action chips) |

Every action appears only when the server says the caller may do it; the database re-checks every write (G1).

## Delegation rules (migration `20260924000008_user_role_admin.sql`)

**Rank** = the highest `roles.precedence` among a user's roles that apply in a scope (global roles + roles of that
showroom; the global scope counts global roles only). SUPER_ADMIN 100 · ADMIN 90 · SHOWROOM_MANAGER 80 · managers /
accountant 70 · executive / cashier 50 · VIEWER 10.

| Change | Allowed when |
|--------|--------------|
| Grant role R in showroom S | caller has `users.edit` in S, R ranks below the caller in S, and the caller outranks the user in S |
| Grant a global role | `users.edit` granted globally, R ranks below the caller globally, and the caller manages the user everywhere (below) |
| Revoke a role / remove a showroom | caller has `users.edit` there and outranks the user there (removing a showroom removes the user's roles in it — FK cascade) |
| Status, profile, password, adding a showroom | caller outranks the user in **every** showroom the user belongs to and globally. An unassigned user belongs to global user admins, or to whoever created them (`profiles.invited_by`) |
| Create / edit / delete a role | `roles.create` / `roles.edit` / `roles.delete` granted globally, and the role ranks below the caller |
| Grant a permission to a role | the above, and the caller holds that permission globally |

Always: nobody changes their own status or assignments; SUPER_ADMIN is exempt from rank; the SUPER_ADMIN matrix row is
locked (it always holds every permission); custom roles rank 1–99; VIEWER stays read-only; `showrooms.view_all` is
SUPER_ADMIN only; a role in use cannot be deleted; assignments are granted or revoked, never edited in place.

So a showroom manager runs their own showroom's staff, but cannot touch someone who also works in another showroom
(the accountant on IND + BPL): that is an administrator's job. A user with `users.view` only (sales manager,
accountant) sees users but changes nothing.

## Pieces

| Piece | Role |
|-------|------|
| `fn_role_rank` (internal), `my_role_rank` | ranks |
| `can_manage_user_in(user, showroom)`, `can_manage_user(user)`, `can_assign_role(role, showroom)`, `can_edit_role(role)` | the rules above; used by the policies and callable by the app for hints |
| policies on `user_roles`, `user_showrooms`, `roles`, `role_permissions` | replace the Phase 4 global-only versions |
| `rpc_get_user_access(user)` | detail screen payload: profile, roles in the caller's showrooms, what the caller may change, `hidden_showroom_count` |
| `rpc_grantable_roles(showroom)` | roles the caller may grant (create-user form) |
| `rpc_admin_update_user`, `rpc_admin_set_user_status` | profile fields and status of another user (`can_manage_user`) |
| `profiles.invited_by` + `trg_auth_users_sync_invited_by` | creator of a user, from auth `app_metadata.invited_by` (service role only; GoTrue writes app_metadata in an UPDATE after the INSERT, so both triggers read it; set once) |
| `supabase/functions/admin-users` | Edge Function: `create`, `set_password` (below) |
| `lib/features/users/…`, `lib/features/roles/…` | domain / data / application / presentation for both modules |
| `AppFormDialog`, `AppAsyncView` / `AppFeedback` | shared form dialog, async states and SnackBar feedback (`lib/common/widgets`) |

## Edge Function `admin-users`

Creating an auth user and setting a password need the Auth admin API, i.e. the service role key, which never leaves
the server (G4). The function:

1. verifies the caller's JWT with the Auth server (`getUser`);
2. checks, **as the caller**, `has_permission_for('users', 'create', showroom)` and `can_assign_role(role, showroom)`
   (or `can_manage_user` for `set_password`) — nothing is created for a refused request;
3. creates the user with the service role (`email_confirm: true`, `app_metadata.invited_by = caller`);
4. inserts the showroom, the first role and the profile fields **with the caller's JWT**, so RLS decides;
5. deletes the new auth user again if any of step 4 is refused.

Deploy: `supabase functions deploy admin-users` (`verify_jwt = false` in `config.toml`: the function verifies the
session itself, which works with legacy and new JWT signing keys). `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY` are provided by the platform — set nothing.

## Decisions

- **Initial password by the administrator** (shown once, shared privately). Email invites and self-service reset need
  SMTP on the project; the admin **Set password** covers "forgot password" until then.
- **Deactivation** is a status change; `is_active_user()` in every policy makes a deactivated user's live JWT see
  nothing at once. The auth user is not banned or deleted, so history keeps its names.
- **No user deletion** in the app: deactivate instead (records reference profiles).
- **AppPermissionWidget** now reads the session permissions and fails closed (Phase 2 item ovl-24).

## Tests

- DB: `supabase/tests/database/08_user_role_admin.test.sql` (80): ranks and flags per user type, access RPC,
  showroom manager delegation and its limits, restricted roles (viewer, cashier, sales executive, sales manager),
  onboarding / claim prevention, roles and the matrix incl. delegated role management. A mutation that drops the
  rank check fails 11 of them.
- Edge Function: `deno test supabase/functions/admin-users/` (10) — real handler and supabase-js against a fake
  Auth / PostgREST: no session → 401 before any privileged call, refused pre-check → nothing created, database writes
  carry the caller's JWT (never the service key), rollback on refusal, existing email → 409.
- Flutter: `test/features/users/users_admin_test.dart`, `test/features/roles/roles_admin_test.dart`, guard and
  error-mapper additions.

## Try it (dev seed, password `MyBike@Dev2026`)

- `manager.indore@mybike.test` → Users shows the Indore staff; can deactivate / edit `sales.exec`, give roles below
  Showroom Manager in Indore; the accountant (also in Bhopal) is read-only except the Indore roles.
- `sales.manager@mybike.test` → sees the users, changes nothing. `cashier@mybike.test` → no Users module.
- `admin@mybike.test` → manages everyone except the owner; grants roles globally; views roles (edits need `roles.edit`).
- `superadmin@mybike.test` → edits the matrix, creates custom roles.

## Known limits

- Revocations and status changes are stamped (`granted_by`, `updated_by`) but not yet kept as history: full audit
  trail is Phase 20.
- Sessions are not revoked on deactivation or password change (data access stops through RLS immediately; the old
  refresh token keeps the app on the "deactivated" screen).
- Changing one's own password and email reset links are not built yet (need SMTP / re-authentication flow).
