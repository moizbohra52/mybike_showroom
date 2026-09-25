# Phase 3 — Supabase Database Foundation

> **Status: IMPLEMENTED.** Validated on an embedded Postgres (§8.4). Remote `supabase db push` is
> pending the dev project link (open questions Q6–Q8).
> Design source: `docs/phase-00/05-database-plan.md`, `02-roles-permissions.md`,
> `04-multishowroom-security.md`. This file records what was actually built and where it deviates (§7).

## 1. Scope

### 1.1 Delivered

| Area | Delivered |
|------|-----------|
| Schema | 13 tables, 5 enum types, 21 functions, all in `public`. RLS is enabled on every table with no policies (deny-all). |
| Showrooms | `showrooms` + automatic `showroom_settings` row + numbering series (bootstrap trigger) |
| Financial years | Indian FY helpers (IST business date), `financial_years`, 12 monthly `accounting_periods`, `fn_ensure_financial_year()` |
| Numbering | `document_sequences`, gap-free `fn_next_document_number()`, GST 16-character limit |
| Identity & RBAC data | `profiles` (auth trigger), `roles`, `permissions`, `role_permissions`, `user_roles`, `user_showrooms`, guard triggers, `current_profile_id()` |
| Reference data (all environments) | 39 GST states, 148 permissions, 11 system roles, 592 matrix grants, 6 company settings, current FY |
| Dev data | `supabase/seed.sql`: 3 showrooms and 14 users (§6) |
| Tests | pgTAP `supabase/tests/database/01_schema_and_privileges.test.sql` (79), `02_functions_and_triggers.test.sql` (82), `03_reference_data.test.sql` (35) — every environment; `04_dev_seed.test.sql` (22, **dev only**). 218 assertions total |
| Config | `supabase/config.toml` hardening (§7 k). `config/*.example.json` + `config/README.md` hold the client env templates; `EnvConfig.validate()` rejects `service_role` / `sb_secret_…` keys. |

### 1.2 Not in Phase 3

| Item | Phase |
|------|-------|
| RLS policies, `FORCE ROW LEVEL SECURITY` decision | 4 (migration 0005) |
| RBAC helpers `is_active_user()`, `is_super_admin()`, `has_permission()`, `has_permission_for()`, `can_access_showroom()`, `accessible_showroom_ids()` | 4 (0005) |
| Storage buckets + storage policies | 4 (0006) |
| `supabase_flutter` client, `AuthService`, `ErrorMapper` | 5 |
| `auth_events`, `app_error_log` | later phases |
| HSN/SAC + tax tables and seeds | 8 |
| Chart of accounts (account groups, accounts) and its seeds | 12 |
| Expense / income categories and their seeds | 13 |
| FY roll-over scheduling, period lock/close RPCs | 12 / 23 |

### 1.3 Files

| File | Contents |
|------|----------|
| `supabase/migrations/20260923000001_extensions_and_helpers.sql` | Extensions (`pgcrypto`, `citext`, `pg_trgm`) in schema `extensions`, default-privilege safety net, 5 enums, `set_updated_at()`, `set_created_by()`, `fn_set_granted_by()`, FY/IST date helpers |
| `supabase/migrations/20260923000002_showrooms_and_settings.sql` | `states`, `showrooms`, `showroom_settings`, `settings`, `financial_years`, `accounting_periods`, `document_sequences`, guard triggers, numbering and FY provisioning functions, showroom bootstrap trigger |
| `supabase/migrations/20260923000003_identity_and_rbac.sql` | `profiles`, `roles`, `permissions`, `role_permissions`, `user_roles`, `user_showrooms`, RBAC guard triggers, audit-column FKs for the 0002 tables, `auth.users` → `profiles` triggers, `current_profile_id()` |
| `supabase/migrations/20260923000004_seed_reference_data.sql` | Idempotent reference data: states, permission catalogue, system roles, module × role matrix, company settings, current FY + periods |
| `supabase/seed.sql` | **Dev/local demo data only.** Loaded by `supabase db reset`. Never pushed outside dev (§6). |
| `supabase/tests/database/*.test.sql` | pgTAP suites (§1.1) |
| `supabase/config.toml` | Local stack config with MyBike hardening (§7 k) |

## 2. Table reference

Common to every table: `id uuid` PK `default gen_random_uuid()` (unless stated otherwise), `created_at` / `updated_at timestamptz`, RLS enabled with no policies.
"Audit" = `created_by → profiles(id) on delete set null` + `updated_by uuid`, stamped by `set_created_by()`.

### 2.1 Enums

| Enum | Values |
|------|--------|
| `user_status` | `invited, active, suspended, deactivated` |
| `accounting_period_status` | `open, locked, closed` |
| `stock_valuation_method` | `specific_id, weighted_avg` |
| `setting_value_type` | `string, number, boolean, json` |
| `document_sequence_type` | 20 values (§4.2) |

### 2.2 Reference, showrooms, settings (0002)

| Table | Purpose | Key columns | Constraints / indexes | Triggers |
|-------|---------|-------------|----------------------|----------|
| `states` | GST state/UT codes (place of supply, IGST) | `code` (2 digits), `name`, `is_union_territory`, `is_active` | unique `code`, unique `name`; CHECK `code ~ '^[0-9]{2}$'`, name 2–80 chars. Written only by migrations. | `set_updated_at` |
| `showrooms` | Tenants | `code`, `name`, `legal_name`, `gstin`, `pan`, `address_line1/2`, `city`, `state_code → states(code)`, `pincode`, `phone`, `email citext`, `invoice_prefix`, `logo_path`, `opened_on`, `is_active`, audit | unique `code`, **unique `invoice_prefix`**, `gstin` **not** unique. CHECK: `code ~ '^[A-Z0-9][A-Z0-9-]{1,19}$'`, name 2–120, GSTIN and PAN formats, GSTIN chars 1–2 = `state_code`, chars 3–12 = `pan`, pincode `^[1-9][0-9]{5}$`, phone `^\+?[0-9]{10,15}$`, e-mail shape, `invoice_prefix ~ '^[A-Z0-9]{2,3}$'`. Indexes: `is_active`, `state_code`, partial `gstin`. | `set_created_by`, `set_updated_at`, `trg_showrooms_bootstrap` (AFTER INSERT: settings row + series for every open FY) |
| `showroom_settings` | 1:1 operational settings | `showroom_id` PK/FK (cascade), `gst_enabled` (true), `default_gst_rate numeric(6,3)` (**no default**), `default_place_of_supply_state → states`, `post_cogs_on_sale` (true), `valuation_method` (`specific_id`), `allow_negative_stock` (false), `low_stock_threshold` (5), `booking_min_amount numeric(14,2)` (0), `booking_validity_days` (30), `discount_approval_threshold`, `round_off_enabled` (true), `invoice_terms`, `invoice_footer`, `receipt_terms`, audit | CHECK: GST rate 0–100, low-stock threshold ≥ 0, booking min ≥ 0, validity 1–365 days, discount threshold ≥ 0. Index on place of supply. | `set_created_by`, `set_updated_at` |
| `settings` | Company-wide key/value | `key`, `value jsonb`, `value_type`, `scope` (`company`), `is_client_readable` (false), `description`, audit | unique `key`; CHECK: dotted lower-case key, `scope = 'company'`, `jsonb_typeof(value)` matches `value_type` | `set_created_by`, `set_updated_at` |

### 2.3 Financial years and numbering (0002)

| Table | Purpose | Key columns | Constraints / indexes | Triggers |
|-------|---------|-------------|----------------------|----------|
| `financial_years` | Indian FY (G10) | `code` (`2026-27`), `start_date`, `end_date`, `is_active`, `is_closed`, `closed_by → profiles`, `closed_at`, audit | unique `code`, unique `start_date` (no overlaps possible); CHECK: start = 1 April, end = start + 1 year − 1 day, `code = fn_fy_code(start_date)`, closed ⇒ `closed_at` set | `set_created_by`, `set_updated_at` |
| `accounting_periods` | 12 monthly periods per FY | `financial_year_id` (restrict), `period_no` (1 = April), `start_date`, `end_date`, `status` (`open`), `locked_by → profiles`, `locked_at`, audit | unique `(financial_year_id, period_no)` and `(financial_year_id, start_date)`; CHECK: `period_no` 1–12, whole calendar month, non-open ⇒ `locked_at` set | `trg_accounting_period_guard` (MB010), `set_created_by`, `set_updated_at` |
| `document_sequences` | Numbering series per showroom / type / FY | `showroom_id` (restrict), `financial_year_id` (restrict), `doc_type`, `prefix`, `suffix`, `next_number bigint` (1), `padding smallint` (5), audit | unique `(showroom_id, doc_type, financial_year_id)`; unique **nulls not distinct** `(financial_year_id, doc_type, prefix, suffix)`; CHECK: prefix `^[A-Z0-9][A-Z0-9-]{0,9}$`, suffix `^[A-Z0-9-]{1,6}$`, `next_number ≥ 1`, padding 3–8, GST length ≤ 16. Index `financial_year_id`. Written only by functions. | `trg_document_sequences_guard` (MB011), `set_created_by`, `set_updated_at` |

### 2.4 Identity and RBAC (0003)

| Table | Purpose | Key columns | Constraints / indexes | Triggers |
|-------|---------|-------------|----------------------|----------|
| `profiles` | App profile per auth user. Holds no role data. | `id` PK = `auth.users.id` (cascade), `employee_code`, `full_name`, `email citext`, `phone`, `designation`, `avatar_path`, `status user_status` (`active`), `is_active` **generated** (`status = 'active'`), `last_login_at`, audit | unique `email`, unique `employee_code`; CHECK: employee code format, name 1–120, phone format. Indexes: `is_active`, GIN trigram `full_name`. | `set_created_by`, `set_updated_at`. Row created by `trg_auth_users_create_profile`; e-mail mirrored by `trg_auth_users_sync_email` (both on `auth.users`). |
| `roles` | Application roles | `code`, `name`, `description`, `is_system`, `precedence smallint`, `is_active`, audit | unique `code`, unique `name`; CHECK: `code ~ '^[A-Z][A-Z0-9_]{1,39}$'`, name 2–80, precedence 0–1000 | `trg_roles_guard` (MB020), `set_created_by`, `set_updated_at` |
| `permissions` | `module.action` catalogue | `module`, `action`, `code` **generated** (`module.action`), `description` | unique `(module, action)`, unique `code`; CHECK: module ∈ the 21 `ModuleKeys`, action ∈ `view, create, edit, delete, approve, export, print, view_all`, `view_all` only for `showrooms`. Written only by migrations. | `set_updated_at` |
| `role_permissions` | Role × permission grants | PK `(role_id, permission_id)` (both cascade), `granted_by → profiles`, `granted_at` | index `permission_id` | `trg_role_permissions_guard` (MB021), `trg_set_granted_by` |
| `user_roles` | Role assignments | `profile_id` (cascade), `role_id` (restrict), `showroom_id` (restrict; **NULL = global**), `granted_by`, `granted_at`, `expires_on`, `updated_at` | unique **nulls not distinct** `(profile_id, role_id, showroom_id)`; indexes `role_id`, partial `showroom_id` | `trg_user_roles_guard` (MB022), `trg_set_granted_by`, `set_updated_at` |
| `user_showrooms` | Showroom access | `profile_id` (cascade), `showroom_id` (restrict), `is_default`, `is_active`, `granted_by`, `granted_at`, `updated_at` | unique `(profile_id, showroom_id)`; partial unique `uq_user_showrooms_one_default (profile_id) where is_default`; CHECK `not is_default or is_active`; index `showroom_id` | `trg_set_granted_by`, `set_updated_at` |

Guard rules: system roles cannot be renamed, demoted, deactivated or deleted. App users cannot create system roles. `VIEWER` never gets `create/edit/delete/approve`. `showrooms.view_all` is granted only to `SUPER_ADMIN`. `SUPER_ADMIN` is only ever assigned globally.

### 2.5 Functions

| Function | Kind | Security | `authenticated` EXECUTE |
|----------|------|----------|:----:|
| `set_updated_at()`, `set_created_by()`, `fn_set_granted_by()` | trigger | invoker | — |
| `fn_business_date(timestamptz)`, `fn_fy_start_date(date)`, `fn_fy_code(date)`, `fn_fy_short_code(text)` | pure helper | invoker | ✔ |
| `fn_document_type_code(doc_type)`, `fn_is_gst_document(doc_type)` | pure helper | invoker | ✔ |
| `fn_accounting_period_guard()`, `fn_document_sequences_guard()`, `fn_roles_guard()`, `fn_role_permissions_guard()`, `fn_user_roles_guard()` | trigger | invoker | — |
| `fn_ensure_document_sequences(uuid, uuid) → int` | provisioning, idempotent | invoker | — |
| `fn_ensure_financial_year(date) → uuid` | provisioning, idempotent | invoker | — |
| `fn_next_document_number(uuid, doc_type, date) → text` | numbering, called inside posting RPCs | invoker | — |
| `fn_bootstrap_showroom()` | trigger on `showrooms` | **definer** | — |
| `fn_handle_new_auth_user()`, `fn_sync_auth_user_email()` | trigger on `auth.users` | **definer** | — |
| `current_profile_id() → uuid` | base for the Phase 4 helpers, stable | **definer** | ✔ |

Trigger functions need no EXECUTE grant (PostgreSQL checks it only at `CREATE TRIGGER`). The six pure helpers are granted because they are side-effect free and CHECK constraints (`fn_fy_code` → `fn_fy_start_date`, `fn_is_gst_document`) run as the inserting role. `current_profile_id()` returns only the caller's own id.

## 3. Conventions

| Rule | Implementation |
|------|----------------|
| Extensions | `create extension … with schema extensions` (Supabase convention). Objects referenced as `extensions.citext`, `extensions.crypt()`, `extensions.gin_trgm_ops`. |
| Search path | Every function has `set search_path = ''` and schema-qualifies every object (`public.`, `auth.`, `extensions.`). |
| Audit stamping | `set_created_by()` takes `created_by` / `updated_by` from `auth.uid()` (= `profiles.id`) and ignores client values when a JWT is present. `created_at` / `created_by` are immutable. Server contexts without a JWT (migrations, `service_role`, cron: the "SYSTEM" actor of 02 §1) may pass explicit values or leave them NULL. `fn_set_granted_by()` does the same for `granted_by` / `granted_at`. |
| Roles never from metadata | Nothing reads `raw_user_meta_data` / `raw_app_meta_data` except the display name. A user with zero `user_roles` rows has no access (fail closed). |
| RLS | Enabled on all 13 tables, **no policies**. Until Phase 4 adds policies, `authenticated` reads return 0 rows, inserts fail with `42501`, and updates/deletes affect 0 rows. `anon` has no privileges at all. |

### 3.1 Privilege model

| Role | Tables in `public` | Functions in `public` |
|------|--------------------|-----------------------|
| `anon` | none (revoked, plus default privileges for future objects) | none |
| `authenticated` | Supabase defaults **minus** `TRUNCATE`, `REFERENCES`, `TRIGGER` (TRUNCATE bypasses RLS). No `INSERT/UPDATE/DELETE` on `states`, `permissions`, `document_sequences`. RLS denies everything else. | only the 7 helpers: `fn_business_date`, `fn_fy_start_date`, `fn_fy_code`, `fn_fy_short_code`, `fn_is_gst_document`, `fn_document_type_code`, `current_profile_id` |
| `PUBLIC` | — | EXECUTE revoked from every function |
| `service_role` | unchanged Supabase defaults (server-side only, never in Flutter, G4) | unchanged |

### 3.2 Mandatory closing block for every future migration

`revoke execute on all functions` also removes grants made by earlier migrations. Every migration must therefore end with this block (copied from 0003 §10), repeat the **full** allow-list, and extend it with its own client-callable functions (e.g. the Phase 4 RLS helpers):

```sql
revoke all on all tables in schema public from anon;
revoke truncate, references, trigger on all tables in schema public from authenticated;
-- + write revokes for tables this migration owns, e.g.:
-- revoke insert, update, delete on public.<migration_owned_table> from authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.fn_business_date(timestamptz) to authenticated, service_role;
grant execute on function public.fn_fy_start_date(date) to authenticated, service_role;
grant execute on function public.fn_fy_code(date) to authenticated, service_role;
grant execute on function public.fn_fy_short_code(text) to authenticated, service_role;
grant execute on function public.fn_is_gst_document(public.document_sequence_type) to authenticated, service_role;
grant execute on function public.fn_document_type_code(public.document_sequence_type) to authenticated, service_role;
grant execute on function public.current_profile_id() to authenticated, service_role;
-- + grants for functions this migration adds for authenticated
```

## 4. Document numbering and financial years

### 4.1 Format

`{prefix}/{YY-YY}/{number}{suffix}`, e.g. `IND/26-27/00001`.

| Rule | Detail |
|------|--------|
| Prefix | `showrooms.invoice_prefix` (2–3 chars, unique) + type code (§4.2), copied into `document_sequences.prefix` when the series is created. Changing `invoice_prefix` later affects only series created afterwards. |
| GST documents | `sales_invoice`, `credit_note`, `debit_note`, `receipt`, `stock_transfer` (`fn_is_gst_document`): total ≤ **16 characters** (CGST Rules 46(b), 50, 53, 55). Enforced by CHECK `document_sequences_gst_length` at series creation and by **MB004** at issue time. |
| Padding | Non-GST: 5 digits, numbers grow past 5 without limit. GST: `min(5, 9 − len(prefix))` (7 = `/` + `YY-YY` + `/`). A number may exceed its padding as long as the total stays ≤ 16. |
| Uniqueness | One series per `(showroom, doc_type, FY)`. `(FY, doc_type, prefix, suffix)` is unique across **all** showrooms, so showrooms sharing a GSTIN never collide. |
| Gap-free | `fn_next_document_number` increments with an `UPDATE … RETURNING`. The row lock is held until the calling transaction ends: concurrent callers queue, and a rollback returns the number unused. `next_number` can never decrease (MB011). |
| Date | `p_doc_date` is required. The FY comes from the document's own date (caller passes the IST date, e.g. `fn_business_date()`), never from the server clock. Closed FY → MB002, no FY → MB001, no series → MB003. |
| Series creation | Automatic, all 20 types: `trg_showrooms_bootstrap` (new showroom × every open FY) and `fn_ensure_financial_year` (new FY × every showroom), both via idempotent `fn_ensure_document_sequences`. Clients never write the table. |

### 4.2 Type codes (`fn_document_type_code`)

| doc_type | Code | GST | Example (IND) | | doc_type | Code | GST | Example (IND) |
|----------|------|:---:|---------------|-|----------|------|:---:|---------------|
| `sales_invoice` | *(none)* | ✔ | `IND/26-27/00001` | | `payment` | `PY` | | `INDPY/26-27/00001` |
| `purchase_invoice` | `PI` | | `INDPI/26-27/00001` | | `receipt` | `RC` | ✔ | `INDRC/26-27/0001` |
| `purchase_order` | `PO` | | `INDPO/26-27/00001` | | `credit_note` | `CN` | ✔ | `INDCN/26-27/0001` |
| `goods_receipt` | `GR` | | `INDGR/26-27/00001` | | `debit_note` | `DR` | ✔ | `INDDR/26-27/0001` |
| `purchase_return` | `PR` | | `INDPR/26-27/00001` | | `contra` | `CT` | | `INDCT/26-27/00001` |
| `quotation` | `QT` | | `INDQT/26-27/00001` | | `expense` | `EX` | | `INDEX/26-27/00001` |
| `booking` | `BK` | | `INDBK/26-27/00001` | | `income` | `IN` | | `INDIN/26-27/00001` |
| `sales_order` | `SO` | | `INDSO/26-27/00001` | | `journal` | `JV` | | `INDJV/26-27/00001` |
| `delivery_note` | `DN` | | `INDDN/26-27/00001` | | `stock_transfer` | `ST` | ✔ | `INDST/26-27/0001` |
| `sales_return` | `SR` | | `INDSR/26-27/00001` | | `stock_adjustment` | `SA` | | `INDSA/26-27/00001` |

### 4.3 GST series capacity per showroom per FY (no suffix)

| Showroom prefix | Series | Padding | Max digits | Capacity |
|-----------------|--------|:-------:|:----------:|---------:|
| 3 chars (`IND`) | tax invoice (`IND`) | 5 | 6 | 999,999 |
| 3 chars | CN / DR / RC / ST (`INDCN`) | 4 | 4 | **9,999** |
| 2 chars (`BP`) | tax invoice (`BP`) | 5 | 7 | 9,999,999 |
| 2 chars | CN / DR / RC / ST (`BPCN`) | 5 | 5 | 99,999 |

A suffix takes digits out of the same 16-character budget. When a series runs out it raises MB004. Pick a 2-character prefix for a showroom expected to issue more than 9,999 receipt vouchers in a year.

### 4.4 Financial years

| Item | Detail |
|------|--------|
| Definition | Indian FY, 1 April – 31 March (G10). `code` = `YYYY-YY`, short code `YY-YY` in numbers. |
| Business date | `fn_business_date(now())` = date in `Asia/Kolkata`. Sessions run in UTC, and 00:30 IST on 1 April is still 31 March in UTC, so every date default uses this function and never `current_date`. |
| Helpers | `fn_fy_start_date(date)`, `fn_fy_code(date)` (`2026-09-23 → 2026-27`), `fn_fy_short_code('2026-27') → '26-27'` |
| Provisioning | `fn_ensure_financial_year(date)`: idempotent. Creates the FY, 12 `open` periods (period 1 = April) and every showroom's 20 series, and returns the FY id. Migration 0004 runs it for `fn_business_date()`. |
| Guards | CHECKs on dates and code. Unique `start_date` (no overlaps). Periods must be whole months inside their FY with `period_no` = month offset from April + 1 (MB010). `is_closed` blocks numbering (MB002). Period status is enforced by the posting functions (Phase 12). |
| Roll-over | Not scheduled yet (Phase 12/23). Until it is, run `select public.fn_ensure_financial_year(date '2027-04-01');` as a server role before 1 April, or numbering raises MB001. |

## 5. SQLSTATE catalogue

Custom errors use class `MB`. The `hint` is a stable machine key. In Phase 5 the Flutter `ErrorMapper` maps SQLSTATE + hint to a friendly message, so users never see the raw exception text.

| SQLSTATE | Meaning | Raised by | `hint` |
|----------|---------|-----------|--------|
| `MB001` | Financial year missing | `fn_ensure_financial_year` (NULL date), `fn_next_document_number` (no FY for the date) | `financial_year_date_required`, `financial_year_not_found` |
| `MB002` | Financial year closed | `fn_next_document_number` | `financial_year_closed` |
| `MB003` | Numbering not possible | `fn_next_document_number` (NULL argument, no series) | `sequence_arguments_required`, `sequence_not_configured` |
| `MB004` | GST series exhausted (would exceed 16 chars) | `fn_next_document_number` | `sequence_exhausted` |
| `MB010` | Invalid accounting period | `fn_accounting_period_guard` | `period_outside_financial_year`, `period_number_mismatch` |
| `MB011` | Illegal series change | `fn_document_sequences_guard` | `sequence_scope_immutable`, `sequence_cannot_decrease` |
| `MB012` | Invoice prefix in use (Phase 7) | `fn_showrooms_sync_prefix` | `invoice_prefix_in_use` |
| `MB030` | Variant fuel type in use (Phase 8) | `fn_vehicle_variants_guard` (fuel type changed while vehicles of it are registered) | `variant_fuel_type_in_use` |
| `MB020` | System role protected | `fn_roles_guard` (rename, demote, deactivate or delete a system role; app user creating one) | `system_role_protected` |
| `MB021` | Forbidden grant | `fn_role_permissions_guard` | `viewer_read_only`, `view_all_super_admin_only` |
| `MB022` | SUPER_ADMIN assigned per showroom | `fn_user_roles_guard` | `super_admin_is_global` |

Standard codes the mapper also handles: `23505` unique, `23514` check (incl. `document_sequences_gst_length`), `23503` FK, `42501` RLS/privilege.

## 6. Dev seed fixtures (`supabase/seed.sql`)

**Dev/local only.** `supabase db reset` loads it. Never pass `--include-seed` to `supabase db push` outside the dev project. Every demo user's password is **`MyBike@Dev2026`**. That credential is public, which is only acceptable on local and dev databases. The fixture ids are asserted by `04_dev_seed.test.sql`, so keep them stable.

Showrooms (Madhya Pradesh, all on company GSTIN `23ABCDE1234F1Z5`), id `5a000000-0000-4000-8000-00000000000N`:

| N | Code | Prefix | City |
|---|------|--------|------|
| 1 | `INDORE-MAIN` | `IND` | Indore |
| 2 | `BHOPAL` | `BPL` | Bhopal |
| 3 | `UJJAIN` | `UJN` | Ujjain |

Users `<login>@mybike.test`, id `a0000000-0000-4000-8000-0000000000NN` (* = default showroom):

| NN | Login | Role(s) | Showrooms | Note |
|----|-------|---------|-----------|------|
| 01 | `superadmin` | SUPER_ADMIN (global) | all, via role | |
| 02 | `admin` | ADMIN (global) | IND*, BPL, UJN | |
| 03 | `manager.indore` | SHOWROOM_MANAGER @IND | IND* | |
| 04 | `manager.bhopal` | SHOWROOM_MANAGER @BPL | BPL* | |
| 05 | `sales.manager` | SALES_MANAGER @IND | IND* | |
| 06 | `sales.exec` | SALES_EXECUTIVE @IND | IND* | |
| 07 | `purchase` | PURCHASE_MANAGER @BPL | BPL* | |
| 08 | `inventory` | INVENTORY_MANAGER @BPL | BPL* | |
| 09 | `accountant` | ACCOUNTANT @IND + @BPL | IND*, BPL | multi-showroom |
| 10 | `cashier` | CASHIER @IND | IND* | |
| 11 | `service` | SERVICE_MANAGER @BPL | BPL* | |
| 12 | `viewer` | VIEWER @UJN | UJN* | |
| 13 | `inactive` | SALES_EXECUTIVE @IND | IND* | `status = deactivated` |
| 14 | `norole` | — | — | fail-closed case |

## 7. Deviations from the Phase 0 plan

| # | Plan | Built | Reason |
|---|------|-------|--------|
| a | Seed data = migration 0007; RBAC functions 0004, RLS 0005, storage 0006 | Seed = **0004**. Phase 4 = **0005** RBAC functions + RLS, **0006** storage. Later phases keep their planned content under timestamp-prefixed names. | Phase 4 migrations must sort after the seed: `supabase db push` refuses a migration older than the last applied one. |
| b | `showrooms.gstin` unique | not unique; `invoice_prefix` unique instead | Showrooms in one state share the company GSTIN. Unique prefixes keep their numbering apart. |
| c | `showrooms.fy_start_month` | dropped | G10: the FY is fixed April–March, enforced by CHECK on `financial_years`. |
| d | `profiles.default_showroom_id` | `user_showrooms.is_default` + partial unique index | A default can never point at an unassigned or inactive showroom, and each user has at most one. |
| e | `profiles.is_active` stored flag | `GENERATED ALWAYS AS (status = 'active')` | Single source of truth, so it cannot drift. |
| f | Full enum catalogue up front | Enums created per phase with their tables (new: `stock_valuation_method`, `setting_value_type`, `document_sequence_type`) | Enum values cannot be dropped, so unused types would be frozen early. |
| g | `document_sequences.reset_policy` | dropped | Rows are per FY. A new FY is a new series starting at 1. |
| h | `states` in Phase 8 | Phase 3 | `showrooms.state_code` references it. |
| i | RLS + policies with each table, FORCE RLS | RLS enabled deny-all, no policies. FORCE decided in Phase 4 with the policy tests. | Policies need the Phase 4 helpers. FORCE also subjects the table owner to RLS (unless it has BYPASSRLS), and so possibly the SECURITY DEFINER bootstrap and auth triggers. |
| j | `auth_events`, `app_error_log` in Phase 3 | deferred | Created by the phase that writes them. |
| k | Default `config.toml` | Signups disabled (`[auth]`, `[auth.email]`, `[auth.sms]`), anonymous sign-ins off, password ≥ 10 chars with `lower_upper_letters_digits`, `secure_password_change = true`, API `schemas = ["public"]` (GraphQL not exposed) | Admin-created users only (Phase 6), smaller attack surface. The remote project needs the same settings in the Dashboard or via `supabase config push`. |
| l | CoA, categories, HSN seeded in Phase 3 | Seeded with their tables in Phases 12, 13 and 8 | The tables do not exist yet. |
| m | `default_gst_rate` with a default | no default value | No hardcoded tax rates. Rates come from configuration. |
| n | `btree_gin`, `pg_cron`, `pg_net` in Phase 3 | only `pgcrypto`, `citext`, `pg_trgm` | Each extension is added by the phase that first uses it. |
| o | `rpc_next_document_number(showroom, doc_type, fy)`, client-callable | `fn_next_document_number(showroom, doc_type, doc_date)`, not executable by clients | Numbering happens only inside posting RPCs, and the FY is derived from the document date. |
| p | `INV/26-27/000123`, free per-type prefix | `{invoice_prefix}{type code}/YY-YY/{5 digits}` | Fits the 16-character GST limit and stays unique across showrooms. |
| q | `financial_years` unique `(start_date, end_date)` + `end > start`; periods via `EXCLUDE` | unique `start_date` + April–March CHECK; periods: `period_no`, whole-month CHECK, guard trigger | Stronger, and overlaps are impossible by construction. |
| r | `showrooms.code citext` | `text` + upper-case CHECK | Codes are canonical upper case, so case-insensitivity is not needed. |
| s | `user_roles` uniqueness via `coalesce` index | `UNIQUE NULLS NOT DISTINCT` | Native in PG 15+. |
| t | `trg_set_created_by` from `current_profile_id()` | from `auth.uid()`, client values ignored, creation fields immutable | Same value (`profiles.id = auth.users.id`) without a lookup, and it also works before the profile exists. |
| u | Demo data in dev/staging | dev/local only | The known password must never reach a shared environment. |
| v | — | Additions: guard triggers MB010–MB022, `fn_set_granted_by`, `role_permissions.granted_by/at`, `user_showrooms.is_active`, `accounting_periods.period_no` | Enforce the 02 §4 invariants and the audit trail in the database. |

## 8. How to run

### 8.1 Local stack (needs Docker Desktop)

```powershell
supabase start            # local Postgres 17 + Auth + REST
supabase db reset         # 0001–0004, then supabase/seed.sql
supabase test db          # pgTAP: 01 (79) + 02 (82) + 03 (35) + 04 dev seed (22) = 218
supabase db lint          # plpgsql_check: expect no errors
```

### 8.2 Remote dev project

```powershell
supabase login
supabase link --project-ref <dev-project-ref>
supabase db push          # migrations only; NEVER --include-seed outside dev
supabase migration list   # local and remote both list 20260923000001…04
supabase db lint --linked
```

Demo data on the remote **dev** project only: `supabase db push --include-seed`. `04_dev_seed.test.sql` fails by design on any database without `seed.sql`.

### 8.3 Verification SQL

```sql
-- public tables without RLS → 0 rows
select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

-- policies → 0 rows in Phase 3 (Phase 4 adds them)
select tablename, policyname from pg_policies where schemaname = 'public';

-- anon table privileges → 0 rows
select table_name, privilege_type from information_schema.role_table_grants
 where grantee = 'anon' and table_schema = 'public';

-- forbidden authenticated privileges → 0 rows
select table_name, privilege_type from information_schema.role_table_grants
 where grantee = 'authenticated' and table_schema = 'public'
   and (privilege_type in ('TRUNCATE', 'REFERENCES', 'TRIGGER')
        or (table_name in ('states', 'permissions', 'document_sequences')
            and privilege_type in ('INSERT', 'UPDATE', 'DELETE')));

-- executable functions → anon: none; authenticated: exactly the 7 helpers
select p.proname,
       has_function_privilege('anon', p.oid, 'execute')          as anon,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and (has_function_privilege('anon', p.oid, 'execute')
        or has_function_privilege('authenticated', p.oid, 'execute'));

-- functions without a pinned search_path → 0 rows
select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');

-- reference data → 39 · 148 · 11 · 592 · 6
select (select count(*) from public.states), (select count(*) from public.permissions),
       (select count(*) from public.roles), (select count(*) from public.role_permissions),
       (select count(*) from public.settings);
```

### 8.4 Validation in this environment and its limits

Docker, and therefore the local Supabase stack, was not available. The SQL was validated on an embedded Postgres (**PGlite, PostgreSQL 18.3**) with a Supabase `auth`-schema shim and a pgTAP shim. Gaps to close with §8.1/§8.2 once a stack or project is available:

| Gap | Consequence |
|-----|-------------|
| No GoTrue / PostgREST | Seeded users were not signed in through Auth. Grants and RLS were not exercised through the REST API. |
| `auth` schema stubbed | `auth.uid()`, `auth.users` and `auth.identities` are approximations of the real schema. |
| No `plpgsql_check` | `supabase db lint` has not been run. |
| Single connection | Concurrent `fn_next_document_number` calls (row-lock serialisation) were not tested. |
| PG 18 vs Supabase PG 17 | Syntax used (e.g. `UNIQUE NULLS NOT DISTINCT`, PG 15+) is valid on 17, but not proven on the target server. |

## 9. Carried-over items and known issues

| Item | Owner phase |
|------|-------------|
| Phase 2 open: widget tests missing for several design-system components (the mobile shell overflow is fixed, `flutter test` is green) | 2 (carried) |
| Remote `supabase db push`, `db lint`, `test db` pending: CLI not logged in, dev project not linked (Q6–Q8) | 3 |
| FY roll-over not scheduled (§4.4) | 12 / 23 |
| GST series capacity for 3-char prefixes: 9,999 CN/DR/RC/ST per FY (§4.3) | 7 (showroom setup) |
