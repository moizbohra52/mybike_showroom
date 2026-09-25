-- =============================================================================
-- MyBike · Phase 3 · database test 01 — schema, RLS and privileges
-- -----------------------------------------------------------------------------
-- Asserts the structure and the security posture created by the Phase 3
-- migrations (20260923000001..4). Everything it writes is its own fixture
-- data (showroom codes T-…, invoice prefixes T1…T8, e-mails @example.test,
-- ids b1000000-… / 5b000000-…) and the file rolls back, so it does NOT depend
-- on supabase/seed.sql: the seeded super admin id (a0000000-…-001) is only
-- used as a JWT subject.
--
--   1. tables: the 13 Phase 3 tables exist, later-phase tables do not, and
--      public holds nothing else (no stray tables, no views)
--   2. key columns: NOT NULL / nullable, e-mail columns are extensions.citext
--   3. extensions: citext, pg_trgm, pgcrypto live in schema extensions and
--      nothing is installed into public
--   4. RLS: enabled on every public table; every table has TO authenticated policies (Phase 4)
--   5. table privileges: anon holds none at all; authenticated never holds
--      TRUNCATE / REFERENCES / TRIGGER and cannot write permissions, states or
--      document_sequences
--   6. function privileges: nothing executable by PUBLIC or anon, exactly 7
--      functions executable by authenticated, the SECURITY DEFINER set, and
--      search_path pinned to '' everywhere
--   7. comments on every public table and function
--   8. money hygiene (no real / double precision / money columns) and a
--      primary key on every table
--   9. uniqueness (23505): showroom code and invoice prefix, case-insensitive
--      profile e-mail (through the auth -> profile trigger and directly),
--      NULLS NOT DISTINCT global role assignments, one default showroom per
--      user; GSTIN is deliberately NOT unique
--  10. CHECK constraints (23514)
--  11. behaviour as the API roles (runs last, after all postgres writes):
--      authenticated (super admin JWT) reads 0 rows everywhere, is refused
--      writes, may call only the granted helpers; anon is refused outright
--
-- Every error assertion pins the exact message (constraint / object name) so
-- it cannot pass because some other constraint or privilege fired.
--
-- Phase 4 (0005) adds RLS policies and the RBAC helper functions: update §4
-- (policies), §6 (authenticated function set / SECURITY DEFINER set), §11
-- (0-row reads) and the hasnt_table checks of §1 together with it.
--
-- Plan: 79 assertions
--   tables 18 · columns 10 · extensions 4 · RLS 2 · table privileges 5 ·
--   function privileges 6 · comments 2 · conventions 2 · uniqueness 9 ·
--   checks 11 · API-role behaviour 10
-- =============================================================================
begin;

create extension if not exists pgtap with schema extensions;

select plan(79);

-- -----------------------------------------------------------------------------
-- 1. Tables (18)
-- -----------------------------------------------------------------------------
select has_table('public', 'states', 'tables: public.states exists');
select has_table('public', 'showrooms', 'tables: public.showrooms exists');
select has_table('public', 'showroom_settings', 'tables: public.showroom_settings exists');
select has_table('public', 'settings', 'tables: public.settings exists');
select has_table('public', 'financial_years', 'tables: public.financial_years exists');
select has_table('public', 'accounting_periods', 'tables: public.accounting_periods exists');
select has_table('public', 'document_sequences', 'tables: public.document_sequences exists');
select has_table('public', 'profiles', 'tables: public.profiles exists');
select has_table('public', 'roles', 'tables: public.roles exists');
select has_table('public', 'permissions', 'tables: public.permissions exists');
select has_table('public', 'role_permissions', 'tables: public.role_permissions exists');
select has_table('public', 'user_roles', 'tables: public.user_roles exists');
select has_table('public', 'user_showrooms', 'tables: public.user_showrooms exists');

-- Later phases create these together with their RLS policies.
select has_table('public', 'vehicles', 'tables: public.vehicles exists (Phase 8)');
select hasnt_table('public', 'customers', 'tables: public.customers does not exist yet (later phase)');
select hasnt_table('public', 'journal_entries', 'tables: public.journal_entries does not exist yet (later phase)');
select hasnt_table('public', 'audit_logs', 'tables: public.audit_logs does not exist yet (later phase)');

-- Views and materialized views are included: a view would bypass RLS unless
-- created with security_invoker.
select set_eq(
  $$ select c.relname::text
       from pg_catalog.pg_class c
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p', 'v', 'm', 'f') $$,
  $$ values ('states'), ('showrooms'), ('showroom_settings'), ('settings'),
            ('financial_years'), ('accounting_periods'), ('document_sequences'),
            ('profiles'), ('roles'), ('permissions'), ('role_permissions'),
            ('user_roles'), ('user_showrooms'), ('bank_accounts'),
            ('vehicle_brands'), ('vehicle_models'), ('vehicle_variants'), ('vehicles'),
            ('vehicle_status_history'), ('vehicle_reservations'), ('stock_ledger'), ('stock_transfers'),
            ('stock_transfer_items'), ('stock_adjustments'), ('stock_adjustment_items'),
            ('v_current_stock'), ('v_stock_ageing') $$,
  'tables: public contains exactly the Phase 3, 7, 8 and 9 tables/views (no others)'
);

-- -----------------------------------------------------------------------------
-- 2. Key columns (10)
-- -----------------------------------------------------------------------------
select col_not_null('public', 'showrooms', 'code', 'columns: showrooms.code is NOT NULL');
select col_not_null('public', 'showrooms', 'invoice_prefix', 'columns: showrooms.invoice_prefix is NOT NULL');
select col_not_null('public', 'profiles', 'full_name', 'columns: profiles.full_name is NOT NULL');
select col_not_null('public', 'user_roles', 'profile_id', 'columns: user_roles.profile_id is NOT NULL');
select col_not_null('public', 'user_roles', 'role_id', 'columns: user_roles.role_id is NOT NULL');
select col_not_null('public', 'document_sequences', 'prefix', 'columns: document_sequences.prefix is NOT NULL');
select col_not_null('public', 'financial_years', 'start_date', 'columns: financial_years.start_date is NOT NULL');
select col_not_null('public', 'financial_years', 'end_date', 'columns: financial_years.end_date is NOT NULL');

select col_is_null('public', 'user_roles', 'showroom_id',
  'columns: user_roles.showroom_id is nullable (NULL = global assignment)');

select set_eq(
  $$ select c.relname || '.' || a.attname || ' ' || tn.nspname || '.' || t.typname
       from pg_catalog.pg_attribute a
       join pg_catalog.pg_class c on c.oid = a.attrelid
       join pg_catalog.pg_type t on t.oid = a.atttypid
       join pg_catalog.pg_namespace tn on tn.oid = t.typnamespace
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p')
        and a.attnum > 0
        and not a.attisdropped
        and t.typname = 'citext' $$,
  $$ values ('profiles.email extensions.citext'), ('showrooms.email extensions.citext'),
            ('vehicle_brands.name extensions.citext'), ('vehicle_models.name extensions.citext'),
            ('vehicle_variants.name extensions.citext') $$,
  'columns: e-mails and catalogue names are extensions.citext (case-insensitive)'
);

-- -----------------------------------------------------------------------------
-- 3. Extensions (4)
-- -----------------------------------------------------------------------------
select is(
  (select n.nspname::text
     from pg_catalog.pg_extension e
     join pg_catalog.pg_namespace n on n.oid = e.extnamespace
    where e.extname = 'citext'),
  'extensions'::text,
  'extensions: citext is installed in schema extensions'
);

select is(
  (select n.nspname::text
     from pg_catalog.pg_extension e
     join pg_catalog.pg_namespace n on n.oid = e.extnamespace
    where e.extname = 'pg_trgm'),
  'extensions'::text,
  'extensions: pg_trgm is installed in schema extensions'
);

select is(
  (select n.nspname::text
     from pg_catalog.pg_extension e
     join pg_catalog.pg_namespace n on n.oid = e.extnamespace
    where e.extname = 'pgcrypto'),
  'extensions'::text,
  'extensions: pgcrypto is installed in schema extensions'
);

select is_empty(
  $$ select e.extname
       from pg_catalog.pg_extension e
      where e.extnamespace = 'public'::regnamespace $$,
  'extensions: no extension is installed into schema public'
);

-- -----------------------------------------------------------------------------
-- 4. Row level security (2)
-- -----------------------------------------------------------------------------
select is_empty(
  $$ select c.relname
       from pg_catalog.pg_class c
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p')
        and not c.relrowsecurity $$,
  'rls: row level security is enabled on every public table'
);

-- Phase 4 (0005): every public table has policies, and every policy targets
-- authenticated only (anon gets nothing, not even through PUBLIC).
select is_empty(
  $$ select c.relname
       from pg_catalog.pg_class c
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p')
        and not exists (select 1 from pg_catalog.pg_policies pp
                         where pp.schemaname = 'public' and pp.tablename = c.relname)
     union all
     select tablename || '.' || policyname
       from pg_catalog.pg_policies
      where schemaname = 'public' and roles <> '{authenticated}'::name[] $$,
  'rls: every public table has policies and every policy is TO authenticated'
);

-- -----------------------------------------------------------------------------
-- 5. Table privileges (5)
-- -----------------------------------------------------------------------------
-- has_*_privilege covers inherited grants; the aclexplode branch additionally
-- catches any privilege type (incl. PG17 MAINTAIN) granted to anon or PUBLIC.
select is_empty(
  $$ select c.relname::text as object, p.priv as privilege
       from pg_catalog.pg_class c
      cross join unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE',
                              'TRUNCATE', 'REFERENCES', 'TRIGGER']) as p (priv)
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p', 'v', 'm', 'f')
        and pg_catalog.has_table_privilege('anon', c.oid, p.priv)
     union all
     select c.relname::text, 'column privilege'
       from pg_catalog.pg_class c
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p', 'v', 'm', 'f')
        and pg_catalog.has_any_column_privilege('anon', c.oid, 'SELECT, INSERT, UPDATE, REFERENCES')
     union all
     select c.relname::text, a.privilege_type::text
       from pg_catalog.pg_class c
      cross join lateral pg_catalog.aclexplode(c.relacl) as a
      where c.relnamespace = 'public'::regnamespace
        and a.grantee in (0::oid, 'anon'::regrole::oid)
     union all
     select c.relname::text, 'sequence privilege'
       from pg_catalog.pg_class c
      where c.relnamespace = 'public'::regnamespace
        -- CASE: has_sequence_privilege() raises on non-sequences and WHERE
        -- clauses have no guaranteed evaluation order.
        and case when c.relkind = 'S'
                 then pg_catalog.has_sequence_privilege('anon', c.oid, 'USAGE, SELECT, UPDATE')
                 else false
            end $$,
  'privileges: anon holds no privilege at all on any public table, column or sequence'
);

-- TRUNCATE bypasses RLS; REFERENCES / TRIGGER are never needed by app users.
select is_empty(
  $$ select c.relname::text as object, p.priv as privilege
       from pg_catalog.pg_class c
      cross join unnest(array['TRUNCATE', 'REFERENCES', 'TRIGGER']) as p (priv)
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p', 'v', 'm', 'f')
        and pg_catalog.has_table_privilege('authenticated', c.oid, p.priv)
     union all
     select c.relname::text, 'REFERENCES (column)'
       from pg_catalog.pg_class c
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p', 'v', 'm', 'f')
        and pg_catalog.has_any_column_privilege('authenticated', c.oid, 'REFERENCES') $$,
  'privileges: authenticated has no TRUNCATE, REFERENCES or TRIGGER on any public table'
);

select is_empty(
  $$ select p.priv
       from unnest(array['INSERT', 'UPDATE', 'DELETE']) as p (priv)
      where pg_catalog.has_table_privilege('authenticated', 'public.permissions', p.priv)
     union all
     select 'INSERT/UPDATE (column)'
      where pg_catalog.has_any_column_privilege('authenticated', 'public.permissions', 'INSERT, UPDATE') $$,
  'privileges: authenticated cannot INSERT, UPDATE or DELETE permissions (migration-owned catalogue)'
);

select is_empty(
  $$ select p.priv
       from unnest(array['INSERT', 'UPDATE', 'DELETE']) as p (priv)
      where pg_catalog.has_table_privilege('authenticated', 'public.states', p.priv)
     union all
     select 'INSERT/UPDATE (column)'
      where pg_catalog.has_any_column_privilege('authenticated', 'public.states', 'INSERT, UPDATE') $$,
  'privileges: authenticated cannot INSERT, UPDATE or DELETE states (migration-owned reference data)'
);

select is_empty(
  $$ select p.priv
       from unnest(array['INSERT', 'UPDATE', 'DELETE']) as p (priv)
      where pg_catalog.has_table_privilege('authenticated', 'public.document_sequences', p.priv)
     union all
     select 'INSERT/UPDATE (column)'
      where pg_catalog.has_any_column_privilege('authenticated', 'public.document_sequences', 'INSERT, UPDATE') $$,
  'privileges: authenticated cannot INSERT, UPDATE or DELETE document_sequences (numbering is server-side only)'
);

-- -----------------------------------------------------------------------------
-- 6. Function privileges and search_path (6)
-- -----------------------------------------------------------------------------
select is_empty(
  $$ select p.oid::regprocedure::text
       from pg_catalog.pg_proc p
      where p.pronamespace = 'public'::regnamespace
        and pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE') $$,
  'functions: no public function is executable by anon'
);

-- A NULL proacl means the built-in default, i.e. EXECUTE for PUBLIC.
select is_empty(
  $$ select p.oid::regprocedure::text
       from pg_catalog.pg_proc p
      where p.pronamespace = 'public'::regnamespace
        and (p.proacl is null
             or exists (select 1
                          from pg_catalog.aclexplode(p.proacl) as a
                         where a.grantee = 0::oid
                           and a.privilege_type = 'EXECUTE')) $$,
  'functions: PUBLIC holds EXECUTE on no public function'
);

select set_eq(
  $$ select p.proname::text
       from pg_catalog.pg_proc p
      where p.pronamespace = 'public'::regnamespace
        and pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE') $$,
  $$ values ('fn_business_date'), ('fn_fy_start_date'), ('fn_fy_code'), ('fn_fy_short_code'),
            ('fn_is_gst_document'), ('fn_document_type_code'), ('current_profile_id'),
            ('is_active_user'), ('is_super_admin'), ('can_access_showroom'), ('accessible_showroom_ids'),
            ('has_permission_for'), ('has_permission'), ('can_view_profile'), ('fn_try_uuid'), ('rpc_get_my_session'),
            ('my_role_rank'), ('can_manage_user_in'), ('can_manage_user'), ('can_assign_role'), ('can_edit_role'),
            ('rpc_admin_update_user'), ('rpc_admin_set_user_status'), ('rpc_get_user_access'),
            ('rpc_grantable_roles'), ('rpc_create_showroom'),
            ('fn_normalize_identifier'), ('rpc_vehicle_identifier_conflicts'),
            ('rpc_receive_vehicle_stock'), ('rpc_reserve_vehicle'), ('rpc_release_reservation'),
            ('rpc_mark_vehicle_damaged'), ('rpc_create_stock_transfer'), ('rpc_receive_stock_transfer'),
            ('rpc_create_stock_adjustment') $$,
  'functions: authenticated can execute exactly the 35 granted helpers and RPCs'
);

select set_eq(
  $$ select p.proname::text
       from pg_catalog.pg_proc p
      where p.pronamespace = 'public'::regnamespace
        and p.prosecdef $$,
  $$ values ('fn_bootstrap_showroom'), ('fn_handle_new_auth_user'),
            ('fn_sync_auth_user_email'), ('current_profile_id'),
            ('is_active_user'), ('is_super_admin'), ('can_access_showroom'), ('accessible_showroom_ids'),
            ('has_permission_for'), ('has_permission'), ('can_view_profile'), ('rpc_get_my_session'),
            ('my_role_rank'), ('can_manage_user_in'), ('can_manage_user'), ('can_assign_role'), ('can_edit_role'),
            ('rpc_admin_update_user'), ('rpc_admin_set_user_status'), ('rpc_get_user_access'),
            ('fn_sync_auth_user_invited_by'), ('fn_showrooms_sync_prefix'), ('rpc_create_showroom'),
            ('rpc_vehicle_identifier_conflicts'), ('fn_stock_ledger_apply'), ('rpc_receive_vehicle_stock'),
            ('rpc_reserve_vehicle'), ('rpc_release_reservation'), ('rpc_mark_vehicle_damaged'),
            ('rpc_create_stock_transfer'), ('rpc_receive_stock_transfer'), ('rpc_create_stock_adjustment') $$,
  'functions: the SECURITY DEFINER functions are exactly the 32 reviewed ones'
);

select is_empty(
  $$ select p.oid::regprocedure::text, p.proconfig::text
       from pg_catalog.pg_proc p
      where p.pronamespace = 'public'::regnamespace
        and p.prosecdef
        and not ('search_path=""' = any (coalesce(p.proconfig, '{}'::text[]))) $$,
  'functions: every SECURITY DEFINER public function pins search_path = '''''
);

select is_empty(
  $$ select p.oid::regprocedure::text, p.proconfig::text
       from pg_catalog.pg_proc p
      where p.pronamespace = 'public'::regnamespace
        and not ('search_path=""' = any (coalesce(p.proconfig, '{}'::text[]))) $$,
  'functions: every public function pins search_path = '''' (MyBike convention)'
);

-- -----------------------------------------------------------------------------
-- 7. Comments (2)
-- -----------------------------------------------------------------------------
select is_empty(
  $$ select c.relname
       from pg_catalog.pg_class c
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p')
        and coalesce(btrim(pg_catalog.obj_description(c.oid, 'pg_class')), '') = '' $$,
  'comments: every public table has a comment'
);

select is_empty(
  $$ select p.oid::regprocedure::text
       from pg_catalog.pg_proc p
      where p.pronamespace = 'public'::regnamespace
        and coalesce(btrim(pg_catalog.obj_description(p.oid, 'pg_proc')), '') = '' $$,
  'comments: every public function has a comment'
);

-- -----------------------------------------------------------------------------
-- 8. Conventions (2)
-- -----------------------------------------------------------------------------
select is_empty(
  $$ select c.relname || '.' || a.attname || ' ' || pg_catalog.format_type(a.atttypid, a.atttypmod)
       from pg_catalog.pg_attribute a
       join pg_catalog.pg_class c on c.oid = a.attrelid
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p', 'v', 'm', 'f')
        and a.attnum > 0
        and not a.attisdropped
        and a.atttypid in ('real'::regtype, 'double precision'::regtype, 'money'::regtype,
                           'real[]'::regtype, 'double precision[]'::regtype, 'money[]'::regtype) $$,
  'conventions: no real, double precision or money column in public (amounts are numeric)'
);

select is_empty(
  $$ select c.relname
       from pg_catalog.pg_class c
      where c.relnamespace = 'public'::regnamespace
        and c.relkind in ('r', 'p')
        and not exists (select 1
                          from pg_catalog.pg_constraint k
                         where k.conrelid = c.oid
                           and k.contype = 'p') $$,
  'conventions: every public table has a primary key'
);

-- -----------------------------------------------------------------------------
-- Fixtures (as postgres, no JWT). The auth -> profile trigger creates the
-- profiles; the showroom bootstrap trigger adds settings + numbering series.
-- -----------------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-000000000000', 'b1000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 't01.case@example.test',
   '{"provider": "email", "providers": ["email"]}', '{"full_name": "Test Case One"}'),
  ('00000000-0000-0000-0000-000000000000', 'b1000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 't01.other@example.test',
   '{"provider": "email", "providers": ["email"]}', '{"full_name": "Test Other Three"}');

insert into public.showrooms (id, code, name, gstin, pan, state_code, pincode, invoice_prefix)
values ('5b000000-0000-4000-8000-000000000001', 'T-ALPHA', 'Test Alpha Showroom',
        '27TESTA1234T1Z9', 'TESTA1234T', '27', '411001', 'T1');

insert into public.user_showrooms (profile_id, showroom_id, is_default)
values ('b1000000-0000-4000-8000-000000000001', '5b000000-0000-4000-8000-000000000001', true);

-- -----------------------------------------------------------------------------
-- 9. Uniqueness (9)
-- -----------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.showrooms (code, name, invoice_prefix)
     values ('T-ALPHA', 'Test Duplicate Code', 'T3') $$,
  '23505',
  'duplicate key value violates unique constraint "showrooms_code_key"',
  'unique: showrooms.code'
);

select throws_ok(
  $$ insert into public.showrooms (code, name, invoice_prefix)
     values ('T-GAMMA', 'Test Duplicate Prefix', 'T1') $$,
  '23505',
  'duplicate key value violates unique constraint "showrooms_invoice_prefix_key"',
  'unique: showrooms.invoice_prefix'
);

select lives_ok(
  $$ insert into public.showrooms (id, code, name, gstin, pan, state_code, pincode, invoice_prefix)
     values ('5b000000-0000-4000-8000-000000000002', 'T-BETA', 'Test Beta Showroom',
             '27TESTA1234T1Z9', 'TESTA1234T', '27', '411002', 'T2') $$,
  'unique: showrooms.gstin is NOT unique (showrooms in one state share the company GSTIN)'
);

-- On Supabase the second insert passes GoTrue's (case-sensitive) e-mail index
-- and the profile trigger raises profiles_email_key; the local harness stub
-- indexes lower(email), so only the SQLSTATE is asserted here and the next
-- assertion pins the profiles constraint itself.
select throws_ok(
  $$ insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data)
     values ('00000000-0000-0000-0000-000000000000', 'b1000000-0000-4000-8000-000000000002',
             'authenticated', 'authenticated', 'T01.CASE@Example.TEST',
             '{"full_name": "Test Case Two"}') $$,
  '23505',
  null,
  'unique: a second auth user whose e-mail differs only in case is rejected (auth -> profile)'
);

select throws_ok(
  $$ update public.profiles
        set email = 'T01.Case@EXAMPLE.test'
      where id = 'b1000000-0000-4000-8000-000000000003' $$,
  '23505',
  'duplicate key value violates unique constraint "profiles_email_key"',
  'unique: profiles.email is case-insensitive (citext)'
);

select lives_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'b1000000-0000-4000-8000-000000000001'::uuid, r.id, s.showroom_id
       from public.roles r
      cross join (values ('5b000000-0000-4000-8000-000000000001'::uuid), (null::uuid)) as s (showroom_id)
      where r.code = 'ADMIN' $$,
  'unique: the same role may be assigned in a showroom and globally'
);

select throws_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'b1000000-0000-4000-8000-000000000001'::uuid, r.id, null::uuid
       from public.roles r
      where r.code = 'ADMIN' $$,
  '23505',
  'duplicate key value violates unique constraint "user_roles_assignment_key"',
  'unique: a duplicate GLOBAL role assignment is rejected (NULLS NOT DISTINCT)'
);

select lives_ok(
  $$ insert into public.user_showrooms (profile_id, showroom_id, is_default)
     values ('b1000000-0000-4000-8000-000000000001', '5b000000-0000-4000-8000-000000000002', false) $$,
  'unique: a user may have a further, non-default showroom'
);

select throws_ok(
  $$ update public.user_showrooms
        set is_default = true
      where profile_id = 'b1000000-0000-4000-8000-000000000001'
        and showroom_id = '5b000000-0000-4000-8000-000000000002' $$,
  '23505',
  'duplicate key value violates unique constraint "uq_user_showrooms_one_default"',
  'unique: a second default showroom for the same user is rejected'
);

-- -----------------------------------------------------------------------------
-- 10. CHECK constraints (11)
-- -----------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.showrooms (code, name, invoice_prefix)
     values ('t-lower', 'Test Lowercase Code', 'T4') $$,
  '23514',
  'new row for relation "showrooms" violates check constraint "showrooms_code_format"',
  'check: showroom code must be upper case'
);

select throws_ok(
  $$ insert into public.showrooms (code, name, invoice_prefix)
     values ('T-PFX4', 'Test Long Prefix', 'T444') $$,
  '23514',
  'new row for relation "showrooms" violates check constraint "showrooms_invoice_prefix_format"',
  'check: invoice_prefix is 2-3 characters (4 rejected, keeps GST numbers within 16 characters)'
);

select throws_ok(
  $$ insert into public.showrooms (code, name, gstin, pan, state_code, invoice_prefix)
     values ('T-GSTIN', 'Test Bad GSTIN', '27TESTA1234T1Y9', 'TESTA1234T', '27', 'T5') $$,
  '23514',
  'new row for relation "showrooms" violates check constraint "showrooms_gstin_format"',
  'check: GSTIN format (14th character must be Z)'
);

select throws_ok(
  $$ insert into public.showrooms (code, name, gstin, pan, state_code, invoice_prefix)
     values ('T-STATE', 'Test GSTIN State', '27TESTA1234T1Z9', 'TESTA1234T', '23', 'T6') $$,
  '23514',
  'new row for relation "showrooms" violates check constraint "showrooms_gstin_matches_state"',
  'check: GSTIN state code must equal showrooms.state_code'
);

select throws_ok(
  $$ insert into public.showrooms (code, name, gstin, pan, state_code, invoice_prefix)
     values ('T-PAN', 'Test GSTIN PAN', '27TESTA1234T1Z9', 'TESTB1234T', '27', 'T7') $$,
  '23514',
  'new row for relation "showrooms" violates check constraint "showrooms_gstin_matches_pan"',
  'check: GSTIN characters 3-12 must equal showrooms.pan'
);

select throws_ok(
  $$ insert into public.showrooms (code, name, pincode, invoice_prefix)
     values ('T-PIN', 'Test Pincode', '012345', 'T8') $$,
  '23514',
  'new row for relation "showrooms" violates check constraint "showrooms_pincode_format"',
  'check: pincode cannot start with 0'
);

select throws_ok(
  $$ insert into public.financial_years (code, start_date, end_date)
     values ('2031-32', '2031-05-01', '2032-04-30') $$,
  '23514',
  'new row for relation "financial_years" violates check constraint "financial_years_april_to_march"',
  'check: a financial year runs 1 April - 31 March'
);

select throws_ok(
  $$ insert into public.financial_years (code, start_date, end_date)
     values ('2032-33', '2031-04-01', '2032-03-31') $$,
  '23514',
  'new row for relation "financial_years" violates check constraint "financial_years_code_matches_dates"',
  'check: financial year code must equal fn_fy_code(start_date)'
);

select throws_ok(
  $$ insert into public.settings (key, value, value_type)
     values ('test.flag', '"yes"', 'boolean') $$,
  '23514',
  'new row for relation "settings" violates check constraint "settings_value_matches_type"',
  'check: settings.value must match value_type (a JSON string is not a boolean)'
);

select throws_ok(
  $$ insert into public.permissions (module, action)
     values ('sales', 'view_all') $$,
  '23514',
  'new row for relation "permissions" violates check constraint "permissions_view_all_showrooms_only"',
  'check: view_all exists only for the showrooms module'
);

select throws_ok(
  $$ insert into public.roles (code, name, precedence)
     values ('test_role', 'Test Role', 20) $$,
  '23514',
  'new row for relation "roles" violates check constraint "roles_code_format"',
  'check: role code must be upper case'
);

-- -----------------------------------------------------------------------------
-- 11. Behaviour as the API roles (10)
-- -----------------------------------------------------------------------------
-- Precondition: the 0-row results below must come from RLS, not empty tables.
select is_empty(
  $$ select 'states' where not exists (select 1 from public.states)
     union all select 'showrooms' where not exists (select 1 from public.showrooms)
     union all select 'showroom_settings' where not exists (select 1 from public.showroom_settings)
     union all select 'settings' where not exists (select 1 from public.settings)
     union all select 'financial_years' where not exists (select 1 from public.financial_years)
     union all select 'accounting_periods' where not exists (select 1 from public.accounting_periods)
     union all select 'document_sequences' where not exists (select 1 from public.document_sequences)
     union all select 'profiles' where not exists (select 1 from public.profiles)
     union all select 'roles' where not exists (select 1 from public.roles)
     union all select 'permissions' where not exists (select 1 from public.permissions)
     union all select 'role_permissions' where not exists (select 1 from public.role_permissions)
     union all select 'user_roles' where not exists (select 1 from public.user_roles)
     union all select 'user_showrooms' where not exists (select 1 from public.user_showrooms) $$,
  'behaviour: as postgres every Phase 3 table holds rows'
);

-- authenticated with a valid JWT whose user has no profile (e.g. an auth user
-- created outside the app): every policy fails closed.
select set_config('request.jwt.claims',
  '{"sub":"0badbeef-0000-4000-8000-000000000000","role":"authenticated"}', true);
set local role authenticated;

select is_empty(
  $$ select 'states' as visible_in from public.states
     union all select 'showrooms' from public.showrooms
     union all select 'showroom_settings' from public.showroom_settings
     union all select 'settings' from public.settings
     union all select 'financial_years' from public.financial_years
     union all select 'accounting_periods' from public.accounting_periods
     union all select 'document_sequences' from public.document_sequences
     union all select 'profiles' from public.profiles
     union all select 'roles' from public.roles
     union all select 'permissions' from public.permissions
     union all select 'role_permissions' from public.role_permissions
     union all select 'user_roles' from public.user_roles
     union all select 'user_showrooms' from public.user_showrooms $$,
  'behaviour: a JWT without a profile reads 0 rows from every Phase 3 table'
);

select throws_ok(
  $$ insert into public.settings (key, value, value_type)
     values ('test.rls_probe', '"x"', 'string') $$,
  '42501',
  'new row violates row-level security policy for table "settings"',
  'behaviour: a JWT without a profile cannot INSERT into settings'
);

select throws_ok(
  $$ insert into public.states (code, name)
     values ('99', 'Test State') $$,
  '42501',
  'permission denied for table states',
  'behaviour: authenticated INSERT into states is refused by privileges'
);

select is(
  public.fn_fy_code('2026-09-23'::date),
  '2026-27'::text,
  'behaviour: authenticated may call the granted helper fn_fy_code()'
);

select throws_ok(
  $$ select public.fn_next_document_number('5b000000-0000-4000-8000-000000000001', 'sales_invoice', '2026-09-23') $$,
  '42501',
  'permission denied for function fn_next_document_number',
  'behaviour: authenticated cannot call fn_next_document_number() (server-side only)'
);

-- current_profile_id() is SECURITY DEFINER, so it resolves the caller's own
-- profile even under deny-all RLS.
select set_config('request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

select is(
  public.current_profile_id(),
  'b1000000-0000-4000-8000-000000000001'::uuid,
  'behaviour: current_profile_id() returns the caller''s own profile id under deny-all RLS'
);

select set_config('request.jwt.claims',
  '{"sub":"b1000000-0000-4000-8000-0000000000ff","role":"authenticated"}', true);

select is(
  public.current_profile_id(),
  null::uuid,
  'behaviour: current_profile_id() is NULL for a JWT without a profile'
);

reset role;

-- anon: no privilege at all.
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

select throws_ok(
  $$ select id from public.profiles $$,
  '42501',
  'permission denied for table profiles',
  'behaviour: anon SELECT from profiles is refused by privileges'
);

select throws_ok(
  $$ select public.current_profile_id() $$,
  '42501',
  'permission denied for function current_profile_id',
  'behaviour: anon cannot call current_profile_id()'
);

reset role;

select * from finish();

rollback;
