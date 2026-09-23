-- =============================================================================
-- MyBike · Phase 3 · 0001 — extensions, enum types, shared helper functions
-- -----------------------------------------------------------------------------
-- Design: docs/phase-00/05-database-plan.md §1–§3, docs/phase-03/README.md
--
-- Conventions applied by every MyBike migration:
--   * extensions live in the `extensions` schema (Supabase convention);
--   * every function pins `search_path = ''` and schema-qualifies objects;
--   * `anon` never receives privileges on application objects;
--   * `authenticated` never receives TRUNCATE / REFERENCES / TRIGGER
--     (TRUNCATE is not subject to RLS);
--   * functions are NOT executable by PUBLIC/anon/authenticated unless a
--     migration grants it explicitly.
-- Custom SQLSTATEs raised by MyBike functions use the `MB` class; the
-- catalogue lives in docs/phase-03/README.md §5 and is mapped by the
-- Flutter ErrorMapper (never shown raw to users).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Extensions
-- -----------------------------------------------------------------------------
-- pgcrypto: pre-installed on Supabase; declared so local stacks match and the
-- dev seed can hash passwords with extensions.crypt().
create extension if not exists pgcrypto with schema extensions;
-- citext: case-insensitive e-mail comparisons / uniqueness.
create extension if not exists citext with schema extensions;
-- pg_trgm: trigram indexes for fuzzy search (profiles.full_name today,
-- vehicles/customers/items in later phases).
create extension if not exists pg_trgm with schema extensions;

-- -----------------------------------------------------------------------------
-- 2. Default privileges — safety net for every future object in `public`
-- -----------------------------------------------------------------------------
-- Supabase's default privileges grant ALL on new public objects to anon,
-- authenticated and service_role. MyBike exposes nothing to anon, and RLS is
-- the authority for authenticated. Per-schema defaults can only remove what a
-- per-schema default added, so PUBLIC's built-in EXECUTE on functions is
-- revoked per function at the end of each migration instead.
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on functions from anon;
alter default privileges in schema public
  revoke truncate, references, trigger on tables from authenticated;

-- -----------------------------------------------------------------------------
-- 3. Enum types (only the closed sets used by Phase 3 tables; later phases add
--    their own enums together with their tables)
-- -----------------------------------------------------------------------------
create type public.user_status as enum ('invited', 'active', 'suspended', 'deactivated');
comment on type public.user_status is
  'Lifecycle of an application user. Only ''active'' users can access data (profiles.is_active).';

create type public.accounting_period_status as enum ('open', 'locked', 'closed');
comment on type public.accounting_period_status is
  'Posting is allowed only into ''open'' periods (enforced by posting functions from Phase 12).';

create type public.stock_valuation_method as enum ('specific_id', 'weighted_avg');
comment on type public.stock_valuation_method is
  'Inventory valuation: specific identification (vehicles) or weighted average (spares).';

create type public.setting_value_type as enum ('string', 'number', 'boolean', 'json');
comment on type public.setting_value_type is
  'JSON type expected in settings.value; enforced by a CHECK constraint.';

create type public.document_sequence_type as enum (
  'sales_invoice',
  'purchase_invoice',
  'purchase_order',
  'goods_receipt',
  'purchase_return',
  'quotation',
  'booking',
  'sales_order',
  'delivery_note',
  'sales_return',
  'payment',
  'receipt',
  'credit_note',
  'debit_note',
  'contra',
  'expense',
  'income',
  'journal',
  'stock_transfer',
  'stock_adjustment'
);
comment on type public.document_sequence_type is
  'Document series numbered per showroom per financial year by fn_next_document_number().';

-- -----------------------------------------------------------------------------
-- 4. Shared trigger functions
-- -----------------------------------------------------------------------------

-- Maintains updated_at on every UPDATE.
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
comment on function public.set_updated_at() is
  'BEFORE UPDATE trigger: stamps updated_at = now().';

-- Stamps created_by / updated_by from the JWT subject and makes creation
-- metadata immutable. Client-supplied values are ignored for end-user
-- requests (auth.uid() present); trusted server contexts without a JWT
-- (migrations, service_role, cron) may pass explicit values.
create function public.set_created_by()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if tg_op = 'INSERT' then
    if v_uid is not null then
      -- End users can neither back-date rows nor attribute them to someone else.
      new.created_at := now();
      new.created_by := v_uid;
      new.updated_by := v_uid;
    else
      new.updated_by := coalesce(new.updated_by, new.created_by);
    end if;
  elsif tg_op = 'UPDATE' then
    new.created_at := old.created_at;
    new.created_by := old.created_by;
    if v_uid is not null then
      new.updated_by := v_uid;
    end if;
  end if;
  return new;
end;
$$;
comment on function public.set_created_by() is
  'BEFORE INSERT/UPDATE trigger: created_by/updated_by come from auth.uid(), never from the client payload; created_at/created_by are immutable.';

-- Stamps granted_by / granted_at on grant rows (role_permissions, user_roles,
-- user_showrooms) and keeps them immutable afterwards.
create function public.fn_set_granted_by()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if tg_op = 'INSERT' then
    new.granted_at := now();
    if v_uid is not null then
      new.granted_by := v_uid;
    end if;
  elsif tg_op = 'UPDATE' then
    new.granted_at := old.granted_at;
    new.granted_by := old.granted_by;
  end if;
  return new;
end;
$$;
comment on function public.fn_set_granted_by() is
  'BEFORE INSERT/UPDATE trigger: granted_by comes from auth.uid(); grant metadata is immutable.';

-- -----------------------------------------------------------------------------
-- 5. Indian financial-year helpers (G10: 1 April – 31 March)
-- -----------------------------------------------------------------------------

-- Business date in India. Supabase sessions run in UTC; a document created at
-- 00:30 IST on 1 April belongs to the new financial year, so date defaults in
-- MyBike use this function rather than current_date.
create function public.fn_business_date(p_at timestamptz default now())
returns date
language sql
stable
set search_path = ''
as $$
  select (p_at at time zone 'Asia/Kolkata')::date;
$$;
comment on function public.fn_business_date(timestamptz) is
  'Calendar date in Asia/Kolkata for the given instant (default now()).';

-- First day (1 April) of the financial year containing p_date.
create function public.fn_fy_start_date(p_date date)
returns date
language sql
immutable
strict
set search_path = ''
as $$
  select make_date(
    case when extract(month from p_date)::int >= 4
         then extract(year from p_date)::int
         else extract(year from p_date)::int - 1
    end,
    4,
    1
  );
$$;
comment on function public.fn_fy_start_date(date) is
  'Start date (1 April) of the Indian financial year containing the date.';

-- Financial-year code, e.g. 2026-09-23 → '2026-27'.
create function public.fn_fy_code(p_date date)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select extract(year from public.fn_fy_start_date(p_date))::int::text
      || '-'
      || lpad(((extract(year from public.fn_fy_start_date(p_date))::int + 1) % 100)::text, 2, '0');
$$;
comment on function public.fn_fy_code(date) is
  'Indian financial-year code (YYYY-YY) for the date, e.g. 2026-27.';

-- Short code used inside document numbers: '2026-27' → '26-27'.
create function public.fn_fy_short_code(p_fy_code text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select right(split_part(p_fy_code, '-', 1), 2) || '-' || split_part(p_fy_code, '-', 2);
$$;
comment on function public.fn_fy_short_code(text) is
  'Short financial-year code used in document numbers: 2026-27 → 26-27.';

-- -----------------------------------------------------------------------------
-- 6. Function privileges
-- -----------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon, authenticated;
-- Pure date helpers are safe to call and are evaluated inside CHECK
-- constraints on behalf of the inserting role, so authenticated needs them.
grant execute on function public.fn_business_date(timestamptz) to authenticated, service_role;
grant execute on function public.fn_fy_start_date(date) to authenticated, service_role;
grant execute on function public.fn_fy_code(date) to authenticated, service_role;
grant execute on function public.fn_fy_short_code(text) to authenticated, service_role;
