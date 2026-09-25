-- =============================================================================
-- MyBike · Phase 8 · 0010 — vehicle master: brands, models, variants (petrol /
--                            EV specifications, warranty) and vehicle units
--                            (VIN, chassis, engine, motor, battery)
-- -----------------------------------------------------------------------------
-- Design: docs/phase-08/README.md, docs/phase-00/05-database-plan.md §4.3–4.4
--
--   * The catalogue (brands → models → variants) is company-wide: readable by
--     every active user, maintained with vehicles.create / edit / delete.
--   * Specifications follow the fuel type; CHECKs make the right ones
--     required and the others empty (EV: motor + battery; petrol / CNG: engine;
--     hybrid: both).
--   * vehicles holds each physical unit in a showroom. Identifiers are stored
--     upper-case without spaces and are unique while the unit is on the books
--     (a sold / delivered / returned unit may come back, e.g. as a used buyback).
--   * Status and showroom are not writable by clients: stock movements
--     (receiving, transfer, sale) change them in Phase 9+.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Enums
-- -----------------------------------------------------------------------------
create type public.fuel_type as enum ('petrol', 'electric', 'cng', 'hybrid');
comment on type public.fuel_type is
  'Power source of a variant. electric = motor + battery; petrol / cng = engine; hybrid = both.';

-- Body type only: "electric" is the fuel type, not a category.
create type public.vehicle_category as enum ('motorcycle', 'scooter', 'moped', 'bicycle');
comment on type public.vehicle_category is 'Body type of a model.';

create type public.vehicle_status as enum (
  'purchased', 'in_transit', 'received', 'in_stock', 'reserved', 'transferred',
  'sold', 'delivered', 'damaged', 'returned_to_supplier'
);
comment on type public.vehicle_status is
  'Lifecycle of a vehicle unit (docs/phase-00/06-business-flows.md). Registered units start as purchased; stock movements (Phase 9+) advance it.';

create type public.vehicle_ownership as enum ('new', 'used', 'demo');
comment on type public.vehicle_ownership is 'Whether a unit is new stock, a used (exchange / buyback) vehicle or a demo unit.';

-- -----------------------------------------------------------------------------
-- 2. Helpers
-- -----------------------------------------------------------------------------
-- Stored form of VIN / chassis / engine / motor / battery numbers: upper-case,
-- no whitespace, NULL when empty. Duplicates are found on this form.
create function public.fn_normalize_identifier(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(regexp_replace(upper(coalesce(p_value, '')), '[[:space:]]+', '', 'g'), '');
$$;
comment on function public.fn_normalize_identifier(text) is
  'Upper-case, whitespace-free form of a vehicle identifier (NULL when empty).';

-- Units whose identifiers are "taken": everything still on the books.
create function public.fn_vehicle_holds_identifiers(p_status public.vehicle_status)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_status not in ('sold', 'delivered', 'returned_to_supplier');
$$;
comment on function public.fn_vehicle_holds_identifiers(public.vehicle_status) is
  'True while a unit''s VIN / chassis / engine / motor / battery numbers must stay unique (not sold, delivered or returned).';

-- -----------------------------------------------------------------------------
-- 3. Catalogue
-- -----------------------------------------------------------------------------
create table public.vehicle_brands (
  id         uuid primary key default gen_random_uuid(),
  code       text not null,
  name       extensions.citext not null,
  country    text,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  updated_by uuid,
  constraint vehicle_brands_code_key unique (code),
  constraint vehicle_brands_name_key unique (name),
  constraint vehicle_brands_code_format check (code ~ '^[A-Z0-9][A-Z0-9-]{1,19}$'),
  constraint vehicle_brands_name_not_blank check (char_length(btrim(name::text)) between 2 and 80),
  constraint vehicle_brands_country_length check (country is null or char_length(btrim(country)) between 2 and 60)
);
comment on table public.vehicle_brands is 'Vehicle manufacturers / brands (company-wide). Names are unique ignoring case.';

create table public.vehicle_models (
  id         uuid primary key default gen_random_uuid(),
  brand_id   uuid not null references public.vehicle_brands (id) on delete restrict,
  name       extensions.citext not null,
  category   public.vehicle_category not null,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  updated_by uuid,
  constraint vehicle_models_brand_name_key unique (brand_id, name),
  constraint vehicle_models_name_not_blank check (char_length(btrim(name::text)) between 1 and 80)
);
comment on table public.vehicle_models is 'Models of a brand (e.g. Activa 6G). Unique name per brand, ignoring case.';

create table public.vehicle_variants (
  id                      uuid primary key default gen_random_uuid(),
  model_id                uuid not null references public.vehicle_models (id) on delete restrict,
  name                    extensions.citext not null,
  fuel_type               public.fuel_type not null,
  hsn_code                text,
  ex_showroom_price       numeric(12,2),
  transmission            text,
  top_speed_kmph          smallint,
  -- engine (petrol / cng / hybrid)
  engine_cc               numeric(6,1),
  mileage_kmpl            numeric(5,1),
  fuel_tank_litres        numeric(4,1),
  -- motor and battery (electric / hybrid)
  motor_power_kw          numeric(5,2),
  battery_capacity_kwh    numeric(5,2),
  battery_type            text,
  range_km                smallint,
  charging_time_hours     numeric(4,1),
  charging_type           text,
  -- warranty terms (the unit's warranty dates start at delivery)
  warranty_months         smallint,
  warranty_km             integer,
  battery_warranty_months smallint,
  battery_warranty_km     integer,
  is_active               boolean not null default true,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  created_by              uuid references public.profiles (id) on delete set null,
  updated_by              uuid,
  constraint vehicle_variants_model_name_key unique (model_id, name),
  constraint vehicle_variants_name_not_blank check (char_length(btrim(name::text)) between 1 and 80),
  constraint vehicle_variants_hsn_format check (hsn_code is null or hsn_code ~ '^[0-9]{4}([0-9]{2}){0,2}$'),
  constraint vehicle_variants_price_nonneg check (ex_showroom_price is null or ex_showroom_price >= 0),
  constraint vehicle_variants_texts_length check (
        (transmission is null or char_length(btrim(transmission)) between 1 and 40)
    and (battery_type is null or char_length(btrim(battery_type)) between 1 and 40)
    and (charging_type is null or char_length(btrim(charging_type)) between 1 and 40)
  ),
  constraint vehicle_variants_specs_positive check (
        coalesce(top_speed_kmph, 1) > 0 and coalesce(engine_cc, 1) > 0 and coalesce(mileage_kmpl, 1) > 0
    and coalesce(fuel_tank_litres, 1) > 0 and coalesce(motor_power_kw, 1) > 0
    and coalesce(battery_capacity_kwh, 1) > 0 and coalesce(range_km, 1) > 0
    and coalesce(charging_time_hours, 1) > 0 and coalesce(warranty_months, 1) > 0
    and coalesce(warranty_km, 1) > 0 and coalesce(battery_warranty_months, 1) > 0
    and coalesce(battery_warranty_km, 1) > 0
  ),
  -- An engine is required unless electric …
  constraint vehicle_variants_engine_required check (fuel_type = 'electric' or engine_cc is not null),
  -- … and an electric variant has no engine specifications.
  constraint vehicle_variants_electric_no_engine check (
    fuel_type <> 'electric' or (engine_cc is null and mileage_kmpl is null and fuel_tank_litres is null)
  ),
  -- Motor and battery are required for electric / hybrid …
  constraint vehicle_variants_ev_required check (
    fuel_type not in ('electric', 'hybrid') or (motor_power_kw is not null and battery_capacity_kwh is not null)
  ),
  -- … and absent otherwise.
  constraint vehicle_variants_no_ev_specs check (
    fuel_type in ('electric', 'hybrid')
    or (motor_power_kw is null and battery_capacity_kwh is null and battery_type is null and range_km is null
        and charging_time_hours is null and charging_type is null
        and battery_warranty_months is null and battery_warranty_km is null)
  )
);
comment on table public.vehicle_variants is
  'Variants of a model with their specifications. The fuel type decides which specifications are required (CHECKs). ex_showroom_price is the default list price.';
comment on column public.vehicle_variants.hsn_code is 'HSN code printed on invoices (4, 6 or 8 digits); tax rates are configured in Phase 14.';

-- The fuel type of a variant with registered units cannot change (their
-- identifiers were validated for it).
create function public.fn_vehicle_variants_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.fuel_type is distinct from old.fuel_type
     and exists (select 1 from public.vehicles v where v.variant_id = old.id) then
    raise exception 'The fuel type of variant % cannot change: vehicles of it are registered.', old.name
      using errcode = 'MB030', hint = 'variant_fuel_type_in_use';
  end if;
  return new;
end;
$$;
comment on function public.fn_vehicle_variants_guard() is
  'BEFORE UPDATE OF fuel_type trigger on vehicle_variants: frozen once units are registered (MB030).';

-- -----------------------------------------------------------------------------
-- 4. Vehicle units
-- -----------------------------------------------------------------------------
create table public.vehicles (
  id                 uuid primary key default gen_random_uuid(),
  showroom_id        uuid not null references public.showrooms (id) on delete restrict,
  variant_id         uuid not null references public.vehicle_variants (id) on delete restrict,
  fuel_type          public.fuel_type not null,
  vin                text,
  chassis_number     text not null,
  engine_number      text,
  motor_number       text,
  battery_number     text,
  color              text,
  manufacturing_year smallint,
  model_year         smallint,
  ownership          public.vehicle_ownership not null default 'new',
  status             public.vehicle_status not null default 'purchased',
  warranty_start     date,
  warranty_end       date,
  remarks            text,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  created_by         uuid references public.profiles (id) on delete set null,
  updated_by         uuid,
  -- ISO 3779: 17 characters, no I, O or Q.
  constraint vehicles_vin_format check (vin is null or vin ~ '^[A-HJ-NPR-Z0-9]{17}$'),
  constraint vehicles_chassis_format check (chassis_number ~ '^[A-Z0-9][A-Z0-9/-]{4,29}$'),
  constraint vehicles_engine_format check (engine_number is null or engine_number ~ '^[A-Z0-9][A-Z0-9/-]{3,29}$'),
  constraint vehicles_motor_format check (motor_number is null or motor_number ~ '^[A-Z0-9][A-Z0-9/-]{3,29}$'),
  constraint vehicles_battery_format check (battery_number is null or battery_number ~ '^[A-Z0-9][A-Z0-9/-]{3,29}$'),
  constraint vehicles_engine_required check (fuel_type = 'electric' or engine_number is not null),
  constraint vehicles_electric_no_engine check (fuel_type <> 'electric' or engine_number is null),
  constraint vehicles_ev_required check (
    fuel_type not in ('electric', 'hybrid') or (motor_number is not null and battery_number is not null)
  ),
  constraint vehicles_no_ev_numbers check (
    fuel_type in ('electric', 'hybrid') or (motor_number is null and battery_number is null)
  ),
  constraint vehicles_years_range check (
        (manufacturing_year is null or manufacturing_year between 1990 and 2100)
    and (model_year is null or model_year between 1990 and 2100)
    and (model_year is null or manufacturing_year is null or model_year between manufacturing_year and manufacturing_year + 1)
  ),
  constraint vehicles_warranty_dates check (
    warranty_end is null or (warranty_start is not null and warranty_end >= warranty_start)
  ),
  constraint vehicles_color_length check (color is null or char_length(btrim(color)) between 1 and 40),
  constraint vehicles_remarks_length check (remarks is null or char_length(remarks) <= 500)
);
comment on table public.vehicles is
  'Physical vehicle units of a showroom (the VIN view). Identifiers are unique while the unit is on the books; status and showroom change only through stock movements (Phase 9+).';
comment on column public.vehicles.fuel_type is 'Copied from the variant by trigger; drives which identifiers are required.';
comment on column public.vehicles.chassis_number is 'Frame number as on the RC (often equal to the VIN).';
comment on column public.vehicles.warranty_start is 'Set at delivery (Phase 11) or when registering a used / demo unit.';

create unique index uq_vehicles_vin_active on public.vehicles (vin)
  where vin is not null and status not in ('sold', 'delivered', 'returned_to_supplier');
create unique index uq_vehicles_chassis_active on public.vehicles (chassis_number)
  where status not in ('sold', 'delivered', 'returned_to_supplier');
create unique index uq_vehicles_engine_active on public.vehicles (engine_number)
  where engine_number is not null and status not in ('sold', 'delivered', 'returned_to_supplier');
create unique index uq_vehicles_motor_active on public.vehicles (motor_number)
  where motor_number is not null and status not in ('sold', 'delivered', 'returned_to_supplier');
create unique index uq_vehicles_battery_active on public.vehicles (battery_number)
  where battery_number is not null and status not in ('sold', 'delivered', 'returned_to_supplier');
create index idx_vehicles_showroom_status on public.vehicles (showroom_id, status);
create index idx_vehicles_variant on public.vehicles (variant_id);
create index idx_vehicles_chassis_trgm on public.vehicles using gin (chassis_number extensions.gin_trgm_ops);

-- Normalises identifiers and takes the fuel type from the variant, so a
-- client can never register an EV without a battery by lying about it.
create function public.fn_vehicles_prepare()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.vin            := public.fn_normalize_identifier(new.vin);
  new.chassis_number := public.fn_normalize_identifier(new.chassis_number);
  new.engine_number  := public.fn_normalize_identifier(new.engine_number);
  new.motor_number   := public.fn_normalize_identifier(new.motor_number);
  new.battery_number := public.fn_normalize_identifier(new.battery_number);
  new.color          := nullif(btrim(new.color), '');
  new.remarks        := nullif(btrim(new.remarks), '');
  select v.fuel_type into new.fuel_type from public.vehicle_variants v where v.id = new.variant_id;
  return new;
end;
$$;
comment on function public.fn_vehicles_prepare() is
  'BEFORE INSERT/UPDATE trigger on vehicles: normalises identifiers and copies fuel_type from the variant.';

-- -----------------------------------------------------------------------------
-- 5. Triggers
-- -----------------------------------------------------------------------------
create trigger trg_vehicle_variants_guard
  before update of fuel_type on public.vehicle_variants
  for each row execute function public.fn_vehicle_variants_guard();
create trigger trg_vehicles_prepare
  before insert or update on public.vehicles
  for each row execute function public.fn_vehicles_prepare();

create trigger trg_set_created_by before insert or update on public.vehicle_brands
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at before update on public.vehicle_brands
  for each row execute function public.set_updated_at();
create trigger trg_set_created_by before insert or update on public.vehicle_models
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at before update on public.vehicle_models
  for each row execute function public.set_updated_at();
create trigger trg_set_created_by before insert or update on public.vehicle_variants
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at before update on public.vehicle_variants
  for each row execute function public.set_updated_at();
create trigger trg_set_created_by before insert or update on public.vehicles
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at before update on public.vehicles
  for each row execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 6. Duplicate check for the forms
-- -----------------------------------------------------------------------------
-- Which of the given identifiers are already used by a unit on the books, in
-- ANY showroom (identifiers are unique company-wide). Returns field names
-- only — never the other unit or its showroom. The unique indexes stay the
-- final check.
create function public.rpc_vehicle_identifier_conflicts(
  p_vin            text,
  p_chassis_number text,
  p_engine_number  text,
  p_motor_number   text,
  p_battery_number text,
  p_exclude_id     uuid default null
)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_vin     text := public.fn_normalize_identifier(p_vin);
  v_chassis text := public.fn_normalize_identifier(p_chassis_number);
  v_engine  text := public.fn_normalize_identifier(p_engine_number);
  v_motor   text := public.fn_normalize_identifier(p_motor_number);
  v_battery text := public.fn_normalize_identifier(p_battery_number);
begin
  if not (public.has_permission('vehicles', 'create') or public.has_permission('vehicles', 'edit')) then
    raise exception 'You cannot register vehicles.' using errcode = '42501';
  end if;
  return array_remove(array[
    case when v_vin is not null and exists (
      select 1 from public.vehicles v where v.vin = v_vin
         and public.fn_vehicle_holds_identifiers(v.status) and v.id is distinct from p_exclude_id) then 'vin' end,
    case when v_chassis is not null and exists (
      select 1 from public.vehicles v where v.chassis_number = v_chassis
         and public.fn_vehicle_holds_identifiers(v.status) and v.id is distinct from p_exclude_id) then 'chassis_number' end,
    case when v_engine is not null and exists (
      select 1 from public.vehicles v where v.engine_number = v_engine
         and public.fn_vehicle_holds_identifiers(v.status) and v.id is distinct from p_exclude_id) then 'engine_number' end,
    case when v_motor is not null and exists (
      select 1 from public.vehicles v where v.motor_number = v_motor
         and public.fn_vehicle_holds_identifiers(v.status) and v.id is distinct from p_exclude_id) then 'motor_number' end,
    case when v_battery is not null and exists (
      select 1 from public.vehicles v where v.battery_number = v_battery
         and public.fn_vehicle_holds_identifiers(v.status) and v.id is distinct from p_exclude_id) then 'battery_number' end
  ], null);
end;
$$;
comment on function public.rpc_vehicle_identifier_conflicts(text, text, text, text, text, uuid) is
  'Field names (vin, chassis_number, engine_number, motor_number, battery_number) already used by a unit on the books in any showroom. Requires vehicles.create or vehicles.edit.';

-- -----------------------------------------------------------------------------
-- 7. RLS
-- -----------------------------------------------------------------------------
alter table public.vehicle_brands enable row level security;
alter table public.vehicle_models enable row level security;
alter table public.vehicle_variants enable row level security;
alter table public.vehicles enable row level security;

-- Catalogue: reference data for every module; maintained by whoever holds the
-- vehicles permission in any of their showrooms (the matrix grants it to
-- inventory / purchase / showroom managers and admins).
create policy vehicle_brands_select on public.vehicle_brands
  for select to authenticated using ((select public.is_active_user()));
create policy vehicle_brands_insert on public.vehicle_brands
  for insert to authenticated with check ((select public.has_permission('vehicles', 'create')));
create policy vehicle_brands_update on public.vehicle_brands
  for update to authenticated
  using ((select public.has_permission('vehicles', 'edit')))
  with check ((select public.has_permission('vehicles', 'edit')));
create policy vehicle_brands_delete on public.vehicle_brands
  for delete to authenticated using ((select public.has_permission('vehicles', 'delete')));

create policy vehicle_models_select on public.vehicle_models
  for select to authenticated using ((select public.is_active_user()));
create policy vehicle_models_insert on public.vehicle_models
  for insert to authenticated with check ((select public.has_permission('vehicles', 'create')));
create policy vehicle_models_update on public.vehicle_models
  for update to authenticated
  using ((select public.has_permission('vehicles', 'edit')))
  with check ((select public.has_permission('vehicles', 'edit')));
create policy vehicle_models_delete on public.vehicle_models
  for delete to authenticated using ((select public.has_permission('vehicles', 'delete')));

create policy vehicle_variants_select on public.vehicle_variants
  for select to authenticated using ((select public.is_active_user()));
create policy vehicle_variants_insert on public.vehicle_variants
  for insert to authenticated with check ((select public.has_permission('vehicles', 'create')));
create policy vehicle_variants_update on public.vehicle_variants
  for update to authenticated
  using ((select public.has_permission('vehicles', 'edit')))
  with check ((select public.has_permission('vehicles', 'edit')));
create policy vehicle_variants_delete on public.vehicle_variants
  for delete to authenticated using ((select public.has_permission('vehicles', 'delete')));

-- Units: showroom-scoped.
create policy vehicles_select on public.vehicles
  for select to authenticated using (public.has_permission_for('vehicles', 'view', showroom_id));
create policy vehicles_insert on public.vehicles
  for insert to authenticated with check (public.has_permission_for('vehicles', 'create', showroom_id));
create policy vehicles_update on public.vehicles
  for update to authenticated
  using (public.has_permission_for('vehicles', 'edit', showroom_id))
  with check (public.has_permission_for('vehicles', 'edit', showroom_id));
create policy vehicles_delete on public.vehicles
  for delete to authenticated using (public.has_permission_for('vehicles', 'delete', showroom_id));

-- -----------------------------------------------------------------------------
-- 8. Privileges
-- -----------------------------------------------------------------------------
revoke all on public.vehicle_brands, public.vehicle_models, public.vehicle_variants, public.vehicles from anon;
revoke truncate, references, trigger
  on public.vehicle_brands, public.vehicle_models, public.vehicle_variants, public.vehicles from authenticated;
-- Status and showroom move only with stock movements (server functions).
revoke insert, update on public.vehicles from authenticated;
grant insert (showroom_id, variant_id, vin, chassis_number, engine_number, motor_number, battery_number, color,
              manufacturing_year, model_year, ownership, warranty_start, warranty_end, remarks)
  on public.vehicles to authenticated;
grant update (variant_id, vin, chassis_number, engine_number, motor_number, battery_number, color,
              manufacturing_year, model_year, ownership, warranty_start, warranty_end, remarks, is_active)
  on public.vehicles to authenticated;

-- Pure helper called by the (invoker) prepare trigger on behalf of the caller.
revoke execute on function public.fn_normalize_identifier(text) from public, anon;
grant execute on function public.fn_normalize_identifier(text) to authenticated, service_role;
revoke execute on function public.fn_vehicle_holds_identifiers(public.vehicle_status) from public, anon, authenticated;
revoke execute on function public.fn_vehicle_variants_guard() from public, anon, authenticated;
revoke execute on function public.fn_vehicles_prepare() from public, anon, authenticated;
revoke execute on function public.rpc_vehicle_identifier_conflicts(text, text, text, text, text, uuid) from public, anon;
grant execute on function public.rpc_vehicle_identifier_conflicts(text, text, text, text, text, uuid)
  to authenticated, service_role;
