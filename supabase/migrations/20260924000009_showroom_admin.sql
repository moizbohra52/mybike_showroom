-- =============================================================================
-- MyBike · Phase 7 · 0009 — showroom administration
-- -----------------------------------------------------------------------------
-- Design: docs/phase-07/README.md
--
--   * bank_accounts: the showroom's bank details (invoices, payment
--     instructions). Phase 13 links them to the ledger and adds balances.
--   * rpc_create_showroom(): creates a showroom and assigns a non-owner
--     creator to it in the same transaction, so the creator can read it back
--     (docs/phase-04/README.md, Phase 7 note).
--   * invoice_prefix can change only until the first document number is
--     issued; the showroom's numbering series follow the new prefix.
--   * rpc_get_my_session() lists active showrooms only: a deactivated
--     showroom leaves the switcher (Super Admin still manages it).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. bank_accounts
-- -----------------------------------------------------------------------------
create table public.bank_accounts (
  id             uuid primary key default gen_random_uuid(),
  showroom_id    uuid not null references public.showrooms (id) on delete restrict,
  account_name   text not null,
  bank_name      text not null,
  account_number text not null,
  ifsc           text not null,
  branch         text,
  upi_id         text,
  is_default     boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid references public.profiles (id) on delete set null,
  updated_by     uuid,
  constraint bank_accounts_showroom_number_key unique (showroom_id, account_number),
  constraint bank_accounts_account_name_not_blank check (char_length(btrim(account_name)) between 2 and 120),
  constraint bank_accounts_bank_name_not_blank check (char_length(btrim(bank_name)) between 2 and 120),
  constraint bank_accounts_account_number_format check (account_number ~ '^[0-9]{9,18}$'),
  constraint bank_accounts_ifsc_format check (ifsc ~ '^[A-Z]{4}0[A-Z0-9]{6}$'),
  constraint bank_accounts_branch_length check (branch is null or char_length(btrim(branch)) between 1 and 120),
  constraint bank_accounts_upi_format check (upi_id is null or upi_id ~ '^[A-Za-z0-9._-]{2,64}@[A-Za-z]{2,64}$')
);
comment on table public.bank_accounts is
  'Bank accounts of a showroom (printed on invoices, used for payments). Phase 13 adds the ledger link and balances.';
comment on column public.bank_accounts.is_default is
  'The account printed on invoices; at most one per showroom (setting a new default clears the old one).';

create unique index uq_bank_accounts_one_default on public.bank_accounts (showroom_id) where is_default;

-- A new default replaces the previous one (the caller's RLS applies: only
-- someone who may edit the showroom's accounts gets here).
create function public.fn_bank_accounts_single_default()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_default then
    update public.bank_accounts b
       set is_default = false
     where b.showroom_id = new.showroom_id
       and b.id <> new.id
       and b.is_default;
  end if;
  return new;
end;
$$;
comment on function public.fn_bank_accounts_single_default() is
  'BEFORE INSERT/UPDATE trigger on bank_accounts: a new default clears the showroom''s previous default.';

create trigger trg_bank_accounts_single_default
  before insert or update of is_default on public.bank_accounts
  for each row execute function public.fn_bank_accounts_single_default();
create trigger trg_set_created_by
  before insert or update on public.bank_accounts
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at
  before update on public.bank_accounts
  for each row execute function public.set_updated_at();

alter table public.bank_accounts enable row level security;

-- Readable wherever the showroom is (invoices print them); maintained with the
-- showroom's setup.
create policy bank_accounts_select on public.bank_accounts
  for select to authenticated
  using (public.can_access_showroom(showroom_id));

create policy bank_accounts_insert on public.bank_accounts
  for insert to authenticated
  with check (public.has_permission_for('showrooms', 'edit', showroom_id));

create policy bank_accounts_update on public.bank_accounts
  for update to authenticated
  using (public.has_permission_for('showrooms', 'edit', showroom_id))
  with check (public.has_permission_for('showrooms', 'edit', showroom_id));

create policy bank_accounts_delete on public.bank_accounts
  for delete to authenticated
  using (public.has_permission_for('showrooms', 'edit', showroom_id));

-- -----------------------------------------------------------------------------
-- 2. Invoice prefix: editable until the first number is issued
-- -----------------------------------------------------------------------------
-- SECURITY DEFINER: numbering series are server-maintained (clients have no
-- write privilege). It touches only the updated showroom's series.
create function public.fn_showrooms_sync_prefix()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from public.document_sequences ds
              where ds.showroom_id = new.id and ds.next_number > 1) then
    raise exception 'The invoice prefix of % cannot change: document numbers were already issued with it.', new.code
      using errcode = 'MB012', hint = 'invoice_prefix_in_use';
  end if;
  update public.document_sequences ds
     set prefix  = new.invoice_prefix || public.fn_document_type_code(ds.doc_type),
         padding = case
                     when public.fn_is_gst_document(ds.doc_type)
                       then least(5, 16 - 7 - char_length(new.invoice_prefix || public.fn_document_type_code(ds.doc_type)))
                     else 5
                   end
   where ds.showroom_id = new.id;
  return new;
end;
$$;
comment on function public.fn_showrooms_sync_prefix() is
  'AFTER UPDATE OF invoice_prefix trigger on showrooms: refuses (MB012) once a number was issued, else re-prefixes the showroom''s series.';

create trigger trg_showrooms_sync_prefix
  after update of invoice_prefix on public.showrooms
  for each row
  when (new.invoice_prefix is distinct from old.invoice_prefix)
  execute function public.fn_showrooms_sync_prefix();

-- -----------------------------------------------------------------------------
-- 3. rpc_create_showroom
-- -----------------------------------------------------------------------------
-- The showrooms insert policy needs showrooms.create granted globally; this
-- RPC applies the same check, inserts, and assigns a non-owner creator (the
-- owner sees every showroom anyway). Settings and numbering come from the
-- 0002 bootstrap trigger.
create function public.rpc_create_showroom(p_showroom jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.showrooms;
  v_id  uuid;
begin
  if not public.has_permission_for('showrooms', 'create', null) then
    raise exception 'You cannot create showrooms.' using errcode = '42501';
  end if;
  v_row := jsonb_populate_record(null::public.showrooms, p_showroom);
  insert into public.showrooms (
    code, name, legal_name, gstin, pan, address_line1, address_line2, city, state_code,
    pincode, phone, email, invoice_prefix, opened_on
  )
  values (
    upper(btrim(v_row.code)), btrim(v_row.name), nullif(btrim(v_row.legal_name), ''),
    nullif(upper(btrim(v_row.gstin)), ''), nullif(upper(btrim(v_row.pan)), ''),
    nullif(btrim(v_row.address_line1), ''), nullif(btrim(v_row.address_line2), ''),
    nullif(btrim(v_row.city), ''), nullif(btrim(v_row.state_code), ''), nullif(btrim(v_row.pincode), ''),
    nullif(btrim(v_row.phone), ''), nullif(btrim(v_row.email::text), ''),
    upper(btrim(v_row.invoice_prefix)), v_row.opened_on
  )
  returning id into v_id;

  if not public.is_super_admin() then
    insert into public.user_showrooms (profile_id, showroom_id)
    values ((select auth.uid()), v_id)
    on conflict (profile_id, showroom_id) do nothing;
  end if;
  return v_id;
end;
$$;
comment on function public.rpc_create_showroom(jsonb) is
  'Creates a showroom (showrooms.create granted globally) and assigns a non-owner creator to it. Returns the id.';

-- -----------------------------------------------------------------------------
-- 4. rpc_get_my_session — active showrooms only (0007 otherwise unchanged)
-- -----------------------------------------------------------------------------
create or replace function public.rpc_get_my_session()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select p.id, p.full_name, p.email, p.status, p.is_active
      from public.profiles p
     where p.id = (select auth.uid())
  ),
  grants as (
    select ur.showroom_id, r.code as role_code, pm.code as permission
      from me
      join public.user_roles ur on ur.profile_id = me.id
      join public.roles r on r.id = ur.role_id and r.is_active
      join public.role_permissions rp on rp.role_id = r.id
      join public.permissions pm on pm.id = rp.permission_id
     where me.is_active
       and (ur.expires_on is null or ur.expires_on >= public.fn_business_date())
  )
  select jsonb_build_object(
           'profile', jsonb_build_object(
             'id', me.id,
             'full_name', me.full_name,
             'email', me.email,
             'status', me.status,
             'is_active', me.is_active
           ),
           'is_super_admin', public.is_super_admin(),
           'global_permissions', coalesce(
             (select jsonb_agg(distinct g.permission order by g.permission)
                from grants g where g.showroom_id is null),
             '[]'::jsonb),
           'showrooms', coalesce(
             (select jsonb_agg(jsonb_build_object(
                       'id', s.id,
                       'code', s.code,
                       'name', s.name,
                       'is_active', s.is_active,
                       'is_default', coalesce(us.is_default, false),
                       'roles', coalesce(
                         (select jsonb_agg(distinct g.role_code order by g.role_code)
                            from grants g where g.showroom_id is null or g.showroom_id = s.id),
                         '[]'::jsonb),
                       'permissions', coalesce(
                         (select jsonb_agg(distinct g.permission order by g.permission)
                            from grants g where g.showroom_id is null or g.showroom_id = s.id),
                         '[]'::jsonb)
                     ) order by s.code)
                from public.showrooms s
                left join public.user_showrooms us
                  on us.showroom_id = s.id and us.profile_id = me.id
               where s.is_active
                 and public.can_access_showroom(s.id)),
             '[]'::jsonb)
         )
    from me;
$$;
comment on function public.rpc_get_my_session() is
  'Session payload for the signed-in user: profile, is_super_admin, global_permissions and the ACTIVE accessible showrooms with their effective roles/permissions. NULL when the JWT has no profile.';

-- -----------------------------------------------------------------------------
-- 5. Privileges
-- -----------------------------------------------------------------------------
revoke truncate, references, trigger on public.bank_accounts from authenticated;
revoke all on public.bank_accounts from anon;
revoke execute on function public.fn_bank_accounts_single_default() from public, anon, authenticated;
revoke execute on function public.fn_showrooms_sync_prefix() from public, anon, authenticated;
revoke execute on function public.rpc_create_showroom(jsonb) from public, anon;
grant execute on function public.rpc_create_showroom(jsonb) to authenticated, service_role;
