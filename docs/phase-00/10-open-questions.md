# PHASE 0 — 10 Open Questions, Assumptions & Risks

## 1. Confirmations needed **before Phase 1** (Flutter foundation)

| # | Question | Default I will proceed with unless you say otherwise |
|---|----------|------------------------------------------------------|
| Q1 | App display name and package/bundle id | `MyBike` / `com.mybike.showroom` (Android `applicationId`, iOS bundle id, Windows publisher) |
| Q2 | Platforms to keep enabled | Android, iOS, Web, Windows (Linux/macOS folders removed to keep the repo lean) |
| Q3 | Font files | Bundle **Inter v4.1 static TTFs**; you download the official archive and place 4 TTFs in `assets/fonts/` (exact commands provided in Phase 1) — or tell me to use `google_fonts` instead |
| Q4 | Minimum platform versions | Android 6.0 (SDK 23, required by secure storage), iOS 13, Windows 10 1809+, evergreen browsers |
| Q5 | Language | English only in v1 (strings centralised so Hindi can be added later) |

## 2. Confirmations needed **before Phase 3** (Supabase foundation)

| # | Question | Default |
|---|----------|---------|
| Q6 | Supabase project(s) available? | One `dev` project now; staging/prod created at Phase 27 (you supply URL + anon key via `config/dev.json`, never committed) |
| Q7 | Supabase CLI installed & logged in? | Phase 3 report includes install/link commands |
| Q8 | Region | Closest Indian region available to the organisation (e.g. `ap-south-1`) |
| Q9 | Seed demo data in dev? | Yes — 3 showrooms, users per role, sample vehicles/items for multi-showroom tests |

## 3. Business decisions (defaults already assumed in the design)

| # | Topic | Default taken | Impact if changed |
|---|-------|---------------|-------------------|
| B1 | Customers shared across showrooms? | **No** — a customer belongs to the showroom that created them | needs `customer_showroom_links` + policy change |
| B2 | Suppliers shared across showrooms? | **Yes** (company-wide master, showroom-scoped transactions) | easy to restrict per showroom |
| B3 | One stock location per showroom? | Yes | extra locations become showrooms or a new `stock_locations` table |
| B4 | COGS posted on every sale? | Yes (`post_cogs_on_sale = true`) | without it P&L and Balance Sheet are incomplete |
| B5 | Freight/other purchase charges | Capitalised into inventory value by default | affects landed cost and gross profit |
| B6 | Insurance/RTO collected from customer | Pass-through liability accounts, expensed when paid to insurer/RTO | alternative: income + matching expense |
| B7 | Used-vehicle exchange | Purchase of a used unit + credit to the customer | — |
| B8 | Discount policy | Pre-tax discount reduces taxable value; post-invoice discount = `Discount Allowed` expense | — |
| B9 | Booking forfeiture on cancellation | Configurable: full refund / partial / forfeit to Other Income | set per showroom |
| B10 | Service module depth | Service lines + spare issue + service income (no job cards/time tracking in v1) | job cards add tables + screens later |
| B11 | Approvals | Threshold-based rules (expense, discount, purchase, payment, stock) | exact thresholds to confirm; sensible defaults seeded in Phase 21 |
| B12 | Warranty | Per-vehicle dates + documents (no claim workflow in v1) | — |
| B13 | Payroll | Out of scope (entered as expenses) | — |
| B14 | Tally/legacy import | Not in v1 (Phase 22+ extension) | — |
| B15 | Scale to plan for | ≤ 25 showrooms, ≤ 500 users | beyond that, revisit partitioning/materialised views earlier |

## 4. Technical risks & mitigations

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| R1 | RLS gaps leaking showroom data | Medium | Critical | negative tests per table class (Phase 4, re-run Phase 24), RLS shipped with each table, audit query for tables without RLS |
| R2 | Money bugs (tax/round-off/partial payments) | Medium | High | `numeric` only, server-side recomputation, unit tests on calculators, trial-balance assertion in every workflow test |
| R3 | Client/server total mismatch | Medium | High | server is authoritative; client shows a "recalculated" notice when values differ before submit |
| R4 | Push unavailable on Windows | High (platform fact) | Low | in-app realtime notification centre is the source of truth; FCM is an extra channel on mobile/web |
| R5 | Web performance with large tables | Medium | Medium | server-side pagination + keyset paging, mobile card mode in `AppDataTable`, virtualised lists |
| R6 | Realtime quota/bandwidth growth | Low–Medium | Medium | subscribe only to small filtered tables (notifications, approvals, stock counters) |
| R7 | Migration drift across environments | Medium | High | one migrations directory, `supabase db diff --linked` in every phase report, applied migrations never edited |
| R8 | Accounting interpretation disputes | Medium | High | posting matrix documented here; accountant review before Phase 12 sign-off; every posting traceable to a source document |
| R9 | Scope creep (job cards, payroll, e-invoice, Tally) | High | Medium | explicit out-of-scope list; extensions documented, never silently added |
| R10 | iOS build requirements (macOS/Apple account) | Medium | Medium | iOS verified via simulator/CI or your Mac; code stays platform-clean behind interfaces |
| R11 | Font/asset missing on a build machine | Low | Low | font files committed; build fails fast if absent |
| R12 | Divergent UI patterns between screens | Medium | Medium | design-system-first (Phase 2) + gallery screen + rule that screens only compose common widgets |

## 5. What Phase 1 will produce (preview — not started)

`pubspec.yaml` (verified, caret-pinned versions), `lib/main.dart`, `lib/app.dart`,
`core/config` (EnvConfig/PlatformTarget), `core/constants`, `core/theme`
(colors, typography, dimensions, shadows, light + dark themes, theme-mode controller),
`core/routes` (route names + router skeleton), `core/errors` (failure types),
`core/utils` (responsive helpers, formatters), `common/layouts` (responsive shell, sidebar,
bottom navigation), Inter fonts under `assets/fonts`, a hardened `analysis_options.yaml`, and a
minimal placeholder home screen that proves light/dark + responsive behaviour on Android, iOS, Web
and Windows.

**Phase 1 contains no business module, no database work and no authentication.**