# MyBike — Multi-Showroom Bike Dealership ERP

Production-grade dealership management + accounting ERP for a multi-showroom two-wheeler business
(Petrol bikes, Electric bikes, Accessories, Spare parts, Services).

One Flutter codebase → **Android · iOS · Web · Windows Desktop**
Backend → **Supabase** (PostgreSQL, Auth, Storage, Realtime, Edge Functions) with **Dio** for raw HTTP
and **Firebase Cloud Messaging** for push notifications.

| Area | Choice |
|------|--------|
| UI | Flutter 3.44.8 stable / Dart 3.12.2, Material 3, Inter typography, Yellow `#F9C846` + Black `#171717` + White brand, light & dark themes |
| State / DI | Riverpod 3 (+ `riverpod_generator`) |
| Routing | `go_router` 18 |
| Backend | Supabase (PostgREST + RPC + RLS + Storage + Realtime + Edge Functions) |
| Security | PostgreSQL RLS as the final authority, per-showroom isolation, RBAC, immutable financial ledgers |
| Architecture | Feature-sliced modules: UI → Controller → Repository → Service → Supabase |

## Documentation

All architecture and phase documentation lives in [`docs/`](docs/README.md):

| Doc | Contents |
|-----|----------|
| [`docs/README.md`](docs/README.md) | Ground rules, phase protocol, doc index |
| [`docs/phase-00/01-requirements.md`](docs/phase-00/01-requirements.md) | Requirements, 26 modules, scope, NFRs |
| [`docs/phase-00/02-roles-permissions.md`](docs/phase-00/02-roles-permissions.md) | Roles, permission model, module × role matrix, showroom scope |
| [`docs/phase-00/03-architecture.md`](docs/phase-00/03-architecture.md) | Layers, folder structure, networking, errors, responsive, theming, cross-platform |
| [`docs/phase-00/04-multishowroom-security.md`](docs/phase-00/04-multishowroom-security.md) | Multi-showroom model, RLS, storage/edge security, threat model, security tests |
| [`docs/phase-00/05-database-plan.md`](docs/phase-00/05-database-plan.md) | Conventions, enums, full table inventory, views/RPCs/triggers, migrations, seeds |
| [`docs/phase-00/06-business-flows.md`](docs/phase-00/06-business-flows.md) | Vehicle lifecycle, inventory, transfer, purchase, sales, accounting posting matrix, GST, dashboard formulas |
| [`docs/phase-00/07-dependency-plan.md`](docs/phase-00/07-dependency-plan.md) | Verified package versions, justifications, rejected packages, env + font strategy |
| [`docs/phase-00/08-roadmap.md`](docs/phase-00/08-roadmap.md) | Phases 1–28 with exit criteria, environments, Definition of Done |
| [`docs/phase-00/09-testing-strategy.md`](docs/phase-00/09-testing-strategy.md) | Test pyramid, RLS negative tests, cross-platform QA matrix, commands |
| [`docs/phase-00/10-open-questions.md`](docs/phase-00/10-open-questions.md) | Assumptions to confirm, business decisions, risks |

## Development protocol

The project is built **one phase at a time**; each phase ends with a structured report
(implemented / files / dependencies / DB / security / tests / checklist / expected result / known issues)
and then stops until `NEXT PHASE` or `CONTINUE` is given.

Current status: Phases 0–1 complete · Phase 2 in progress ([open items](docs/phase-02/open-items.md)) · Phase 3 implemented ([database](docs/phase-03/README.md)) · Phase 4 implemented ([security](docs/phase-04/README.md)) · Phase 5 implemented ([authentication](docs/phase-05/README.md)) · Phase 6 implemented ([users, roles, permissions](docs/phase-06/README.md)) · Phase 7 implemented ([showrooms](docs/phase-07/README.md)) · Phase 8 implemented ([vehicle master](docs/phase-08/README.md)) · Phase 9 implemented ([inventory & stock](docs/phase-09/README.md)).

## Database (Supabase)

```powershell
supabase login
supabase link --project-ref <dev-project-ref>
supabase db push            # migrations only — never --include-seed outside dev
supabase db reset           # local stack (Docker): migrations + supabase/seed.sql demo data
supabase test db            # pgTAP tests in supabase/tests/database
```

## Getting started

```powershell
flutter pub get
flutter run -d windows --dart-define-from-file=config/dev.json
```

