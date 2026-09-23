-- =============================================================================
-- MyBike · DEV / LOCAL DEMO DATA ONLY — never run against staging or production
-- -----------------------------------------------------------------------------
-- Loaded by `supabase db reset` (local stack) via [db.seed] in config.toml.
-- `supabase db push` does NOT apply this file unless --include-seed is passed:
-- never pass it for staging/prod. Idempotent: safe to re-run.
--
-- Every demo user signs in with the password:  MyBike@Dev2026
-- (known credentials — acceptable only for local/dev databases).
--
-- Fixture ids (asserted by database and integration tests — keep stable):
--
--   Showrooms (all in Madhya Pradesh, sharing one company GSTIN)
--     5a000000-0000-4000-8000-000000000001  INDORE-MAIN  prefix IND
--     5a000000-0000-4000-8000-000000000002  BHOPAL       prefix BPL
--     5a000000-0000-4000-8000-000000000003  UJJAIN       prefix UJN
--
--   Users (e-mail @mybike.test)                 role(s)                 showrooms
--     a0000000-0000-4000-8000-000000000001  superadmin       SUPER_ADMIN (global)   — (all via role)
--     a0000000-0000-4000-8000-000000000002  admin            ADMIN (global)         IND*, BPL, UJN
--     a0000000-0000-4000-8000-000000000003  manager.indore   SHOWROOM_MANAGER @IND  IND*
--     a0000000-0000-4000-8000-000000000004  manager.bhopal   SHOWROOM_MANAGER @BPL  BPL*
--     a0000000-0000-4000-8000-000000000005  sales.manager    SALES_MANAGER @IND     IND*
--     a0000000-0000-4000-8000-000000000006  sales.exec       SALES_EXECUTIVE @IND   IND*
--     a0000000-0000-4000-8000-000000000007  purchase         PURCHASE_MANAGER @BPL  BPL*
--     a0000000-0000-4000-8000-000000000008  inventory        INVENTORY_MANAGER @BPL BPL*
--     a0000000-0000-4000-8000-000000000009  accountant       ACCOUNTANT @IND + @BPL IND*, BPL  (multi-showroom)
--     a0000000-0000-4000-8000-000000000010  cashier          CASHIER @IND           IND*
--     a0000000-0000-4000-8000-000000000011  service          SERVICE_MANAGER @BPL   BPL*
--     a0000000-0000-4000-8000-000000000012  viewer           VIEWER @UJN            UJN*
--     a0000000-0000-4000-8000-000000000013  inactive         SALES_EXECUTIVE @IND   IND*  (status deactivated)
--     a0000000-0000-4000-8000-000000000014  norole           — (no roles)           —    (fail-closed case)
--   (* = default showroom)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Auth users + e-mail identities (GoTrue needs both; token columns must be
--    '' rather than NULL or GoTrue fails to load the user).
-- -----------------------------------------------------------------------------
with demo_users (id, email, full_name) as (
  values
    ('a0000000-0000-4000-8000-000000000001'::uuid, 'superadmin@mybike.test',     'Asha Verma'),
    ('a0000000-0000-4000-8000-000000000002'::uuid, 'admin@mybike.test',          'Rohit Sharma'),
    ('a0000000-0000-4000-8000-000000000003'::uuid, 'manager.indore@mybike.test', 'Neha Joshi'),
    ('a0000000-0000-4000-8000-000000000004'::uuid, 'manager.bhopal@mybike.test', 'Arjun Mehta'),
    ('a0000000-0000-4000-8000-000000000005'::uuid, 'sales.manager@mybike.test',  'Kavita Rao'),
    ('a0000000-0000-4000-8000-000000000006'::uuid, 'sales.exec@mybike.test',     'Imran Khan'),
    ('a0000000-0000-4000-8000-000000000007'::uuid, 'purchase@mybike.test',       'Sunita Patel'),
    ('a0000000-0000-4000-8000-000000000008'::uuid, 'inventory@mybike.test',      'Vikram Singh'),
    ('a0000000-0000-4000-8000-000000000009'::uuid, 'accountant@mybike.test',     'Pooja Agrawal'),
    ('a0000000-0000-4000-8000-000000000010'::uuid, 'cashier@mybike.test',        'Deepak Yadav'),
    ('a0000000-0000-4000-8000-000000000011'::uuid, 'service@mybike.test',        'Farhan Ali'),
    ('a0000000-0000-4000-8000-000000000012'::uuid, 'viewer@mybike.test',         'Meera Iyer'),
    ('a0000000-0000-4000-8000-000000000013'::uuid, 'inactive@mybike.test',       'Sanjay Gupta'),
    ('a0000000-0000-4000-8000-000000000014'::uuid, 'norole@mybike.test',         'Ritu Malhotra')
)
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select '00000000-0000-0000-0000-000000000000'::uuid,
       u.id,
       'authenticated',
       'authenticated',
       u.email,
       extensions.crypt('MyBike@Dev2026', extensions.gen_salt('bf')),
       now(),
       '{"provider": "email", "providers": ["email"]}'::jsonb,
       jsonb_build_object('full_name', u.full_name),
       now(),
       now(),
       '', '', '', ''
  from demo_users u
on conflict (id) do nothing;

insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select u.id::text,
       u.id,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true, 'phone_verified', false),
       'email',
       now(),
       now(),
       now()
  from auth.users u
 where u.email like '%@mybike.test'
on conflict (provider_id, provider) do nothing;

-- Profiles were created by trg_auth_users_create_profile; add HR details.
update public.profiles p
   set employee_code = v.employee_code,
       designation   = v.designation,
       status        = v.status::public.user_status
  from (values
    ('a0000000-0000-4000-8000-000000000001'::uuid, 'MB-0001', 'Owner',                 'active'),
    ('a0000000-0000-4000-8000-000000000002'::uuid, 'MB-0002', 'Administrator',         'active'),
    ('a0000000-0000-4000-8000-000000000003'::uuid, 'MB-0003', 'Showroom Manager',      'active'),
    ('a0000000-0000-4000-8000-000000000004'::uuid, 'MB-0004', 'Showroom Manager',      'active'),
    ('a0000000-0000-4000-8000-000000000005'::uuid, 'MB-0005', 'Sales Manager',         'active'),
    ('a0000000-0000-4000-8000-000000000006'::uuid, 'MB-0006', 'Sales Executive',       'active'),
    ('a0000000-0000-4000-8000-000000000007'::uuid, 'MB-0007', 'Purchase Manager',      'active'),
    ('a0000000-0000-4000-8000-000000000008'::uuid, 'MB-0008', 'Inventory Manager',     'active'),
    ('a0000000-0000-4000-8000-000000000009'::uuid, 'MB-0009', 'Accountant',            'active'),
    ('a0000000-0000-4000-8000-000000000010'::uuid, 'MB-0010', 'Cashier',               'active'),
    ('a0000000-0000-4000-8000-000000000011'::uuid, 'MB-0011', 'Service Manager',       'active'),
    ('a0000000-0000-4000-8000-000000000012'::uuid, 'MB-0012', 'Auditor',               'active'),
    ('a0000000-0000-4000-8000-000000000013'::uuid, 'MB-0013', 'Sales Executive (left)', 'deactivated'),
    ('a0000000-0000-4000-8000-000000000014'::uuid, 'MB-0014', 'Trainee',               'active')
  ) as v (id, employee_code, designation, status)
 where p.id = v.id;

-- -----------------------------------------------------------------------------
-- 2. Showrooms (the bootstrap trigger adds showroom_settings + numbering)
-- -----------------------------------------------------------------------------
insert into public.showrooms (
  id, code, name, legal_name, gstin, pan, address_line1, city, state_code, pincode,
  phone, email, invoice_prefix, opened_on
)
values
  ('5a000000-0000-4000-8000-000000000001', 'INDORE-MAIN', 'Indore Main Showroom',
   'MyBike Motors Private Limited', '23ABCDE1234F1Z5', 'ABCDE1234F', '12 AB Road, Vijay Nagar',
   'Indore', '23', '452010', '+917310000001', 'indore@mybike.test', 'IND', '2021-04-01'),
  ('5a000000-0000-4000-8000-000000000002', 'BHOPAL', 'Bhopal Showroom',
   'MyBike Motors Private Limited', '23ABCDE1234F1Z5', 'ABCDE1234F', '45 Hoshangabad Road',
   'Bhopal', '23', '462011', '+917550000002', 'bhopal@mybike.test', 'BPL', '2023-01-15'),
  ('5a000000-0000-4000-8000-000000000003', 'UJJAIN', 'Ujjain Showroom',
   'MyBike Motors Private Limited', '23ABCDE1234F1Z5', 'ABCDE1234F', '7 Freeganj',
   'Ujjain', '23', '456010', '+917340000003', 'ujjain@mybike.test', 'UJN', '2025-10-02')
on conflict (id) do nothing;

-- Covers showrooms created before a financial year existed (idempotent).
select public.fn_ensure_document_sequences(s.id, fy.id)
  from public.showrooms s
 cross join public.financial_years fy
 where not fy.is_closed;

update public.showroom_settings ss
   set default_place_of_supply_state = '23',
       invoice_terms = 'Goods once sold will not be taken back. Subject to local jurisdiction.',
       receipt_terms = 'Receipt valid subject to realisation of cheque / UPI settlement.'
 where ss.showroom_id in (
         '5a000000-0000-4000-8000-000000000001',
         '5a000000-0000-4000-8000-000000000002',
         '5a000000-0000-4000-8000-000000000003'
       )
   and ss.default_place_of_supply_state is null;

-- -----------------------------------------------------------------------------
-- 3. Showroom access
-- -----------------------------------------------------------------------------
insert into public.user_showrooms (profile_id, showroom_id, is_default)
values
  ('a0000000-0000-4000-8000-000000000002', '5a000000-0000-4000-8000-000000000001', true),
  ('a0000000-0000-4000-8000-000000000002', '5a000000-0000-4000-8000-000000000002', false),
  ('a0000000-0000-4000-8000-000000000002', '5a000000-0000-4000-8000-000000000003', false),
  ('a0000000-0000-4000-8000-000000000003', '5a000000-0000-4000-8000-000000000001', true),
  ('a0000000-0000-4000-8000-000000000004', '5a000000-0000-4000-8000-000000000002', true),
  ('a0000000-0000-4000-8000-000000000005', '5a000000-0000-4000-8000-000000000001', true),
  ('a0000000-0000-4000-8000-000000000006', '5a000000-0000-4000-8000-000000000001', true),
  ('a0000000-0000-4000-8000-000000000007', '5a000000-0000-4000-8000-000000000002', true),
  ('a0000000-0000-4000-8000-000000000008', '5a000000-0000-4000-8000-000000000002', true),
  ('a0000000-0000-4000-8000-000000000009', '5a000000-0000-4000-8000-000000000001', true),
  ('a0000000-0000-4000-8000-000000000009', '5a000000-0000-4000-8000-000000000002', false),
  ('a0000000-0000-4000-8000-000000000010', '5a000000-0000-4000-8000-000000000001', true),
  ('a0000000-0000-4000-8000-000000000011', '5a000000-0000-4000-8000-000000000002', true),
  ('a0000000-0000-4000-8000-000000000012', '5a000000-0000-4000-8000-000000000003', true),
  ('a0000000-0000-4000-8000-000000000013', '5a000000-0000-4000-8000-000000000001', true)
on conflict (profile_id, showroom_id) do nothing;

-- -----------------------------------------------------------------------------
-- 4. Role assignments (showroom_id NULL = global)
-- -----------------------------------------------------------------------------
insert into public.user_roles (profile_id, role_id, showroom_id)
select a.profile_id, r.id, a.showroom_id
  from (values
    ('a0000000-0000-4000-8000-000000000001'::uuid, 'SUPER_ADMIN',       null::uuid),
    ('a0000000-0000-4000-8000-000000000002'::uuid, 'ADMIN',             null::uuid),
    ('a0000000-0000-4000-8000-000000000003'::uuid, 'SHOWROOM_MANAGER',  '5a000000-0000-4000-8000-000000000001'::uuid),
    ('a0000000-0000-4000-8000-000000000004'::uuid, 'SHOWROOM_MANAGER',  '5a000000-0000-4000-8000-000000000002'::uuid),
    ('a0000000-0000-4000-8000-000000000005'::uuid, 'SALES_MANAGER',     '5a000000-0000-4000-8000-000000000001'::uuid),
    ('a0000000-0000-4000-8000-000000000006'::uuid, 'SALES_EXECUTIVE',   '5a000000-0000-4000-8000-000000000001'::uuid),
    ('a0000000-0000-4000-8000-000000000007'::uuid, 'PURCHASE_MANAGER',  '5a000000-0000-4000-8000-000000000002'::uuid),
    ('a0000000-0000-4000-8000-000000000008'::uuid, 'INVENTORY_MANAGER', '5a000000-0000-4000-8000-000000000002'::uuid),
    ('a0000000-0000-4000-8000-000000000009'::uuid, 'ACCOUNTANT',        '5a000000-0000-4000-8000-000000000001'::uuid),
    ('a0000000-0000-4000-8000-000000000009'::uuid, 'ACCOUNTANT',        '5a000000-0000-4000-8000-000000000002'::uuid),
    ('a0000000-0000-4000-8000-000000000010'::uuid, 'CASHIER',           '5a000000-0000-4000-8000-000000000001'::uuid),
    ('a0000000-0000-4000-8000-000000000011'::uuid, 'SERVICE_MANAGER',   '5a000000-0000-4000-8000-000000000002'::uuid),
    ('a0000000-0000-4000-8000-000000000012'::uuid, 'VIEWER',            '5a000000-0000-4000-8000-000000000003'::uuid),
    ('a0000000-0000-4000-8000-000000000013'::uuid, 'SALES_EXECUTIVE',   '5a000000-0000-4000-8000-000000000001'::uuid)
  ) as a (profile_id, role_code, showroom_id)
  join public.roles r on r.code = a.role_code
on conflict do nothing;
