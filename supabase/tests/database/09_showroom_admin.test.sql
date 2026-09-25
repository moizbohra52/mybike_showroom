-- =============================================================================
-- 09 — Phase 7 showroom administration (migration 0009)
-- -----------------------------------------------------------------------------
-- Fixtures (supabase/seed.sql): showrooms IND 5a…001, BPL 5a…002, UJN 5a…003;
--   users 001 superadmin · 002 admin (global, IND/BPL/UJN) · 003 manager IND ·
--   004 manager BPL · 009 accountant IND+BPL · 012 viewer UJN.
--   Bank accounts: IND and BPL one default account each, UJN none.
--   A. create showroom                                                 (9)
--   B. edit, settings, invoice prefix                                  (8)
--   C. bank accounts (isolation, single default, formats)              (9)
--   D. deactivation and the session / switcher                         (7)
-- Plan: 33 assertions
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

-- -----------------------------------------------------------------------------
-- A. Create
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(
  $$ select public.rpc_create_showroom('{"code":"DEWAS","name":"Dewas Showroom","invoice_prefix":"DWS"}') $$,
  '42501', null,
  'create: a showroom manager (showrooms view only) cannot create showrooms');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select lives_ok(
  $$ select public.rpc_create_showroom('{"code":" dewas ","name":"Dewas Showroom","invoice_prefix":"dws",
       "state_code":"23","gstin":"23ABCDE1234F1Z5","pan":"ABCDE1234F","city":"Dewas","pincode":"455001"}') $$,
  'create: admin (global showrooms.create) creates a showroom');
select results_eq(
  $$ select code, invoice_prefix from public.showrooms where code = 'DEWAS' $$,
  $$ values ('DEWAS'::text, 'DWS'::text) $$,
  'create: the creator reads it back; code and prefix are upper-cased');
select is(
  (select count(*)::int from public.user_showrooms us join public.showrooms s on s.id = us.showroom_id
    where s.code = 'DEWAS' and us.profile_id = 'a0000000-0000-4000-8000-000000000002'),
  1, 'create: a non-owner creator is assigned to the new showroom');
select ok(
  exists (select 1 from public.showroom_settings ss join public.showrooms s on s.id = ss.showroom_id where s.code = 'DEWAS'),
  'create: settings are bootstrapped');
select is(
  (select count(distinct ds.doc_type)::int from public.document_sequences ds
     join public.showrooms s on s.id = ds.showroom_id where s.code = 'DEWAS'),
  (select count(*)::int from unnest(enum_range(null::public.document_sequence_type))),
  'create: every document type gets a numbering series');
select throws_ok(
  $$ select public.rpc_create_showroom('{"code":"INDORE-2","name":"Indore Two","invoice_prefix":"IND"}') $$,
  '23505', null,
  'create: the invoice prefix is unique across showrooms');
select throws_ok(
  $$ select public.rpc_create_showroom('{"code":"PUNE","name":"Pune Showroom","invoice_prefix":"PUN",
       "state_code":"23","gstin":"27ABCDE1234F1Z5"}') $$,
  '23514', null,
  'create: a GSTIN must match the showroom state');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select public.rpc_create_showroom('{"code":"RATLAM","name":"Ratlam Showroom","invoice_prefix":"RTM"}');
select is_empty(
  $$ select 1 from public.user_showrooms us join public.showrooms s on s.id = us.showroom_id
      where s.code = 'RATLAM' $$,
  'create: the owner is not assigned (Super Admin sees every showroom)');

-- -----------------------------------------------------------------------------
-- B. Edit, settings, invoice prefix
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select results_eq(
  $$ with u as (update public.showrooms set name = 'Indore Flagship'
                 where id = '5a000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'edit: a showroom manager cannot edit its showroom (showrooms view only)');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000009","role":"authenticated"}', true);
select results_eq(
  $$ with u as (update public.showroom_settings set booking_validity_days = 60
                 where showroom_id = '5a000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'settings: the accountant reads but cannot change showroom settings');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select results_eq(
  $$ with u as (update public.showrooms set phone = '+917310000099'
                 where id = '5a000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from u $$,
  $$ values (1) $$,
  'edit: admin edits a showroom');
select results_eq(
  $$ with u as (update public.showroom_settings set booking_validity_days = 45, booking_min_amount = 5000.50
                 where showroom_id = '5a000000-0000-4000-8000-000000000002' returning 1)
     select count(*)::int from u $$,
  $$ values (1) $$,
  'settings: admin changes showroom settings');
select lives_ok(
  $$ update public.showrooms set invoice_prefix = 'DW' where code = 'DEWAS' $$,
  'prefix: an unused prefix can change');
select results_eq(
  $$ select ds.doc_type::text, ds.prefix, ds.padding::int from public.document_sequences ds
       join public.showrooms s on s.id = ds.showroom_id
      where s.code = 'DEWAS' and ds.doc_type in ('sales_invoice', 'credit_note') order by 1 $$,
  $$ values ('credit_note'::text, 'DWCN'::text, 5), ('sales_invoice', 'DW', 5) $$,
  'prefix: the numbering series follow the new prefix (padding recomputed)');

reset role;
select public.fn_next_document_number('5a000000-0000-4000-8000-000000000001', 'sales_invoice', public.fn_business_date());
set local role authenticated;
select throws_ok(
  $$ update public.showrooms set invoice_prefix = 'IDR' where id = '5a000000-0000-4000-8000-000000000001' $$,
  'MB012', null,
  'prefix: frozen once a document number was issued');
select throws_ok(
  $$ update public.document_sequences set next_number = 1 $$,
  '42501', null,
  'numbering: clients never write numbering series directly');

-- -----------------------------------------------------------------------------
-- C. Bank accounts
-- -----------------------------------------------------------------------------
select lives_ok(
  $$ insert into public.bank_accounts (showroom_id, account_name, bank_name, account_number, ifsc, is_default)
     values ('5a000000-0000-4000-8000-000000000001', 'MyBike Motors Private Limited', 'ICICI Bank',
             '001105012345', 'ICIC0000011', true) $$,
  'bank: admin adds a default account to IND');
select results_eq(
  $$ select bank_name from public.bank_accounts
      where showroom_id = '5a000000-0000-4000-8000-000000000001' and is_default $$,
  $$ values ('ICICI Bank'::text) $$,
  'bank: a new default replaces the previous one (one default per showroom)');
select throws_ok(
  $$ insert into public.bank_accounts (showroom_id, account_name, bank_name, account_number, ifsc)
     values ('5a000000-0000-4000-8000-000000000001', 'MyBike', 'Axis Bank', '917020012345678', 'UTIB000123') $$,
  '23514', null,
  'bank: an IFSC must be 4 letters, 0 and 6 characters');
select throws_ok(
  $$ insert into public.bank_accounts (showroom_id, account_name, bank_name, account_number, ifsc)
     values ('5a000000-0000-4000-8000-000000000001', 'MyBike', 'HDFC Bank', '50200012345678', 'HDFC0001234') $$,
  '23505', null,
  'bank: the same account number cannot be added twice to a showroom');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select is((select count(*)::int from public.bank_accounts where showroom_id = '5a000000-0000-4000-8000-000000000001'), 2,
  'bank: the showroom''s staff can read its bank details (invoices print them)');
select throws_ok(
  $$ insert into public.bank_accounts (showroom_id, account_name, bank_name, account_number, ifsc)
     values ('5a000000-0000-4000-8000-000000000001', 'MyBike', 'Axis Bank', '917020012345678', 'UTIB0000123') $$,
  '42501', null,
  'bank: a showroom manager (showrooms view only) cannot add accounts');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select is_empty(
  $$ select 1 from public.bank_accounts where showroom_id = '5a000000-0000-4000-8000-000000000001' $$,
  'isolation: the Bhopal manager cannot read Indore''s bank accounts');
select results_eq(
  $$ with u as (update public.bank_accounts set ifsc = 'HDFC0009999'
                 where showroom_id = '5a000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'isolation: the Bhopal manager cannot change Indore''s bank accounts');
select results_eq(
  $$ with d as (delete from public.bank_accounts
                 where showroom_id = '5a000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from d $$,
  $$ values (0) $$,
  'isolation: the Bhopal manager cannot delete Indore''s bank accounts');

-- -----------------------------------------------------------------------------
-- D. Deactivation
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select results_eq(
  $$ with u as (update public.showrooms set is_active = false
                 where id = '5a000000-0000-4000-8000-000000000003' returning 1)
     select count(*)::int from u $$,
  $$ values (1) $$,
  'deactivate: admin deactivates Ujjain');
select ok(
  not ((public.rpc_get_my_session() -> 'showrooms') @> '[{"code":"UJJAIN"}]'),
  'deactivate: Ujjain leaves the admin''s switcher');
select is_empty($$ select 1 from public.showrooms where code = 'UJJAIN' $$,
  'deactivate: only the owner still sees an inactive showroom');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000012","role":"authenticated"}', true);
select is(jsonb_array_length(public.rpc_get_my_session() -> 'showrooms'), 0,
  'deactivate: a user working only there has no showroom left (access-blocked screen)');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select ok(
  exists (select 1 from public.showrooms where code = 'UJJAIN' and not is_active)
  and not ((public.rpc_get_my_session() -> 'showrooms') @> '[{"code":"UJJAIN"}]'),
  'deactivate: the owner still manages it, but it is not a working showroom');
select results_eq(
  $$ with u as (update public.showrooms set is_active = true where code = 'UJJAIN' returning 1)
     select count(*)::int from u $$,
  $$ values (1) $$,
  'reactivate: the owner reactivates Ujjain');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000012","role":"authenticated"}', true);
select is((public.rpc_get_my_session() -> 'showrooms' -> 0 ->> 'code'), 'UJJAIN',
  'reactivate: the viewer works in Ujjain again');

select * from finish();
rollback;
