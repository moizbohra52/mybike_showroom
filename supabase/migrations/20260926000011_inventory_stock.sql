-- =============================================================================
-- MyBike · Phase 9 · 0011 — inventory & stock: the vehicle lifecycle
--                            (receive, reserve, transfer, damage, adjust)
-- -----------------------------------------------------------------------------
-- Design: docs/phase-09/README.md, docs/phase-00/06-business-flows.md §1–3
--
--   * stock_ledger is the single source of truth: vehicles.status and
--     vehicles.showroom_id are DERIVED from it by trg_stock_ledger_apply,
--     never set directly (0010 already blocks the client column privilege).
--   * The ledger is append-only and closed to clients entirely (like
--     document_sequences): every row is written by a SECURITY DEFINER RPC
--     that checks has_permission_for('inventory', action, showroom) and the
--     unit's current status first.
--   * Reservations carry no stock value, so they bypass the ledger and move
--     status directly (still SECURITY DEFINER, still logged via
--     trg_vehicle_status_history).
--   * Transfers skip a separate draft/approval stage in this phase (v1): a
--     transfer is created already dispatched; receiving is a second step.
--     No income or expense account is touched anywhere here — accounting
--     integration (in-transit clearing, inventory accounts) is Phase 12/13.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Enums
-- -----------------------------------------------------------------------------
create type public.stock_movement_type as enum (
  'purchase_receipt', 'sale_issue', 'transfer_out', 'transfer_in',
  'adjustment_in', 'adjustment_out', 'return_in', 'return_out', 'damage', 'opening'
);
comment on type public.stock_movement_type is
  'stock_ledger row kind. sale_issue / return_in / return_out are reserved for Phases 10–11 (no RPC writes them yet).';

create type public.transfer_status as enum ('in_transit', 'received', 'cancelled');
comment on type public.transfer_status is
  'v1 skips a separate draft/approval stage (Phase 21 approval engine): a transfer is created already in_transit.';

-- -----------------------------------------------------------------------------
-- 2. vehicle_status_history — append-only, one row per real status change
-- -----------------------------------------------------------------------------
create table public.vehicle_status_history (
  id             uuid primary key default gen_random_uuid(),
  vehicle_id     uuid not null references public.vehicles (id) on delete restrict,
  showroom_id    uuid not null references public.showrooms (id) on delete restrict,
  from_status    public.vehicle_status,
  to_status      public.vehicle_status not null,
  changed_by     uuid references public.profiles (id) on delete set null,
  changed_at     timestamptz not null default now(),
  reason         text,
  reference_type text,
  reference_id   uuid
);
comment on table public.vehicle_status_history is
  'Every vehicle status change (docs/phase-00/06-business-flows.md §1), written only by trg_vehicle_status_history. Append-only.';
comment on column public.vehicle_status_history.reference_type is
  'Loose reference tag, e.g. stock_transfer / stock_adjustment / manual_reservation / manual_receipt / manual_damage.';

create index idx_vehicle_status_history_vehicle on public.vehicle_status_history (vehicle_id, changed_at desc);
create index idx_vehicle_status_history_showroom on public.vehicle_status_history (showroom_id, changed_at desc);

-- Fires on every status change however it happened; the RPC that made the
-- change sets these transaction-local settings first so the row carries a
-- real reason/reference (cleared automatically at commit/rollback).
create function public.fn_vehicle_status_history_record()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  insert into public.vehicle_status_history (
    vehicle_id, showroom_id, from_status, to_status, changed_by, reason, reference_type, reference_id
  )
  values (
    new.id, new.showroom_id, old.status, new.status, (select auth.uid()),
    nullif(current_setting('mybike.status_reason', true), ''),
    nullif(current_setting('mybike.status_reference_type', true), ''),
    public.fn_try_uuid(current_setting('mybike.status_reference_id', true))
  );
  return new;
end;
$$;
comment on function public.fn_vehicle_status_history_record() is
  'AFTER UPDATE OF status trigger on vehicles: logs every status change. Reads optional mybike.status_* transaction-local settings for the reason/reference.';

create trigger trg_vehicle_status_history
  after update of status on public.vehicles
  for each row
  when (old.status is distinct from new.status)
  execute function public.fn_vehicle_status_history_record();

alter table public.vehicle_status_history enable row level security;
create policy vehicle_status_history_select on public.vehicle_status_history
  for select to authenticated using (public.has_permission_for('inventory', 'view', showroom_id));
-- Written only by the trigger above; never by a client.

-- -----------------------------------------------------------------------------
-- 3. vehicle_reservations — at most one active reservation per vehicle
-- -----------------------------------------------------------------------------
create table public.vehicle_reservations (
  id               uuid primary key default gen_random_uuid(),
  vehicle_id       uuid not null references public.vehicles (id) on delete restrict,
  showroom_id      uuid not null references public.showrooms (id) on delete restrict,
  reserved_for_type text not null default 'manual',
  reserved_for_id  uuid,
  reserved_by      uuid references public.profiles (id) on delete set null,
  reserved_at      timestamptz not null default now(),
  expires_at       timestamptz,
  released_at      timestamptz,
  release_reason   text,
  constraint vehicle_reservations_type_check check (reserved_for_type in ('manual', 'booking', 'sales_order')),
  constraint vehicle_reservations_released_stamp check (released_at is null or release_reason is not null)
);
comment on table public.vehicle_reservations is
  'Holds on a vehicle. booking / sales_order linkage arrives with Phase 11; v1 only ever writes reserved_for_type = manual.';

create unique index uq_vehicle_reservations_active on public.vehicle_reservations (vehicle_id) where released_at is null;
create index idx_vehicle_reservations_showroom on public.vehicle_reservations (showroom_id) where released_at is null;

alter table public.vehicle_reservations enable row level security;
create policy vehicle_reservations_select on public.vehicle_reservations
  for select to authenticated using (public.has_permission_for('inventory', 'view', showroom_id));
-- Written only by rpc_reserve_vehicle / rpc_release_reservation below.

-- -----------------------------------------------------------------------------
-- 4. stock_ledger — the single source of truth (append-only, closed to clients)
-- -----------------------------------------------------------------------------
create table public.stock_ledger (
  id               uuid primary key default gen_random_uuid(),
  showroom_id      uuid not null references public.showrooms (id) on delete restrict,
  movement_type    public.stock_movement_type not null,
  vehicle_id       uuid not null references public.vehicles (id) on delete restrict,
  unit_cost        numeric(14,2),
  value            numeric(14,2),
  from_showroom_id uuid references public.showrooms (id) on delete restrict,
  to_showroom_id   uuid references public.showrooms (id) on delete restrict,
  reference_type   text,
  reference_id     uuid,
  reference_no     text,
  remarks          text,
  created_by       uuid references public.profiles (id) on delete set null,
  created_at       timestamptz not null default now()
);
comment on table public.stock_ledger is
  'Append-only stock movements (docs/phase-00/06-business-flows.md §2): vehicles.status/showroom_id are DERIVED from it by trg_stock_ledger_apply. Written only by the RPCs in this migration; no client privilege at all.';

create index idx_stock_ledger_showroom on public.stock_ledger (showroom_id, created_at desc);
create index idx_stock_ledger_vehicle on public.stock_ledger (vehicle_id, created_at desc);

alter table public.stock_ledger enable row level security;
create policy stock_ledger_select on public.stock_ledger
  for select to authenticated using (public.has_permission_for('inventory', 'view', showroom_id));

-- The one place stock math happens. SECURITY DEFINER so it can update the
-- vehicles column privileges block for authenticated (0010); every guard a
-- writing RPC did not already check is re-checked here as a last line of
-- defence.
create function public.fn_stock_ledger_apply()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status public.vehicle_status;
begin
  select status into v_status from public.vehicles where id = new.vehicle_id for update;

  case new.movement_type
    when 'purchase_receipt', 'opening' then
      if v_status <> 'purchased' then
        raise exception 'This vehicle is not awaiting receipt.' using errcode = 'MB040', hint = 'wrong_status_for_action';
      end if;
      update public.vehicles set status = 'in_stock' where id = new.vehicle_id;
    when 'transfer_out' then
      if v_status <> 'in_stock' then
        raise exception 'This vehicle is not available to transfer.' using errcode = 'MB040', hint = 'wrong_status_for_action';
      end if;
      update public.vehicles set status = 'in_transit' where id = new.vehicle_id;
    when 'transfer_in' then
      if v_status <> 'in_transit' then
        raise exception 'This vehicle is not in transit.' using errcode = 'MB040', hint = 'wrong_status_for_action';
      end if;
      update public.vehicles set status = 'in_stock', showroom_id = new.showroom_id where id = new.vehicle_id;
    when 'damage' then
      if v_status not in ('in_stock', 'reserved') then
        raise exception 'This vehicle is not available to mark damaged.' using errcode = 'MB040', hint = 'wrong_status_for_action';
      end if;
      update public.vehicles set status = 'damaged' where id = new.vehicle_id;
    when 'adjustment_out' then
      if v_status <> 'in_stock' then
        raise exception 'Only stock currently in stock can be adjusted out.' using errcode = 'MB040', hint = 'wrong_status_for_action';
      end if;
      -- v1 buckets every write-off reason (damage / theft / expiry / correction) as damaged.
      update public.vehicles set status = 'damaged' where id = new.vehicle_id;
    when 'adjustment_in' then
      if v_status in ('in_stock', 'reserved', 'sold', 'delivered') then
        raise exception 'This vehicle is already in stock.' using errcode = 'MB040', hint = 'wrong_status_for_action';
      end if;
      update public.vehicles set status = 'in_stock' where id = new.vehicle_id;
    else
      raise exception 'Movement type % is not supported yet.', new.movement_type
        using errcode = 'MB046', hint = 'movement_type_not_implemented';
  end case;
  return new;
end;
$$;
comment on function public.fn_stock_ledger_apply() is
  'AFTER INSERT trigger on stock_ledger: the only place vehicles.status / showroom_id change. Re-validates the transition regardless of the caller.';

create trigger trg_stock_ledger_apply
  after insert on public.stock_ledger
  for each row execute function public.fn_stock_ledger_apply();

-- -----------------------------------------------------------------------------
-- 5. stock_transfers / stock_transfer_items
-- -----------------------------------------------------------------------------
create table public.stock_transfers (
  id                      uuid primary key default gen_random_uuid(),
  transfer_no             text not null,
  source_showroom_id      uuid not null references public.showrooms (id) on delete restrict,
  destination_showroom_id uuid not null references public.showrooms (id) on delete restrict,
  transfer_date           date not null,
  status                  public.transfer_status not null default 'in_transit',
  dispatched_by           uuid references public.profiles (id) on delete set null,
  dispatched_at           timestamptz,
  received_by             uuid references public.profiles (id) on delete set null,
  received_at             timestamptz,
  remarks                 text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  created_by              uuid references public.profiles (id) on delete set null,
  updated_by              uuid,
  constraint stock_transfers_transfer_no_key unique (transfer_no),
  constraint stock_transfers_different_showrooms check (source_showroom_id <> destination_showroom_id)
);
comment on table public.stock_transfers is
  'Showroom-to-showroom vehicle transfers. v1: created already in_transit (rpc_create_stock_transfer), closed by rpc_receive_stock_transfer. No accounting entry (Phase 12/13).';

create table public.stock_transfer_items (
  id          uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.stock_transfers (id) on delete cascade,
  vehicle_id  uuid not null references public.vehicles (id) on delete restrict,
  unit_cost   numeric(14,2),
  constraint stock_transfer_items_unique unique (transfer_id, vehicle_id)
);
comment on table public.stock_transfer_items is 'One vehicle line of a stock transfer, with the unit cost carried at dispatch.';
create index idx_stock_transfer_items_vehicle on public.stock_transfer_items (vehicle_id);

create trigger trg_set_updated_at before update on public.stock_transfers
  for each row execute function public.set_updated_at();

alter table public.stock_transfers enable row level security;
alter table public.stock_transfer_items enable row level security;

create policy stock_transfers_select on public.stock_transfers
  for select to authenticated using (
    public.has_permission_for('inventory', 'view', source_showroom_id)
    or public.has_permission_for('inventory', 'view', destination_showroom_id)
  );
create policy stock_transfer_items_select on public.stock_transfer_items
  for select to authenticated using (
    exists (select 1 from public.stock_transfers t where t.id = transfer_id
              and (public.has_permission_for('inventory', 'view', t.source_showroom_id)
                   or public.has_permission_for('inventory', 'view', t.destination_showroom_id)))
  );
-- Written only by rpc_create_stock_transfer / rpc_receive_stock_transfer.

-- -----------------------------------------------------------------------------
-- 6. stock_adjustments / stock_adjustment_items
-- -----------------------------------------------------------------------------
create table public.stock_adjustments (
  id              uuid primary key default gen_random_uuid(),
  showroom_id     uuid not null references public.showrooms (id) on delete restrict,
  adjustment_no   text not null,
  adjustment_date date not null,
  reason_code     text not null,
  status          text not null default 'posted',
  total_value     numeric(14,2) not null default 0,
  notes           text,
  created_at      timestamptz not null default now(),
  created_by      uuid references public.profiles (id) on delete set null,
  posted_by       uuid references public.profiles (id) on delete set null,
  posted_at       timestamptz,
  constraint stock_adjustments_showroom_no_key unique (showroom_id, adjustment_no),
  constraint stock_adjustments_reason_check
    check (reason_code in ('physical_count', 'damage', 'theft', 'expiry', 'correction', 'opening')),
  constraint stock_adjustments_status_check check (status in ('posted', 'cancelled'))
);
comment on table public.stock_adjustments is
  'Batch stock corrections (docs/phase-00/06-business-flows.md §2). v1 posts immediately (no draft/approval stage); reversal, not deletion, if ever wrong.';

create table public.stock_adjustment_items (
  id            uuid primary key default gen_random_uuid(),
  adjustment_id uuid not null references public.stock_adjustments (id) on delete restrict,
  vehicle_id    uuid not null references public.vehicles (id) on delete restrict,
  direction     text not null,
  unit_cost     numeric(14,2),
  constraint stock_adjustment_items_unique unique (adjustment_id, vehicle_id),
  constraint stock_adjustment_items_direction_check check (direction in ('in', 'out'))
);
comment on table public.stock_adjustment_items is 'One vehicle line of a stock adjustment (in or out), with its unit cost.';
create index idx_stock_adjustment_items_vehicle on public.stock_adjustment_items (vehicle_id);

alter table public.stock_adjustments enable row level security;
alter table public.stock_adjustment_items enable row level security;

create policy stock_adjustments_select on public.stock_adjustments
  for select to authenticated using (public.has_permission_for('inventory', 'view', showroom_id));
create policy stock_adjustment_items_select on public.stock_adjustment_items
  for select to authenticated using (
    exists (select 1 from public.stock_adjustments a where a.id = adjustment_id
              and public.has_permission_for('inventory', 'view', a.showroom_id))
  );
-- Written only by rpc_create_stock_adjustment.

-- -----------------------------------------------------------------------------
-- 7. RPCs
-- -----------------------------------------------------------------------------

-- The vehicle's most recent known unit cost (from its last receipt or
-- transfer-in); NULL if it was never received. Internal helper.
create function public.fn_vehicle_last_unit_cost(p_vehicle_id uuid)
returns numeric
language sql
stable
set search_path = ''
as $$
  select l.unit_cost
    from public.stock_ledger l
   where l.vehicle_id = p_vehicle_id
     and l.movement_type in ('purchase_receipt', 'transfer_in', 'opening', 'adjustment_in')
   order by l.created_at desc
   limit 1;
$$;
comment on function public.fn_vehicle_last_unit_cost(uuid) is
  'The vehicle''s most recent known unit cost from its last receipt/transfer-in/opening/adjustment-in row; NULL if never received. Internal.';

create function public.rpc_receive_vehicle_stock(
  p_vehicle_id uuid, p_unit_cost numeric, p_reference_no text default null, p_remarks text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_showroom_id uuid;
begin
  select showroom_id into v_showroom_id from public.vehicles where id = p_vehicle_id;
  if v_showroom_id is null then
    raise exception 'Vehicle not found.' using errcode = 'PGRST116';
  end if;
  if not public.has_permission_for('inventory', 'create', v_showroom_id) then
    raise exception 'You cannot receive stock in this showroom.' using errcode = '42501';
  end if;
  if p_unit_cost is null or p_unit_cost < 0 then
    raise exception 'Enter the unit cost.' using errcode = '23514';
  end if;

  perform set_config('mybike.status_reason', 'Stock received', true);
  perform set_config('mybike.status_reference_type', 'manual_receipt', true);
  perform set_config('mybike.status_reference_id', p_vehicle_id::text, true);

  insert into public.stock_ledger (showroom_id, movement_type, vehicle_id, unit_cost, value, reference_no, remarks, created_by)
  values (v_showroom_id, 'purchase_receipt', p_vehicle_id, p_unit_cost, p_unit_cost, p_reference_no, p_remarks, (select auth.uid()));
end;
$$;
comment on function public.rpc_receive_vehicle_stock(uuid, numeric, text, text) is
  'Moves a purchased vehicle to in_stock with its unit cost. Requires inventory.create in its showroom.';

create function public.rpc_reserve_vehicle(p_vehicle_id uuid, p_reason text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_showroom_id uuid;
  v_status      public.vehicle_status;
  v_id          uuid;
begin
  select showroom_id, status into v_showroom_id, v_status from public.vehicles where id = p_vehicle_id for update;
  if v_showroom_id is null then
    raise exception 'Vehicle not found.' using errcode = 'PGRST116';
  end if;
  if not public.has_permission_for('inventory', 'edit', v_showroom_id) then
    raise exception 'You cannot reserve vehicles in this showroom.' using errcode = '42501';
  end if;
  if v_status <> 'in_stock' then
    raise exception 'Only vehicles in stock can be reserved.' using errcode = 'MB040', hint = 'wrong_status_for_action';
  end if;

  insert into public.vehicle_reservations (vehicle_id, showroom_id, reserved_by)
  values (p_vehicle_id, v_showroom_id, (select auth.uid()))
  returning id into v_id;

  perform set_config('mybike.status_reason', coalesce(p_reason, 'Reserved'), true);
  perform set_config('mybike.status_reference_type', 'manual_reservation', true);
  perform set_config('mybike.status_reference_id', v_id::text, true);
  update public.vehicles set status = 'reserved' where id = p_vehicle_id;
  return v_id;
end;
$$;
comment on function public.rpc_reserve_vehicle(uuid, text) is
  'Holds an in-stock vehicle (one active reservation at a time). Requires inventory.edit in its showroom.';

create function public.rpc_release_reservation(p_vehicle_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_showroom_id uuid;
  v_id          uuid;
begin
  select showroom_id into v_showroom_id from public.vehicles where id = p_vehicle_id;
  if v_showroom_id is null then
    raise exception 'Vehicle not found.' using errcode = 'PGRST116';
  end if;
  if not public.has_permission_for('inventory', 'edit', v_showroom_id) then
    raise exception 'You cannot release reservations in this showroom.' using errcode = '42501';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'Enter a reason.' using errcode = '23514';
  end if;

  select id into v_id from public.vehicle_reservations where vehicle_id = p_vehicle_id and released_at is null;
  if v_id is null then
    raise exception 'This vehicle has no active reservation.' using errcode = 'MB041', hint = 'no_active_reservation';
  end if;
  update public.vehicle_reservations set released_at = now(), release_reason = p_reason where id = v_id;

  perform set_config('mybike.status_reason', p_reason, true);
  perform set_config('mybike.status_reference_type', 'manual_reservation', true);
  perform set_config('mybike.status_reference_id', v_id::text, true);
  update public.vehicles set status = 'in_stock' where id = p_vehicle_id;
end;
$$;
comment on function public.rpc_release_reservation(uuid, text) is
  'Releases a vehicle''s active reservation back to in_stock. Requires inventory.edit in its showroom.';

create function public.rpc_mark_vehicle_damaged(p_vehicle_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_showroom_id uuid;
  v_status      public.vehicle_status;
  v_cost        numeric;
  v_reservation uuid;
begin
  select showroom_id, status into v_showroom_id, v_status from public.vehicles where id = p_vehicle_id for update;
  if v_showroom_id is null then
    raise exception 'Vehicle not found.' using errcode = 'PGRST116';
  end if;
  if not public.has_permission_for('inventory', 'edit', v_showroom_id) then
    raise exception 'You cannot mark vehicles damaged in this showroom.' using errcode = '42501';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'Enter a reason.' using errcode = '23514';
  end if;
  if v_status not in ('in_stock', 'reserved') then
    raise exception 'This vehicle is not available to mark damaged.' using errcode = 'MB040', hint = 'wrong_status_for_action';
  end if;

  if v_status = 'reserved' then
    select id into v_reservation from public.vehicle_reservations where vehicle_id = p_vehicle_id and released_at is null;
    update public.vehicle_reservations
       set released_at = now(), release_reason = 'Vehicle marked damaged'
     where id = v_reservation;
  end if;

  v_cost := public.fn_vehicle_last_unit_cost(p_vehicle_id);
  perform set_config('mybike.status_reason', p_reason, true);
  perform set_config('mybike.status_reference_type', 'manual_damage', true);
  perform set_config('mybike.status_reference_id', p_vehicle_id::text, true);

  insert into public.stock_ledger (showroom_id, movement_type, vehicle_id, unit_cost, value, remarks, created_by)
  values (v_showroom_id, 'damage', p_vehicle_id, v_cost, v_cost, p_reason, (select auth.uid()));
end;
$$;
comment on function public.rpc_mark_vehicle_damaged(uuid, text) is
  'Marks an in-stock/reserved vehicle damaged (releasing any reservation) with a required reason. Requires inventory.edit in its showroom.';

create function public.rpc_create_stock_transfer(
  p_source_showroom_id uuid, p_destination_showroom_id uuid, p_transfer_date date,
  p_vehicle_ids uuid[], p_remarks text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_transfer_id uuid;
  v_transfer_no text;
  v_vehicle_id  uuid;
  v_cost        numeric;
begin
  if not public.has_permission_for('inventory', 'create', p_source_showroom_id) then
    raise exception 'You cannot dispatch transfers from this showroom.' using errcode = '42501';
  end if;
  if not public.has_permission_for('inventory', 'view', p_destination_showroom_id) then
    raise exception 'You cannot transfer to a showroom you cannot access.' using errcode = '42501';
  end if;
  if p_vehicle_ids is null or array_length(p_vehicle_ids, 1) is null then
    raise exception 'Choose at least one vehicle.' using errcode = '23514';
  end if;
  if exists (
    select 1 from public.vehicles v
     where v.id = any (p_vehicle_ids) and (v.showroom_id <> p_source_showroom_id or v.status <> 'in_stock')
  ) then
    raise exception 'Every vehicle must be in stock at the source showroom.' using errcode = 'MB040', hint = 'wrong_status_for_action';
  end if;

  v_transfer_no := public.fn_next_document_number(p_source_showroom_id, 'stock_transfer', p_transfer_date);
  insert into public.stock_transfers (
    transfer_no, source_showroom_id, destination_showroom_id, transfer_date, dispatched_by, dispatched_at, remarks, created_by
  ) values (
    v_transfer_no, p_source_showroom_id, p_destination_showroom_id, p_transfer_date, (select auth.uid()), now(), p_remarks, (select auth.uid())
  ) returning id into v_transfer_id;

  perform set_config('mybike.status_reason', 'Dispatched: ' || v_transfer_no, true);
  perform set_config('mybike.status_reference_type', 'stock_transfer', true);
  perform set_config('mybike.status_reference_id', v_transfer_id::text, true);

  foreach v_vehicle_id in array p_vehicle_ids loop
    v_cost := public.fn_vehicle_last_unit_cost(v_vehicle_id);
    insert into public.stock_transfer_items (transfer_id, vehicle_id, unit_cost) values (v_transfer_id, v_vehicle_id, v_cost);
    insert into public.stock_ledger (
      showroom_id, movement_type, vehicle_id, unit_cost, value, from_showroom_id, to_showroom_id,
      reference_type, reference_id, reference_no, created_by
    ) values (
      p_source_showroom_id, 'transfer_out', v_vehicle_id, v_cost, v_cost, p_source_showroom_id, p_destination_showroom_id,
      'stock_transfer', v_transfer_id, v_transfer_no, (select auth.uid())
    );
  end loop;
  return v_transfer_id;
end;
$$;
comment on function public.rpc_create_stock_transfer(uuid, uuid, date, uuid[], text) is
  'Dispatches in-stock vehicles from source to destination (created already in_transit; no accounting entry, Phase 12/13). Requires inventory.create at the source and inventory.view at the destination.';

create function public.rpc_receive_stock_transfer(p_transfer_id uuid, p_remarks text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_transfer public.stock_transfers;
  v_item     record;
begin
  select * into v_transfer from public.stock_transfers where id = p_transfer_id for update;
  if v_transfer.id is null then
    raise exception 'Transfer not found.' using errcode = 'PGRST116';
  end if;
  if not public.has_permission_for('inventory', 'create', v_transfer.destination_showroom_id) then
    raise exception 'You cannot receive transfers into this showroom.' using errcode = '42501';
  end if;
  if v_transfer.status <> 'in_transit' then
    raise exception 'This transfer is not awaiting receipt.' using errcode = 'MB045', hint = 'transfer_not_receivable';
  end if;

  perform set_config('mybike.status_reason', 'Received: ' || v_transfer.transfer_no, true);
  perform set_config('mybike.status_reference_type', 'stock_transfer', true);
  perform set_config('mybike.status_reference_id', p_transfer_id::text, true);

  for v_item in select * from public.stock_transfer_items where transfer_id = p_transfer_id loop
    insert into public.stock_ledger (
      showroom_id, movement_type, vehicle_id, unit_cost, value, from_showroom_id, to_showroom_id,
      reference_type, reference_id, reference_no, created_by
    ) values (
      v_transfer.destination_showroom_id, 'transfer_in', v_item.vehicle_id, v_item.unit_cost, v_item.unit_cost,
      v_transfer.source_showroom_id, v_transfer.destination_showroom_id,
      'stock_transfer', p_transfer_id, v_transfer.transfer_no, (select auth.uid())
    );
  end loop;

  update public.stock_transfers
     set status = 'received', received_by = (select auth.uid()), received_at = now(),
         remarks = coalesce(p_remarks, remarks)
   where id = p_transfer_id;
end;
$$;
comment on function public.rpc_receive_stock_transfer(uuid, text) is
  'Receives every vehicle of an in-transit transfer into the destination showroom at the same unit cost (no P&L impact). Requires inventory.create at the destination.';

-- p_items: jsonb array of {"vehicle_id": uuid, "direction": "in"|"out", "unit_cost": number?}.
-- unit_cost is required for "in" (nothing to derive it from) and ignored for
-- "out" (taken from the vehicle's own last known cost).
create function public.rpc_create_stock_adjustment(
  p_showroom_id uuid, p_adjustment_date date, p_reason_code text, p_items jsonb, p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_adjustment_id uuid;
  v_adjustment_no text;
  v_item          jsonb;
  v_vehicle_id    uuid;
  v_direction     text;
  v_cost          numeric;
  v_status        public.vehicle_status;
  v_total         numeric := 0;
begin
  if not public.has_permission_for('inventory', 'create', p_showroom_id) then
    raise exception 'You cannot create stock adjustments in this showroom.' using errcode = '42501';
  end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Add at least one vehicle.' using errcode = '23514';
  end if;

  v_adjustment_no := public.fn_next_document_number(p_showroom_id, 'stock_adjustment', p_adjustment_date);
  insert into public.stock_adjustments (showroom_id, adjustment_no, adjustment_date, reason_code, notes, created_by, posted_by, posted_at)
  values (p_showroom_id, v_adjustment_no, p_adjustment_date, p_reason_code, p_notes, (select auth.uid()), (select auth.uid()), now())
  returning id into v_adjustment_id;

  perform set_config('mybike.status_reference_type', 'stock_adjustment', true);
  perform set_config('mybike.status_reference_id', v_adjustment_id::text, true);
  perform set_config('mybike.status_reason', p_reason_code, true);

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_vehicle_id := (v_item ->> 'vehicle_id')::uuid;
    v_direction := v_item ->> 'direction';
    select status into v_status from public.vehicles where id = v_vehicle_id and showroom_id = p_showroom_id;
    if v_status is null then
      raise exception 'A vehicle in the adjustment is not in this showroom.' using errcode = 'PGRST116';
    end if;
    v_cost := case
      when v_direction = 'out' then public.fn_vehicle_last_unit_cost(v_vehicle_id)
      else (v_item ->> 'unit_cost')::numeric
    end;
    if v_direction = 'in' and (v_cost is null or v_cost < 0) then
      raise exception 'Enter the unit cost for a vehicle brought into stock.' using errcode = '23514';
    end if;

    insert into public.stock_adjustment_items (adjustment_id, vehicle_id, direction, unit_cost)
    values (v_adjustment_id, v_vehicle_id, v_direction, v_cost);
    insert into public.stock_ledger (showroom_id, movement_type, vehicle_id, unit_cost, value, reference_type, reference_id, reference_no, created_by)
    values (
      p_showroom_id,
      (case when v_direction = 'in' then 'adjustment_in' else 'adjustment_out' end)::public.stock_movement_type,
      v_vehicle_id, v_cost, v_cost, 'stock_adjustment', v_adjustment_id, v_adjustment_no, (select auth.uid())
    );
    v_total := v_total + coalesce(v_cost, 0);
  end loop;

  update public.stock_adjustments set total_value = v_total where id = v_adjustment_id;
  return v_adjustment_id;
end;
$$;
comment on function public.rpc_create_stock_adjustment(uuid, date, text, jsonb, text) is
  'Posts a batch stock correction (physical_count / damage / theft / expiry / correction / opening), one stock_ledger row per item. Requires inventory.create in the showroom.';

-- -----------------------------------------------------------------------------
-- 8. Views
-- -----------------------------------------------------------------------------
-- security_invoker: respects the querying user's own RLS, so this view never
-- widens what has_permission_for() already decides.
create view public.v_current_stock
with (security_invoker = true) as
select s.id as showroom_id, s.code as showroom_code,
       count(*) filter (where v.status = 'in_stock')                          as available_count,
       count(*) filter (where v.status = 'reserved')                         as reserved_count,
       count(*) filter (where v.status = 'in_transit')                       as in_transit_count,
       count(*) filter (where v.status = 'damaged')                         as damaged_count,
       coalesce(sum(l.unit_cost) filter (where v.status in ('in_stock', 'reserved')), 0) as available_value
  from public.showrooms s
  join public.vehicles v on v.showroom_id = s.id
  left join lateral (
    select ledger.unit_cost from public.stock_ledger ledger
     where ledger.vehicle_id = v.id
       and ledger.movement_type in ('purchase_receipt', 'transfer_in', 'opening', 'adjustment_in')
     order by ledger.created_at desc limit 1
  ) l on true
 group by s.id, s.code;
comment on view public.v_current_stock is
  'Available / reserved / in-transit / damaged vehicle counts and available value per showroom. security_invoker: RLS-scoped to the caller.';

-- variant_label is computed here (not embedded via a relationship) because
-- PostgREST cannot infer a foreign key through a plain view.
create view public.v_stock_ageing
with (security_invoker = true) as
select v.id as vehicle_id, v.showroom_id, v.chassis_number, v.status,
       btrim(vb.name || ' ' || vm.name || ' ' || vv.name) as variant_label,
       r.received_at,
       (public.fn_business_date() - r.received_at::date) as days_in_stock,
       case
         when public.fn_business_date() - r.received_at::date <= 30 then '0-30'
         when public.fn_business_date() - r.received_at::date <= 60 then '31-60'
         when public.fn_business_date() - r.received_at::date <= 90 then '61-90'
         else '90+'
       end as ageing_bucket
  from public.vehicles v
  join public.vehicle_variants vv on vv.id = v.variant_id
  join public.vehicle_models vm on vm.id = vv.model_id
  join public.vehicle_brands vb on vb.id = vm.brand_id
  join lateral (
    select ledger.created_at as received_at from public.stock_ledger ledger
     where ledger.vehicle_id = v.id
       and ledger.movement_type in ('purchase_receipt', 'transfer_in', 'opening', 'adjustment_in')
     order by ledger.created_at desc limit 1
  ) r on true
 where v.status in ('in_stock', 'reserved');
comment on view public.v_stock_ageing is
  'Days since a currently in-stock/reserved vehicle''s last receipt, bucketed 0-30/31-60/61-90/90+. security_invoker: RLS-scoped to the caller.';

-- -----------------------------------------------------------------------------
-- 9. Privileges
-- -----------------------------------------------------------------------------
revoke all on public.vehicle_status_history, public.vehicle_reservations, public.stock_ledger,
  public.stock_transfers, public.stock_transfer_items, public.stock_adjustments, public.stock_adjustment_items
  from anon;
revoke truncate, references, trigger on public.vehicle_status_history, public.vehicle_reservations,
  public.stock_ledger, public.stock_transfers, public.stock_transfer_items, public.stock_adjustments,
  public.stock_adjustment_items from authenticated;
-- No direct client writes at all: every change happens through the RPCs below.
revoke insert, update, delete on public.vehicle_status_history, public.vehicle_reservations, public.stock_ledger,
  public.stock_transfers, public.stock_transfer_items, public.stock_adjustments, public.stock_adjustment_items
  from authenticated;
revoke all on public.v_current_stock, public.v_stock_ageing from anon;
grant select on public.v_current_stock, public.v_stock_ageing to authenticated, service_role;

revoke execute on function public.fn_vehicle_status_history_record() from public, anon, authenticated;
revoke execute on function public.fn_stock_ledger_apply() from public, anon, authenticated;
revoke execute on function public.fn_vehicle_last_unit_cost(uuid) from public, anon, authenticated;

revoke execute on function public.rpc_receive_vehicle_stock(uuid, numeric, text, text) from public, anon;
revoke execute on function public.rpc_reserve_vehicle(uuid, text) from public, anon;
revoke execute on function public.rpc_release_reservation(uuid, text) from public, anon;
revoke execute on function public.rpc_mark_vehicle_damaged(uuid, text) from public, anon;
revoke execute on function public.rpc_create_stock_transfer(uuid, uuid, date, uuid[], text) from public, anon;
revoke execute on function public.rpc_receive_stock_transfer(uuid, text) from public, anon;
revoke execute on function public.rpc_create_stock_adjustment(uuid, date, text, jsonb, text) from public, anon;

grant execute on function public.rpc_receive_vehicle_stock(uuid, numeric, text, text) to authenticated, service_role;
grant execute on function public.rpc_reserve_vehicle(uuid, text) to authenticated, service_role;
grant execute on function public.rpc_release_reservation(uuid, text) to authenticated, service_role;
grant execute on function public.rpc_mark_vehicle_damaged(uuid, text) to authenticated, service_role;
grant execute on function public.rpc_create_stock_transfer(uuid, uuid, date, uuid[], text) to authenticated, service_role;
grant execute on function public.rpc_receive_stock_transfer(uuid, text) to authenticated, service_role;
grant execute on function public.rpc_create_stock_adjustment(uuid, date, text, jsonb, text) to authenticated, service_role;
