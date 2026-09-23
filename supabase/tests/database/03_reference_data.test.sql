-- =============================================================================
-- MyBike · Phase 3 · database test 03 — reference data (migration 0004)
-- -----------------------------------------------------------------------------
-- Asserts ONLY what supabase/migrations/20260923000004_seed_reference_data.sql
-- seeds, so it must pass in EVERY environment (local, dev, staging, prod) —
-- nothing here depends on supabase/seed.sql.
--
--   * GST states: 39 codes, 37 active (legacy 25 and 28 inactive), 9 union
--     territories, spot checks of codes 23 and 37
--   * permission catalogue: 148 = 21 modules x 7 actions + showrooms.view_all,
--     code = module.action
--   * the 11 system roles and their precedence
--   * THE MATRIX: docs/phase-00/02-roles-permissions.md §4 transcribed
--     independently from the DOCUMENT (not from the migration) and compared
--     with role_permissions, plus per-role grant counts and the §4 invariants
--   * the 6 company settings
--   * the current Indian FY (fn_fy_code(fn_business_date())) and its 12 open
--     monthly periods. This is the only wall-clock dependent part: it holds as
--     long as the FY of today has been created (migration 0004 or the FY
--     roll-over via fn_ensure_financial_year()).
--
-- If the matrix is deliberately changed (Phase 6), update §4 of the document
-- AND the doc_matrix transcription below together.
--
-- Plan: 35 assertions
--   states 7 · permissions 5 · roles 3 · matrix 3 · invariants 8 ·
--   settings 4 · financial year 5
-- =============================================================================
begin;

create extension if not exists pgtap with schema extensions;

select plan(35);

-- -----------------------------------------------------------------------------
-- 1. GST states (7)
-- -----------------------------------------------------------------------------
select is(
  (select count(*)::int from public.states),
  39,
  'states: 39 GST state / UT codes are seeded'
);

select is(
  (select count(*)::int from public.states where is_active),
  37,
  'states: 37 codes are active'
);

select set_eq(
  $$ select code from public.states where not is_active $$,
  $$ values ('25'), ('28') $$,
  'states: only the legacy codes 25 (Daman and Diu) and 28 (undivided Andhra Pradesh) are inactive'
);

select is(
  (select count(*)::int from public.states where is_union_territory),
  9,
  'states: 9 codes are union territories'
);

select set_eq(
  $$ select code from public.states where is_union_territory $$,
  $$ values ('01'), ('04'), ('07'), ('25'), ('26'), ('31'), ('34'), ('35'), ('38') $$,
  'states: the union territories are 01, 04, 07, 25, 26, 31, 34, 35, 38'
);

select is(
  (select name from public.states where code = '23'),
  'Madhya Pradesh'::text,
  'states: GST code 23 is Madhya Pradesh'
);

select is(
  (select name from public.states where code = '37'),
  'Andhra Pradesh'::text,
  'states: GST code 37 is Andhra Pradesh'
);

-- -----------------------------------------------------------------------------
-- 2. Permission catalogue (5)
-- -----------------------------------------------------------------------------
select is(
  (select count(*)::int from public.permissions),
  148,
  'permissions: 148 permissions = 21 modules x 7 actions + showrooms.view_all'
);

-- Canonical module keys from 02-roles-permissions.md §2.
select set_eq(
  $$ select distinct module from public.permissions $$,
  $$ values ('dashboard'), ('showrooms'), ('users'), ('roles'), ('vehicles'), ('inventory'),
            ('purchases'), ('suppliers'), ('sales'), ('customers'), ('bookings'), ('finance'),
            ('accounting'), ('expenses'), ('income'), ('reports'), ('documents'),
            ('notifications'), ('audit'), ('settings'), ('approvals') $$,
  'permissions: exactly the 21 canonical modules of 02-roles-permissions §2'
);

select is_empty(
  $$ select m.module
       from (select distinct module from public.permissions) as m
       left join public.permissions p
         on p.module = m.module
        and p.action in ('view', 'create', 'edit', 'delete', 'approve', 'export', 'print')
      group by m.module
     having count(p.id) <> 7 $$,
  'permissions: every module has exactly the 7 standard actions'
);

select set_eq(
  $$ select code from public.permissions
      where action not in ('view', 'create', 'edit', 'delete', 'approve', 'export', 'print') $$,
  $$ values ('showrooms.view_all') $$,
  'permissions: showrooms.view_all is the only non-standard permission'
);

select is_empty(
  $$ select code from public.permissions where code is distinct from module || '.' || action $$,
  'permissions: code always equals module.action'
);

-- -----------------------------------------------------------------------------
-- 3. System roles (3)
-- -----------------------------------------------------------------------------
select set_eq(
  $$ select code from public.roles where is_system $$,
  $$ values ('SUPER_ADMIN'), ('ADMIN'), ('SHOWROOM_MANAGER'), ('SALES_MANAGER'),
            ('SALES_EXECUTIVE'), ('PURCHASE_MANAGER'), ('INVENTORY_MANAGER'), ('ACCOUNTANT'),
            ('CASHIER'), ('SERVICE_MANAGER'), ('VIEWER') $$,
  'roles: exactly the 11 system roles of 02-roles-permissions §1'
);

-- Ties (70, 50) are listed by code, matching the ORDER BY.
select results_eq(
  $$ select code, precedence::int
       from public.roles
      where is_system
      order by precedence desc, code collate "C" $$,
  $$ values ('SUPER_ADMIN', 100), ('ADMIN', 90), ('SHOWROOM_MANAGER', 80),
            ('ACCOUNTANT', 70), ('INVENTORY_MANAGER', 70), ('PURCHASE_MANAGER', 70),
            ('SALES_MANAGER', 70), ('SERVICE_MANAGER', 70),
            ('CASHIER', 50), ('SALES_EXECUTIVE', 50),
            ('VIEWER', 10) $$,
  'roles: precedence SUPER_ADMIN 100 > ADMIN 90 > SHOWROOM_MANAGER 80 > 70 > 50 > VIEWER 10'
);

select is_empty(
  $$ select code from public.roles where is_system and not is_active $$,
  'roles: every system role is active'
);

-- -----------------------------------------------------------------------------
-- 4. The module x role matrix (3)
-- -----------------------------------------------------------------------------
-- Transcribed from docs/phase-00/02-roles-permissions.md §4 — one group of
-- lines per non-empty cell (the trailing comment quotes the cell), letters
-- expanded in the order the cell lists them. Qualifiers such as "(own)" or
-- "(request)" are row-level rules of later phases, the grant is the letter
-- set. Cells marked with a dash have no rows. showrooms.view_all comes from §3.
-- Letters: V view · C create · E edit · D delete · A approve · X export · P print
create temporary table doc_matrix (
  role_code       text not null,
  permission_code text not null,
  primary key (role_code, permission_code)
);

insert into doc_matrix (role_code, permission_code)
values
  -- SUPER_ADMIN (136)
  ('SUPER_ADMIN', 'dashboard.view'), ('SUPER_ADMIN', 'dashboard.export'), ('SUPER_ADMIN', 'dashboard.approve'), ('SUPER_ADMIN', 'dashboard.print'),  -- dashboard: VXAP
  ('SUPER_ADMIN', 'showrooms.view'), ('SUPER_ADMIN', 'showrooms.create'), ('SUPER_ADMIN', 'showrooms.edit'), ('SUPER_ADMIN', 'showrooms.delete'),  -- showrooms: VCEDAXP
  ('SUPER_ADMIN', 'showrooms.approve'), ('SUPER_ADMIN', 'showrooms.export'), ('SUPER_ADMIN', 'showrooms.print'),
  ('SUPER_ADMIN', 'users.view'), ('SUPER_ADMIN', 'users.create'), ('SUPER_ADMIN', 'users.edit'), ('SUPER_ADMIN', 'users.delete'),  -- users: VCEDAXP
  ('SUPER_ADMIN', 'users.approve'), ('SUPER_ADMIN', 'users.export'), ('SUPER_ADMIN', 'users.print'),
  ('SUPER_ADMIN', 'roles.view'), ('SUPER_ADMIN', 'roles.create'), ('SUPER_ADMIN', 'roles.edit'), ('SUPER_ADMIN', 'roles.delete'),  -- roles: VCEDAXP
  ('SUPER_ADMIN', 'roles.approve'), ('SUPER_ADMIN', 'roles.export'), ('SUPER_ADMIN', 'roles.print'),
  ('SUPER_ADMIN', 'vehicles.view'), ('SUPER_ADMIN', 'vehicles.create'), ('SUPER_ADMIN', 'vehicles.edit'), ('SUPER_ADMIN', 'vehicles.delete'),  -- vehicles: VCEDAXP
  ('SUPER_ADMIN', 'vehicles.approve'), ('SUPER_ADMIN', 'vehicles.export'), ('SUPER_ADMIN', 'vehicles.print'),
  ('SUPER_ADMIN', 'inventory.view'), ('SUPER_ADMIN', 'inventory.create'), ('SUPER_ADMIN', 'inventory.edit'), ('SUPER_ADMIN', 'inventory.delete'),  -- inventory: VCEDAXP
  ('SUPER_ADMIN', 'inventory.approve'), ('SUPER_ADMIN', 'inventory.export'), ('SUPER_ADMIN', 'inventory.print'),
  ('SUPER_ADMIN', 'purchases.view'), ('SUPER_ADMIN', 'purchases.create'), ('SUPER_ADMIN', 'purchases.edit'), ('SUPER_ADMIN', 'purchases.delete'),  -- purchases: VCEDAXP
  ('SUPER_ADMIN', 'purchases.approve'), ('SUPER_ADMIN', 'purchases.export'), ('SUPER_ADMIN', 'purchases.print'),
  ('SUPER_ADMIN', 'suppliers.view'), ('SUPER_ADMIN', 'suppliers.create'), ('SUPER_ADMIN', 'suppliers.edit'), ('SUPER_ADMIN', 'suppliers.delete'),  -- suppliers: VCEDAXP
  ('SUPER_ADMIN', 'suppliers.approve'), ('SUPER_ADMIN', 'suppliers.export'), ('SUPER_ADMIN', 'suppliers.print'),
  ('SUPER_ADMIN', 'sales.view'), ('SUPER_ADMIN', 'sales.create'), ('SUPER_ADMIN', 'sales.edit'), ('SUPER_ADMIN', 'sales.delete'),  -- sales: VCEDAXP
  ('SUPER_ADMIN', 'sales.approve'), ('SUPER_ADMIN', 'sales.export'), ('SUPER_ADMIN', 'sales.print'),
  ('SUPER_ADMIN', 'customers.view'), ('SUPER_ADMIN', 'customers.create'), ('SUPER_ADMIN', 'customers.edit'), ('SUPER_ADMIN', 'customers.delete'),  -- customers: VCEDAXP
  ('SUPER_ADMIN', 'customers.approve'), ('SUPER_ADMIN', 'customers.export'), ('SUPER_ADMIN', 'customers.print'),
  ('SUPER_ADMIN', 'bookings.view'), ('SUPER_ADMIN', 'bookings.create'), ('SUPER_ADMIN', 'bookings.edit'), ('SUPER_ADMIN', 'bookings.delete'),  -- bookings: VCEDAXP
  ('SUPER_ADMIN', 'bookings.approve'), ('SUPER_ADMIN', 'bookings.export'), ('SUPER_ADMIN', 'bookings.print'),
  ('SUPER_ADMIN', 'finance.view'), ('SUPER_ADMIN', 'finance.create'), ('SUPER_ADMIN', 'finance.edit'), ('SUPER_ADMIN', 'finance.delete'),  -- finance: VCEDAXP
  ('SUPER_ADMIN', 'finance.approve'), ('SUPER_ADMIN', 'finance.export'), ('SUPER_ADMIN', 'finance.print'),
  ('SUPER_ADMIN', 'accounting.view'), ('SUPER_ADMIN', 'accounting.create'), ('SUPER_ADMIN', 'accounting.edit'), ('SUPER_ADMIN', 'accounting.delete'),  -- accounting: VCEDAXP
  ('SUPER_ADMIN', 'accounting.approve'), ('SUPER_ADMIN', 'accounting.export'), ('SUPER_ADMIN', 'accounting.print'),
  ('SUPER_ADMIN', 'expenses.view'), ('SUPER_ADMIN', 'expenses.create'), ('SUPER_ADMIN', 'expenses.edit'), ('SUPER_ADMIN', 'expenses.delete'),  -- expenses: VCEDAXP
  ('SUPER_ADMIN', 'expenses.approve'), ('SUPER_ADMIN', 'expenses.export'), ('SUPER_ADMIN', 'expenses.print'),
  ('SUPER_ADMIN', 'income.view'), ('SUPER_ADMIN', 'income.create'), ('SUPER_ADMIN', 'income.edit'), ('SUPER_ADMIN', 'income.delete'),  -- income: VCEDAXP
  ('SUPER_ADMIN', 'income.approve'), ('SUPER_ADMIN', 'income.export'), ('SUPER_ADMIN', 'income.print'),
  ('SUPER_ADMIN', 'reports.view'), ('SUPER_ADMIN', 'reports.create'), ('SUPER_ADMIN', 'reports.edit'), ('SUPER_ADMIN', 'reports.delete'),  -- reports: VCEDAXP
  ('SUPER_ADMIN', 'reports.approve'), ('SUPER_ADMIN', 'reports.export'), ('SUPER_ADMIN', 'reports.print'),
  ('SUPER_ADMIN', 'documents.view'), ('SUPER_ADMIN', 'documents.create'), ('SUPER_ADMIN', 'documents.edit'), ('SUPER_ADMIN', 'documents.delete'),  -- documents: VCEDAXP
  ('SUPER_ADMIN', 'documents.approve'), ('SUPER_ADMIN', 'documents.export'), ('SUPER_ADMIN', 'documents.print'),
  ('SUPER_ADMIN', 'notifications.view'), ('SUPER_ADMIN', 'notifications.create'), ('SUPER_ADMIN', 'notifications.edit'),  -- notifications: VCE
  ('SUPER_ADMIN', 'audit.view'), ('SUPER_ADMIN', 'audit.export'),  -- audit: VX
  ('SUPER_ADMIN', 'approvals.view'), ('SUPER_ADMIN', 'approvals.create'), ('SUPER_ADMIN', 'approvals.edit'), ('SUPER_ADMIN', 'approvals.delete'),  -- approvals: VCEDAXP
  ('SUPER_ADMIN', 'approvals.approve'), ('SUPER_ADMIN', 'approvals.export'), ('SUPER_ADMIN', 'approvals.print'),
  ('SUPER_ADMIN', 'settings.view'), ('SUPER_ADMIN', 'settings.create'), ('SUPER_ADMIN', 'settings.edit'), ('SUPER_ADMIN', 'settings.delete'),  -- settings: VCEDAXP
  ('SUPER_ADMIN', 'settings.approve'), ('SUPER_ADMIN', 'settings.export'), ('SUPER_ADMIN', 'settings.print'),
  ('SUPER_ADMIN', 'showrooms.view_all'),  -- §3: ALL SHOWROOMS
  -- ADMIN (108)
  ('ADMIN', 'dashboard.view'), ('ADMIN', 'dashboard.export'), ('ADMIN', 'dashboard.approve'), ('ADMIN', 'dashboard.print'),  -- dashboard: VXAP
  ('ADMIN', 'showrooms.view'), ('ADMIN', 'showrooms.create'), ('ADMIN', 'showrooms.edit'), ('ADMIN', 'showrooms.approve'),  -- showrooms: VCEAXP
  ('ADMIN', 'showrooms.export'), ('ADMIN', 'showrooms.print'),
  ('ADMIN', 'users.view'), ('ADMIN', 'users.create'), ('ADMIN', 'users.edit'), ('ADMIN', 'users.approve'),  -- users: VCEAXP
  ('ADMIN', 'users.export'), ('ADMIN', 'users.print'),
  ('ADMIN', 'roles.view'), ('ADMIN', 'roles.export'),  -- roles: VX
  ('ADMIN', 'vehicles.view'), ('ADMIN', 'vehicles.create'), ('ADMIN', 'vehicles.edit'), ('ADMIN', 'vehicles.approve'),  -- vehicles: VCEAXP
  ('ADMIN', 'vehicles.export'), ('ADMIN', 'vehicles.print'),
  ('ADMIN', 'inventory.view'), ('ADMIN', 'inventory.create'), ('ADMIN', 'inventory.edit'), ('ADMIN', 'inventory.approve'),  -- inventory: VCEAXP
  ('ADMIN', 'inventory.export'), ('ADMIN', 'inventory.print'),
  ('ADMIN', 'purchases.view'), ('ADMIN', 'purchases.create'), ('ADMIN', 'purchases.edit'), ('ADMIN', 'purchases.approve'),  -- purchases: VCEAXP
  ('ADMIN', 'purchases.export'), ('ADMIN', 'purchases.print'),
  ('ADMIN', 'suppliers.view'), ('ADMIN', 'suppliers.create'), ('ADMIN', 'suppliers.edit'), ('ADMIN', 'suppliers.approve'),  -- suppliers: VCEAXP
  ('ADMIN', 'suppliers.export'), ('ADMIN', 'suppliers.print'),
  ('ADMIN', 'sales.view'), ('ADMIN', 'sales.create'), ('ADMIN', 'sales.edit'), ('ADMIN', 'sales.approve'),  -- sales: VCEAXP
  ('ADMIN', 'sales.export'), ('ADMIN', 'sales.print'),
  ('ADMIN', 'customers.view'), ('ADMIN', 'customers.create'), ('ADMIN', 'customers.edit'), ('ADMIN', 'customers.approve'),  -- customers: VCEAXP
  ('ADMIN', 'customers.export'), ('ADMIN', 'customers.print'),
  ('ADMIN', 'bookings.view'), ('ADMIN', 'bookings.create'), ('ADMIN', 'bookings.edit'), ('ADMIN', 'bookings.approve'),  -- bookings: VCEAXP
  ('ADMIN', 'bookings.export'), ('ADMIN', 'bookings.print'),
  ('ADMIN', 'finance.view'), ('ADMIN', 'finance.create'), ('ADMIN', 'finance.edit'), ('ADMIN', 'finance.approve'),  -- finance: VCEAXP
  ('ADMIN', 'finance.export'), ('ADMIN', 'finance.print'),
  ('ADMIN', 'accounting.view'), ('ADMIN', 'accounting.export'),  -- accounting: VX
  ('ADMIN', 'expenses.view'), ('ADMIN', 'expenses.create'), ('ADMIN', 'expenses.edit'), ('ADMIN', 'expenses.approve'),  -- expenses: VCEAXP
  ('ADMIN', 'expenses.export'), ('ADMIN', 'expenses.print'),
  ('ADMIN', 'income.view'), ('ADMIN', 'income.create'), ('ADMIN', 'income.edit'), ('ADMIN', 'income.approve'),  -- income: VCEAXP
  ('ADMIN', 'income.export'), ('ADMIN', 'income.print'),
  ('ADMIN', 'reports.view'), ('ADMIN', 'reports.export'), ('ADMIN', 'reports.approve'), ('ADMIN', 'reports.print'),  -- reports: VXAP
  ('ADMIN', 'documents.view'), ('ADMIN', 'documents.create'), ('ADMIN', 'documents.edit'), ('ADMIN', 'documents.approve'),  -- documents: VCEADXP
  ('ADMIN', 'documents.delete'), ('ADMIN', 'documents.export'), ('ADMIN', 'documents.print'),
  ('ADMIN', 'notifications.view'), ('ADMIN', 'notifications.create'), ('ADMIN', 'notifications.edit'),  -- notifications: VCE
  ('ADMIN', 'audit.view'), ('ADMIN', 'audit.export'),  -- audit: VX
  ('ADMIN', 'approvals.view'), ('ADMIN', 'approvals.create'), ('ADMIN', 'approvals.edit'), ('ADMIN', 'approvals.approve'),  -- approvals: VCEAXP
  ('ADMIN', 'approvals.export'), ('ADMIN', 'approvals.print'),
  ('ADMIN', 'settings.view'), ('ADMIN', 'settings.create'), ('ADMIN', 'settings.edit'), ('ADMIN', 'settings.approve'),  -- settings: VCEAXP
  ('ADMIN', 'settings.export'), ('ADMIN', 'settings.print'),
  -- SHOWROOM_MANAGER (58)
  ('SHOWROOM_MANAGER', 'dashboard.view'), ('SHOWROOM_MANAGER', 'dashboard.export'), ('SHOWROOM_MANAGER', 'dashboard.approve'), ('SHOWROOM_MANAGER', 'dashboard.print'),  -- dashboard: VXAP
  ('SHOWROOM_MANAGER', 'showrooms.view'),  -- showrooms: V
  ('SHOWROOM_MANAGER', 'users.view'), ('SHOWROOM_MANAGER', 'users.create'), ('SHOWROOM_MANAGER', 'users.edit'),  -- users: VCE
  ('SHOWROOM_MANAGER', 'vehicles.view'), ('SHOWROOM_MANAGER', 'vehicles.create'), ('SHOWROOM_MANAGER', 'vehicles.edit'),  -- vehicles: VCE
  ('SHOWROOM_MANAGER', 'inventory.view'), ('SHOWROOM_MANAGER', 'inventory.create'), ('SHOWROOM_MANAGER', 'inventory.edit'), ('SHOWROOM_MANAGER', 'inventory.export'),  -- inventory: VCEX
  ('SHOWROOM_MANAGER', 'purchases.view'), ('SHOWROOM_MANAGER', 'purchases.export'),  -- purchases: VX
  ('SHOWROOM_MANAGER', 'suppliers.view'),  -- suppliers: V
  ('SHOWROOM_MANAGER', 'sales.view'), ('SHOWROOM_MANAGER', 'sales.create'), ('SHOWROOM_MANAGER', 'sales.edit'), ('SHOWROOM_MANAGER', 'sales.approve'),  -- sales: VCEAXP
  ('SHOWROOM_MANAGER', 'sales.export'), ('SHOWROOM_MANAGER', 'sales.print'),
  ('SHOWROOM_MANAGER', 'customers.view'), ('SHOWROOM_MANAGER', 'customers.create'), ('SHOWROOM_MANAGER', 'customers.edit'), ('SHOWROOM_MANAGER', 'customers.export'),  -- customers: VCEX
  ('SHOWROOM_MANAGER', 'bookings.view'), ('SHOWROOM_MANAGER', 'bookings.create'), ('SHOWROOM_MANAGER', 'bookings.edit'), ('SHOWROOM_MANAGER', 'bookings.approve'),  -- bookings: VCEAXP
  ('SHOWROOM_MANAGER', 'bookings.export'), ('SHOWROOM_MANAGER', 'bookings.print'),
  ('SHOWROOM_MANAGER', 'finance.view'), ('SHOWROOM_MANAGER', 'finance.export'),  -- finance: VX
  ('SHOWROOM_MANAGER', 'expenses.view'), ('SHOWROOM_MANAGER', 'expenses.create'), ('SHOWROOM_MANAGER', 'expenses.edit'), ('SHOWROOM_MANAGER', 'expenses.approve'),  -- expenses: VCEAX
  ('SHOWROOM_MANAGER', 'expenses.export'),
  ('SHOWROOM_MANAGER', 'income.view'), ('SHOWROOM_MANAGER', 'income.export'),  -- income: VX
  ('SHOWROOM_MANAGER', 'reports.view'), ('SHOWROOM_MANAGER', 'reports.export'), ('SHOWROOM_MANAGER', 'reports.approve'), ('SHOWROOM_MANAGER', 'reports.print'),  -- reports: VXAP
  ('SHOWROOM_MANAGER', 'documents.view'), ('SHOWROOM_MANAGER', 'documents.create'), ('SHOWROOM_MANAGER', 'documents.edit'), ('SHOWROOM_MANAGER', 'documents.export'),  -- documents: VCEX
  ('SHOWROOM_MANAGER', 'notifications.view'), ('SHOWROOM_MANAGER', 'notifications.create'), ('SHOWROOM_MANAGER', 'notifications.edit'),  -- notifications: VCE
  ('SHOWROOM_MANAGER', 'approvals.view'), ('SHOWROOM_MANAGER', 'approvals.export'), ('SHOWROOM_MANAGER', 'approvals.approve'),  -- approvals: VXA (limits)
  ('SHOWROOM_MANAGER', 'settings.view'),  -- settings: V
  -- SALES_MANAGER (44)
  ('SALES_MANAGER', 'dashboard.view'), ('SALES_MANAGER', 'dashboard.export'), ('SALES_MANAGER', 'dashboard.approve'),  -- dashboard: VXA
  ('SALES_MANAGER', 'users.view'),  -- users: V
  ('SALES_MANAGER', 'vehicles.view'),  -- vehicles: V
  ('SALES_MANAGER', 'inventory.view'), ('SALES_MANAGER', 'inventory.export'),  -- inventory: VX
  ('SALES_MANAGER', 'purchases.view'),  -- purchases: V
  ('SALES_MANAGER', 'sales.view'), ('SALES_MANAGER', 'sales.create'), ('SALES_MANAGER', 'sales.edit'), ('SALES_MANAGER', 'sales.approve'),  -- sales: VCEADXP
  ('SALES_MANAGER', 'sales.delete'), ('SALES_MANAGER', 'sales.export'), ('SALES_MANAGER', 'sales.print'),
  ('SALES_MANAGER', 'customers.view'), ('SALES_MANAGER', 'customers.create'), ('SALES_MANAGER', 'customers.edit'), ('SALES_MANAGER', 'customers.export'),  -- customers: VCEX
  ('SALES_MANAGER', 'bookings.view'), ('SALES_MANAGER', 'bookings.create'), ('SALES_MANAGER', 'bookings.edit'), ('SALES_MANAGER', 'bookings.approve'),  -- bookings: VCEAXP
  ('SALES_MANAGER', 'bookings.export'), ('SALES_MANAGER', 'bookings.print'),
  ('SALES_MANAGER', 'finance.view'), ('SALES_MANAGER', 'finance.export'),  -- finance: VX
  ('SALES_MANAGER', 'expenses.view'), ('SALES_MANAGER', 'expenses.export'),  -- expenses: VX
  ('SALES_MANAGER', 'income.view'),  -- income: V
  ('SALES_MANAGER', 'reports.view'), ('SALES_MANAGER', 'reports.export'), ('SALES_MANAGER', 'reports.approve'), ('SALES_MANAGER', 'reports.print'),  -- reports: VXAP
  ('SALES_MANAGER', 'documents.view'), ('SALES_MANAGER', 'documents.create'), ('SALES_MANAGER', 'documents.edit'), ('SALES_MANAGER', 'documents.export'),  -- documents: VCEX
  ('SALES_MANAGER', 'notifications.view'), ('SALES_MANAGER', 'notifications.create'), ('SALES_MANAGER', 'notifications.edit'),  -- notifications: VCE
  ('SALES_MANAGER', 'approvals.view'), ('SALES_MANAGER', 'approvals.export'), ('SALES_MANAGER', 'approvals.approve'),  -- approvals: VXA (discount)
  -- SALES_EXECUTIVE (28)
  ('SALES_EXECUTIVE', 'dashboard.view'), ('SALES_EXECUTIVE', 'dashboard.export'),  -- dashboard: VX (own)
  ('SALES_EXECUTIVE', 'vehicles.view'),  -- vehicles: V
  ('SALES_EXECUTIVE', 'inventory.view'),  -- inventory: V
  ('SALES_EXECUTIVE', 'sales.view'), ('SALES_EXECUTIVE', 'sales.create'), ('SALES_EXECUTIVE', 'sales.edit'), ('SALES_EXECUTIVE', 'sales.export'),  -- sales: VCEX (own)
  ('SALES_EXECUTIVE', 'customers.view'), ('SALES_EXECUTIVE', 'customers.create'), ('SALES_EXECUTIVE', 'customers.edit'), ('SALES_EXECUTIVE', 'customers.export'),  -- customers: VCEX
  ('SALES_EXECUTIVE', 'bookings.view'), ('SALES_EXECUTIVE', 'bookings.create'), ('SALES_EXECUTIVE', 'bookings.edit'), ('SALES_EXECUTIVE', 'bookings.export'),  -- bookings: VCEX
  ('SALES_EXECUTIVE', 'expenses.view'), ('SALES_EXECUTIVE', 'expenses.create'),  -- expenses: VC (request)
  ('SALES_EXECUTIVE', 'reports.view'), ('SALES_EXECUTIVE', 'reports.export'),  -- reports: VX (own)
  ('SALES_EXECUTIVE', 'documents.view'), ('SALES_EXECUTIVE', 'documents.create'), ('SALES_EXECUTIVE', 'documents.edit'),  -- documents: VCE
  ('SALES_EXECUTIVE', 'notifications.view'), ('SALES_EXECUTIVE', 'notifications.create'), ('SALES_EXECUTIVE', 'notifications.edit'),  -- notifications: VCE
  ('SALES_EXECUTIVE', 'approvals.view'), ('SALES_EXECUTIVE', 'approvals.create'),  -- approvals: VC (request)
  -- PURCHASE_MANAGER (39)
  ('PURCHASE_MANAGER', 'dashboard.view'), ('PURCHASE_MANAGER', 'dashboard.export'),  -- dashboard: VX
  ('PURCHASE_MANAGER', 'vehicles.view'), ('PURCHASE_MANAGER', 'vehicles.create'), ('PURCHASE_MANAGER', 'vehicles.edit'),  -- vehicles: VCE
  ('PURCHASE_MANAGER', 'inventory.view'), ('PURCHASE_MANAGER', 'inventory.create'), ('PURCHASE_MANAGER', 'inventory.edit'), ('PURCHASE_MANAGER', 'inventory.export'),  -- inventory: VCEX
  ('PURCHASE_MANAGER', 'purchases.view'), ('PURCHASE_MANAGER', 'purchases.create'), ('PURCHASE_MANAGER', 'purchases.edit'), ('PURCHASE_MANAGER', 'purchases.delete'),  -- purchases: VCEDAXP
  ('PURCHASE_MANAGER', 'purchases.approve'), ('PURCHASE_MANAGER', 'purchases.export'), ('PURCHASE_MANAGER', 'purchases.print'),
  ('PURCHASE_MANAGER', 'suppliers.view'), ('PURCHASE_MANAGER', 'suppliers.create'), ('PURCHASE_MANAGER', 'suppliers.edit'), ('PURCHASE_MANAGER', 'suppliers.approve'),  -- suppliers: VCEAXP
  ('PURCHASE_MANAGER', 'suppliers.export'), ('PURCHASE_MANAGER', 'suppliers.print'),
  ('PURCHASE_MANAGER', 'customers.view'),  -- customers: V
  ('PURCHASE_MANAGER', 'finance.view'), ('PURCHASE_MANAGER', 'finance.export'),  -- finance: VX
  ('PURCHASE_MANAGER', 'expenses.view'), ('PURCHASE_MANAGER', 'expenses.create'),  -- expenses: VC (request)
  ('PURCHASE_MANAGER', 'reports.view'), ('PURCHASE_MANAGER', 'reports.export'), ('PURCHASE_MANAGER', 'reports.approve'),  -- reports: VXA
  ('PURCHASE_MANAGER', 'documents.view'), ('PURCHASE_MANAGER', 'documents.create'), ('PURCHASE_MANAGER', 'documents.edit'),  -- documents: VCE
  ('PURCHASE_MANAGER', 'notifications.view'), ('PURCHASE_MANAGER', 'notifications.create'), ('PURCHASE_MANAGER', 'notifications.edit'),  -- notifications: VCE
  ('PURCHASE_MANAGER', 'approvals.view'), ('PURCHASE_MANAGER', 'approvals.export'), ('PURCHASE_MANAGER', 'approvals.approve'),  -- approvals: VXA (purchase)
  -- INVENTORY_MANAGER (35)
  ('INVENTORY_MANAGER', 'dashboard.view'), ('INVENTORY_MANAGER', 'dashboard.export'),  -- dashboard: VX
  ('INVENTORY_MANAGER', 'vehicles.view'), ('INVENTORY_MANAGER', 'vehicles.create'), ('INVENTORY_MANAGER', 'vehicles.edit'), ('INVENTORY_MANAGER', 'vehicles.approve'),  -- vehicles: VCEAXP
  ('INVENTORY_MANAGER', 'vehicles.export'), ('INVENTORY_MANAGER', 'vehicles.print'),
  ('INVENTORY_MANAGER', 'inventory.view'), ('INVENTORY_MANAGER', 'inventory.create'), ('INVENTORY_MANAGER', 'inventory.edit'), ('INVENTORY_MANAGER', 'inventory.approve'),  -- inventory: VCEAXP
  ('INVENTORY_MANAGER', 'inventory.export'), ('INVENTORY_MANAGER', 'inventory.print'),
  ('INVENTORY_MANAGER', 'purchases.view'), ('INVENTORY_MANAGER', 'purchases.export'),  -- purchases: VX
  ('INVENTORY_MANAGER', 'suppliers.view'),  -- suppliers: V
  ('INVENTORY_MANAGER', 'sales.view'), ('INVENTORY_MANAGER', 'sales.export'),  -- sales: VX
  ('INVENTORY_MANAGER', 'customers.view'),  -- customers: V
  ('INVENTORY_MANAGER', 'bookings.view'),  -- bookings: V
  ('INVENTORY_MANAGER', 'expenses.view'), ('INVENTORY_MANAGER', 'expenses.create'),  -- expenses: VC (request)
  ('INVENTORY_MANAGER', 'reports.view'), ('INVENTORY_MANAGER', 'reports.export'), ('INVENTORY_MANAGER', 'reports.approve'),  -- reports: VXA
  ('INVENTORY_MANAGER', 'documents.view'), ('INVENTORY_MANAGER', 'documents.create'), ('INVENTORY_MANAGER', 'documents.edit'),  -- documents: VCE
  ('INVENTORY_MANAGER', 'notifications.view'), ('INVENTORY_MANAGER', 'notifications.create'), ('INVENTORY_MANAGER', 'notifications.edit'),  -- notifications: VCE
  ('INVENTORY_MANAGER', 'approvals.view'), ('INVENTORY_MANAGER', 'approvals.export'), ('INVENTORY_MANAGER', 'approvals.approve'),  -- approvals: VXA (stock)
  -- ACCOUNTANT (63)
  ('ACCOUNTANT', 'dashboard.view'), ('ACCOUNTANT', 'dashboard.export'), ('ACCOUNTANT', 'dashboard.approve'), ('ACCOUNTANT', 'dashboard.print'),  -- dashboard: VXAP
  ('ACCOUNTANT', 'showrooms.view'),  -- showrooms: V
  ('ACCOUNTANT', 'users.view'),  -- users: V
  ('ACCOUNTANT', 'vehicles.view'),  -- vehicles: V
  ('ACCOUNTANT', 'inventory.view'), ('ACCOUNTANT', 'inventory.export'),  -- inventory: VX
  ('ACCOUNTANT', 'purchases.view'), ('ACCOUNTANT', 'purchases.export'),  -- purchases: VX
  ('ACCOUNTANT', 'suppliers.view'), ('ACCOUNTANT', 'suppliers.create'), ('ACCOUNTANT', 'suppliers.edit'), ('ACCOUNTANT', 'suppliers.export'),  -- suppliers: VCEX
  ('ACCOUNTANT', 'sales.view'), ('ACCOUNTANT', 'sales.export'),  -- sales: VX
  ('ACCOUNTANT', 'customers.view'), ('ACCOUNTANT', 'customers.export'),  -- customers: VX
  ('ACCOUNTANT', 'bookings.view'), ('ACCOUNTANT', 'bookings.export'),  -- bookings: VX
  ('ACCOUNTANT', 'finance.view'), ('ACCOUNTANT', 'finance.create'), ('ACCOUNTANT', 'finance.edit'), ('ACCOUNTANT', 'finance.delete'),  -- finance: VCEDAXP
  ('ACCOUNTANT', 'finance.approve'), ('ACCOUNTANT', 'finance.export'), ('ACCOUNTANT', 'finance.print'),
  ('ACCOUNTANT', 'accounting.view'), ('ACCOUNTANT', 'accounting.create'), ('ACCOUNTANT', 'accounting.edit'), ('ACCOUNTANT', 'accounting.approve'),  -- accounting: VCEAXP
  ('ACCOUNTANT', 'accounting.export'), ('ACCOUNTANT', 'accounting.print'),
  ('ACCOUNTANT', 'expenses.view'), ('ACCOUNTANT', 'expenses.create'), ('ACCOUNTANT', 'expenses.edit'), ('ACCOUNTANT', 'expenses.approve'),  -- expenses: VCEAXP
  ('ACCOUNTANT', 'expenses.export'), ('ACCOUNTANT', 'expenses.print'),
  ('ACCOUNTANT', 'income.view'), ('ACCOUNTANT', 'income.create'), ('ACCOUNTANT', 'income.edit'), ('ACCOUNTANT', 'income.approve'),  -- income: VCEAXP
  ('ACCOUNTANT', 'income.export'), ('ACCOUNTANT', 'income.print'),
  ('ACCOUNTANT', 'reports.view'), ('ACCOUNTANT', 'reports.export'), ('ACCOUNTANT', 'reports.approve'), ('ACCOUNTANT', 'reports.print'),  -- reports: VXAP
  ('ACCOUNTANT', 'documents.view'), ('ACCOUNTANT', 'documents.create'), ('ACCOUNTANT', 'documents.edit'), ('ACCOUNTANT', 'documents.export'),  -- documents: VCEX
  ('ACCOUNTANT', 'notifications.view'), ('ACCOUNTANT', 'notifications.create'), ('ACCOUNTANT', 'notifications.edit'),  -- notifications: VCE
  ('ACCOUNTANT', 'audit.view'), ('ACCOUNTANT', 'audit.export'),  -- audit: VX
  ('ACCOUNTANT', 'approvals.view'), ('ACCOUNTANT', 'approvals.export'), ('ACCOUNTANT', 'approvals.approve'),  -- approvals: VXA (finance)
  ('ACCOUNTANT', 'settings.view'),  -- settings: V (limited)
  -- CASHIER (34)
  ('CASHIER', 'dashboard.view'), ('CASHIER', 'dashboard.export'),  -- dashboard: VX
  ('CASHIER', 'vehicles.view'),  -- vehicles: V
  ('CASHIER', 'inventory.view'),  -- inventory: V
  ('CASHIER', 'purchases.view'),  -- purchases: V
  ('CASHIER', 'suppliers.view'),  -- suppliers: V
  ('CASHIER', 'sales.view'), ('CASHIER', 'sales.create'), ('CASHIER', 'sales.export'),  -- sales: VCX
  ('CASHIER', 'customers.view'), ('CASHIER', 'customers.create'), ('CASHIER', 'customers.edit'),  -- customers: VCE
  ('CASHIER', 'bookings.view'), ('CASHIER', 'bookings.create'),  -- bookings: VC
  ('CASHIER', 'finance.view'), ('CASHIER', 'finance.create'), ('CASHIER', 'finance.edit'), ('CASHIER', 'finance.export'),  -- finance: VCEX
  ('CASHIER', 'expenses.view'), ('CASHIER', 'expenses.create'), ('CASHIER', 'expenses.edit'),  -- expenses: VCE
  ('CASHIER', 'income.view'), ('CASHIER', 'income.create'),  -- income: VC
  ('CASHIER', 'reports.view'), ('CASHIER', 'reports.export'), ('CASHIER', 'reports.approve'), ('CASHIER', 'reports.print'),  -- reports: VXAP
  ('CASHIER', 'documents.view'), ('CASHIER', 'documents.create'), ('CASHIER', 'documents.edit'),  -- documents: VCE
  ('CASHIER', 'notifications.view'), ('CASHIER', 'notifications.create'), ('CASHIER', 'notifications.edit'),  -- notifications: VCE
  ('CASHIER', 'approvals.view'),  -- approvals: V (request)
  -- SERVICE_MANAGER (31)
  ('SERVICE_MANAGER', 'dashboard.view'), ('SERVICE_MANAGER', 'dashboard.export'),  -- dashboard: VX
  ('SERVICE_MANAGER', 'vehicles.view'),  -- vehicles: V
  ('SERVICE_MANAGER', 'inventory.view'), ('SERVICE_MANAGER', 'inventory.create'), ('SERVICE_MANAGER', 'inventory.edit'),  -- inventory: VCE
  ('SERVICE_MANAGER', 'purchases.view'),  -- purchases: V
  ('SERVICE_MANAGER', 'sales.view'),  -- sales: V
  ('SERVICE_MANAGER', 'customers.view'), ('SERVICE_MANAGER', 'customers.create'), ('SERVICE_MANAGER', 'customers.edit'), ('SERVICE_MANAGER', 'customers.export'),  -- customers: VCEX
  ('SERVICE_MANAGER', 'bookings.view'),  -- bookings: V
  ('SERVICE_MANAGER', 'finance.view'), ('SERVICE_MANAGER', 'finance.create'),  -- finance: VC
  ('SERVICE_MANAGER', 'expenses.view'), ('SERVICE_MANAGER', 'expenses.create'),  -- expenses: VC (request)
  ('SERVICE_MANAGER', 'income.view'), ('SERVICE_MANAGER', 'income.create'), ('SERVICE_MANAGER', 'income.edit'),  -- income: VCE
  ('SERVICE_MANAGER', 'reports.view'), ('SERVICE_MANAGER', 'reports.export'), ('SERVICE_MANAGER', 'reports.approve'),  -- reports: VXA
  ('SERVICE_MANAGER', 'documents.view'), ('SERVICE_MANAGER', 'documents.create'), ('SERVICE_MANAGER', 'documents.edit'),  -- documents: VCE
  ('SERVICE_MANAGER', 'notifications.view'), ('SERVICE_MANAGER', 'notifications.create'), ('SERVICE_MANAGER', 'notifications.edit'),  -- notifications: VCE
  ('SERVICE_MANAGER', 'approvals.view'), ('SERVICE_MANAGER', 'approvals.create'),  -- approvals: VC
  -- VIEWER (16)
  ('VIEWER', 'dashboard.view'), ('VIEWER', 'dashboard.export'),  -- dashboard: VX
  ('VIEWER', 'vehicles.view'),  -- vehicles: V
  ('VIEWER', 'inventory.view'), ('VIEWER', 'inventory.export'),  -- inventory: VX
  ('VIEWER', 'sales.view'), ('VIEWER', 'sales.export'),  -- sales: VX
  ('VIEWER', 'customers.view'), ('VIEWER', 'customers.export'),  -- customers: VX
  ('VIEWER', 'bookings.view'), ('VIEWER', 'bookings.export'),  -- bookings: VX
  ('VIEWER', 'accounting.view'),  -- accounting: V
  ('VIEWER', 'reports.view'), ('VIEWER', 'reports.export'),  -- reports: VX
  ('VIEWER', 'documents.view'),  -- documents: V
  ('VIEWER', 'notifications.view')  -- notifications: V
;

select set_eq(
  $$ select r.code, p.code
       from public.role_permissions rp
       join public.roles r on r.id = rp.role_id
       join public.permissions p on p.id = rp.permission_id
      where r.is_system $$,
  $$ select role_code, permission_code from doc_matrix $$,
  'matrix: role_permissions of the system roles equal 02-roles-permissions §4 exactly'
);

-- Per-role totals counted from the document cells (independent of doc_matrix).
select set_eq(
  $$ select r.code, count(*)::int
       from public.role_permissions rp
       join public.roles r on r.id = rp.role_id
      where r.is_system
      group by r.code $$,
  $$ values ('SUPER_ADMIN', 136), ('ADMIN', 108), ('SHOWROOM_MANAGER', 58),
            ('SALES_MANAGER', 44), ('SALES_EXECUTIVE', 28), ('PURCHASE_MANAGER', 39),
            ('INVENTORY_MANAGER', 35), ('ACCOUNTANT', 63), ('CASHIER', 34),
            ('SERVICE_MANAGER', 31), ('VIEWER', 16) $$,
  'matrix: per-role grant counts match the document'
);

select is(
  (select count(*)::int
     from public.role_permissions rp
     join public.roles r on r.id = rp.role_id
    where r.is_system),
  592,
  'matrix: 592 grants in total for the 11 system roles'
);

-- -----------------------------------------------------------------------------
-- 5. Matrix invariants (8)
-- -----------------------------------------------------------------------------
select is_empty(
  $$ select p.code
       from public.role_permissions rp
       join public.roles r on r.id = rp.role_id
       join public.permissions p on p.id = rp.permission_id
      where r.code = 'VIEWER'
        and p.action in ('create', 'edit', 'delete', 'approve') $$,
  'invariant: VIEWER has no create / edit / delete / approve grant'
);

select set_eq(
  $$ select r.code
       from public.role_permissions rp
       join public.roles r on r.id = rp.role_id
       join public.permissions p on p.id = rp.permission_id
      where p.code = 'roles.delete' $$,
  $$ values ('SUPER_ADMIN') $$,
  'invariant: only SUPER_ADMIN has roles.delete'
);

select set_eq(
  $$ select r.code
       from public.role_permissions rp
       join public.roles r on r.id = rp.role_id
       join public.permissions p on p.id = rp.permission_id
      where p.code = 'showrooms.view_all' $$,
  $$ values ('SUPER_ADMIN') $$,
  'invariant: only SUPER_ADMIN has showrooms.view_all (ALL SHOWROOMS)'
);

select set_eq(
  $$ select r.code
       from public.role_permissions rp
       join public.roles r on r.id = rp.role_id
       join public.permissions p on p.id = rp.permission_id
      where p.code = 'accounting.delete' $$,
  $$ values ('SUPER_ADMIN') $$,
  'invariant: only SUPER_ADMIN has accounting.delete'
);

select ok(
  not exists (
    select 1
      from public.role_permissions rp
      join public.roles r on r.id = rp.role_id
      join public.permissions p on p.id = rp.permission_id
     where r.code = 'ADMIN' and p.code = 'roles.create'
  ),
  'invariant: ADMIN does not have roles.create (roles: VX)'
);

select ok(
  exists (
    select 1
      from public.role_permissions rp
      join public.roles r on r.id = rp.role_id
      join public.permissions p on p.id = rp.permission_id
     where r.code = 'SALES_MANAGER' and p.code = 'sales.delete'
  ),
  'invariant: SALES_MANAGER has sales.delete (sales: VCEADXP)'
);

select ok(
  exists (
    select 1
      from public.role_permissions rp
      join public.roles r on r.id = rp.role_id
      join public.permissions p on p.id = rp.permission_id
     where r.code = 'ACCOUNTANT' and p.code = 'finance.delete'
  ),
  'invariant: ACCOUNTANT has finance.delete (finance: VCEDAXP)'
);

select ok(
  not exists (
    select 1
      from public.role_permissions rp
      join public.roles r on r.id = rp.role_id
      join public.permissions p on p.id = rp.permission_id
     where r.code = 'ACCOUNTANT' and p.code = 'accounting.delete'
  ),
  'invariant: ACCOUNTANT does not have accounting.delete (accounting: VCEAXP)'
);

-- -----------------------------------------------------------------------------
-- 6. Company settings (4)
-- -----------------------------------------------------------------------------
select set_eq(
  $$ select key, value_type::text, is_client_readable
       from public.settings
      where key in ('company.name', 'company.currency_code', 'company.locale',
                    'company.timezone', 'ui.default_theme_mode',
                    'security.signed_url_ttl_seconds') $$,
  $$ values ('company.name', 'string', true),
            ('company.currency_code', 'string', true),
            ('company.locale', 'string', true),
            ('company.timezone', 'string', true),
            ('ui.default_theme_mode', 'string', true),
            ('security.signed_url_ttl_seconds', 'number', false) $$,
  'settings: the 6 company settings exist with the expected value_type and client visibility'
);

select is(
  (select value #>> '{}' from public.settings where key = 'company.timezone'),
  'Asia/Kolkata'::text,
  'settings: company.timezone is Asia/Kolkata'
);

select ok(
  (select not is_client_readable from public.settings where key = 'security.signed_url_ttl_seconds'),
  'settings: security.signed_url_ttl_seconds is not client readable'
);

select ok(
  (select (value #>> '{}')::numeric between 1 and 900
     from public.settings
    where key = 'security.signed_url_ttl_seconds'),
  'settings: signed URL lifetime is positive and at most 900 s (15 minutes)'
);

-- -----------------------------------------------------------------------------
-- 7. Current Indian financial year (5)
-- -----------------------------------------------------------------------------
select is(
  (select count(*)::int
     from public.financial_years fy
    where fy.code = public.fn_fy_code(public.fn_business_date())
      and fy.start_date = public.fn_fy_start_date(public.fn_business_date())
      and fy.end_date = (fy.start_date + interval '1 year' - interval '1 day')::date),
  1,
  'financial year: the current FY exists and runs 1 April - 31 March'
);

select ok(
  (select fy.is_active and not fy.is_closed
     from public.financial_years fy
    where fy.code = public.fn_fy_code(public.fn_business_date())),
  'financial year: the current FY is active and not closed'
);

select is(
  (select count(*)::int
     from public.accounting_periods ap
     join public.financial_years fy on fy.id = ap.financial_year_id
    where fy.code = public.fn_fy_code(public.fn_business_date())),
  12,
  'financial year: the current FY has 12 accounting periods'
);

select is_empty(
  $$ select ap.period_no
       from public.accounting_periods ap
       join public.financial_years fy on fy.id = ap.financial_year_id
      where fy.code = public.fn_fy_code(public.fn_business_date())
        and ap.status <> 'open' $$,
  'financial year: every period of the current FY is open'
);

select set_eq(
  $$ select ap.period_no::int, ap.start_date, ap.end_date
       from public.accounting_periods ap
       join public.financial_years fy on fy.id = ap.financial_year_id
      where fy.code = public.fn_fy_code(public.fn_business_date()) $$,
  $$ select g.p,
            (x.fy_start + make_interval(months => g.p - 1))::date,
            (x.fy_start + make_interval(months => g.p))::date - 1
       from generate_series(1, 12) as g (p)
      cross join (select public.fn_fy_start_date(public.fn_business_date()) as fy_start) as x $$,
  'financial year: period 1 = April ... period 12 = March, each a whole calendar month'
);

select * from finish();

rollback;
