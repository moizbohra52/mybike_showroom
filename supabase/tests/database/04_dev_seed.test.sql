-- =============================================================================
-- MyBike · Phase 3 · database test 04 — DEV SEED FIXTURES (supabase/seed.sql)
-- -----------------------------------------------------------------------------
-- DEV / LOCAL ONLY. Asserts the demo data of supabase/seed.sql (fixture ids
-- listed in its header), which database and integration tests rely on.
-- seed.sql is never applied to staging or production, so this file is
-- EXPECTED TO FAIL on any non-dev database. Do not run it there, and do not
-- "fix" it by weakening the assertions.
--
--   * 3 showrooms (INDORE-MAIN / IND, BHOPAL / BPL, UJJAIN / UJN) sharing
--     GSTIN 23ABCDE1234F1Z5, each with its showroom_settings row (place of
--     supply 23) and the 20 numbering series of the current FY
--   * 14 auth users @mybike.test, each with an e-mail identity, a profile and
--     a bcrypt password hash, user ...013 deactivated
--   * the exact user_roles and user_showrooms fixture tables, one default
--     showroom per assigned user, the multi-showroom accountant, the
--     fail-closed "norole" user, and role/showroom consistency
--
-- Wall clock: the numbering-series checks use the current FY
-- (fn_fy_code(fn_business_date())), which exists after `supabase db reset`
-- in the same financial year.
--
-- Plan: 22 assertions
--   showrooms 6 · auth users and profiles 7 · roles and showroom access 7 ·
--   credentials and e-mail domain 2
-- =============================================================================
begin;

create extension if not exists pgtap with schema extensions;

select plan(22);

-- -----------------------------------------------------------------------------
-- 1. Showrooms (6)
-- -----------------------------------------------------------------------------
select set_eq(
  $$ select id::text, code, invoice_prefix from public.showrooms $$,
  $$ values ('5a000000-0000-4000-8000-000000000001', 'INDORE-MAIN', 'IND'),
            ('5a000000-0000-4000-8000-000000000002', 'BHOPAL', 'BPL'),
            ('5a000000-0000-4000-8000-000000000003', 'UJJAIN', 'UJN') $$,
  'seed: exactly the 3 fixture showrooms with their ids, codes and invoice prefixes'
);

select is(
  (select count(*)::int
     from public.showrooms
    where id in ('5a000000-0000-4000-8000-000000000001',
                 '5a000000-0000-4000-8000-000000000002',
                 '5a000000-0000-4000-8000-000000000003')
      and gstin = '23ABCDE1234F1Z5'
      and state_code = '23'),
  3,
  'seed: all three showrooms share GSTIN 23ABCDE1234F1Z5 in state 23'
);

select set_eq(
  $$ select showroom_id::text, default_place_of_supply_state
       from public.showroom_settings
      where showroom_id in ('5a000000-0000-4000-8000-000000000001',
                            '5a000000-0000-4000-8000-000000000002',
                            '5a000000-0000-4000-8000-000000000003') $$,
  $$ values ('5a000000-0000-4000-8000-000000000001', '23'),
            ('5a000000-0000-4000-8000-000000000002', '23'),
            ('5a000000-0000-4000-8000-000000000003', '23') $$,
  'seed: each showroom has its showroom_settings row with place of supply 23'
);

select set_eq(
  $$ select s.code, count(*)::int
       from public.document_sequences ds
       join public.showrooms s on s.id = ds.showroom_id
       join public.financial_years fy on fy.id = ds.financial_year_id
      where fy.code = public.fn_fy_code(public.fn_business_date())
        and s.id in ('5a000000-0000-4000-8000-000000000001',
                     '5a000000-0000-4000-8000-000000000002',
                     '5a000000-0000-4000-8000-000000000003')
      group by s.code $$,
  $$ values ('INDORE-MAIN', 20), ('BHOPAL', 20), ('UJJAIN', 20) $$,
  'seed: each showroom has the 20 numbering series of the current FY'
);

select is_empty(
  $$ select s.code, ds.doc_type
       from public.document_sequences ds
       join public.showrooms s on s.id = ds.showroom_id
       join public.financial_years fy on fy.id = ds.financial_year_id
      where fy.code = public.fn_fy_code(public.fn_business_date())
        and s.id in ('5a000000-0000-4000-8000-000000000001',
                     '5a000000-0000-4000-8000-000000000002',
                     '5a000000-0000-4000-8000-000000000003')
        and left(ds.prefix, char_length(s.invoice_prefix)) is distinct from s.invoice_prefix $$,
  'seed: every numbering series prefix starts with its showroom invoice_prefix'
);

select set_eq(
  $$ select s.code, ds.prefix
       from public.document_sequences ds
       join public.showrooms s on s.id = ds.showroom_id
       join public.financial_years fy on fy.id = ds.financial_year_id
      where fy.code = public.fn_fy_code(public.fn_business_date())
        and ds.doc_type = 'sales_invoice'
        and s.id in ('5a000000-0000-4000-8000-000000000001',
                     '5a000000-0000-4000-8000-000000000002',
                     '5a000000-0000-4000-8000-000000000003') $$,
  $$ values ('INDORE-MAIN', 'IND'), ('BHOPAL', 'BPL'), ('UJJAIN', 'UJN') $$,
  'seed: the tax-invoice series of each showroom uses the bare invoice_prefix'
);

-- -----------------------------------------------------------------------------
-- 2. Auth users and profiles (7)
-- -----------------------------------------------------------------------------
select set_eq(
  $$ select id::text, email::text from auth.users where email like '%@mybike.test' $$,
  $$ values ('a0000000-0000-4000-8000-000000000001', 'superadmin@mybike.test'),
            ('a0000000-0000-4000-8000-000000000002', 'admin@mybike.test'),
            ('a0000000-0000-4000-8000-000000000003', 'manager.indore@mybike.test'),
            ('a0000000-0000-4000-8000-000000000004', 'manager.bhopal@mybike.test'),
            ('a0000000-0000-4000-8000-000000000005', 'sales.manager@mybike.test'),
            ('a0000000-0000-4000-8000-000000000006', 'sales.exec@mybike.test'),
            ('a0000000-0000-4000-8000-000000000007', 'purchase@mybike.test'),
            ('a0000000-0000-4000-8000-000000000008', 'inventory@mybike.test'),
            ('a0000000-0000-4000-8000-000000000009', 'accountant@mybike.test'),
            ('a0000000-0000-4000-8000-000000000010', 'cashier@mybike.test'),
            ('a0000000-0000-4000-8000-000000000011', 'service@mybike.test'),
            ('a0000000-0000-4000-8000-000000000012', 'viewer@mybike.test'),
            ('a0000000-0000-4000-8000-000000000013', 'inactive@mybike.test'),
            ('a0000000-0000-4000-8000-000000000014', 'norole@mybike.test') $$,
  'seed: exactly the 14 fixture auth users @mybike.test'
);

select is_empty(
  $$ select u.email
       from auth.users u
      where u.email like '%@mybike.test'
        and not exists (
              select 1
                from auth.identities i
               where i.user_id = u.id
                 and i.provider = 'email'
                 and i.provider_id = u.id::text
                 and i.identity_data ->> 'email' = u.email::text
            ) $$,
  'seed: every fixture user has an email identity'
);

select is_empty(
  $$ select u.email
       from auth.users u
      where u.email like '%@mybike.test'
        and not exists (
              select 1
                from public.profiles p
               where p.id = u.id
                 and p.email::text = u.email::text
            ) $$,
  'seed: every fixture user has a profile carrying the same e-mail'
);

select set_eq(
  $$ select p.id::text, p.employee_code, p.full_name
       from public.profiles p
       join auth.users u on u.id = p.id
      where u.email like '%@mybike.test' $$,
  $$ values ('a0000000-0000-4000-8000-000000000001', 'MB-0001', 'Asha Verma'),
            ('a0000000-0000-4000-8000-000000000002', 'MB-0002', 'Rohit Sharma'),
            ('a0000000-0000-4000-8000-000000000003', 'MB-0003', 'Neha Joshi'),
            ('a0000000-0000-4000-8000-000000000004', 'MB-0004', 'Arjun Mehta'),
            ('a0000000-0000-4000-8000-000000000005', 'MB-0005', 'Kavita Rao'),
            ('a0000000-0000-4000-8000-000000000006', 'MB-0006', 'Imran Khan'),
            ('a0000000-0000-4000-8000-000000000007', 'MB-0007', 'Sunita Patel'),
            ('a0000000-0000-4000-8000-000000000008', 'MB-0008', 'Vikram Singh'),
            ('a0000000-0000-4000-8000-000000000009', 'MB-0009', 'Pooja Agrawal'),
            ('a0000000-0000-4000-8000-000000000010', 'MB-0010', 'Deepak Yadav'),
            ('a0000000-0000-4000-8000-000000000011', 'MB-0011', 'Farhan Ali'),
            ('a0000000-0000-4000-8000-000000000012', 'MB-0012', 'Meera Iyer'),
            ('a0000000-0000-4000-8000-000000000013', 'MB-0013', 'Sanjay Gupta'),
            ('a0000000-0000-4000-8000-000000000014', 'MB-0014', 'Ritu Malhotra') $$,
  'seed: profiles carry the fixture employee codes and the full_name from user metadata'
);

select is(
  (select status::text from public.profiles where id = 'a0000000-0000-4000-8000-000000000013'),
  'deactivated'::text,
  'seed: profile ...013 (inactive@) has status deactivated'
);

select is(
  (select is_active from public.profiles where id = 'a0000000-0000-4000-8000-000000000013'),
  false,
  'seed: profile ...013 (inactive@) is not active'
);

select is_empty(
  $$ select p.id
       from public.profiles p
       join auth.users u on u.id = p.id
      where u.email like '%@mybike.test'
        and p.id <> 'a0000000-0000-4000-8000-000000000013'
        and (p.status <> 'active' or not p.is_active) $$,
  'seed: every other fixture profile is active'
);

-- -----------------------------------------------------------------------------
-- 3. Role assignments and showroom access (7)
-- -----------------------------------------------------------------------------
-- The seed.sql header table: showroom NULL = global assignment.
select set_eq(
  $$ select ur.profile_id::text, r.code, s.code
       from public.user_roles ur
       join public.roles r on r.id = ur.role_id
       left join public.showrooms s on s.id = ur.showroom_id
      where ur.profile_id in (select id from auth.users where email like '%@mybike.test') $$,
  $$ values ('a0000000-0000-4000-8000-000000000001', 'SUPER_ADMIN', null::text),
            ('a0000000-0000-4000-8000-000000000002', 'ADMIN', null),
            ('a0000000-0000-4000-8000-000000000003', 'SHOWROOM_MANAGER', 'INDORE-MAIN'),
            ('a0000000-0000-4000-8000-000000000004', 'SHOWROOM_MANAGER', 'BHOPAL'),
            ('a0000000-0000-4000-8000-000000000005', 'SALES_MANAGER', 'INDORE-MAIN'),
            ('a0000000-0000-4000-8000-000000000006', 'SALES_EXECUTIVE', 'INDORE-MAIN'),
            ('a0000000-0000-4000-8000-000000000007', 'PURCHASE_MANAGER', 'BHOPAL'),
            ('a0000000-0000-4000-8000-000000000008', 'INVENTORY_MANAGER', 'BHOPAL'),
            ('a0000000-0000-4000-8000-000000000009', 'ACCOUNTANT', 'INDORE-MAIN'),
            ('a0000000-0000-4000-8000-000000000009', 'ACCOUNTANT', 'BHOPAL'),
            ('a0000000-0000-4000-8000-000000000010', 'CASHIER', 'INDORE-MAIN'),
            ('a0000000-0000-4000-8000-000000000011', 'SERVICE_MANAGER', 'BHOPAL'),
            ('a0000000-0000-4000-8000-000000000012', 'VIEWER', 'UJJAIN'),
            ('a0000000-0000-4000-8000-000000000013', 'SALES_EXECUTIVE', 'INDORE-MAIN') $$,
  'seed: user_roles are exactly the fixture table (14 assignments)'
);

select set_eq(
  $$ select us.profile_id::text, s.code, us.is_default, us.is_active
       from public.user_showrooms us
       join public.showrooms s on s.id = us.showroom_id
      where us.profile_id in (select id from auth.users where email like '%@mybike.test') $$,
  $$ values ('a0000000-0000-4000-8000-000000000002', 'INDORE-MAIN', true, true),
            ('a0000000-0000-4000-8000-000000000002', 'BHOPAL', false, true),
            ('a0000000-0000-4000-8000-000000000002', 'UJJAIN', false, true),
            ('a0000000-0000-4000-8000-000000000003', 'INDORE-MAIN', true, true),
            ('a0000000-0000-4000-8000-000000000004', 'BHOPAL', true, true),
            ('a0000000-0000-4000-8000-000000000005', 'INDORE-MAIN', true, true),
            ('a0000000-0000-4000-8000-000000000006', 'INDORE-MAIN', true, true),
            ('a0000000-0000-4000-8000-000000000007', 'BHOPAL', true, true),
            ('a0000000-0000-4000-8000-000000000008', 'BHOPAL', true, true),
            ('a0000000-0000-4000-8000-000000000009', 'INDORE-MAIN', true, true),
            ('a0000000-0000-4000-8000-000000000009', 'BHOPAL', false, true),
            ('a0000000-0000-4000-8000-000000000010', 'INDORE-MAIN', true, true),
            ('a0000000-0000-4000-8000-000000000011', 'BHOPAL', true, true),
            ('a0000000-0000-4000-8000-000000000012', 'UJJAIN', true, true),
            ('a0000000-0000-4000-8000-000000000013', 'INDORE-MAIN', true, true) $$,
  'seed: user_showrooms are exactly the fixture table (15 rows, defaults marked)'
);

select is_empty(
  $$ select us.profile_id
       from public.user_showrooms us
      where us.profile_id in (select id from auth.users where email like '%@mybike.test')
      group by us.profile_id
     having count(*) filter (where us.is_default) <> 1 $$,
  'seed: every fixture user with showroom access has exactly one default showroom'
);

select is(
  (select count(*)::int
     from public.user_showrooms
    where profile_id = 'a0000000-0000-4000-8000-000000000009'
      and is_active),
  2,
  'seed: the accountant (...009) works in 2 showrooms'
);

select is(
  (select count(*)::int from public.user_roles where profile_id = 'a0000000-0000-4000-8000-000000000014'),
  0,
  'seed: norole (...014) has no role assignment (fail-closed fixture)'
);

select is(
  (select count(*)::int from public.user_showrooms where profile_id = 'a0000000-0000-4000-8000-000000000014'),
  0,
  'seed: norole (...014) has no showroom access'
);

select is_empty(
  $$ select ur.profile_id, ur.showroom_id
       from public.user_roles ur
      where ur.showroom_id is not null
        and ur.profile_id in (select id from auth.users where email like '%@mybike.test')
        and not exists (
              select 1
                from public.user_showrooms us
               where us.profile_id = ur.profile_id
                 and us.showroom_id = ur.showroom_id
                 and us.is_active
            ) $$,
  'seed: every showroom-scoped role has a matching active user_showrooms row'
);

-- -----------------------------------------------------------------------------
-- 4. Credentials and e-mail domain (2)
-- -----------------------------------------------------------------------------
select is_empty(
  $$ select email
       from auth.users
      where email like '%@mybike.test'
        and (encrypted_password is null or encrypted_password not like '$2%') $$,
  'seed: every fixture password is stored as a bcrypt hash'
);

-- No fixture may carry a real, deliverable address.
select is_empty(
  $$ select 'auth.users' as source, id::text, email::text
       from auth.users
      where id in (select ('a0000000-0000-4000-8000-0000000000' || lpad(n::text, 2, '0'))::uuid
                     from generate_series(1, 14) as n)
        and (email is null or email::text not like '%@mybike.test')
     union all
     select 'profiles', id::text, email::text
       from public.profiles
      where id in (select ('a0000000-0000-4000-8000-0000000000' || lpad(n::text, 2, '0'))::uuid
                     from generate_series(1, 14) as n)
        and (email is null or email::text not like '%@mybike.test')
     union all
     select 'showrooms', id::text, email::text
       from public.showrooms
      where id in ('5a000000-0000-4000-8000-000000000001',
                   '5a000000-0000-4000-8000-000000000002',
                   '5a000000-0000-4000-8000-000000000003')
        and (email is null or email::text not like '%@mybike.test') $$,
  'seed: every fixture e-mail (users, profiles, showrooms) ends with @mybike.test'
);

select * from finish();

rollback;
