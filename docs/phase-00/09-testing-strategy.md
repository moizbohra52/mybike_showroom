# PHASE 0 — 09 Testing Strategy

## 1. Test pyramid

| Layer | Tooling | What is covered | Location |
|-------|---------|-----------------|----------|
| Unit | `flutter_test`, `mocktail` | validators (GSTIN, PAN, mobile, VIN, chassis), money/round-off math, tax split (CGST/SGST vs IGST), invoice total calculators, formatters (INR grouping, dates, FY), error mapping, permission helpers, FY/date utilities | `test/unit/**` |
| Widget | `flutter_test` | every `common/widgets` component (states, disabled, loading, error, light/dark), responsive behaviour at 360/600/1024/1440, key screens with mocked repositories | `test/widget/**` |
| Integration | `integration_test` | real workflows against the **dev** Supabase project: login → showroom select → customer → booking → sale → receipt → ledger; purchase → GRN → invoice → payment; transfer; expense; report | `integration_test/**` |
| Database | SQL scripts via `supabase db` / psql | RLS isolation, constraints, immutability triggers, balanced journals, numbering atomicity | `supabase/tests/**` |
| Manual / platform QA | per-phase checklist | Android, iOS, Web, Windows behaviour (PDF, print, upload, responsive, notifications) | phase reports |

## 2. Rules

1. Widgets are tested through the **same public API** the app uses — no private helpers to test.
2. Repository/service tests mock only the network boundary (`SupabaseClient` wrapper / `Dio`), never internal logic.
3. Money logic has dedicated unit tests: per-line tax, discount before/after tax, round-off, mixed payments, partial payments, COGS, advance reclassification.
4. RLS gets a **negative test per table class** — a passing "can read own showroom" test proves nothing.
5. Integration tests create their own fixtures and clean up (or use a dedicated dev project that is re-seeded).
6. No test depends on wall-clock time or on production data.

## 3. RLS / database test template

```sql
-- supabase/tests/rls_isolation.sql (shape of every RLS test)
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"<userA-uuid>","role":"authenticated"}';

  -- 1. own showroom visible
  select count(*) from public.vehicles where showroom_id = '<showroom-A>';   -- expect > 0
  -- 2. other showroom invisible even when explicitly requested
  select count(*) from public.vehicles where showroom_id = '<showroom-B>';   -- expect 0
  -- 3. cross-showroom write refused  → expect ERROR (42501)
  insert into public.vehicles (showroom_id, variant_id, vin)
  values ('<showroom-B>', '<variant>', 'TESTVIN');
rollback;
```

Per-phase database checks:
```powershell
supabase db lint
supabase db diff --linked        # drift between local migrations and remote
supabase migration list          # applied vs pending
```
```sql
-- no business table may lack RLS
select tablename from pg_tables where schemaname = 'public' and not rowsecurity order by tablename;

-- inspect every policy
select tablename, policyname, cmd, qual from pg_policies where schemaname = 'public' order by 1,2;

-- journals must always balance
select count(*) from public.journal_entries where total_debit <> total_credit;   -- expect 0
```

## 4. Cross-platform QA matrix (from Phase 2 onward; full pass in Phase 26)

| Area | Android | iOS | Web | Windows |
|------|---------|-----|-----|---------|
| Launch + splash + theme (light/dark/system) | ✅ | ✅ | ✅ | ✅ |
| Responsive layouts (600 / 1024 breakpoints) | ✅ | ✅ | ✅ | ✅ |
| Forms, validation, keyboard/scroll behaviour | ✅ | ✅ | ✅ | ✅ |
| Data tables, pagination, filters, sort | ✅ | ✅ | ✅ | ✅ |
| Dashboard charts | ✅ | ✅ | ✅ | ✅ |
| PDF invoice/receipt preview | ✅ | ✅ | ✅ | ✅ |
| Print / share | ✅ (print service) | ✅ (AirPrint) | ✅ (browser) | ✅ (print dialog) |
| Excel/CSV export + save location | ✅ (app docs) | ✅ (app docs) | ✅ (download) | ✅ (Downloads) |
| Document upload (camera/gallery vs file picker) | ✅ | ✅ | ✅ (file input) | ✅ (file dialog) |
| Push notifications (FCM) | ✅ | ✅ | ✅ | ❌ → in-app centre |
| Deep links / web URLs | ✅ | ✅ | ✅ | n/a |
| Offline banner + retry | ✅ | ✅ | ✅ | ✅ |

Platform limitations are recorded openly, never hidden: no FCM on Windows, web secure storage requires
HTTPS/localhost, iOS file visibility needs `UIFileSharingEnabled`, Windows minimum window size (Phase 26).

## 5. Critical workflow test list (Phases 25 + 26)

1. Login (valid, invalid, deactivated user) and logout cache clearing.
2. Showroom selection: single, multiple, ALL SHOWROOMS, zero showrooms.
3. Permission enforcement: Viewer / Sales Executive / Cashier cannot perform forbidden actions.
4. Customer → booking + advance → sale invoice → receipt → customer ledger balance.
5. Purchase order → GRN (vehicle instances created) → purchase invoice → payment → supplier ledger.
6. Stock transfer: dispatch → in-transit → receive; verify no P&L impact and correct ledger entries.
7. Stock adjustment (damage) with approval; verify the write-off journal.
8. Expense create → approve → pay; verify journal and cash balance.
9. Trial balance balances after all of the above; P&L and Balance Sheet tie out.
10. Invoice PDF matches screen values; exported CSV/XLSX opens correctly.
11. Negative: cross-showroom read/write fails; posted journal cannot be edited or deleted.
12. Dashboard KPIs equal report figures for the same filters.

## 6. Test data & fixtures

- `supabase/seed.dev.sql`: 3 showrooms, one user per role with known credentials, 10 variants (petrol + EV),
  20 vehicles, 15 items, 10 customers, 5 suppliers, plus a couple of bookings, invoices and payments.
- Integration tests assert against fixture ids documented in the seed header, so failures are diagnosable.
- Fixture reset (dev only): `supabase db reset` (migrations + seeds), then re-run the demo seed.

## 7. Commands used in every phase

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # once codegen exists
flutter analyze
flutter test
flutter test --coverage
flutter run -d windows
flutter run -d chrome
flutter build apk --debug        # Android compile check
flutter build web                # Web compile check
```

Expected results per phase are listed in that phase's report; a phase never stops with analyzer errors,
failing tests or an unverified database change.