# Phase 4 — Supabase Security (RLS, RBAC helpers, storage)

Migrations: `supabase/migrations/20260924000005_rbac_functions_and_rls_core.sql`,
`20260924000006_storage_buckets_and_policies.sql`.
Tests: `supabase/tests/database/05_rls_policies.test.sql` (67), `06_storage_policies.test.sql` (22);
`01_schema_and_privileges.test.sql` updated for the Phase 4 state.

## 1. Helper functions

All `SECURITY DEFINER`, `STABLE`, `search_path = ''`, EXECUTE for `authenticated` only. They answer
questions about the caller (`auth.uid()`) only.

| Function | True when |
|----------|-----------|
| `is_active_user()` | caller has a profile with `status = 'active'` |
| `is_super_admin()` | active user with an active, unexpired **global** `SUPER_ADMIN` assignment |
| `can_access_showroom(id)` | active user and (super admin, or an active `user_showrooms` row for an **active** showroom) |
| `accessible_showroom_ids()` | array of showrooms passing `can_access_showroom` (all for super admin), ordered by code |
| `has_permission_for(module, action, showroom)` | an active, unexpired assignment grants `module.action` and applies to the showroom (global assignments always, scoped ones only in their showroom) **and** the caller can access that showroom. `showroom = NULL` → **global assignments only** |
| `has_permission(module, action)` | any usable assignment (global, or scoped to an accessible showroom) grants it — UI / module gating |
| `can_view_profile(id)` | `users.view` globally, or in a showroom the other user is actively assigned to |
| `fn_try_uuid(text)` | (0006, plain helper) text → uuid or NULL; used to read ids from storage paths safely |

Assignment validity: `roles.is_active`, `user_roles.expires_on` (inclusive, IST business date), user active,
showroom active and assigned. Permissions always come from `role_permissions` — no role list is hard-coded
except `SUPER_ADMIN` in `is_super_admin()`.

## 2. Table policies (all `TO authenticated`; anon has no privileges)

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| `states`, `permissions`, `financial_years`, `accounting_periods` | active user | — (privilege revoked) | — | — |
| `showrooms` | `can_access_showroom(id)` | `showrooms.create` global | `showrooms.edit` in that showroom | `showrooms.delete` global (FKs restrict) |
| `showroom_settings` | `can_access_showroom` | — (bootstrap trigger) | `showrooms.edit` in that showroom | — (cascade) |
| `document_sequences` | `showrooms.view` in that showroom | — (SECURITY DEFINER functions only) | — | — |
| `settings` | active user and (`is_client_readable` or `settings.view` global) | `settings.create` global | `settings.edit` global | `settings.delete` global |
| `profiles` | own row (even when deactivated) or `can_view_profile` | — (auth trigger) | own row, active user, **columns `full_name`, `phone`, `avatar_path` only** | — (cascade) |
| `roles` | active user | `roles.create` global | `roles.edit` global | `roles.delete` global (system roles protected by trigger) |
| `role_permissions` | active user | `roles.edit` global | — | `roles.edit` global |
| `user_roles` | own (active) or `can_view_profile` | `roles.edit` global, **not on oneself** | same | same |
| `user_showrooms` | own (active) or `can_view_profile` | `users.edit` global, **not on oneself** | same | same |

Decisions:
- **Company-wide data needs a global grant.** A showroom-scoped role (e.g. a showroom manager's `users.edit`)
  never edits roles, the matrix, settings or assignments directly; scoped delegation comes with the Phase 6
  RPCs, which check the grantable set.
- **No self-escalation.** Nobody (not even Super Admin) changes their own role or showroom rows, which also
  prevents locking oneself out.
- **Role assignment = `roles.edit`**, not `users.edit`: otherwise an ADMIN could assign `SUPER_ADMIN`.
- **No `FORCE ROW LEVEL SECURITY`**: the owner (`postgres`) has `BYPASSRLS` on Supabase, so FORCE would change
  nothing; API roles are always subject to RLS.
- Phase 7 note: an ADMIN who creates a showroom cannot read it back until assigned to it (PostgREST
  `return=representation` would fail) — **resolved in Phase 7**: `rpc_create_showroom` assigns the creator.

## 3. Storage

| Bucket | Public | Size limit | Path | Read | Write |
|--------|--------|-----------|------|------|-------|
| `showroom-documents` | no | 10 MB | `{showroom_id}/{module}/{entity_id}/{file}` | `{module}.view` in showroom | `{module}.create/edit/delete` in showroom |
| `vehicle-images` | **yes** (public URLs) | 5 MB | `{showroom_id}/{vehicle_id}/{file}` | API listing: `can_access_showroom` | `inventory.edit`, delete `inventory.delete` |
| `invoice-pdfs` | no | 10 MB | `{showroom_id}/{sales\|purchases}/{invoice_id}/{file}` | `sales.view` / `purchases.view` in showroom | Edge Functions only (service role) |
| `customer-kyc` | no | 10 MB | `{showroom_id}/customers/{customer_id}/{file}` | `customers.view` | `customers.create/edit/delete` |
| `avatars` | no | 2 MB | `{profile_id}/{file}` | owner or `can_view_profile` | owner (active) |
| `imports-temp` | no | 20 MB | `{profile_id}/{file}` | owner (active) | owner (active) |

A path whose first segment is not a uuid never matches (no fall-through to a global grant). MIME types are
restricted per bucket. Downloads of private buckets use signed URLs ≤ 15 minutes (`security.signed_url_ttl_seconds`).

## 4. Security tests (04-multishowroom-security §11)

| # | Status in Phase 4 |
|---|-------------------|
| S1, S2, S3 | covered on `showrooms` / `showroom_settings` / `document_sequences` (05 §B); re-applied to vehicles and invoices in Phases 9–11 |
| S6 | covered as "cannot create showroom / role without permission" (05); per-module inserts come with each module |
| S7 | covered — deactivated user sees no showroom, no roles, no FY, no storage object, only own profile |
| S8 | covered on storage paths (06) |
| S12 (audit_logs), S4/S5/S9/S10/S11 | need tables from Phases 9–20; must be added with those tables |

A mutation check was run: replacing the `showrooms` select policy with `using (true)` and dropping the showroom
check from the documents policy makes 6 assertions fail (S1, S2, S7, S8 among them).

## 5. Verify

```sql
select tablename from pg_tables where schemaname = 'public' and not rowsecurity;              -- 0 rows
select c.relname from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
   and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname); -- 0 rows
select tablename, policyname, cmd, roles from pg_policies where schemaname in ('public', 'storage') order by 1, 2;
```
`supabase test db` runs files 01–06 (04 expects the dev seed).
