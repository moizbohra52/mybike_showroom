-- =============================================================================
-- 11 — Phase 9 inventory & stock (migration 0011)
-- -----------------------------------------------------------------------------
-- Fixtures (supabase/seed.sql): showrooms IND 5a…001, BPL 5a…002;
--   users 003 manager IND (inventory VCEX) · 004 manager BPL (inventory VCEX) ·
--   005 sales manager IND (inventory VX, no create) · 006 sales exec IND
--   (inventory V) · 008 inventory manager BPL (inventory VCEAXP) · 009
--   accountant IND+BPL (inventory VX, no create).
--   Vehicles: c4…001 Activa petrol @ IND, received (unit cost 68000), reserved
--   by sales.exec; c4…002 iQube electric @ IND, purchased (not received);
--   c4…003 450X electric @ BPL, received (unit cost 130000); c4…004 Freedom
--   CNG @ BPL, purchased.
--   A. receiving                                                        (9)
--   B. reserve / release                                                (9)
--   C. mark damaged                                                     (7)
--   D. transfer (dispatch + receive), no P&L impact                    (12)
--   E. stock adjustment                                                 (8)
--   F. isolation and reconciliation                                     (6)
-- Plan: 51 assertions
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select plan(51);

-- -----------------------------------------------------------------------------
-- A. Receiving
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000006","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$ select public.rpc_receive_vehicle_stock('c4000000-0000-4000-8000-000000000002', 55000.00) $$,
  '42501', null,
  'receive: a sales executive (inventory view only) cannot receive stock');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select throws_ok(
  $$ select public.rpc_receive_vehicle_stock('c4000000-0000-4000-8000-000000000004', 90000.00) $$,
  '42501', null,
  'isolation: the Indore manager cannot receive a Bhopal vehicle');
select lives_ok(
  $$ select public.rpc_receive_vehicle_stock('c4000000-0000-4000-8000-000000000002', 92000.00, 'DEV-GRN-003') $$,
  'receive: the Indore manager receives the iQube (inventory.create)');
select is(
  (select status::text from public.vehicles where id = 'c4000000-0000-4000-8000-000000000002'),
  'in_stock', 'receive: the vehicle moves purchased -> in_stock');
select is(
  (select count(*)::int from public.vehicle_status_history
    where vehicle_id = 'c4000000-0000-4000-8000-000000000002' and to_status = 'in_stock'),
  1, 'receive: a history row records the change');
select is(
  (select l.reference_type from public.vehicle_status_history l
    where l.vehicle_id = 'c4000000-0000-4000-8000-000000000002' and l.to_status = 'in_stock'),
  'manual_receipt', 'receive: the history row carries a reference');
select throws_ok(
  $$ select public.rpc_receive_vehicle_stock('c4000000-0000-4000-8000-000000000002', 92000.00) $$,
  'MB040', null,
  'receive: an already-received vehicle cannot be received again');
select throws_ok(
  $$ select public.rpc_receive_vehicle_stock('c4000000-0000-4000-8000-000000000002', -1) $$,
  '23514', null,
  'receive: a negative unit cost is refused');
select throws_ok(
  $$ insert into public.stock_ledger (showroom_id, movement_type, vehicle_id, unit_cost, value)
     values ('5a000000-0000-4000-8000-000000000001', 'purchase_receipt', 'c4000000-0000-4000-8000-000000000001', 1, 1) $$,
  '42501', null,
  'ledger: authenticated has no direct write privilege at all (only the RPCs)');

-- -----------------------------------------------------------------------------
-- B. Reserve / release
-- -----------------------------------------------------------------------------
select throws_ok(
  $$ select public.rpc_release_reservation('c4000000-0000-4000-8000-000000000002', 'n/a') $$,
  'MB041', null,
  'release: a freshly received vehicle (no active reservation) cannot be released');
select throws_ok(
  $$ select public.rpc_reserve_vehicle('c4000000-0000-4000-8000-000000000001') $$,
  'MB040', null,
  'reserve: an already-reserved vehicle cannot be reserved again');
select lives_ok(
  $$ select public.rpc_reserve_vehicle('c4000000-0000-4000-8000-000000000002', 'Customer hold') $$,
  'reserve: the manager reserves the newly received iQube');
select is(
  (select status::text from public.vehicles where id = 'c4000000-0000-4000-8000-000000000002'),
  'reserved', 'reserve: status moves to reserved');
select is(
  (select count(*)::int from public.vehicle_reservations
    where vehicle_id = 'c4000000-0000-4000-8000-000000000002' and released_at is null),
  1, 'reserve: exactly one active reservation exists');
select lives_ok(
  $$ select public.rpc_release_reservation('c4000000-0000-4000-8000-000000000002', 'Customer changed mind') $$,
  'release: the manager releases the reservation');
select is(
  (select status::text from public.vehicles where id = 'c4000000-0000-4000-8000-000000000002'),
  'in_stock', 'release: status returns to in_stock');
select is(
  (select release_reason from public.vehicle_reservations
    where vehicle_id = 'c4000000-0000-4000-8000-000000000002' order by reserved_at desc limit 1),
  'Customer changed mind', 'release: the reason is recorded');
select throws_ok(
  $$ select public.rpc_release_reservation('c4000000-0000-4000-8000-000000000002', '') $$,
  '23514', null,
  'release: a reason is required');

-- -----------------------------------------------------------------------------
-- C. Mark damaged
-- -----------------------------------------------------------------------------
select throws_ok(
  $$ select public.rpc_mark_vehicle_damaged('c4000000-0000-4000-8000-000000000004', 'Fell off the truck') $$,
  '42501', null,
  'damaged: the Indore manager cannot mark a Bhopal vehicle damaged');
select lives_ok(
  $$ select public.rpc_reserve_vehicle('c4000000-0000-4000-8000-000000000002') $$,
  'damaged: reserve the iQube again to test that damage releases the reservation');
select lives_ok(
  $$ select public.rpc_mark_vehicle_damaged('c4000000-0000-4000-8000-000000000002', 'Showroom fire') $$,
  'damaged: the manager marks the reserved iQube damaged');
select is(
  (select status::text from public.vehicles where id = 'c4000000-0000-4000-8000-000000000002'),
  'damaged', 'damaged: status moves to damaged');
select is(
  (select count(*)::int from public.vehicle_reservations
    where vehicle_id = 'c4000000-0000-4000-8000-000000000002' and released_at is null),
  0, 'damaged: the reservation was released automatically');
select is(
  (select l.unit_cost from public.stock_ledger l
    where l.vehicle_id = 'c4000000-0000-4000-8000-000000000002' and l.movement_type = 'damage'),
  92000.00, 'damaged: the ledger row carries the vehicle''s last known cost');
select throws_ok(
  $$ select public.rpc_mark_vehicle_damaged('c4000000-0000-4000-8000-000000000002', 'again') $$,
  'MB040', null,
  'damaged: an already-damaged vehicle cannot be marked damaged again');

-- -----------------------------------------------------------------------------
-- D. Transfer (dispatch + receive), no P&L impact
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000009","role":"authenticated"}', true);
select throws_ok(
  $$ select public.rpc_create_stock_transfer('5a000000-0000-4000-8000-000000000001',
       '5a000000-0000-4000-8000-000000000002', current_date, array['c4000000-0000-4000-8000-000000000001']::uuid[]) $$,
  '42501', null,
  'transfer: the accountant (inventory view only) cannot dispatch a transfer');

-- Uses the admin (global access) so the failure below is the status guard,
-- not a missing-destination-view refusal.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok(
  $$ select public.rpc_create_stock_transfer('5a000000-0000-4000-8000-000000000001',
       '5a000000-0000-4000-8000-000000000002', current_date, array['c4000000-0000-4000-8000-000000000001']::uuid[]) $$,
  'MB040', null,
  'transfer: the reserved Activa cannot be dispatched (not in_stock)');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select lives_ok(
  $$ select public.rpc_release_reservation('c4000000-0000-4000-8000-000000000001', 'Freeing the unit for a transfer test') $$,
  'transfer: release the Activa''s reservation first');

-- A showroom-scoped Indore manager has no visibility into Bhopal at all, so
-- real staff dispatching cross-showroom need at least inventory.view at the
-- destination too (docs/phase-00/06-business-flows.md §3); only a global
-- role (admin here) has both sides in this seed.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select results_eq(
  $$ select 1 from (
       select public.rpc_create_stock_transfer('5a000000-0000-4000-8000-000000000001',
         '5a000000-0000-4000-8000-000000000002', current_date, array['c4000000-0000-4000-8000-000000000001']::uuid[],
         'Rebalancing stock') as id
     ) x $$,
  $$ values (1) $$,
  'transfer: the admin dispatches the Activa from Indore to Bhopal');
select is(
  (select status::text from public.vehicles where id = 'c4000000-0000-4000-8000-000000000001'),
  'in_transit', 'transfer: the unit is in_transit immediately after dispatch');
select is(
  (select showroom_id from public.vehicles where id = 'c4000000-0000-4000-8000-000000000001'),
  '5a000000-0000-4000-8000-000000000001'::uuid,
  'transfer: the showroom does not change until it is received');
select is(
  (select t.status::text from public.stock_transfers t
    join public.stock_transfer_items i on i.transfer_id = t.id
   where i.vehicle_id = 'c4000000-0000-4000-8000-000000000001'),
  'in_transit', 'transfer: the transfer header is in_transit');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select lives_ok(
  $$ select public.rpc_receive_stock_transfer(
       (select t.id from public.stock_transfers t join public.stock_transfer_items i on i.transfer_id = t.id
         where i.vehicle_id = 'c4000000-0000-4000-8000-000000000001')) $$,
  'transfer: the Bhopal manager receives the transfer');
select is(
  (select status::text from public.vehicles where id = 'c4000000-0000-4000-8000-000000000001'),
  'in_stock', 'transfer: the unit is in_stock again after receipt');
select is(
  (select showroom_id from public.vehicles where id = 'c4000000-0000-4000-8000-000000000001'),
  '5a000000-0000-4000-8000-000000000002'::uuid,
  'transfer: the showroom is now the destination');
-- A global role, since a showroom-scoped Bhopal manager cannot see the
-- source showrooms ledger row at all (RLS), which is correct isolation,
-- not a defect in this cross-showroom invariant.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is(
  (select l1.unit_cost = l2.unit_cost from public.stock_ledger l1, public.stock_ledger l2
    where l1.vehicle_id = 'c4000000-0000-4000-8000-000000000001' and l1.movement_type = 'transfer_out'
      and l2.vehicle_id = 'c4000000-0000-4000-8000-000000000001' and l2.movement_type = 'transfer_in'),
  true, 'transfer: dispatch and receipt carry the same unit cost (no P&L impact)');
select throws_ok(
  $$ select public.rpc_receive_stock_transfer(
       (select t.id from public.stock_transfers t join public.stock_transfer_items i on i.transfer_id = t.id
         where i.vehicle_id = 'c4000000-0000-4000-8000-000000000001')) $$,
  'MB045', null,
  'transfer: an already-received transfer cannot be received again');

-- -----------------------------------------------------------------------------
-- E. Stock adjustment
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000009","role":"authenticated"}', true);
select throws_ok(
  $$ select public.rpc_create_stock_adjustment('5a000000-0000-4000-8000-000000000002', current_date, 'physical_count',
       jsonb_build_array(jsonb_build_object('vehicle_id', 'c4000000-0000-4000-8000-000000000004', 'direction', 'out'))) $$,
  '42501', null,
  'adjustment: the accountant (inventory view only) cannot post an adjustment');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000008","role":"authenticated"}', true);
select lives_ok(
  $$ select public.rpc_create_stock_adjustment('5a000000-0000-4000-8000-000000000002', current_date, 'opening',
       jsonb_build_array(jsonb_build_object('vehicle_id', 'c4000000-0000-4000-8000-000000000004', 'direction', 'in',
                                            'unit_cost', 78500.00))) $$,
  'adjustment: the Bhopal inventory manager brings the Freedom in as an opening balance');
select is(
  (select status::text from public.vehicles where id = 'c4000000-0000-4000-8000-000000000004'),
  'in_stock', 'adjustment: the vehicle becomes in_stock');
select is(
  (select total_value from public.stock_adjustments
    where showroom_id = '5a000000-0000-4000-8000-000000000002' and reason_code = 'opening'),
  78500.00, 'adjustment: the header total matches its one line');
select lives_ok(
  $$ select public.rpc_create_stock_adjustment('5a000000-0000-4000-8000-000000000002', current_date, 'theft',
       jsonb_build_array(jsonb_build_object('vehicle_id', 'c4000000-0000-4000-8000-000000000003', 'direction', 'out'))) $$,
  'adjustment: writes off the 450X for theft');
select is(
  (select status::text from public.vehicles where id = 'c4000000-0000-4000-8000-000000000003'),
  'damaged', 'adjustment: an out-adjustment removes the unit from available stock');
select throws_ok(
  $$ select public.rpc_create_stock_adjustment('5a000000-0000-4000-8000-000000000002', current_date, 'physical_count',
       jsonb_build_array(jsonb_build_object('vehicle_id', 'c4000000-0000-4000-8000-000000000003', 'direction', 'out'))) $$,
  'MB040', null,
  'adjustment: an already written-off vehicle cannot be adjusted out again');
select throws_ok(
  $$ select public.rpc_create_stock_adjustment('5a000000-0000-4000-8000-000000000002', current_date, 'not-a-reason',
       jsonb_build_array(jsonb_build_object('vehicle_id', 'c4000000-0000-4000-8000-000000000004', 'direction', 'out'))) $$,
  '23514', null,
  'adjustment: an unknown reason code is refused');

-- -----------------------------------------------------------------------------
-- F. Isolation and reconciliation
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select is_empty(
  $$ select 1 from public.stock_ledger where showroom_id = '5a000000-0000-4000-8000-000000000002' $$,
  'isolation: the Indore manager cannot read Bhopal''s stock ledger');
select is_empty(
  $$ select 1 from public.vehicle_status_history where showroom_id = '5a000000-0000-4000-8000-000000000002' $$,
  'isolation: … nor Bhopal''s status history');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000008","role":"authenticated"}', true);
select is(
  (select available_count from public.v_current_stock where showroom_id = '5a000000-0000-4000-8000-000000000002'),
  (select count(*)::bigint from public.vehicles
    where showroom_id = '5a000000-0000-4000-8000-000000000002' and status = 'in_stock'),
  'reconciliation: v_current_stock.available_count matches vehicles in_stock in Bhopal');
select is(
  (select damaged_count from public.v_current_stock where showroom_id = '5a000000-0000-4000-8000-000000000002'),
  1::bigint, 'reconciliation: the theft write-off (450X) counts as damaged; the opening-balance Freedom does not');
select ok(
  (select days_in_stock from public.v_stock_ageing where vehicle_id = 'c4000000-0000-4000-8000-000000000001') >= 0,
  'reconciliation: ageing is non-negative for the transferred-in Activa');
select is_empty(
  $$ select 1 from public.v_stock_ageing where vehicle_id = 'c4000000-0000-4000-8000-000000000003' $$,
  'reconciliation: a damaged (written-off) vehicle does not appear in the ageing view');

select * from finish();
rollback;
