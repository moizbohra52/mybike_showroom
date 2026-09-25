# Phase 8 — Vehicle master

## Screens

| Screen | What it shows / does |
|--------|----------------------|
| **Vehicles** (`/vehicles`) — Vehicles tab | The register of the current showroom (every accessible one in ALL SHOWROOMS), searchable by VIN, chassis, engine, motor or battery number; **Register vehicle** with `vehicles.create` in that showroom |
| Catalogue tab | Brands → models → variants, expandable; **Add brand** with `vehicles.create`; each brand's models list their variants as chips, with **Add variant** / **Edit model** / **Edit brand** where permitted |
| **Vehicle** (`/vehicles/units/:id`) | Identification (VIN, chassis, and engine or motor + battery numbers, whichever apply), details (colour, years, ownership, status, remarks), warranty; **Edit** with `vehicles.edit` in the unit's showroom |
| **Variant** (`/vehicles/variants/:id`) | Specifications (general, engine or motor/battery, whichever apply) and warranty terms; **Edit** with `vehicles.edit` |

The variant and vehicle forms show only the fields that apply to the chosen fuel type — an electric variant never
asks for engine displacement, a petrol vehicle never asks for a motor number — mirroring the database CHECKs
(`vehicle_variants_*`, `vehicles_*`). Money and specification numbers travel from the database to the form and back
as text (`::text` in the select), never as `double` (G5).

## Database (`20260925000010_vehicle_master.sql`)

| Object | Rule |
|--------|------|
| `vehicle_brands` → `vehicle_models` → `vehicle_variants` | company-wide catalogue; names unique per brand/model ignoring case (`citext`); read by every active user, written with `vehicles.create` / `edit` / `delete` |
| `vehicle_variants` specification CHECKs | an engine is required unless `fuel_type = 'electric'`; an electric variant has no engine fields; motor + battery are required for `electric` / `hybrid`; a non-EV variant has no motor/battery fields; HSN code is 4, 6 or 8 digits |
| `vehicles` | one row per physical unit in a showroom; `fuel_type` is copied from the variant by trigger (a client cannot set it); status and showroom are not client-writable — they change only through stock movements (Phase 9+) |
| `fn_normalize_identifier` | upper-cases and strips whitespace from VIN / chassis / engine / motor / battery numbers before they are compared or stored |
| `uq_vehicles_*_active` (partial unique indexes) | each identifier is unique **while the unit is on the books** (`status not in ('sold','delivered','returned_to_supplier')`); a sold unit frees its numbers, e.g. for a used buyback |
| `rpc_vehicle_identifier_conflicts(...)` | tells the form which of the given identifiers are already taken, in **any** showroom, without revealing which showroom or unit; requires `vehicles.create` or `vehicles.edit`; the unique indexes are the final check |
| `fn_vehicle_variants_guard` | a variant's fuel type is frozen once vehicles of it exist (MB030) |

## Duplicate validation (UI **and** DB)

1. The form checks its own fields (VIN format, identifier format, required-by-fuel-type) before anything is sent.
2. On submit, `VehicleAdminActions.saveUnit` calls `rpc_vehicle_identifier_conflicts` first and, if any field is
   already registered elsewhere, throws a `ValidationFailure` naming every taken field — the dialog marks each one
   inline (`Already registered.`) instead of a single generic error.
3. The unique partial indexes are the actual authority: a race between two people registering the same VIN at once
   is decided there, and `ErrorMapper.mapUnique` turns the resulting `23505` into the same per-field message
   (`uniqueConstraints` map, keyed by the PostgreSQL constraint name PostgreSQL puts in the error).

## Decisions

- **Vehicle categories** dropped `e_scooter` / `e_motorcycle` from the Phase 0 draft: electric is a `fuel_type`
  (`vehicle_category` is body type only — motorcycle, scooter, moped, bicycle), so an Ather 450X is category
  `scooter`, fuel `electric`.
- **Warranty terms live on the variant** (months/km, and battery months/km for EVs); a **unit's own** warranty
  start/end date is set when it is delivered (Phase 11) or when a used/demo unit is registered with known dates.
- **`vehicles.create` / `vehicles.edit` also govern the catalogue** — no separate `catalogue.*` permission — matching
  the seeded matrix (inventory / purchase / showroom managers and admins already hold them).
- **Ex-showroom price on the variant is a default list price**, not a per-sale price; sales pricing arrives with
  Sales (Phase 11).

## Tests

- DB: `supabase/tests/database/10_vehicle_master.test.sql` (39): catalogue access and duplicates (brand/model/variant
  names, ignoring case), every specification rule per fuel type (electric needs battery, no engine; petrol needs
  engine, no battery; hybrid needs both; HSN format), vehicle units (identifiers normalised and stored upper-case,
  fuel type not client-settable, VIN format, warranty dates, duplicate identifiers **across showrooms**, the
  duplicate-check RPC excluding the unit being edited, showroom isolation, status/showroom not client-writable, a
  sold unit freeing its identifiers, a variant's fuel type frozen once units exist). Removing the chassis unique
  index makes the cross-showroom duplicate test fail.
- Flutter: `test/features/vehicles/vehicle_master_test.dart` (10): register list scoped to the showroom, view-only
  staff blocked from editing, ALL SHOWROOMS hides Register vehicle, identifiers requested follow the fuel type,
  server duplicate check marks fields inline, catalogue browsing and the variant form's conditional fields, a
  variant switched to electric drops its stale engine data, duplicate-constraint error messages, VIN / identifier
  validators.
- Dev seed: 4 brands (Honda, TVS, Ather, Bajaj), 5 models, 6 variants (petrol, electric ×2, CNG, hybrid via the DB
  test only), 4 units across Indore and Bhopal.

## Known limits

- **No stock lifecycle yet**: a registered unit starts `purchased` and stays there — receiving, transfers, sales and
  status history are Phase 9.
- **No item/spare-parts master** (`items`, `hsn_sac_codes`, `tax_rates`): deferred to whichever phase needs them
  first (purchase/sales line items reference `items` from Phase 10 onward); vehicles' own HSN code is on the variant
  already.
- **No brand/model/variant deletion in the UI**: the database allows it (`vehicles.delete`) while nothing references
  the row (`on delete restrict`); the screens only expose edit and add for now.
- **No image/logo upload** for brands or variants — same dependency gap as the Phase 7 showroom logo.
