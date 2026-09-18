# PHASE 0 — 02 Roles, Permissions & Showroom Scope

## 1. Role catalogue (seeded in Phase 3, editable in Phase 6)

| Role code | Display | Scope | Typical duties |
|-----------|---------|-------|----------------|
| `SUPER_ADMIN` | Super Admin / Owner | **Global** (ALL SHOWROOMS) | Everything incl. showroom creation, roles, settings, consolidated reports |
| `ADMIN` | Administrator | Global (may be restricted) | Master data, users, approvals, reports; cannot delete posted financial entries |
| `SHOWROOM_MANAGER` | Showroom Manager | Showroom-scoped (1..N) | Runs a showroom: approvals within limits, stock, sales/purchase supervision |
| `SALES_MANAGER` | Sales Manager | Showroom-scoped | Sales targets, discount approval, booking/sale supervision, sales reports |
| `SALES_EXECUTIVE` | Sales Executive | Showroom-scoped | Customers, quotations, bookings, sales entry (own records), document upload |
| `PURCHASE_MANAGER` | Purchase Manager | Showroom-scoped | Suppliers, PO, GRN, purchase invoice, purchase payments (request), returns |
| `INVENTORY_MANAGER` | Inventory Manager | Showroom-scoped | Vehicle master, stock receiving, transfers, adjustments, valuation, ageing |
| `ACCOUNTANT` | Accountant | Showroom-scoped (1..N) | CoA, journals, payments/receipts, expense posting, ledgers, statutory reports |
| `CASHIER` | Cashier | Showroom-scoped | Receipts/collections, day book, expense payment, cash handover |
| `SERVICE_MANAGER` | Service Manager | Showroom-scoped | Service income entries, spare issue, service customer records |
| `VIEWER` | Viewer / Auditor | Showroom-scoped or global | Read-only access to permitted modules; export where granted |

Role rules:
1. `SUPER_ADMIN` bypasses showroom scoping **only** for reads and administrative writes; financial posting rules still apply.
2. A user may hold **different roles in different showrooms** (global assignment ⇒ `showroom_id = NULL`; showroom-specific assignment sets `showroom_id`).
3. A user with zero role rows gets **no** access (fail closed).
4. `SYSTEM` is a reserved actor for trigger/Edge-Function automation (cannot log in).

## 2. Permission model

- Permission key format: `module.action` (e.g. `sales.create`, `payments.approve`), stored in `permissions`.
- Actions: `view, create, edit, delete, approve, export, print`.
- Canonical module keys (reused by routes, sidebar, RLS checks, tests):

`dashboard, showrooms, users, roles, vehicles, inventory, purchases, suppliers, sales, customers, bookings, finance, accounting, expenses, income, reports, documents, notifications, audit, settings, approvals`

- Enforcement layers, in order:
  1. **UI** — `AppPermissionWidget` + route guards hide/disable actions (convenience only).
  2. **Service/Repository** — refuses forbidden commands before the network call (defence in depth).
  3. **Database (authoritative)** — `has_permission(module, action)` + `can_access_showroom(showroom_id)` inside every RLS policy; posting/money RPCs re-check permissions server-side.

> Client-supplied `permissions`, `role_id`, `user_id`, `showroom_id` are never authority — display hints only.

## 3. Showroom scoping rules

| Scenario | Behaviour |
|----------|-----------|
| User assigned exactly 1 showroom | Auto-select on login; switcher shows single entry |
| User assigned N showrooms | Showroom picker after login; switcher in header; selection persisted locally per user |
| User with any global role (`showroom_id = NULL`) | Can select any showroom in their `user_showrooms`; `ALL SHOWROOMS` appears only if role grants `showrooms.view_all` (Super Admin) |
| Showroom deactivated | Hidden from switcher; RLS blocks its data; historical records remain readable only via ALL SHOWROOMS admin views |
| Showroom switched | All showroom-scoped providers invalidated (dashboard, inventory, sales, purchase, finance, reports) |
| `ALL SHOWROOMS` mode | Aggregates via RPC/views; per-showroom break-up table also displayed; write actions required to pick a concrete showroom |
| Zero showrooms assigned | Access denied screen with "contact administrator" message (no data leakage) |

## 4. Module × role permission matrix

Legend — `V` view, `C` create, `E` edit, `D` delete, `A` approve, `X` export, `P` print, `—` no access. Codes are concatenated (e.g. `VCEAXP`).

| Module | SUPER_ADMIN | ADMIN | SHOWROOM_MGR | SALES_MGR | SALES_EXEC | PURCHASE_MGR | INVENTORY_MGR | ACCOUNTANT | CASHIER | SERVICE_MGR | VIEWER |
|--------|-------------|-------|--------------|-----------|------------|--------------|---------------|------------|---------|-------------|--------|
| dashboard | VXAP | VXAP | VXAP | VXA | VX (own) | VX | VX | VXAP | VX | VX | VX |
| showrooms | VCEDAXP | VCEAXP | V | — | — | — | — | V | — | — | — |
| users | VCEDAXP | VCEAXP | VCE | V | — | — | — | V | — | — | — |
| roles | VCEDAXP | VX | — | — | — | — | — | — | — | — | — |
| vehicles | VCEDAXP | VCEAXP | VCE | V | V | VCE | VCEAXP | V | V | V | V |
| inventory | VCEDAXP | VCEAXP | VCEX | VX | V | VCEX | VCEAXP | VX | V | VCE | VX |
| purchases | VCEDAXP | VCEAXP | VX | V | — | VCEDAXP | VX | VX | V | V | — |
| suppliers | VCEDAXP | VCEAXP | V | — | — | VCEAXP | V | VCEX | V | — | — |
| sales | VCEDAXP | VCEAXP | VCEAXP | VCEADXP | VCEX (own) | — | VX | VX | VCX | V | VX |
| customers | VCEDAXP | VCEAXP | VCEX | VCEX | VCEX | V | V | VX | VCE | VCEX | VX |
| bookings | VCEDAXP | VCEAXP | VCEAXP | VCEAXP | VCEX | — | V | VX | VC | V | VX |
| finance | VCEDAXP | VCEAXP | VX | VX | — | VX | — | VCEDAXP | VCEX | VC | — |
| accounting | VCEDAXP | VX | — | — | — | — | — | VCEAXP | — | — | V |
| expenses | VCEDAXP | VCEAXP | VCEAX | VX | VC (request) | VC (request) | VC (request) | VCEAXP | VCE | VC (request) | — |
| income | VCEDAXP | VCEAXP | VX | V | — | — | — | VCEAXP | VC | VCE | — |
| reports | VCEDAXP | VXAP | VXAP | VXAP | VX (own) | VXA | VXA | VXAP | VXAP | VXA | VX |
| documents | VCEDAXP | VCEADXP | VCEX | VCEX | VCE | VCE | VCE | VCEX | VCE | VCE | V |
| notifications | VCE | VCE | VCE | VCE | VCE | VCE | VCE | VCE | VCE | VCE | V |
| audit | VX | VX | — | — | — | — | — | VX | — | — | — |
| approvals | VCEDAXP | VCEAXP | VXA (limits) | VXA (discount) | VC (request) | VXA (purchase) | VXA (stock) | VXA (finance) | V (request) | VC | — |
| settings | VCEDAXP | VCEAXP | V | — | — | — | — | V (limited) | — | — | — |

Matrix invariants:
- **Only `SUPER_ADMIN` may delete posted accounting/journal rows.** `D` in `accounting`/`finance` covers drafts and unallocated entries only (enforced by RLS + immutability triggers).
- `VIEWER` never receives `C/E/D/A`; the only permitted write is managing its own notification read-state.
- `reports.export` / `reports.print` are independently grantable — auditors can get `VX` without operational rights.
- `approvals.approve` is additionally bounded by value thresholds in `approval_rules` (Phase 21).

## 5. Effective permission resolution (server side)

```
effective_permissions(user, showroom) =
      union( permissions of roles where role.showroom_id IS NULL  AND user has that role )
    ∪ union( permissions of roles where role.showroom_id = :showroom AND user has that role )

effective_role(user, showroom) = highest-precedence role from the same two sets
                                 (precedence: SUPER_ADMIN > ADMIN > MANAGER > EXEC > VIEWER)

can_access_showroom(user, showroom) =
      is_super_admin(user)
   OR exists(user_showrooms where user_id = user AND showroom_id = showroom AND is_active)
```

Implementation notes (Phases 3–4):

| Object | Signature | Purpose |
|--------|-----------|---------|
| `public.current_profile_id()` | `uuid` | Resolve `profiles.id` from `auth.uid()` (STABLE, cached per statement) |
| `public.is_active_user()` | `boolean` | profile exists and `is_active` |
| `public.is_super_admin()` | `boolean` | global role check |
| `public.has_permission(module text, action text)` | `boolean` | effective permission check for current user (all assigned showrooms) |
| `public.has_permission_for(module text, action text, showroom uuid)` | `boolean` | showroom-scoped permission check |
| `public.can_access_showroom(showroom uuid)` | `boolean` | RLS backbone for every showroom-scoped table |
| `public.accessible_showroom_ids()` | `uuid[]` | Used by storage policies, list filters, dashboard RPCs |

All helper functions are `SECURITY DEFINER` with `search_path = ''` (schema-qualified), `STABLE`, and only `EXECUTE` to `authenticated` where needed — this prevents permission spoofing and search-path attacks (details in `04-multishowroom-security.md`).