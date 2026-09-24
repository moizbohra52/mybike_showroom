# MYBIKE — Multi-Showroom Bike Dealership Management & Accounting ERP

Production ERP for a multi-showroom two-wheeler dealership (Petrol / Electric bikes,
Accessories, Spare Parts, Services). One Flutter codebase runs on **Android, iOS, Web
and Windows Desktop**; the backend is **Supabase (PostgreSQL, Auth, Storage, Realtime,
Edge Functions)** with **Dio** for raw HTTP and **Firebase Cloud Messaging** for push.

---

## 1. Phase protocol (mandatory)

1. Only **one phase** is worked on at a time.
2. A phase is finished with a report in the fixed format:
   `IMPLEMENTED / FILES CREATED / FILES MODIFIED / DEPENDENCIES / DATABASE CHANGES /
   SECURITY CHANGES / TEST COMMANDS / TEST CHECKLIST / EXPECTED RESULT / KNOWN ISSUES /
   NEXT ACTION` → then **STOP**.
3. The next phase starts **only** on the explicit keywords `NEXT PHASE` or `CONTINUE`.
4. No phase may be skipped; blocking errors must be fixed inside the phase that created them.
5. Every phase must be independently testable (analyze + run + DB check where applicable).

## 2. Ground rules (non-negotiable)

| # | Rule |
|---|------|
| G1 | **RLS is the final authority.** Client-side `user_id`, `role_id`, `showroom_id`, `permissions` are never trusted. |
| G2 | No database query inside a UI widget. UI → State/Controller → Repository → Service → Supabase/API. |
| G3 | Reusable logic lives in **public** functions/classes/services — no `_buildCard()`, `_loadData()`, `_saveData()`, `_validateForm()` style private helpers. |
| G4 | The Supabase **service_role key never ships in Flutter**. Only the anon/publishable key. |
| G5 | Money = `numeric(14,2)` in PostgreSQL and `Decimal`-safe handling in Dart. Never `double` for money math. |
| G6 | Posted accounting rows are **never deleted** — they are reversed (credit/debit note, reversal entry). |
| G7 | Only verified, actively maintained, latest-stable packages (see `07-dependency-plan.md`). |
| G8 | Every UI surface is responsive for Android / iOS / Web / Windows; no "stretched mobile" desktop. |
| G9 | Multi-showroom isolation is enforced in the database, verified by negative tests (User A cannot read Showroom B). |
| G10 | Financial year = Indian FY (1 April – 31 March); numbering and reports are FY-aware. |

## 3. Phase 0 documentation map

| Doc | Contents |
|-----|----------|
| `phase-00/01-requirements.md` | Requirement breakdown (FR/NFR), module list, scope, out-of-scope |
| `phase-00/02-roles-permissions.md` | Roles, permission model, module × role permission matrix, effective-permission algorithm |
| `phase-00/03-architecture.md` | Layered architecture, folder structure, state/routing/DI, network, errors, responsive, theming, cross-platform strategy |
| `phase-00/04-multishowroom-security.md` | Tenancy model, security layers, RLS design, storage security, edge-function security, threat model |
| `phase-00/05-database-plan.md` | Conventions, enums, full table inventory, constraints/indexes, RPC/view/trigger plan, migration plan, seeds |
| `phase-00/06-business-flows.md` | Vehicle lifecycle, inventory, purchase, sales, booking, accounting posting matrix, GST, period lock, dashboard metric formulas |
| `phase-00/07-dependency-plan.md` | Verified latest package versions, justification, rejected packages, env/font strategy |
| `phase-00/08-roadmap.md` | Phase 1–28 plan, exit criteria, environments, migration & release workflow |
| `phase-00/09-testing-strategy.md` | Test pyramid, RLS negative tests, cross-platform QA matrix, CI jobs |
| `phase-00/10-open-questions.md` | Assumptions taken as defaults + confirmations needed before Phase 3 |
| `phase-02/open-items.md` | Phase 2 audit: open items carried forward (Phase 2 not yet closed) |
| `phase-03/README.md` | Phase 3 as built: schema, privilege model, numbering, SQLSTATE catalogue, deviations, how to run |
| `phase-04/README.md` | Phase 4 as built: RBAC helpers, per-table policies, storage buckets/policies, security-test coverage |
| `phase-05/README.md` | Phase 5 as built: sign-in flow, session RPC, router guard, showroom selection, remote auth settings |
| `phase-06/README.md` | Phase 6 as built: delegation rules (rank), user / role screens, permission matrix, `admin-users` Edge Function |

## 4. Status

| Item | Value |
|------|-------|
| Phase 0 (Requirements & Architecture) | **COMPLETE** |
| Phase 1 (Flutter Foundation) | **COMPLETE** |
| Phase 2 (Common UI Design System) | **IN PROGRESS** — shell overflow fixed; open items in `phase-02/open-items.md` (missing widget tests, G5 `AppCurrencyText`, contrast, `AppDataTable` presentations) |
| Phase 3 (Supabase Database Foundation) | **IMPLEMENTED** — 4 migrations + dev seed, 218 pgTAP assertions green on an embedded Postgres; remote `supabase db push` pending project link |
| Phase 4 (Supabase Security) | **IMPLEMENTED** — RBAC helpers + RLS on all 13 tables + 6 storage buckets; 307 pgTAP assertions green; remote push pending |
| Phase 5 (Authentication) | **IMPLEMENTED** — login / session / showroom selection / guards; 323 pgTAP + 122 Flutter tests green; web + Android build verified |
| Phase 6 (Users / Roles / Permissions) | **IMPLEMENTED** — user & role management, permission matrix, rank-based delegation in RLS, `admin-users` Edge Function; 403 pgTAP + 10 Deno + 143 Flutter tests green; web + Android build verified |
| Toolchain verified | Flutter 3.44.8 stable, Dart 3.12.2 (Windows host) |
| Package versions | verified on pub.dev at time of writing — see `phase-00/07-dependency-plan.md` |
