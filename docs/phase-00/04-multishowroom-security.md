# PHASE 0 — 04 Multi-Showroom & Security Architecture

## 1. Tenancy model

- **One Supabase project = one dealership company.** Tenants inside it are **showrooms**.
- Every business table carries `showroom_id uuid NOT NULL REFERENCES showrooms(id)`.
- Isolation mechanism: **PostgreSQL Row Level Security on every business table**, driven by
  `can_access_showroom(showroom_id)` + `has_permission(module, action)`.
- The client may *request* a showroom (`eq('showroom_id', ...)`), but the database decides what
  is visible; a forged `showroom_id` yields **zero rows**, never another showroom's data.
- Why not schema-per-showroom or database-per-showroom: consolidated ALL-SHOWROOMS reporting,
  shared masters (brands/models/CoA) and one migration pipeline make `showroom_id` + RLS the
  cheapest model at ≤ 25 showrooms. (Revisit only if the product becomes multi-company SaaS.)

## 2. Security layers (defence in depth)

| Layer | Mechanism | Fails closed? |
|-------|-----------|---------------|
| 1. UI | `AppPermissionWidget`, route guards, hidden sidebar entries | Yes (convenience only) |
| 2. Service/Repository | permission + showroom pre-checks before the call | Yes |
| 3. **RLS (authority)** | per-table policies using `can_access_showroom` + `has_permission*` | Yes — empty result / `42501` |
| 4. DB constraints & triggers | FKs, uniques, checks, balanced-journal trigger, immutability triggers, `NOT NULL` | Yes — transaction aborts |
| 5. Business validation in RPCs | `SECURITY DEFINER` functions re-validate permission, period lock, stock, amounts | Yes — raises exception |
| 6. Edge Functions | JWT verification + explicit permission check + service-role only for admin ops | Yes |

Never trusted from the client: `user_id`, `profile_id`, `role_id`, role codes, permission list,
`showroom_id` ownership, `created_by`, status transitions, totals/subtotals/tax amounts,
document numbers.

## 3. Identity, claims and sessions

- `auth.users` (Supabase Auth) is the identity store; `public.profiles` is the app profile
  (`id = auth.users.id`, name, phone, `is_active`, avatar path, …).
- Active status is re-checked in the DB on every request via `is_active_user()`, so a
  deactivated user's still-valid JWT returns **no** data.
- Hardening decision (Phase 4): a **custom access token hook** may inject `user_roles` /
  `user_showrooms` into JWT claims to cut per-query lookups. Even then, DB functions remain
  authoritative — claims are a cache, never the source of truth.
- `SessionService` listens to `onAuthStateChange`: on `signedOut` / refresh failure it clears
  caches, drops realtime channels and routes to `/login`.
- Login success/failure events are recorded (Phase 20) with platform, app version and device label.

## 4. RLS design

### 4.1 Table classification

| Class | Description | Read policy | Write policy |
|-------|-------------|-------------|--------------|
| **A — Showroom-scoped operational** | vehicles, vehicle_stock, stock_ledger, transfers, purchase/sales documents, bookings, customers, suppliers, payments, expenses, income, documents, journal entries/lines, approvals, notifications, showroom_settings | `is_active_user() AND can_access_showroom(showroom_id) AND has_permission(module,'view')` | insert/update require `create`/`edit` + `can_access_showroom`; delete requires `delete` **and** passes immutability rules |
| **B — Global masters** (shared, admin-curated) | vehicle_brands, vehicle_models, vehicle_variants, hsn_sac_codes, expense/income categories, permissions, account group templates, financial_years | active user read (dropdowns) | `SUPER_ADMIN`/`ADMIN` only |
| **C — Global secure** | showrooms, profiles, roles, role_permissions, user_roles, user_showrooms, settings, document_sequences, approval_rules, audit_logs, app_error_log | Super/Admin (audit: +Accountant read), own-row access for `profiles` | `SUPER_ADMIN` only (roles/settings); limited self-service columns for `profiles` |
| **D — Append-only ledgers** | stock_ledger, journal_entry_lines, posted journal_entries, audit_logs, system notifications | as Class A/C | **INSERT only**; UPDATE/DELETE blocked by triggers (reversal path is explicit) |

### 4.2 Policy templates

```sql
-- Class A: read
create policy vehicles_select on public.vehicles
for select to authenticated
using (
  public.is_active_user()
  and public.can_access_showroom(showroom_id)
  and public.has_permission('vehicles','view')
);

-- Class A: insert (target showroom must be one the user can act on)
create policy vehicles_insert on public.vehicles
for insert to authenticated
with check (
  public.can_access_showroom(showroom_id)
  and public.has_permission_for('vehicles','create', showroom_id)
);

-- Class A: update (row must be accessible AND must remain accessible)
create policy vehicles_update on public.vehicles
for update to authenticated
using (
  public.can_access_showroom(showroom_id)
  and public.has_permission_for('vehicles','edit', showroom_id)
)
with check (
  public.can_access_showroom(showroom_id)
  and public.has_permission_for('vehicles','edit', showroom_id)
);

-- Class A: delete — restricted; posted financial rows are never deletable
create policy vehicles_delete on public.vehicles
for delete to authenticated
using (
  public.can_access_showroom(showroom_id)
  and public.has_permission_for('vehicles','delete', showroom_id)
  and not exists (
    select 1 from public.sales_invoice_items i where i.vehicle_id = vehicles.id
  )
);

-- Class A child rows without showroom_id: derive through the parent header
create policy sales_invoice_items_all on public.sales_invoice_items
for all to authenticated
using (
  exists (select 1 from public.sales_invoices h
          where h.id = sales_invoice_items.invoice_id
            and public.can_access_showroom(h.showroom_id)
            and public.has_permission('sales','view'))
)
with check (
  exists (select 1 from public.sales_invoices h
          where h.id = sales_invoice_items.invoice_id
            and public.can_access_showroom(h.showroom_id)
            and public.has_permission('sales','edit'))
);
```

Policy rules:
1. Every policy is scoped `to authenticated`; `anon` receives nothing (no public business tables).
2. Every `using` **and** `with check` clause contains a showroom check — a bare `true` is a bug.
3. Child tables either carry `showroom_id` (preferred, indexed) or resolve it via `EXISTS` on the parent.
4. Permission helpers are `STABLE` so the planner caches them per statement; hot policies are backed by
   indexes on `(showroom_id, status, created_at)`.
5. `force row level security` is set on business tables so owner and `SECURITY DEFINER` paths are explicit.
6. RLS is created in the same migration as the table; no table ever ships without RLS
   (Phase 24 audit query asserts `relrowsecurity = false` returns zero rows for business tables).

### 4.3 Anti-patterns explicitly forbidden

- Filtering by showroom **only** in Flutter/SQL queries without RLS.
- Storing `role` or `permissions` inside `profiles` and trusting it.
- Using `service_role` in the Flutter app or in a client-triggered Edge Function without verification.
- `SECURITY DEFINER` functions without a permission check and without `search_path = ''`.
- Using `auth.jwt() ->> 'role'` (Supabase's DB role claim) as the *app* role.
- Wildcard policies (`using (true)`) on any table containing money, customers or stock.
- Direct client `insert` into `journal_entry_lines`, `stock_ledger`, `document_sequences` or `audit_logs`
  (these are written only by RPCs/triggers; INSERT revoked from `authenticated`).

## 5. Storage security (Supabase Storage)

Buckets (created in Phase 4, used from Phase 19):

| Bucket | Public | Path convention | Policy summary |
|--------|--------|-----------------|----------------|
| `showroom-documents` |  private | `{showroom_id}/{module}/{entity_id}/{uuid}-{filename}` | read/write only if `can_access_showroom((storage.foldername(name))[1]::uuid)` **and** `has_permission(module,'view'/'create')` |
| `vehicle-images` | ✅ public read (catalogue imagery) | `{showroom_id}/{vehicle_id}/{uuid}.{ext}` | authed write with `can_access_showroom(...)` + `inventory.edit`; delete restricted |
| `invoice-pdfs` | ❌ private | `{showroom_id}/{invoice_type}/{invoice_id}/{uuid}.pdf` | read with `sales.view`/`purchases.view` for that showroom |
| `customer-kyc` | ❌ private | `{showroom_id}/customers/{customer_id}/{uuid}-{doc}.{ext}` | `customers.view` + showroom check; expiry tracked in `documents` |
| `avatars` |  private | `{profile_id}/{uuid}.{ext}` | owner + Super/Admin |
| `imports-temp` | ❌ private | `{profile_id}/{uuid}` | owner only, purged by scheduled job |

Rules:
1. Upload paths are built by `StorageService` (never a raw client-supplied path).
2. Downloads use **short-lived signed URLs (≤ 15 min)**; no permanent public links for KYC/invoices.
3. `documents` stores metadata only (bucket, path, mime, size, checksum, expiry, owner, showroom) — never bytes.
4. Storage policies are validated in Phase 24 with a negative test: user A cannot list or sign a path under showroom B.
5. Image transformations provide thumbnails (bandwidth/performance).
6. Service-role uploads (edge-generated invoice PDFs) follow the same layout so policies stay valid.

## 6. Edge Function security

| Function (planned) | Auth | Privilege | Notes |
|--------------------|------|-----------|-------|
| `admin-create-user` | JWT of Super/Admin + permission check | `service_role` (Auth admin API) | never accepts a role/showroom combination the caller cannot grant |
| `admin-set-password`, `admin-deactivate-user` | Super/Admin | `service_role` | audited; cannot target a Super Admin unless caller is Super Admin |
| `send-notification` | DB webhook/`pg_net` with shared secret, or internal JWT | `service_role` + FCM credentials | validates the secret header; never an open client endpoint |
| `scheduled-jobs` (low stock, aging, document expiry) | `pg_cron` + secret | `service_role` | idempotent per day |
| `gst-einvoice`, `sms-whatsapp` (future) | server-side only | 3rd-party secrets | out of v1 scope |

Every function must: verify the `Authorization` JWT via `supabase.auth.getUser()`, re-check the
required permission against the DB (never trust a claim from the request body), validate/type-check
the payload, avoid echoing internals in errors, log structured context (caller `profile_id`, module),
and keep `verify_jwt` **enabled** unless the endpoint is deliberately a server-to-server webhook.

## 7. Realtime security

Realtime honours RLS for authenticated `postgres_changes`, and the project adds discipline:

- Subscriptions are limited to `notifications` (filter `user_id=eq.<me>`), `approval_requests`
  (filter `showroom_id=eq.<current>`) and optional current-showroom counters (`vehicle_stock`).
- No subscriptions on financially sensitive tables across showrooms — RLS blocks them anyway, but
  bandwidth and accidental exposure both matter.
- `SessionService`/`ShowroomController` unsubscribe all channels on logout and on showroom switch.

## 8. Financial data integrity rules

1. Posted `journal_entries` / `journal_entry_lines` are **immutable** — a trigger blocks UPDATE/DELETE;
   only the transition `draft → posted` is allowed on the header.
2. Corrections happen through a **reversal entry** (`reverses_entry_id`) or a credit/debit note; original
   and reversal both stay in the ledger forever.
3. Posting date must fall inside an **open** `accounting_period` (period-lock trigger).
4. Every entry must balance: `sum(debit) = sum(credit)`, enforced by a deferred constraint trigger plus
   `CHECK (total_debit = total_credit)` on the header.
5. Journal writing is reachable only via `SECURITY DEFINER` RPCs that re-check permissions; `authenticated`
   has no direct INSERT grant.
6. Financial documents (`sales_invoices`, `purchase_invoices`, `payments`) cannot be deleted once `posted`;
   allowed states are `draft`, `cancelled` (audited, with reversal), `posted`.
7. `document_sequences` increments inside the same transaction as the document insert → gap-free numbering
   per showroom/FY; clients cannot write to the table.
8. `stock_ledger` is append-only, so physical stock can always be traced back to its movements.

## 9. Secrets & key management

| Secret | Location | Notes |
|--------|----------|-------|
| Supabase URL + anon/publishable key | client build defines | safe to ship (RLS protects data) |
| Supabase `service_role` key | Edge Function secrets / dashboard only | never in repo, Flutter bundle or CI logs |
| FCM server credentials | Edge Function secrets | push sending only |
| Third-party API keys (SMS/WhatsApp/GST) | Edge Function secrets | per environment |
| `--dart-define-from-file` files | local only, git-ignored | template with placeholders is committed |

## 10. Threat model (summary)

| Threat | Mitigation |
|--------|-----------|
| User reads another showroom's data | RLS `can_access_showroom` on every business table + Phase 4/24 negative tests |
| User escalates own role/permission | `user_roles`/`role_permissions` writable only by Super Admin; DB-side permission reads |
| Deactivated user keeps working with a live JWT | `is_active_user()` inside every policy |
| Repudiation of a financial action | append-only `audit_logs` written by triggers + `posted_by`/`created_by` stamps |
| Silent deletion or alteration of books | immutability + reversal-only corrections + period locks; no DELETE grant to `authenticated` |
| Invoice-number manipulation / duplicates | server-side `document_sequences` + unique index `(showroom_id, fy_id, doc_type, number)` |
| Token/key theft from a client device | no service key client-side; platform secure storage for session; short-lived signed URLs |
| Injection via search strings | PostgREST parameterised filters (no string-concatenated SQL); RPCs take typed params |
| Denial of service by huge queries | mandatory pagination caps, `statement_timeout`, indexes, `count: planned` on large tables |
| Malicious file upload | size/mime validation, private buckets, no execution, signed access, checksum stored |
| Data loss | Supabase PITR/backups + daily logical dump job (Phase 27/28 runbook) |

## 11. Security test plan (executed Phase 4, re-run Phase 24)

| # | Test | Expected result |
|---|------|-----------------|
| S1 | Showroom A manager: `select * from vehicles` with no filter | only Showroom A rows |
| S2 | Same user: `sales_invoices` filtered by Showroom B | `[]` (zero rows) |
| S3 | Same user: `insert` vehicle with Showroom B `showroom_id` | RLS `with check` violation error |
| S4 | Same user: `update` a Showroom A invoice `status = posted` directly | blocked (permission + immutability) |
| S5 | Same user: `delete` a posted journal line | error from trigger/RLS |
| S6 | Viewer: `insert into customers` | error (missing `customers.create`) |
| S7 | Deactivated user with a valid token: `select vehicles` | `[]` |
| S8 | Signed URL for `showroom-documents/{B}/...` as Showroom A user | denied |
| S9 | `rpc_create_sale` with a Showroom B vehicle as Showroom A user | business/permission error |
| S10 | Direct `insert into journal_entry_lines` as any non-service role | permission denied |
| S11 | Super Admin ALL SHOWROOMS aggregates | equals sum of per-showroom values |
| S12 | `update audit_logs` attempt | denied for every role |