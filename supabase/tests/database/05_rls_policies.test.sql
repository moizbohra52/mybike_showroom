-- =============================================================================
-- 05 — Phase 4 RBAC helpers + RLS policies (migration 0005)
-- -----------------------------------------------------------------------------
-- Uses the dev seed fixtures (supabase/seed.sql header). Covers:
--   A. helper functions per user type                                  (21)
--   B. showroom isolation: user A cannot read / change showroom B
--      (docs/phase-00/04-multishowroom-security.md S1, S2, S3, S6, S7) (15)
--   C. profiles, role / showroom assignments, role matrix, roles
--      (self-service columns, no self-escalation, global-only admin)  (16)
--   D. settings and financial years                                    (6)
--   E. deactivated showroom, expired role, revoked assignment          (7)
--   F. anon                                                            (2)
-- Plan: 67 assertions
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select plan(67);

-- Fixtures (supabase/seed.sql):
--   showrooms IND 5a…001, BPL 5a…002, UJN 5a…003
--   users 001 superadmin · 002 admin (global, IND/BPL/UJN) · 003 manager IND ·
--         006 sales exec IND · 009 accountant IND+BPL · 010 cashier IND ·
--         012 viewer UJN · 013 inactive (IND) · 014 norole

-- -----------------------------------------------------------------------------
-- A. Helper functions
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;

select is(public.is_active_user(), true, 'helpers: showroom manager is an active user');
select is(public.is_super_admin(), false, 'helpers: showroom manager is not super admin');
select is(public.can_access_showroom('5a000000-0000-4000-8000-000000000001'), true,
  'helpers: showroom manager can access own showroom (IND)');
select is(public.can_access_showroom('5a000000-0000-4000-8000-000000000002'), false,
  'helpers: showroom manager cannot access another showroom (BPL)');
select is(public.accessible_showroom_ids(), array['5a000000-0000-4000-8000-000000000001']::uuid[],
  'helpers: showroom manager''s accessible showrooms = {IND}');
select is(public.has_permission_for('customers', 'create', '5a000000-0000-4000-8000-000000000001'), true,
  'helpers: scoped role grants customers.create in its showroom');
select is(public.has_permission_for('customers', 'create', '5a000000-0000-4000-8000-000000000002'), false,
  'helpers: scoped role grants nothing in another showroom');
select is(public.has_permission_for('users', 'view', null), false,
  'helpers: a showroom-scoped role never counts as a global grant');
select is(public.has_permission('sales', 'approve'), true,
  'helpers: has_permission sees the scoped sales.approve grant');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is(public.is_super_admin(), true, 'helpers: seeded owner is super admin');
select is(public.accessible_showroom_ids(),
  array['5a000000-0000-4000-8000-000000000002', '5a000000-0000-4000-8000-000000000001',
        '5a000000-0000-4000-8000-000000000003']::uuid[],
  'helpers: super admin accesses every showroom (ordered by code)');
select is(public.has_permission_for('showrooms', 'view_all', null), true,
  'helpers: super admin holds ALL SHOWROOMS (showrooms.view_all)');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000009","role":"authenticated"}', true);
select is(public.accessible_showroom_ids(),
  array['5a000000-0000-4000-8000-000000000002', '5a000000-0000-4000-8000-000000000001']::uuid[],
  'helpers: multi-showroom accountant accesses BPL and IND');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000012","role":"authenticated"}', true);
select is(public.has_permission('sales', 'create'), false, 'helpers: viewer has no sales.create');
select is(public.has_permission('sales', 'view'), true, 'helpers: viewer has sales.view');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000013","role":"authenticated"}', true);
select is(public.is_active_user(), false, 'helpers: deactivated user is not active');
select is(public.can_access_showroom('5a000000-0000-4000-8000-000000000001'), false,
  'helpers: deactivated user cannot access even an assigned showroom');
select is(public.has_permission('sales', 'view'), false, 'helpers: deactivated user has no permission');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000014","role":"authenticated"}', true);
select is(public.is_active_user(), true, 'helpers: user without roles is still an active user');
select is(public.accessible_showroom_ids(), '{}'::uuid[], 'helpers: user without assignments accesses no showroom');
select is(public.has_permission('dashboard', 'view'), false, 'helpers: user without roles has no permission (fail closed)');

-- -----------------------------------------------------------------------------
-- B. Showroom isolation
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);

select set_eq($$ select code from public.showrooms $$, $$ values ('INDORE-MAIN') $$,
  'isolation (S1): showroom manager IND sees only showroom IND');
select is_empty($$ select 1 from public.showrooms where id = '5a000000-0000-4000-8000-000000000002' $$,
  'isolation (S2): explicitly requesting showroom BPL returns nothing');
select set_eq($$ select showroom_id from public.showroom_settings $$,
  $$ values ('5a000000-0000-4000-8000-000000000001'::uuid) $$,
  'isolation: showroom_settings of IND only');
select set_eq($$ select distinct showroom_id from public.document_sequences $$,
  $$ values ('5a000000-0000-4000-8000-000000000001'::uuid) $$,
  'isolation: numbering series of IND only');
select results_eq($$ with u as (update public.showrooms set name = 'Hacked' where id = '5a000000-0000-4000-8000-000000000002' returning 1)
           select count(*)::int from u $$, $$ values (0) $$,
  'isolation (S3): updating showroom BPL affects no row');
select results_eq($$ with u as (update public.showrooms set name = 'Renamed' where id = '5a000000-0000-4000-8000-000000000001' returning 1)
           select count(*)::int from u $$, $$ values (0) $$,
  'permissions: showroom manager (showrooms: V) cannot edit even own showroom');
select throws_ok(
  $$ insert into public.showrooms (code, name, invoice_prefix) values ('T-X', 'Test Showroom', 'TX') $$,
  '42501', null,
  'permissions (S6): showroom manager cannot create a showroom');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select results_eq($$ with u as (update public.showrooms set name = 'Bhopal Showroom (Main Road)'
                       where id = '5a000000-0000-4000-8000-000000000002' returning 1)
           select count(*)::int from u $$, $$ values (1) $$,
  'permissions: admin (global showrooms.edit, assigned BPL) edits showroom BPL');
select results_eq($$ with u as (update public.showroom_settings set booking_validity_days = 45
                       where showroom_id = '5a000000-0000-4000-8000-000000000002' returning 1)
           select count(*)::int from u $$, $$ values (1) $$,
  'permissions: admin edits showroom BPL settings');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000006","role":"authenticated"}', true);
select set_eq($$ select code from public.showrooms $$, $$ values ('INDORE-MAIN') $$,
  'isolation: sales executive sees the showroom they work in');
select is_empty($$ select 1 from public.document_sequences $$,
  'permissions: sales executive (no showrooms.view) sees no numbering series');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000013","role":"authenticated"}', true);
select is_empty($$ select 1 from public.showrooms $$, 'deactivated (S7): sees no showroom');
select is((select count(*)::int from public.profiles), 1, 'deactivated (S7): sees only own profile');
select is_empty($$ select 1 from public.roles $$, 'deactivated (S7): sees no roles');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select count(*)::int from public.showrooms), 3, 'super admin sees all 3 showrooms');

-- -----------------------------------------------------------------------------
-- C. Profiles, assignments, roles
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select set_eq($$ select id from public.profiles $$,
  $$ values ('a0000000-0000-4000-8000-000000000002'::uuid), ('a0000000-0000-4000-8000-000000000003'::uuid),
            ('a0000000-0000-4000-8000-000000000005'::uuid), ('a0000000-0000-4000-8000-000000000006'::uuid),
            ('a0000000-0000-4000-8000-000000000009'::uuid), ('a0000000-0000-4000-8000-000000000010'::uuid),
            ('a0000000-0000-4000-8000-000000000013'::uuid) $$,
  'profiles: showroom manager sees exactly the users assigned to IND');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000006","role":"authenticated"}', true);
select set_eq($$ select id from public.profiles $$, $$ values ('a0000000-0000-4000-8000-000000000006'::uuid) $$,
  'profiles: sales executive (no users.view) sees only own profile');
select results_eq($$ with u as (update public.profiles set full_name = 'Imran K.'
                       where id = 'a0000000-0000-4000-8000-000000000006' returning 1)
           select count(*)::int from u $$, $$ values (1) $$,
  'profiles: a user can edit own full_name');
select throws_ok(
  $$ update public.profiles set status = 'suspended' where id = 'a0000000-0000-4000-8000-000000000006' $$,
  '42501', 'permission denied for table profiles',
  'profiles: a user cannot change own status (column privilege)');
select results_eq($$ with u as (update public.profiles set full_name = 'X'
                       where id = 'a0000000-0000-4000-8000-000000000003' returning 1)
           select count(*)::int from u $$, $$ values (0) $$,
  'profiles: a user cannot edit someone else''s profile');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is((select count(*)::int from public.profiles), 14, 'profiles: admin (global users.view) sees all 14 profiles');
select throws_ok(
  $$ insert into public.user_roles (profile_id, role_id)
     select 'a0000000-0000-4000-8000-000000000006', r.id from public.roles r where r.code = 'ADMIN' $$,
  '42501', null,
  'escalation: admin cannot grant a role of its own rank (ADMIN)');
select lives_ok(
  $$ insert into public.user_showrooms (profile_id, showroom_id)
     values ('a0000000-0000-4000-8000-000000000006', '5a000000-0000-4000-8000-000000000002') $$,
  'assignments: admin (global users.edit) assigns a showroom to another user');
select results_eq($$ with d as (delete from public.user_showrooms
                       where profile_id = 'a0000000-0000-4000-8000-000000000002' returning 1)
           select count(*)::int from d $$, $$ values (0) $$,
  'escalation: admin cannot change own showroom assignments');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select throws_ok(
  $$ insert into public.user_showrooms (profile_id, showroom_id)
     values ('a0000000-0000-4000-8000-000000000014', '5a000000-0000-4000-8000-000000000001') $$,
  '42501', null,
  'assignments: a showroom manager cannot claim a user it did not create');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok(
  $$ insert into public.user_roles (profile_id, role_id)
     select 'a0000000-0000-4000-8000-000000000014', r.id from public.roles r where r.code = 'VIEWER' $$,
  'assignments: super admin assigns a role to another user');
select throws_ok(
  $$ insert into public.user_roles (profile_id, role_id)
     select 'a0000000-0000-4000-8000-000000000001', r.id from public.roles r where r.code = 'ADMIN' $$,
  '42501', null,
  'escalation: even super admin cannot change own role assignments');
select lives_ok(
  $$ insert into public.role_permissions (role_id, permission_id)
     select r.id, p.id from public.roles r, public.permissions p
      where r.code = 'VIEWER' and p.code = 'dashboard.print' $$,
  'matrix: super admin (global roles.edit) edits the role matrix');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok(
  $$ insert into public.role_permissions (role_id, permission_id)
     select r.id, p.id from public.roles r, public.permissions p
      where r.code = 'ADMIN' and p.code = 'roles.create' $$,
  '42501', null,
  'escalation: admin cannot grant its own role new permissions');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000012","role":"authenticated"}', true);
select is((select count(*)::int from public.roles), 11, 'roles: active users read the role list');
select throws_ok(
  $$ insert into public.roles (code, name, precedence) values ('T_ROLE', 'Test Role', 5) $$,
  '42501', null,
  'roles: viewer cannot create roles');

-- -----------------------------------------------------------------------------
-- D. Settings and financial years
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000006","role":"authenticated"}', true);
select set_eq($$ select key from public.settings $$,
  $$ values ('company.name'), ('company.currency_code'), ('company.locale'), ('company.timezone'),
            ('ui.default_theme_mode') $$,
  'settings: without settings.view only client-readable settings are visible');
select results_eq($$ with u as (update public.settings set value = '"X"' where key = 'company.name' returning 1)
           select count(*)::int from u $$, $$ values (0) $$,
  'settings: sales executive cannot change company settings');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is((select count(*)::int from public.settings), 6, 'settings: admin (global settings.view) sees all settings');
select results_eq($$ with u as (update public.settings set value = '"MyBike Motors"' where key = 'company.name' returning 1)
           select count(*)::int from u $$, $$ values (1) $$,
  'settings: admin (global settings.edit) changes a company setting');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000014","role":"authenticated"}', true);
select ok((select count(*) from public.financial_years) > 0, 'financial years: readable by any active user');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000013","role":"authenticated"}', true);
select is_empty($$ select 1 from public.financial_years $$, 'financial years: not readable by a deactivated user');

-- -----------------------------------------------------------------------------
-- E. Deactivated showroom, expired role, revoked assignment
-- -----------------------------------------------------------------------------
reset role;
update public.showrooms set is_active = false where id = '5a000000-0000-4000-8000-000000000003';
update public.user_roles set expires_on = public.fn_business_date() - 1
 where profile_id = 'a0000000-0000-4000-8000-000000000009'
   and showroom_id = '5a000000-0000-4000-8000-000000000001';
update public.user_showrooms set is_active = false
 where profile_id = 'a0000000-0000-4000-8000-000000000002'
   and showroom_id = '5a000000-0000-4000-8000-000000000002';
set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000012","role":"authenticated"}', true);
select is(public.can_access_showroom('5a000000-0000-4000-8000-000000000003'), false,
  'deactivated showroom: its users lose access');
select is(public.has_permission('sales', 'view'), false,
  'deactivated showroom: a role scoped to it grants nothing');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is(public.can_access_showroom('5a000000-0000-4000-8000-000000000003'), true,
  'deactivated showroom: super admin still reaches it (history)');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000009","role":"authenticated"}', true);
select is(public.has_permission_for('accounting', 'view', '5a000000-0000-4000-8000-000000000001'), false,
  'expired role: the accountant''s expired IND assignment grants nothing');
select is(public.has_permission_for('accounting', 'view', '5a000000-0000-4000-8000-000000000002'), true,
  'expired role: the still-valid BPL assignment keeps working');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is(public.can_access_showroom('5a000000-0000-4000-8000-000000000002'), false,
  'revoked assignment: a global admin needs an active showroom assignment');
select is(public.has_permission_for('customers', 'view', '5a000000-0000-4000-8000-000000000002'), false,
  'revoked assignment: global roles grant nothing in an inaccessible showroom');

-- -----------------------------------------------------------------------------
-- F. anon
-- -----------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$ select 1 from public.showrooms $$, '42501', null, 'anon: no access to showrooms');
select throws_ok($$ select public.is_active_user() $$, '42501', null, 'anon: cannot call RBAC helpers');
reset role;

select * from finish();
rollback;
