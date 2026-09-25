# Phase 9 — Inventory & stock

## Scope

The roadmap's "vehicles list/detail (VIN view)" landed in Phase 8 alongside duplicate validation (the register
needed a working form to test against). Phase 9 adds the actual **stock lifecycle** on top of it: receive,
reserve, transfer, damage, adjust — vehicles only, matching the exit criterion's own sequence ("purchase → stock →
reserve → transfer → receive → damaged → adjustment"). Items/spares (`items`, `item_stock`) are out of scope until a
later phase needs them; see Known limits.

## Screens

| Screen | What it shows / does |
|--------|----------------------|
| **Vehicle detail** (`/vehicles/units/:id`) — Stock card | Context-sensitive actions by current status: **Receive stock** (`purchased`), **Reserve** / **Mark damaged** (`in_stock`), **Release reservation** (`reserved`); the active reservation's holder and date |
| Status history | Every status change, oldest reason first: `Awaiting receipt → In stock · Stock received`, with the date |
| **Inventory** (`/inventory`) — Overview tab | A card per showroom (available/reserved/in-transit/damaged counts, available value) and an ageing table (0–30/31–60/61–90/90+ days since receipt) |
| Transfers tab | Every transfer the caller can see (either side); **New transfer** (source, destination, date, vehicle picker) with `inventory.create`; **Receive** on an in-transit transfer at the destination |
| Adjustments tab | Batch corrections per showroom the caller may create; **New adjustment** (reason code, date, vehicles in or out) |

Every action is a permission-gated UI convenience; the server re-checks the caller's `inventory.*` permission and
the vehicle's current status before touching anything (`vehicles.*` stays the Phase 8 permission for master-data
edits — chassis number, colour — while `inventory.*` governs stock movement).

## Database (`20260926000011_inventory_stock.sql`)

**The stock ledger is the single source of truth** (docs/phase-00/06-business-flows.md §2): `vehicles.status` and
`vehicles.showroom_id` are never set directly (blocked since Phase 8) — they are *derived* by `trg_stock_ledger_apply`
from what gets inserted into `stock_ledger`. The ledger itself is append-only and closed to clients entirely (no
INSERT/UPDATE/DELETE grant at all, like `document_sequences`): every row is written by one of the RPCs below, each
of which checks `has_permission_for('inventory', action, showroom)` and the vehicle's current status first, then
the ledger trigger re-validates the transition as a last line of defence.

| Table | Role |
|-------|------|
| `vehicle_status_history` | one row per real status change, however it happened; a trigger on `vehicles` (not the ledger) writes it, so both ledger-driven and reservation-driven changes are logged the same way |
| `vehicle_reservations` | at most one active reservation per vehicle (partial unique index); `booking`/`sales_order` linkage is reserved for Phase 11 — v1 only ever writes `manual` |
| `stock_ledger` | append-only; `movement_type` drives the trigger's status mapping |
| `stock_transfers` / `stock_transfer_items` | v1 skips a separate draft/approval stage (Phase 21's approval engine): a transfer is created already `in_transit`; `rpc_receive_stock_transfer` closes it |
| `stock_adjustments` / `stock_adjustment_items` | posts immediately (no draft stage); reason codes `physical_count` / `damage` / `theft` / `expiry` / `correction` / `opening` |
| `v_current_stock`, `v_stock_ageing` | `security_invoker` views — RLS-scoped to the caller, never wider |

| RPC | What it does |
|-----|--------------|
| `rpc_receive_vehicle_stock(vehicle, unit_cost, ref?, remarks?)` | `purchased → in_stock` with its cost |
| `rpc_reserve_vehicle(vehicle, reason?)` / `rpc_release_reservation(vehicle, reason)` | `in_stock ⇄ reserved` |
| `rpc_mark_vehicle_damaged(vehicle, reason)` | `in_stock`/`reserved` → `damaged`; releases any reservation first |
| `rpc_create_stock_transfer(source, destination, date, vehicle_ids[], remarks?)` | dispatches (`in_stock → in_transit`); needs `inventory.create` at the source and `inventory.view` at the destination |
| `rpc_receive_stock_transfer(transfer, remarks?)` | closes it (`in_transit → in_stock`, showroom moves to the destination) at the **same unit cost** — no P&L impact |
| `rpc_create_stock_adjustment(showroom, date, reason, items[], notes?)` | one ledger row per item; `direction: 'out'` write-offs are bucketed as `damaged` in v1 (theft/expiry/correction share it; see Known limits); `direction: 'in'` needs a supplied unit cost |

MB040 covers many distinct "wrong status for this action" scenarios, each with its own precise, already user-safe
message written directly in SQL — the app passes it straight through instead of blurring every case into one
static string (the established pattern for single-meaning codes like MB041/MB045 still applies to those).

## No P&L impact

A transfer's dispatch and receipt ledger rows always carry the *same* unit cost — checked by a database test — and
nothing here posts to any account. Accounting integration (in-transit clearing, inventory accounts, the adjustment
write-down journal) is Phase 12/13; until then, every stock movement in this phase is deliberately journal-free.

## Tests

- DB: `supabase/tests/database/11_inventory_stock.test.sql` (51): receiving (permission, showroom isolation, wrong
  status, negative cost, ledger closed to clients), reserve/release (one active reservation, required reason),
  mark damaged (releases the reservation, uses the last known cost), transfer dispatch + receive (showroom
  unchanged until receipt, same cost both sides, already-received refused), adjustment in/out (opening balance,
  theft write-off, unknown reason code refused), cross-showroom isolation, and reconciliation (`v_current_stock`
  counts match `vehicles` directly, ageing excludes a written-off unit). Weakening the ledger's RLS policy on
  purpose fails the isolation test.
- Flutter: `test/features/inventory/inventory_test.dart` (14): actions follow status and permission, the reason-
  required flows, status/movement history rendering, the Overview/Transfers/Adjustments tabs, MB040 pass-through
  vs. static single-meaning codes.
- Dev seed: the Activa (Indore) and the 450X (Bhopal) are received with a cost; the Activa is reserved.

## Known limits

- **Items/spares are out of scope** (`items`, `item_stock`, weighted-average valuation, low-stock alerts): the
  `stock_ledger`/`stock_adjustment_items`/`stock_transfer_items` tables carry only `vehicle_id` for now: adding item
  support means an additive migration (an `entry_kind` column + `item_id`), not a redesign.
- **Adjustment write-offs share one status.** `damage`, `theft`, `expiry` and `correction` (when direction = `out`)
  all move a vehicle to `damaged` in v1 — the enum has no separate "lost"/"written off" state yet. A future phase
  could add one if the distinction matters operationally.
- **No draft/approval stage** for transfers or adjustments (both post immediately) — the approval engine is
  Phase 21; the business-flow doc's fuller `Draft → Pending approval → Approved → …` transfer flow is deferred.
- **No accounting entries** anywhere in this phase (Phase 12/13).
- Carried over: the Phase 2 open items, Windows/iOS builds, nothing run against a real Supabase project yet.
