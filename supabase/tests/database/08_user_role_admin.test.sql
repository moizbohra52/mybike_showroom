-- =============================================================================
-- 08 — Phase 6 user, role and permission administration (migration 0008)
-- -----------------------------------------------------------------------------
-- Uses the dev seed fixtures (supabase/seed.sql header):
--   showrooms IND 5a…001, BPL 5a…002, UJN 5a…003
--   users 001 superadmin · 002 admin (global) · 003 manager IND · 004 manager BPL ·
--         005 sales manager IND · 006 sales exec IND · 009 accountant IND+BPL ·
--         010 cashier IND · 012 viewer UJN · 013 inactive · 014 norole
--   A. rank and delegation helpers                                   (20)
--   B. rpc_get_user_access, rpc_grantable_roles                      (10)
--   C. showroom manager: roles, showrooms, status, profile           (21)
--   D. restricted roles: viewer, cashier, sales executive, sales mgr  (9)
--   E. onboarding: creator and claim prevention                       (8)
--   F. roles and the role matrix                                     (12)
-- Plan: 80 assertions
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select plan(80);

-- -----------------------------------------------------------------------------
-- A. Rank and delegation helpers
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;

select is(public.my_role_rank('5a000000-0000-4000-8000-000000000001'), 80,
  'rank: showroom manager ranks 80 in own showroom');
select is(public.my_role_rank(null), -1, 'rank: showroom manager has no global rank');
select is(public.can_manage_user_in('a0000000-0000-4000-8000-000000000006', '5a000000-0000-4000-8000-000000000001'), true,
  'delegation: manager manages a sales executive in own showroom');
select is(public.can_manage_user_in('a0000000-0000-4000-8000-000000000002', '5a000000-0000-4000-8000-000000000001'), false,
  'delegation: manager cannot manage the admin (higher rank)');
select is(public.can_manage_user_in('a0000000-0000-4000-8000-000000000009', '5a000000-0000-4000-8000-000000000001'), true,
  'delegation: manager manages the shared accountant inside own showroom');
select is(public.can_manage_user('a0000000-0000-4000-8000-000000000009'), false,
  'delegation: manager cannot make changes that reach the accountant''s other showroom');
select is(public.can_manage_user('a0000000-0000-4000-8000-000000000006'), true,
  'delegation: manager fully manages a single-showroom executive');
select is(public.can_manage_user('a0000000-0000-4000-8000-000000000003'), false,
  'delegation: nobody manages themselves');
select is(public.can_assign_role((select id from public.roles where code = 'SALES_EXECUTIVE'),
                                 '5a000000-0000-4000-8000-000000000001'), true,
  'grant: manager can grant a lower role in own showroom');
select is(public.can_assign_role((select id from public.roles where code = 'SHOWROOM_MANAGER'),
                                 '5a000000-0000-4000-8000-000000000001'), false,
  'grant: manager cannot grant its own rank');
select is(public.can_assign_role((select id from public.roles where code = 'SALES_EXECUTIVE'),
                                 '5a000000-0000-4000-8000-000000000002'), false,
  'grant: manager cannot grant in another showroom');
select is(public.can_assign_role((select id from public.roles where code = 'VIEWER'), null), false,
  'grant: a showroom-scoped manager cannot grant global roles');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is(public.my_role_rank(null), 90, 'rank: admin ranks 90 globally');
select is(public.can_manage_user('a0000000-0000-4000-8000-000000000001'), false,
  'delegation: admin cannot manage the super admin');
select is(public.can_manage_user('a0000000-0000-4000-8000-000000000009'), true,
  'delegation: admin manages the multi-showroom accountant');
select is(public.can_assign_role((select id from public.roles where code = 'SHOWROOM_MANAGER'), null), true,
  'grant: admin can grant a lower role globally');
select is(public.can_assign_role((select id from public.roles where code = 'SUPER_ADMIN'), null), false,
  'grant: admin cannot grant SUPER_ADMIN');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000005","role":"authenticated"}', true);
select is(public.can_manage_user_in('a0000000-0000-4000-8000-000000000006', '5a000000-0000-4000-8000-000000000001'), false,
  'delegation: users.view alone (sales manager) manages nobody');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000013","role":"authenticated"}', true);
select is(public.my_role_rank('5a000000-0000-4000-8000-000000000001'), -1, 'rank: a deactivated user has no rank');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is(public.can_manage_user('a0000000-0000-4000-8000-000000000002'), true,
  'delegation: super admin manages the admin');

-- -----------------------------------------------------------------------------
-- B. rpc_get_user_access
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select results_eq(
  $$ select jsonb_array_length(a -> 'showrooms'), a -> 'showrooms' -> 0 ->> 'id',
            (a ->> 'hidden_showroom_count')::int, (a ->> 'can_manage')::boolean
       from (select public.rpc_get_user_access('a0000000-0000-4000-8000-000000000009') as a) s $$,
  $$ values (1, '5a000000-0000-4000-8000-000000000001'::text, 1, false) $$,
  'access rpc: manager sees only its own showroom of the accountant; the other is counted, not shown');
select is((public.rpc_get_user_access('a0000000-0000-4000-8000-000000000009') -> 'showrooms' -> 0 ->> 'can_manage')::boolean,
  true, 'access rpc: manager may change the accountant''s roles in its own showroom');
select set_eq(
  $$ select jsonb_array_elements(public.rpc_get_user_access('a0000000-0000-4000-8000-000000000006')
                                   -> 'showrooms' -> 0 -> 'grantable_roles') ->> 'code' $$,
  $$ values ('SALES_MANAGER'), ('PURCHASE_MANAGER'), ('INVENTORY_MANAGER'), ('ACCOUNTANT'),
            ('SERVICE_MANAGER'), ('CASHIER'), ('VIEWER') $$,
  'access rpc: grantable roles rank below the manager and exclude roles already held');
select is(jsonb_array_length(public.rpc_get_user_access('a0000000-0000-4000-8000-000000000006')
                               -> 'global' -> 'grantable_roles'), 0,
  'access rpc: a showroom-scoped manager is offered no global roles');
select set_eq(
  $$ select code from public.rpc_grantable_roles('5a000000-0000-4000-8000-000000000001') $$,
  $$ values ('SALES_MANAGER'), ('PURCHASE_MANAGER'), ('INVENTORY_MANAGER'), ('ACCOUNTANT'),
            ('SERVICE_MANAGER'), ('SALES_EXECUTIVE'), ('CASHIER'), ('VIEWER') $$,
  'grantable roles: a manager may grant every role below its rank in its showroom');
select is_empty($$ select 1 from public.rpc_grantable_roles('5a000000-0000-4000-8000-000000000002') $$,
  'grantable roles: nothing in a showroom the manager does not run');
select is(public.rpc_get_user_access('a0000000-0000-4000-8000-000000000004'), null,
  'access rpc: a user outside the caller''s showrooms is not returned');
select results_eq(
  $$ select (a ->> 'is_self')::boolean, (a ->> 'can_manage')::boolean
       from (select public.rpc_get_user_access('a0000000-0000-4000-8000-000000000003') as a) s $$,
  $$ values (true, false) $$,
  'access rpc: own record is readable but never manageable');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select set_eq(
  $$ select jsonb_array_elements(public.rpc_get_user_access('a0000000-0000-4000-8000-000000000006')
                                   -> 'addable_showrooms') ->> 'id' $$,
  $$ values ('5a000000-0000-4000-8000-000000000002'), ('5a000000-0000-4000-8000-000000000003') $$,
  'access rpc: admin is offered the showrooms the executive is not in yet');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000010","role":"authenticated"}', true);
select is(public.rpc_get_user_access('a0000000-0000-4000-8000-000000000006'), null,
  'access rpc: without users.view other users are not returned');

-- -----------------------------------------------------------------------------
-- C. Showroom manager
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select lives_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'a0000000-0000-4000-8000-000000000006', r.id, '5a000000-0000-4000-8000-000000000001'
       from public.roles r where r.code = 'CASHIER' $$,
  'manager: grants CASHIER to an executive in own showroom');
select throws_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'a0000000-0000-4000-8000-000000000006', r.id, '5a000000-0000-4000-8000-000000000001'
       from public.roles r where r.code = 'SHOWROOM_MANAGER' $$,
  '42501', null,
  'escalation: manager cannot grant its own rank (SHOWROOM_MANAGER)');
select throws_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'a0000000-0000-4000-8000-000000000009', r.id, '5a000000-0000-4000-8000-000000000002'
       from public.roles r where r.code = 'SALES_EXECUTIVE' $$,
  '42501', null,
  'isolation: manager cannot grant roles in another showroom');
select throws_ok(
  $$ insert into public.user_roles (profile_id, role_id)
     select 'a0000000-0000-4000-8000-000000000006', r.id from public.roles r where r.code = 'VIEWER' $$,
  '42501', null,
  'escalation: manager cannot grant global roles');
select results_eq(
  $$ with d as (delete from public.user_roles ur using public.roles r
                 where r.id = ur.role_id and r.code = 'CASHIER'
                   and ur.profile_id = 'a0000000-0000-4000-8000-000000000006' returning 1)
     select count(*)::int from d $$,
  $$ values (1) $$,
  'manager: revokes a role in own showroom');
select results_eq(
  $$ with d as (delete from public.user_roles
                 where profile_id = 'a0000000-0000-4000-8000-000000000002' returning 1)
     select count(*)::int from d $$,
  $$ values (0) $$,
  'escalation: manager cannot revoke the admin''s roles');
select results_eq(
  $$ with d as (delete from public.user_showrooms
                 where profile_id = 'a0000000-0000-4000-8000-000000000009'
                   and showroom_id = '5a000000-0000-4000-8000-000000000002' returning 1)
     select count(*)::int from d $$,
  $$ values (0) $$,
  'isolation: manager cannot remove a membership in another showroom');
select throws_ok(
  $$ update public.user_roles set expires_on = '2030-03-31'
      where profile_id = 'a0000000-0000-4000-8000-000000000006' $$,
  '42501', null,
  'assignments: role assignments are never edited in place (no UPDATE privilege)');
select throws_ok(
  $$ select public.rpc_admin_set_user_status('a0000000-0000-4000-8000-000000000002', 'deactivated') $$,
  '42501', null,
  'escalation: manager cannot deactivate the admin');
select throws_ok(
  $$ select public.rpc_admin_set_user_status('a0000000-0000-4000-8000-000000000003', 'deactivated') $$,
  '42501', null,
  'escalation: nobody deactivates themselves');
select throws_ok(
  $$ select public.rpc_admin_set_user_status('a0000000-0000-4000-8000-000000000009', 'deactivated') $$,
  '42501', null,
  'isolation: manager cannot deactivate staff shared with another showroom');
select throws_ok(
  $$ select public.rpc_admin_set_user_status('a0000000-0000-4000-8000-000000000006', 'invited') $$,
  '22023', null,
  'status: invited is not a status an administrator sets');
select lives_ok(
  $$ select public.rpc_admin_update_user('a0000000-0000-4000-8000-000000000006', ' Imran Khan ',
                                         '+919800000006', 'Senior Sales Executive', 'ind-se-99') $$,
  'manager: updates an executive''s profile');
select results_eq(
  $$ select full_name, designation, employee_code from public.profiles
      where id = 'a0000000-0000-4000-8000-000000000006' $$,
  $$ values ('Imran Khan'::text, 'Senior Sales Executive'::text, 'IND-SE-99'::text) $$,
  'profile: fields are trimmed and the employee code upper-cased');
select lives_ok(
  $$ select public.rpc_admin_set_user_status('a0000000-0000-4000-8000-000000000006', 'deactivated') $$,
  'manager: deactivates an executive');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000006","role":"authenticated"}', true);
select is(public.has_permission('sales', 'view'), false,
  'deactivation: the executive''s live session loses every permission');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select lives_ok(
  $$ select public.rpc_admin_set_user_status('a0000000-0000-4000-8000-000000000006', 'active') $$,
  'manager: reactivates the executive');
select results_eq(
  $$ with d as (delete from public.user_showrooms
                 where profile_id = 'a0000000-0000-4000-8000-000000000009'
                   and showroom_id = '5a000000-0000-4000-8000-000000000001' returning 1)
     select count(*)::int from d $$,
  $$ values (1) $$,
  'manager: removes the shared accountant from own showroom');

reset role;
select is_empty(
  $$ select 1 from public.user_roles
      where profile_id = 'a0000000-0000-4000-8000-000000000009'
        and showroom_id = '5a000000-0000-4000-8000-000000000001' $$,
  'assignments: removing a showroom removes the user''s roles there');
set local role authenticated;

select throws_ok(
  $$ insert into public.user_showrooms (profile_id, showroom_id)
     values ('a0000000-0000-4000-8000-000000000009', '5a000000-0000-4000-8000-000000000001') $$,
  '42501', null,
  'claim: manager cannot re-add staff who work in another showroom');
select throws_ok(
  $$ insert into public.user_showrooms (profile_id, showroom_id)
     values ('a0000000-0000-4000-8000-000000000003', '5a000000-0000-4000-8000-000000000002') $$,
  '42501', null,
  'escalation: manager cannot add a showroom to itself');

-- -----------------------------------------------------------------------------
-- D. Restricted roles (Viewer, Cashier, Sales Executive, Sales Manager)
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000012","role":"authenticated"}', true);
select throws_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'a0000000-0000-4000-8000-000000000002', r.id, '5a000000-0000-4000-8000-000000000003'
       from public.roles r where r.code = 'VIEWER' $$,
  '42501', null,
  'viewer: cannot grant roles');
select throws_ok(
  $$ insert into public.user_showrooms (profile_id, showroom_id)
     values ('a0000000-0000-4000-8000-000000000014', '5a000000-0000-4000-8000-000000000003') $$,
  '42501', null,
  'viewer: cannot assign showrooms');
select throws_ok(
  $$ select public.rpc_admin_update_user('a0000000-0000-4000-8000-000000000002', 'X', null, null, null) $$,
  '42501', null,
  'viewer: cannot edit other users');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000010","role":"authenticated"}', true);
select throws_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'a0000000-0000-4000-8000-000000000006', r.id, '5a000000-0000-4000-8000-000000000001'
       from public.roles r where r.code = 'VIEWER' $$,
  '42501', null,
  'cashier: cannot grant roles');
select results_eq(
  $$ with d as (delete from public.user_roles
                 where profile_id = 'a0000000-0000-4000-8000-000000000006' returning 1)
     select count(*)::int from d $$,
  $$ values (0) $$,
  'cashier: cannot revoke roles');
select throws_ok(
  $$ select public.rpc_admin_set_user_status('a0000000-0000-4000-8000-000000000006', 'deactivated') $$,
  '42501', null,
  'cashier: cannot deactivate users');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000006","role":"authenticated"}', true);
select throws_ok(
  $$ insert into public.role_permissions (role_id, permission_id)
     select r.id, p.id from public.roles r, public.permissions p
      where r.code = 'SALES_EXECUTIVE' and p.code = 'sales.approve' $$,
  '42501', null,
  'sales executive: cannot widen its own role');
select throws_ok(
  $$ insert into public.roles (code, name, precedence) values ('SE_PLUS', 'Sales Executive Plus', 55) $$,
  '42501', null,
  'sales executive: cannot create roles');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000005","role":"authenticated"}', true);
select throws_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'a0000000-0000-4000-8000-000000000006', r.id, '5a000000-0000-4000-8000-000000000001'
       from public.roles r where r.code = 'CASHIER' $$,
  '42501', null,
  'sales manager (users.view only): cannot grant roles');

-- -----------------------------------------------------------------------------
-- E. Onboarding (admin-users Edge Function: the service role creates the auth
--    user with app_metadata.invited_by; the caller's JWT does the rest)
-- -----------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
-- GoTrue inserts the user with provider data only and merges the caller's
-- app_metadata in a later UPDATE of the same transaction.
insert into auth.users (instance_id, id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
select '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
       '{"provider": "email", "providers": ["email"]}', jsonb_build_object('full_name', u.full_name)
  from (values ('b6000000-0000-4000-8000-000000000001'::uuid, 'new.exec@mybike.test', 'New Exec'),
               ('b6000000-0000-4000-8000-000000000002'::uuid, 'pending.user@mybike.test', 'Pending User'),
               ('b6000000-0000-4000-8000-000000000003'::uuid, 'forged.user@mybike.test', 'Forged'))
       as u (id, email, full_name);
update auth.users
   set raw_app_meta_data = raw_app_meta_data
       || jsonb_build_object('invited_by', case when id = 'b6000000-0000-4000-8000-000000000003'
                                                   then 'not-a-uuid'
                                                   else 'a0000000-0000-4000-8000-000000000003' end)
 where id in ('b6000000-0000-4000-8000-000000000001', 'b6000000-0000-4000-8000-000000000002',
              'b6000000-0000-4000-8000-000000000003');
-- A later change of app_metadata never moves the attribution.
update auth.users
   set raw_app_meta_data = raw_app_meta_data || '{"invited_by": "a0000000-0000-4000-8000-000000000004"}'
 where id = 'b6000000-0000-4000-8000-000000000001';

select is((select invited_by from public.profiles where id = 'b6000000-0000-4000-8000-000000000001'),
  'a0000000-0000-4000-8000-000000000003'::uuid,
  'onboarding: app_metadata.invited_by (service role only) records the creator once');
select is((select invited_by from public.profiles where id = 'b6000000-0000-4000-8000-000000000003'), null,
  'onboarding: an invalid invited_by is ignored');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select is(public.can_manage_user('b6000000-0000-4000-8000-000000000001'), true,
  'onboarding: the creator manages its unassigned new user');
select is(public.can_manage_user('a0000000-0000-4000-8000-000000000014'), false,
  'claim: a manager cannot manage an unassigned user it did not create');
select lives_ok(
  $$ insert into public.user_showrooms (profile_id, showroom_id, is_default)
     values ('b6000000-0000-4000-8000-000000000001', '5a000000-0000-4000-8000-000000000001', true) $$,
  'onboarding: the creator assigns its showroom');
select lives_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'b6000000-0000-4000-8000-000000000001', r.id, '5a000000-0000-4000-8000-000000000001'
       from public.roles r where r.code = 'SALES_EXECUTIVE' $$,
  'onboarding: the creator grants the first role');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select throws_ok(
  $$ insert into public.user_showrooms (profile_id, showroom_id)
     values ('b6000000-0000-4000-8000-000000000002', '5a000000-0000-4000-8000-000000000002') $$,
  '42501', null,
  'claim: another manager cannot take over an unassigned user');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select lives_ok(
  $$ insert into public.user_showrooms (profile_id, showroom_id)
     values ('a0000000-0000-4000-8000-000000000014', '5a000000-0000-4000-8000-000000000003') $$,
  'claim: a global user administrator assigns an unassigned user');

-- -----------------------------------------------------------------------------
-- F. Roles and the role matrix
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select lives_ok(
  $$ insert into public.roles (code, name, precedence) values ('FLOOR_LEAD', 'Floor Lead', 60) $$,
  'roles: super admin creates a custom role');
select throws_ok(
  $$ insert into public.roles (code, name, precedence) values ('OWNER_TWO', 'Owner Two', 100) $$,
  '23514', null,
  'roles: a custom role cannot rank with SUPER_ADMIN');
select lives_ok(
  $$ insert into public.role_permissions (role_id, permission_id)
     select r.id, p.id from public.roles r, public.permissions p
      where r.code = 'FLOOR_LEAD' and p.code = 'sales.view' $$,
  'matrix: super admin grants a permission to the custom role');
select throws_ok(
  $$ delete from public.role_permissions rp using public.roles r, public.permissions p
      where r.id = rp.role_id and p.id = rp.permission_id
        and r.code = 'SUPER_ADMIN' and p.code = 'sales.view' $$,
  'MB021', null,
  'matrix: the SUPER_ADMIN row is locked (it always holds every permission)');
select lives_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'a0000000-0000-4000-8000-000000000006', r.id, '5a000000-0000-4000-8000-000000000001'
       from public.roles r where r.code = 'FLOOR_LEAD' $$,
  'roles: super admin assigns the custom role');
select throws_ok(
  $$ delete from public.roles where code = 'FLOOR_LEAD' $$,
  '23001', null,
  'roles: a role in use cannot be deleted');

-- The owner delegates role management to ADMIN.
reset role;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r, public.permissions p
 where r.code = 'ADMIN' and p.code in ('roles.create', 'roles.edit');
set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select lives_ok(
  $$ insert into public.roles (code, name, precedence) values ('SHIFT_LEAD', 'Shift Lead', 60) $$,
  'delegated roles.create: admin creates a role ranking below itself');
select throws_ok(
  $$ insert into public.roles (code, name, precedence) values ('DEPUTY_OWNER', 'Deputy Owner', 95) $$,
  '42501', null,
  'escalation: admin cannot create a role ranking above itself');
select lives_ok(
  $$ insert into public.role_permissions (role_id, permission_id)
     select r.id, p.id from public.roles r, public.permissions p
      where r.code = 'SHIFT_LEAD' and p.code = 'users.approve' $$,
  'delegated matrix: admin grants a permission it holds');
select throws_ok(
  $$ insert into public.role_permissions (role_id, permission_id)
     select r.id, p.id from public.roles r, public.permissions p
      where r.code = 'SHIFT_LEAD' and p.code = 'users.delete' $$,
  '42501', null,
  'escalation: admin cannot grant a permission it does not hold');
select throws_ok(
  $$ insert into public.role_permissions (role_id, permission_id)
     select r.id, p.id from public.roles r, public.permissions p
      where r.code = 'ADMIN' and p.code = 'roles.delete' $$,
  '42501', null,
  'escalation: admin cannot widen its own role');
select results_eq(
  $$ with u as (update public.roles set name = 'Boss' where code = 'SUPER_ADMIN' returning 1)
     select count(*)::int from u $$,
  $$ values (0) $$,
  'escalation: admin cannot edit a higher role');

select * from finish();
rollback;
