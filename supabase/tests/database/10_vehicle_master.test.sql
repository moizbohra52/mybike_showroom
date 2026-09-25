-- =============================================================================
-- 10 — Phase 8 vehicle master (migration 0010)
-- -----------------------------------------------------------------------------
-- Fixtures (supabase/seed.sql): showrooms IND 5a…001, BPL 5a…002;
--   users 003 manager IND (vehicles VCE) · 004 manager BPL · 006 sales exec IND
--   (vehicles V) · 008 inventory manager BPL (vehicles VCEAXP) · 010 cashier IND
--   (vehicles V) · 013 inactive · 001 superadmin.
--   Catalogue: Honda (Activa 6G STD/DLX petrol, Shine 125), TVS iQube 2.2 kWh
--   (EV), Ather 450X (EV), Bajaj Freedom 125 (CNG). Units: IND Activa STD
--   c4…001 + iQube c4…002; BPL 450X c4…003 + Freedom c4…004.
--   A. catalogue access and duplicates                                (10)
--   B. specification rules by fuel type                                (7)
--   C. vehicle units: identifiers, duplicates, isolation, lifecycle   (22)
-- Plan: 39 assertions
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select plan(39);

-- -----------------------------------------------------------------------------
-- A. Catalogue
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000006","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from public.vehicle_brands), 4, 'catalogue: every active user reads the brands');
select is((select count(*)::int from public.vehicle_variants), 6, 'catalogue: … and the variants');
select throws_ok(
  $$ insert into public.vehicle_brands (code, name) values ('HERO', 'Hero MotoCorp') $$,
  '42501', null,
  'catalogue: a sales executive (vehicles view only) cannot add brands');
select results_eq(
  $$ with u as (update public.vehicle_variants set ex_showroom_price = 1
                 where id = 'c3000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'catalogue: a sales executive cannot change prices');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000013","role":"authenticated"}', true);
select is_empty($$ select 1 from public.vehicle_brands $$, 'catalogue: a deactivated user reads nothing');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000008","role":"authenticated"}', true);
select lives_ok(
  $$ insert into public.vehicle_brands (code, name, country) values ('HERO', 'Hero MotoCorp', 'India') $$,
  'catalogue: an inventory manager (showroom-scoped vehicles.create) maintains the company catalogue');
select throws_ok(
  $$ insert into public.vehicle_brands (code, name) values ('HONDA2', 'HONDA') $$,
  '23505', null,
  'duplicates: brand names are unique ignoring case');
select throws_ok(
  $$ insert into public.vehicle_models (brand_id, name, category)
     values ('c1000000-0000-4000-8000-000000000001', 'activa 6g', 'scooter') $$,
  '23505', null,
  'duplicates: a brand cannot have the same model twice (ignoring case)');
select throws_ok(
  $$ insert into public.vehicle_variants (model_id, name, fuel_type, engine_cc)
     values ('c2000000-0000-4000-8000-000000000001', 'std', 'petrol', 109.5) $$,
  '23505', null,
  'duplicates: a model cannot have the same variant twice (ignoring case)');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select results_eq(
  $$ with u as (update public.vehicle_variants set ex_showroom_price = 77999.00
                 where id = 'c3000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from u $$,
  $$ values (1) $$,
  'catalogue: a showroom manager (vehicles.edit) updates a price');

-- -----------------------------------------------------------------------------
-- B. Specification rules
-- -----------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.vehicle_variants (model_id, name, fuel_type, motor_power_kw)
     values ('c2000000-0000-4000-8000-000000000003', '3.4 kWh', 'electric', 4.4) $$,
  '23514', null,
  'specs: an electric variant needs its battery capacity');
select throws_ok(
  $$ insert into public.vehicle_variants (model_id, name, fuel_type, motor_power_kw, battery_capacity_kwh, engine_cc)
     values ('c2000000-0000-4000-8000-000000000003', '3.4 kWh', 'electric', 4.4, 3.4, 110) $$,
  '23514', null,
  'specs: an electric variant has no engine');
select throws_ok(
  $$ insert into public.vehicle_variants (model_id, name, fuel_type)
     values ('c2000000-0000-4000-8000-000000000002', 'Disc', 'petrol') $$,
  '23514', null,
  'specs: a petrol variant needs its engine displacement');
select throws_ok(
  $$ insert into public.vehicle_variants (model_id, name, fuel_type, engine_cc, battery_capacity_kwh)
     values ('c2000000-0000-4000-8000-000000000002', 'Disc', 'petrol', 123.9, 2.0) $$,
  '23514', null,
  'specs: a petrol variant has no battery specifications');
select throws_ok(
  $$ insert into public.vehicle_variants (model_id, name, fuel_type, engine_cc)
     values ('c2000000-0000-4000-8000-000000000002', 'Hybrid', 'hybrid', 123.9) $$,
  '23514', null,
  'specs: a hybrid needs an engine AND a motor with battery');
select lives_ok(
  $$ insert into public.vehicle_variants (model_id, name, fuel_type, engine_cc, motor_power_kw, battery_capacity_kwh)
     values ('c2000000-0000-4000-8000-000000000002', 'Hybrid', 'hybrid', 123.9, 1.5, 0.5) $$,
  'specs: a hybrid with both is accepted');
select throws_ok(
  $$ insert into public.vehicle_variants (model_id, name, fuel_type, engine_cc, hsn_code)
     values ('c2000000-0000-4000-8000-000000000002', 'Disc', 'petrol', 123.9, '87112') $$,
  '23514', null,
  'specs: an HSN code has 4, 6 or 8 digits');

-- -----------------------------------------------------------------------------
-- C. Vehicle units
-- -----------------------------------------------------------------------------
select lives_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, vin, chassis_number, engine_number, color)
     values ('5a000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000002',
             'me4jf508arj 000999', ' me4jf508arj000999 ', 'jf50e7 000999', 'Matte Axis Grey') $$,
  'units: a showroom manager registers a petrol unit in its showroom');
select results_eq(
  $$ select vin, chassis_number, engine_number, fuel_type::text, status::text from public.vehicles
      where chassis_number = 'ME4JF508ARJ000999' $$,
  $$ values ('ME4JF508ARJ000999'::text, 'ME4JF508ARJ000999'::text, 'JF50E7000999'::text, 'petrol'::text, 'purchased'::text) $$,
  'units: identifiers are stored upper-case without spaces; fuel type comes from the variant; new units await receipt');
select throws_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, fuel_type, chassis_number, motor_number, battery_number)
     values ('5a000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'electric',
             'MXAB1234567', 'MOT0001', 'BAT0001') $$,
  '42501', null,
  'units: the client cannot set the fuel type (it follows the variant)');
select throws_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, chassis_number, motor_number)
     values ('5a000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000004', 'MD6EVB9A2R1000999', 'IQM24100999') $$,
  '23514', null,
  'units: an electric unit needs its battery number');
select throws_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, chassis_number, engine_number, motor_number)
     values ('5a000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'ME4JF508ARJ000998',
             'JF50E7000998', 'MOT000998') $$,
  '23514', null,
  'units: a petrol unit has no motor number');
select throws_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, vin, chassis_number, engine_number)
     values ('5a000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'ME4JF508ORJ000997',
             'ME4JF508ARJ000997', 'JF50E7000997') $$,
  '23514', null,
  'units: a VIN has 17 characters without I, O or Q');
select throws_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, chassis_number, engine_number, warranty_start, warranty_end)
     values ('5a000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001', 'ME4JF508ARJ000996',
             'JF50E7000996', '2026-09-01', '2026-08-01') $$,
  '23514', null,
  'units: warranty cannot end before it starts');

-- Duplicates across showrooms (identifiers are company-wide).
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select throws_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, chassis_number, engine_number)
     values ('5a000000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000001', 'me4jf508arj000101', 'JF50E7555555') $$,
  '23505', null,
  'duplicates: a chassis number registered in Indore is refused in Bhopal (case and spaces ignored)');
select throws_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, chassis_number, engine_number)
     values ('5a000000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000001', 'ME4JF508ARJ555555', 'JF50E7000101') $$,
  '23505', null,
  'duplicates: engine numbers are unique');
select throws_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, chassis_number, motor_number, battery_number)
     values ('5a000000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000004', 'MD6EVB9A2R1555555',
             'IQM24100201', 'IQB22K0555555') $$,
  '23505', null,
  'duplicates: motor numbers are unique');
select throws_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, chassis_number, motor_number, battery_number)
     values ('5a000000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000004', 'MD6EVB9A2R1555555',
             'IQM24155555', 'IQB22K0100201') $$,
  '23505', null,
  'duplicates: battery numbers are unique');
select is(
  public.rpc_vehicle_identifier_conflicts('MD6EVB9A2R1000201', 'md6evb9a2r1000201', null, 'IQM99999', 'iqb22k0100201'),
  array['vin', 'chassis_number', 'battery_number'],
  'duplicate check: the form learns which fields are taken, in any showroom');
select is(
  public.rpc_vehicle_identifier_conflicts(null, 'MB9AE3A2XR0000301', null, 'ATHM640000301', 'ATHB37K0000301',
                                          'c4000000-0000-4000-8000-000000000003'),
  '{}'::text[],
  'duplicate check: a unit does not conflict with itself when edited');
select is_empty(
  $$ select 1 from public.vehicles where showroom_id = '5a000000-0000-4000-8000-000000000001' $$,
  'isolation: the Bhopal manager sees no Indore unit');
select results_eq(
  $$ with u as (update public.vehicles set color = 'Blue'
                 where id = 'c4000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'isolation: the Bhopal manager cannot change an Indore unit');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000010","role":"authenticated"}', true);
select is((select count(*)::int from public.vehicles), 3, 'units: the Indore cashier (vehicles view) sees Indore''s units');
select results_eq(
  $$ with u as (update public.vehicles set color = 'Blue'
                 where id = 'c4000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'units: view-only staff cannot change units');
select throws_ok(
  $$ select public.rpc_vehicle_identifier_conflicts('X', 'Y', null, null, null) $$,
  '42501', null,
  'duplicate check: needs vehicles.create or vehicles.edit');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select throws_ok(
  $$ update public.vehicles set status = 'in_stock' where id = 'c4000000-0000-4000-8000-000000000001' $$,
  '42501', null,
  'lifecycle: status changes only through stock movements (no client privilege)');
select throws_ok(
  $$ update public.vehicles set showroom_id = '5a000000-0000-4000-8000-000000000002'
      where id = 'c4000000-0000-4000-8000-000000000001' $$,
  '42501', null,
  'lifecycle: moving a unit to another showroom is a transfer, not an edit');

reset role;
update public.vehicles set status = 'sold' where id = 'c4000000-0000-4000-8000-000000000001';
set local role authenticated;
select lives_ok(
  $$ insert into public.vehicles (showroom_id, variant_id, vin, chassis_number, engine_number, ownership)
     values ('5a000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001',
             'ME4JF508ARJ000101', 'ME4JF508ARJ000101', 'JF50E7000101', 'used') $$,
  'lifecycle: a sold unit frees its identifiers (it can come back as a used buyback)');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select throws_ok(
  $$ update public.vehicle_variants set fuel_type = 'electric', engine_cc = null, mileage_kmpl = null,
            fuel_tank_litres = null, motor_power_kw = 2, battery_capacity_kwh = 2
      where id = 'c3000000-0000-4000-8000-000000000001' $$,
  'MB030', null,
  'catalogue: the fuel type of a variant with registered units is frozen');

select * from finish();
rollback;
