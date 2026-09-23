-- =============================================================================
-- MyBike · Phase 3 · 0004 — reference data (all environments)
-- -----------------------------------------------------------------------------
-- Idempotent: every statement can be re-run without duplicates or errors.
-- Contents: GST states, permission catalogue, 11 system roles, the module ×
-- role matrix, company settings, the current Indian financial year.
--
-- Renumbered from the Phase 0 plan's 0007 so that Phase 4 migrations
-- (0005 RBAC functions + RLS, 0006 …) sort after it — `supabase db push`
-- refuses migrations older than the last applied one.
-- Chart of accounts, expense/income categories and HSN/SAC defaults are
-- seeded together with their tables (Phases 8, 12, 13) — they do not exist yet.
-- Demo showrooms and users are dev-only and live in supabase/seed.sql.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. GST state codes (place of supply). Migration-owned reference data:
--    re-running corrects names/flags.
-- -----------------------------------------------------------------------------
insert into public.states (code, name, is_union_territory, is_active)
values
  ('01', 'Jammu and Kashmir', true, true),
  ('02', 'Himachal Pradesh', false, true),
  ('03', 'Punjab', false, true),
  ('04', 'Chandigarh', true, true),
  ('05', 'Uttarakhand', false, true),
  ('06', 'Haryana', false, true),
  ('07', 'Delhi', true, true),
  ('08', 'Rajasthan', false, true),
  ('09', 'Uttar Pradesh', false, true),
  ('10', 'Bihar', false, true),
  ('11', 'Sikkim', false, true),
  ('12', 'Arunachal Pradesh', false, true),
  ('13', 'Nagaland', false, true),
  ('14', 'Manipur', false, true),
  ('15', 'Mizoram', false, true),
  ('16', 'Tripura', false, true),
  ('17', 'Meghalaya', false, true),
  ('18', 'Assam', false, true),
  ('19', 'West Bengal', false, true),
  ('20', 'Jharkhand', false, true),
  ('21', 'Odisha', false, true),
  ('22', 'Chhattisgarh', false, true),
  ('23', 'Madhya Pradesh', false, true),
  ('24', 'Gujarat', false, true),
  ('25', 'Daman and Diu (merged into 26)', true, false),
  ('26', 'Dadra and Nagar Haveli and Daman and Diu', true, true),
  ('27', 'Maharashtra', false, true),
  ('28', 'Andhra Pradesh (before division)', false, false),
  ('29', 'Karnataka', false, true),
  ('30', 'Goa', false, true),
  ('31', 'Lakshadweep', true, true),
  ('32', 'Kerala', false, true),
  ('33', 'Tamil Nadu', false, true),
  ('34', 'Puducherry', true, true),
  ('35', 'Andaman and Nicobar Islands', true, true),
  ('36', 'Telangana', false, true),
  ('37', 'Andhra Pradesh', false, true),
  ('38', 'Ladakh', true, true),
  ('97', 'Other Territory', false, true)
on conflict (code) do update
  set name               = excluded.name,
      is_union_territory = excluded.is_union_territory,
      is_active          = excluded.is_active;

-- -----------------------------------------------------------------------------
-- 2. Permission catalogue: 21 modules × 7 actions + showrooms.view_all = 148
-- -----------------------------------------------------------------------------
insert into public.permissions (module, action, description)
select m.module,
       a.action,
       a.label || ' ' || replace(m.module, '_', ' ')
  from unnest(array[
         'dashboard', 'showrooms', 'users', 'roles', 'vehicles', 'inventory', 'purchases',
         'suppliers', 'sales', 'customers', 'bookings', 'finance', 'accounting', 'expenses',
         'income', 'reports', 'documents', 'notifications', 'audit', 'settings', 'approvals'
       ]) as m (module)
 cross join (values
         ('view', 'View'), ('create', 'Create'), ('edit', 'Edit'), ('delete', 'Delete'),
         ('approve', 'Approve'), ('export', 'Export'), ('print', 'Print')
       ) as a (action, label)
on conflict (module, action) do nothing;

insert into public.permissions (module, action, description)
values ('showrooms', 'view_all', 'View ALL SHOWROOMS (consolidated mode)')
on conflict (module, action) do nothing;

-- -----------------------------------------------------------------------------
-- 3. System roles (02-roles-permissions.md §1). Existing rows are left alone
--    so Phase 6 edits (name/description/precedence) survive a re-run.
-- -----------------------------------------------------------------------------
insert into public.roles (code, name, description, is_system, precedence)
values
  ('SUPER_ADMIN', 'Super Admin', 'Owner. Everything incl. showroom creation, roles, settings and consolidated reports (ALL SHOWROOMS).', true, 100),
  ('ADMIN', 'Administrator', 'Master data, users, approvals and reports. Cannot delete posted financial entries.', true, 90),
  ('SHOWROOM_MANAGER', 'Showroom Manager', 'Runs a showroom: approvals within limits, stock, sales and purchase supervision.', true, 80),
  ('SALES_MANAGER', 'Sales Manager', 'Sales targets, discount approval, booking and sale supervision, sales reports.', true, 70),
  ('PURCHASE_MANAGER', 'Purchase Manager', 'Suppliers, purchase orders, GRN, purchase invoices, purchase payment requests, returns.', true, 70),
  ('INVENTORY_MANAGER', 'Inventory Manager', 'Vehicle master, stock receiving, transfers, adjustments, valuation and ageing.', true, 70),
  ('ACCOUNTANT', 'Accountant', 'Chart of accounts, journals, payments and receipts, expense posting, ledgers, statutory reports.', true, 70),
  ('SERVICE_MANAGER', 'Service Manager', 'Service income entries, spare issue, service customer records.', true, 70),
  ('SALES_EXECUTIVE', 'Sales Executive', 'Customers, quotations, bookings and sales entry (own records), document upload.', true, 50),
  ('CASHIER', 'Cashier', 'Receipts and collections, day book, expense payment, cash handover.', true, 50),
  ('VIEWER', 'Viewer / Auditor', 'Read-only access to permitted modules; export where granted.', true, 10)
on conflict (code) do nothing;

-- -----------------------------------------------------------------------------
-- 4. Module × role matrix (02-roles-permissions.md §4), one row per module in
--    the same column order as the document. Letters: V view, C create,
--    E edit, D delete, A approve, X export, P print; '' = no access.
--    Qualifiers such as "(own)" or "(request)" are row-level rules enforced by
--    later phases; the grant itself is the letter set.
-- -----------------------------------------------------------------------------
with matrix (module, super_admin, admin, showroom_manager, sales_manager, sales_executive,
             purchase_manager, inventory_manager, accountant, cashier, service_manager, viewer) as (
  values
    ('dashboard',     'VXAP',    'VXAP',    'VXAP',   'VXA',     'VX',   'VX',      'VX',     'VXAP',    'VX',   'VX',   'VX'),
    ('showrooms',     'VCEDAXP', 'VCEAXP',  'V',      '',        '',     '',        '',       'V',       '',     '',     ''),
    ('users',         'VCEDAXP', 'VCEAXP',  'VCE',    'V',       '',     '',        '',       'V',       '',     '',     ''),
    ('roles',         'VCEDAXP', 'VX',      '',       '',        '',     '',        '',       '',        '',     '',     ''),
    ('vehicles',      'VCEDAXP', 'VCEAXP',  'VCE',    'V',       'V',    'VCE',     'VCEAXP', 'V',       'V',    'V',    'V'),
    ('inventory',     'VCEDAXP', 'VCEAXP',  'VCEX',   'VX',      'V',    'VCEX',    'VCEAXP', 'VX',      'V',    'VCE',  'VX'),
    ('purchases',     'VCEDAXP', 'VCEAXP',  'VX',     'V',       '',     'VCEDAXP', 'VX',     'VX',      'V',    'V',    ''),
    ('suppliers',     'VCEDAXP', 'VCEAXP',  'V',      '',        '',     'VCEAXP',  'V',      'VCEX',    'V',    '',     ''),
    ('sales',         'VCEDAXP', 'VCEAXP',  'VCEAXP', 'VCEADXP', 'VCEX', '',        'VX',     'VX',      'VCX',  'V',    'VX'),
    ('customers',     'VCEDAXP', 'VCEAXP',  'VCEX',   'VCEX',    'VCEX', 'V',       'V',      'VX',      'VCE',  'VCEX', 'VX'),
    ('bookings',      'VCEDAXP', 'VCEAXP',  'VCEAXP', 'VCEAXP',  'VCEX', '',        'V',      'VX',      'VC',   'V',    'VX'),
    ('finance',       'VCEDAXP', 'VCEAXP',  'VX',     'VX',      '',     'VX',      '',       'VCEDAXP', 'VCEX', 'VC',   ''),
    ('accounting',    'VCEDAXP', 'VX',      '',       '',        '',     '',        '',       'VCEAXP',  '',     '',     'V'),
    ('expenses',      'VCEDAXP', 'VCEAXP',  'VCEAX',  'VX',      'VC',   'VC',      'VC',     'VCEAXP',  'VCE',  'VC',   ''),
    ('income',        'VCEDAXP', 'VCEAXP',  'VX',     'V',       '',     '',        '',       'VCEAXP',  'VC',   'VCE',  ''),
    ('reports',       'VCEDAXP', 'VXAP',    'VXAP',   'VXAP',    'VX',   'VXA',     'VXA',    'VXAP',    'VXAP', 'VXA',  'VX'),
    ('documents',     'VCEDAXP', 'VCEADXP', 'VCEX',   'VCEX',    'VCE',  'VCE',     'VCE',    'VCEX',    'VCE',  'VCE',  'V'),
    ('notifications', 'VCE',     'VCE',     'VCE',    'VCE',     'VCE',  'VCE',     'VCE',    'VCE',     'VCE',  'VCE',  'V'),
    ('audit',         'VX',      'VX',      '',       '',        '',     '',        '',       'VX',      '',     '',     ''),
    ('approvals',     'VCEDAXP', 'VCEAXP',  'VXA',    'VXA',     'VC',   'VXA',     'VXA',    'VXA',     'V',    'VC',   ''),
    ('settings',      'VCEDAXP', 'VCEAXP',  'V',      '',        '',     '',        '',       'V',       '',     '',     '')
),
grants (module, role_code, letters) as (
  select m.module, g.role_code, g.letters
    from matrix m
   cross join lateral (values
           ('SUPER_ADMIN', m.super_admin),
           ('ADMIN', m.admin),
           ('SHOWROOM_MANAGER', m.showroom_manager),
           ('SALES_MANAGER', m.sales_manager),
           ('SALES_EXECUTIVE', m.sales_executive),
           ('PURCHASE_MANAGER', m.purchase_manager),
           ('INVENTORY_MANAGER', m.inventory_manager),
           ('ACCOUNTANT', m.accountant),
           ('CASHIER', m.cashier),
           ('SERVICE_MANAGER', m.service_manager),
           ('VIEWER', m.viewer)
         ) as g (role_code, letters)
),
letters (letter, action) as (
  values ('V', 'view'), ('C', 'create'), ('E', 'edit'), ('D', 'delete'),
         ('A', 'approve'), ('X', 'export'), ('P', 'print')
)
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from grants g
  join letters l on strpos(g.letters, l.letter) > 0
  join public.roles r on r.code = g.role_code
  join public.permissions p on p.module = g.module and p.action = l.action
on conflict (role_id, permission_id) do nothing;

-- ALL SHOWROOMS mode (02-roles-permissions §3) — Super Admin only.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
  from public.roles r
  join public.permissions p on p.module = 'showrooms' and p.action = 'view_all'
 where r.code = 'SUPER_ADMIN'
on conflict (role_id, permission_id) do nothing;

-- -----------------------------------------------------------------------------
-- 5. Company settings (values are edited later by Super Admin; a re-run never
--    overwrites them)
-- -----------------------------------------------------------------------------
insert into public.settings (key, value, value_type, is_client_readable, description)
values
  ('company.name', '"MyBike"', 'string', true, 'Trading name shown in the app header, invoices and reports.'),
  ('company.currency_code', '"INR"', 'string', true, 'ISO 4217 currency of all money columns.'),
  ('company.locale', '"en_IN"', 'string', true, 'Formatting locale (Indian digit grouping, dates).'),
  ('company.timezone', '"Asia/Kolkata"', 'string', true, 'Business time zone; document dates and financial years are decided in this zone.'),
  ('ui.default_theme_mode', '"system"', 'string', true, 'Theme used until the user picks one: light, dark or system.'),
  ('security.signed_url_ttl_seconds', '900', 'number', false, 'Lifetime of storage signed URLs (≤ 15 minutes, 04-multishowroom-security §5).')
on conflict (key) do nothing;

-- -----------------------------------------------------------------------------
-- 6. Current Indian financial year (+ 12 open periods). Numbering series are
--    created for every showroom by fn_ensure_financial_year / the showroom
--    bootstrap trigger.
-- -----------------------------------------------------------------------------
select public.fn_ensure_financial_year(public.fn_business_date());
