# PHASE 0 — 08 Development Roadmap (Phases 1–28)

## 1. Phase plan with deliverables and exit criteria

| Phase | Objective | Key deliverables | Exit criteria (must pass before stopping) |
|-------|-----------|------------------|-------------------------------------------|
| **1** Flutter Foundation | Runnable shell on all 4 platforms | `pubspec`, folder skeleton, `EnvConfig`, `AppColors/Typography/Dimensions/Shadows`, `AppTheme` (light+dark), `AppRouter` skeleton, `ResponsiveLayout` + shells, `main.dart`/`app.dart`, Inter fonts bundled, hardened `analysis_options.yaml` | `flutter analyze` clean; runs on Android, iOS, Web, Windows; theme switch light/dark/system works and persists; responsive shell switches at 600/1024 |
| **2** Common UI Design System | Reusable widget library in the MyBike style | `AppButton`, `AppOutlinedButton`, `AppTextField`, `AppDropdown`, `AppSearchField`, `AppDatePicker`, `AppCard`, `AppStatCard`, `AppDashboardCard`, `AppDataTable`, `AppEmptyState`, `AppErrorState`, `AppLoading`, `AppShimmer`, `AppStatusBadge`, `AppCurrencyText`, `AppConfirmDialog`, `AppBottomSheet`, `AppAppBar`, `AppSidebar`, `AppBottomNavigation`, `AppFormSection`, `AppSectionHeader`, `AppPermissionWidget` + gallery screen | Widget tests per component; gallery renders light + dark on all 4 platforms; no component contains business logic |
| **3** Supabase DB Foundation | Schema + seeds for Phase 3 scope | Supabase project link, `supabase/` config, migrations `0001–0003` + `0007`, seeds (permissions/roles/CoA/categories/states/FY/sequences) | `supabase db push` succeeds; tables/constraints/indexes verified; seeds are idempotent when re-run; `supabase db lint` clean |
| **4** Supabase Security | RLS + helper functions + storage policies | migrations `0004–0006`, RLS per table class, buckets + storage policies | Applicable security tests (S1–S12) pass; zero business tables without RLS; User A cannot read Showroom B |
| **5** Authentication | Login/logout/session/profile/roles/permissions/showrooms | `AuthService`, `SessionService`, `PermissionService`, `ShowroomService`, splash/login/select-showroom/forbidden/no-showroom screens, router guards | Single-showroom user lands on dashboard; multi-showroom user must choose; inactive user blocked; logout clears caches + session; wrong password shows a friendly error |
| **6** Users / Roles / Permissions | Admin management | users list/detail/form, role assignment (global + per showroom), showroom assignment, activate/deactivate, role-permission editor, `admin-create-user` Edge Function | Permission-restriction tests (Viewer/Cashier/Executive) pass; deactivated user is blocked everywhere; every change audited |
| **7** Showroom Management | Multi-showroom administration | showroom CRUD, GST/bank/invoice settings, default cash/bank accounts, logo upload, showroom switcher, ALL SHOWROOMS mode for Super Admin | Switching showroom refreshes all data; scoped user sees only allowed showrooms; deactivated showroom disappears from the switcher |
| **8** Vehicle Master | Brands/models/variants with petrol & EV specs | master screens, variant specifications (conditional petrol/EV fields), item master (accessories/spares/services), HSN/tax configuration, duplicate validation | Duplicate VIN/chassis/engine/motor rejected by UI **and** DB; EV fields required only for electric; masters consumable by later modules |
| **9** Inventory & Stock | Full unit lifecycle | vehicles list/detail (VIN view), stock receiving, status change with history, adjustments, transfers (dispatch/receive), stock ledger screen, valuation + ageing + low stock | Lifecycle test (purchase → stock → reserve → transfer → receive → damaged → adjustment) passes; ledger reconciles with derived stock; transfers cause no P&L impact |
| **10** Suppliers & Purchase | PO → GRN → invoice → payment → return | supplier master/profile, PO, GRN, purchase invoice (GST), purchase payments, purchase returns, supplier ledger + outstanding | Purchase flow test passes; inventory + payable + input GST = invoice value; supplier ledger closing = outstanding report |
| **11** Customers & Sales | Quotation → booking → invoice → payment → delivery | customer master + 360° profile, quotation, booking + advance, sales order, sales invoice (discount/accessories/insurance/RTO/other/exchange), receipt allocation, delivery note | Sale test passes: vehicle unavailable after sale, invoice totals correct, COGS posted, receivable correct, booking advance reclassified |
| **12** Accounting Foundation | Real double entry | CoA screen, journal entries/lines, manual journal + reversal, period management, ledgers, trial balance | Trial balance always balances; posted entries immutable; reversal works; ledger equals journal |
| **13** Finance | Money-movement modules | payments/receipts, allocations, cash & bank books, contra, credit/debit notes, expenses (+approval), other income, outstanding | Cash/bank balances match the day book; receivable/payable match party ledgers; expense approval + payment post correctly |
| **14** GST & Tax | Configurable tax engine | tax rate/HSN configuration, intra vs inter-state logic, taxable value + round-off, GST summary views/screens | Invoice GST equals `v_gst_summary`; interstate sale yields IGST only; rates changeable without code changes |
| **15** Dashboard | KPI + charts | dashboard per role, KPI cards, trend charts, showroom performance, ALL SHOWROOMS mode, date-range filter, single `rpc_dashboard_kpis` call | KPIs match underlying reports for the same filters; consolidated = Σ per-showroom; cards respect permissions |
| **16** Reporting | All required reports | report screens (sales/purchase/stock/ledger/cash/bank/TB/P&L/BS/receivable/payable/GST/expense/income) with a shared filter component | Report figures tie back to source documents; RLS scoping verified; all filters (date/showroom/user/brand/customer/supplier/status) work |
| **17** PDF / Excel / CSV / Print | Output layer | invoice/receipt/report templates, PDF generation, XLSX + CSV export, printing, `ExportService`/`PDFService` | Invoice PDF matches the on-screen invoice; numbering/logo/GSTIN/signature correct; export + print verified on all 4 platforms |
| **18** Notifications | Push + in-app | FCM setup per platform, token registration, `NotificationService`, notification centre (read/unread), role/showroom targeting, `send-notification` Edge Function, realtime fallback on Windows | Push received on Android/iOS/web; in-app centre works on all 4 (incl. Windows); targeted notifications only reach authorised users |
| **19** Document Management | Secure storage | upload/download/delete for customer/vehicle/invoice/receipt/insurance/RC/warranty documents, signed URLs, expiry reminders | Path isolation verified (user A cannot access Showroom B files); expiry reminders fire; documents viewable on all platforms |
| **20** Audit Logs | Complete trail | `fn_audit_row` triggers, audit screens with filters and before/after diff, login/logout events | Every mutation produces an audit row with old/new values; no role can modify `audit_logs` |
| **21** Approval Workflow | Configurable approvals | rules (module/action/threshold), requests + steps, approval queue UI, notifications, integration into discounts/expenses/purchases/payments/stock | Threshold-triggered request blocks posting until approved; rejection path gives a clear message; decisions fully audited |
| **22** Search & Filters | Reusable query layer | global search, per-module filters, sort, pagination (incl. keyset), saved filters, advanced filter builder | Search returns correctly scoped results; no full-table scans; filter state persists per user |
| **23** Performance | Optimisation pass | rebuild audit, `EXPLAIN ANALYZE` review, index additions, materialised views + `pg_cron`, image transforms, bundle-size check | Dashboard/list screens meet NFR-3; no N+1 in the top 20 flows; no unbounded query remains |
| **24** Security Audit | Adversarial verification | RLS/privilege audit queries, negative tests S1–S12, storage isolation test, secret scan, dependency audit | All negative tests pass; zero business tables without RLS; no secret in the client bundle or repo |
| **25** Testing | Automated test suite | unit tests (services/validators/formatters/totals), widget tests (design system + key screens), integration tests (login, customer, purchase, stock transfer, booking, sale, payment, expense, ledger, report) | `flutter test` green; integration workflows green on Android + Windows (+ web smoke); coverage report produced |
| **26** Cross-Platform QA | Platform verification | checklist execution on Android/iOS/Web/Windows: navigation, forms, tables, reports, PDF, printing, upload, notifications, responsiveness | Every item passes or has a documented, accepted limitation (e.g. no push on Windows) |
| **27** Production Build | Release artefacts | app icons + splash, version/build numbers, prod Supabase + Firebase config, signed Android AAB, iOS release config, web build + hosting headers, Windows installer | Release builds install and run; environments isolated; production log level; smoke test on all 4 targets |
| **28** Final Audit | Sign-off | architecture/security/DB/accounting/inventory/performance/UX/cross-platform review, production checklist, backup/restore drill, runbook | Production checklist complete; known issues triaged; owner sign-off |

## 2. Milestones

| Milestone | Phases | Business value delivered |
|-----------|--------|--------------------------|
| M1 — Foundation | 1–2 | Brand look and feel + reusable UI kit |
| M2 — Secure core | 3–5 | Real database, RLS, login, showroom context |
| M3 — Administration | 6–8 | Users/roles/showrooms/vehicle master operational |
| M4 — Operations | 9–11 | Stock, purchase and sales transactions live |
| M5 — Books | 12–14 | Double-entry accounting + GST |
| M6 — Insight | 15–17 | Dashboard, reports, print/export |
| M7 — Engagement | 18–22 | Notifications, documents, audit, approvals, search |
| M8 — Hardening | 23–26 | Performance, security, tests, cross-platform QA |
| M9 — Release | 27–28 | Production artefacts + final audit |

## 3. Environments, migrations, releases

| Environment | Supabase project | Firebase project | Purpose |
|-------------|------------------|------------------|---------|
| dev | `mybike-dev` | `mybike-dev` | Developer machine, demo data, migrations applied here first |
| staging | `mybike-staging` | `mybike-staging` | Pre-release verification with production-like data volume |
| prod | `mybike-prod` | `mybike-prod` | Live business data, restricted access, PITR enabled |

Workflow:
1. Migrations are authored in `supabase/migrations/`, applied with `supabase db push` (dev) → verified →
   promoted to staging → prod. Never edited after promotion.
2. Edge Functions deploy with `supabase functions deploy <name> --project-ref <ref>`; secrets are set with
   `supabase secrets set` and never committed.
3. Client builds select the environment via `--dart-define-from-file=config/<env>.json`.
4. Git: `main` = release-ready, `develop` = integration, `feature/<phase>-<slug>` = phase work;
   Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`); each completed phase is tagged `v0.<phase>.0`.
5. CI (finalised in Phase 27): `flutter analyze`, `flutter test`,
   `dart run build_runner build --delete-conflicting-outputs`, web + Windows + Android builds,
   `supabase db lint`, and a secret-scan job.

## 4. Definition of Done (every phase)

1. Code compiles with zero analyzer errors and zero warnings introduced by the phase.
2. `flutter test` passes for everything written so far.
3. The phase's own test checklist is executed and reported.
4. New database objects ship with RLS + constraints + indexes in the same migration.
5. New UI is verified responsive (mobile 360×640, tablet 800×1280, desktop 1440×900) in light **and** dark.
6. No secret, no `service_role` key, no raw SQL string concatenation, no direct DB call inside a widget.
7. Documentation updated in `docs/` (this folder) when behaviour or schema changes.
8. Phase report emitted in the required 11-section format, then **STOP**.