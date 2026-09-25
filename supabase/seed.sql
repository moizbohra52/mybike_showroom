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

-- Bank details printed on invoices (Phase 7). Ujjain has none on purpose.
insert into public.bank_accounts (showroom_id, account_name, bank_name, account_number, ifsc, branch, upi_id, is_default)
values
  ('5a000000-0000-4000-8000-000000000001', 'MyBike Motors Private Limited', 'HDFC Bank', '50200012345678',
   'HDFC0001234', 'Vijay Nagar, Indore', 'mybike.indore@hdfcbank', true),
  ('5a000000-0000-4000-8000-000000000002', 'MyBike Motors Private Limited', 'State Bank of India', '38123456789',
   'SBIN0005678', 'MP Nagar, Bhopal', null, true)
on conflict (showroom_id, account_number) do nothing;

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

-- -----------------------------------------------------------------------------
-- 5. Vehicle catalogue and units (Phase 8). Prices and specifications are
--    illustrative dev data, not a price list.
-- -----------------------------------------------------------------------------
insert into public.vehicle_brands (id, code, name, country)
values
  ('c1000000-0000-4000-8000-000000000001', 'HONDA', 'Honda', 'Japan'),
  ('c1000000-0000-4000-8000-000000000002', 'TVS', 'TVS Motor', 'India'),
  ('c1000000-0000-4000-8000-000000000003', 'ATHER', 'Ather Energy', 'India'),
  ('c1000000-0000-4000-8000-000000000004', 'BAJAJ', 'Bajaj Auto', 'India')
on conflict (id) do nothing;

insert into public.vehicle_models (id, brand_id, name, category)
values
  ('c2000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'Activa 6G', 'scooter'),
  ('c2000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001', 'Shine 125', 'motorcycle'),
  ('c2000000-0000-4000-8000-000000000003', 'c1000000-0000-4000-8000-000000000002', 'iQube', 'scooter'),
  ('c2000000-0000-4000-8000-000000000004', 'c1000000-0000-4000-8000-000000000003', '450X', 'scooter'),
  ('c2000000-0000-4000-8000-000000000005', 'c1000000-0000-4000-8000-000000000004', 'Freedom 125', 'motorcycle')
on conflict (id) do nothing;

insert into public.vehicle_variants (
  id, model_id, name, fuel_type, hsn_code, ex_showroom_price, transmission, top_speed_kmph,
  engine_cc, mileage_kmpl, fuel_tank_litres,
  motor_power_kw, battery_capacity_kwh, battery_type, range_km, charging_time_hours, charging_type,
  warranty_months, warranty_km, battery_warranty_months, battery_warranty_km
)
values
  ('c3000000-0000-4000-8000-000000000001', 'c2000000-0000-4000-8000-000000000001', 'STD', 'petrol', '871120',
   76684.00, 'Automatic (CVT)', 85, 109.5, 50.0, 5.3, null, null, null, null, null, null, 36, 42000, null, null),
  ('c3000000-0000-4000-8000-000000000002', 'c2000000-0000-4000-8000-000000000001', 'DLX', 'petrol', '871120',
   80000.00, 'Automatic (CVT)', 85, 109.5, 50.0, 5.3, null, null, null, null, null, null, 36, 42000, null, null),
  ('c3000000-0000-4000-8000-000000000003', 'c2000000-0000-4000-8000-000000000002', 'Drum', 'petrol', '871120',
   81251.00, 'Manual (5-speed)', 100, 123.9, 55.0, 10.5, null, null, null, null, null, null, 36, 42000, null, null),
  ('c3000000-0000-4000-8000-000000000004', 'c2000000-0000-4000-8000-000000000003', '2.2 kWh', 'electric', '871160',
   94999.00, 'Automatic', 75, null, null, null, 4.40, 2.20, 'Li-ion', 75, 2.0, 'Portable 650 W',
   36, 50000, 36, 50000),
  ('c3000000-0000-4000-8000-000000000005', 'c2000000-0000-4000-8000-000000000004', '3.7 kWh', 'electric', '871160',
   149999.00, 'Automatic', 90, null, null, null, 6.40, 3.70, 'Li-ion', 130, 5.7, 'Home charger / fast charging',
   36, 30000, 36, 30000),
  ('c3000000-0000-4000-8000-000000000006', 'c2000000-0000-4000-8000-000000000005', 'NG04 Drum', 'cng', '871120',
   95000.00, 'Manual (5-speed)', 90, 124.6, 65.0, 2.0, null, null, null, null, null, null, 60, 75000, null, null)
on conflict (id) do nothing;

insert into public.vehicles (
  id, showroom_id, variant_id, vin, chassis_number, engine_number, motor_number, battery_number,
  color, manufacturing_year, model_year
)
values
  ('c4000000-0000-4000-8000-000000000001', '5a000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000001',
   'ME4JF508ARJ000101', 'ME4JF508ARJ000101', 'JF50E7000101', null, null, 'Pearl Precious White', 2026, 2026),
  ('c4000000-0000-4000-8000-000000000002', '5a000000-0000-4000-8000-000000000001', 'c3000000-0000-4000-8000-000000000004',
   'MD6EVB9A2R1000201', 'MD6EVB9A2R1000201', null, 'IQM24100201', 'IQB22K0100201', 'Titanium Grey', 2026, 2026),
  ('c4000000-0000-4000-8000-000000000003', '5a000000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000005',
   'MB9AE3A2XR0000301', 'MB9AE3A2XR0000301', null, 'ATHM640000301', 'ATHB37K0000301', 'Space Grey', 2026, 2026),
  ('c4000000-0000-4000-8000-000000000004', '5a000000-0000-4000-8000-000000000002', 'c3000000-0000-4000-8000-000000000006',
   'MD2B8GBX1R0000401', 'MD2B8GBX1R0000401', 'JZXCRL00401', null, null, 'Racing Red', 2026, 2026)
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- 6. Stock movements (Phase 9). Inserted directly (as postgres) rather than
--    through the RPCs, which check the caller's own permissions via auth.uid()
--    — meaningless outside a real request. Triggers still apply normally.
-- -----------------------------------------------------------------------------
-- No natural unique key to hang ON CONFLICT off, so guard idempotency with a
-- plain existence check instead (a second run must not re-insert the row and
-- push an already-received vehicle through the trigger's guard again).
insert into public.stock_ledger (showroom_id, movement_type, vehicle_id, unit_cost, value, reference_no, remarks)
select v.showroom_id, 'purchase_receipt', v.id, v.unit_cost, v.unit_cost, v.reference_no, v.remarks
  from (values
    ('5a000000-0000-4000-8000-000000000001'::uuid, 'c4000000-0000-4000-8000-000000000001'::uuid,
     68000.00::numeric, 'DEV-GRN-001', 'Dev seed: received into Indore stock'),
    ('5a000000-0000-4000-8000-000000000002'::uuid, 'c4000000-0000-4000-8000-000000000003'::uuid,
     130000.00::numeric, 'DEV-GRN-002', 'Dev seed: received into Bhopal stock')
  ) as v (showroom_id, id, unit_cost, reference_no, remarks)
 where not exists (
   select 1 from public.stock_ledger l where l.vehicle_id = v.id and l.movement_type = 'purchase_receipt'
 );

insert into public.vehicle_reservations (vehicle_id, showroom_id, reserved_by)
select 'c4000000-0000-4000-8000-000000000001', '5a000000-0000-4000-8000-000000000001',
       'a0000000-0000-4000-8000-000000000006'
 where not exists (
   select 1 from public.vehicle_reservations where vehicle_id = 'c4000000-0000-4000-8000-000000000001' and released_at is null
 );
update public.vehicles set status = 'reserved' where id = 'c4000000-0000-4000-8000-000000000001' and status = 'in_stock';
