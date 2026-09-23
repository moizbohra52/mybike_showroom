-- =============================================================================
-- MyBike · Phase 3 · 0003 — profiles, roles, permissions, role_permissions,
--                            user_roles, user_showrooms, auth → profile trigger
-- -----------------------------------------------------------------------------
-- Design: docs/phase-00/02-roles-permissions.md, 04-multishowroom-security.md §3,
--         05-database-plan.md §4.1, docs/phase-03/README.md
--
-- Security notes
--   * Roles and permissions live ONLY in these tables. Nothing is ever read
--     from auth.users.raw_user_meta_data / raw_app_meta_data (user metadata is
--     writable by the user and must never grant access).
--   * A user with zero user_roles rows has no access (fail closed).
--   * RLS is enabled with no policies (deny-all) until Phase 4 (0005).
--   * RBAC helper functions (is_super_admin, has_permission, …) arrive in
--     Phase 4 (0005); only current_profile_id() is created here.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. profiles — application profile of every auth user
-- -----------------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  employee_code text,
  full_name     text not null,
  email         extensions.citext,
  phone         text,
  designation   text,
  avatar_path   text,
  status        public.user_status not null default 'active',
  is_active     boolean generated always as (status = 'active') stored,
  last_login_at timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid references public.profiles (id) on delete set null,
  updated_by    uuid,
  constraint profiles_email_key unique (email),
  constraint profiles_employee_code_key unique (employee_code),
  constraint profiles_employee_code_format
    check (employee_code is null or employee_code ~ '^[A-Z0-9][A-Z0-9-]{1,19}$'),
  constraint profiles_full_name_not_blank check (char_length(btrim(full_name)) between 1 and 120),
  constraint profiles_phone_format check (phone is null or phone ~ '^\+?[0-9]{10,15}$')
);
comment on table public.profiles is
  'Application profile per Supabase Auth user (id = auth.users.id), created by trigger on auth.users. Holds no role or permission data.';
comment on column public.profiles.email is 'Mirrors auth.users.email (kept in sync by trigger); case-insensitive unique.';
comment on column public.profiles.is_active is
  'Derived from status = active. Re-checked by is_active_user() inside every RLS policy (Phase 4), so a deactivated user''s live JWT sees nothing.';
comment on column public.profiles.avatar_path is 'Storage object path in the private avatars bucket, never a public URL.';

create index idx_profiles_is_active on public.profiles (is_active);
create index idx_profiles_full_name_trgm on public.profiles using gin (full_name extensions.gin_trgm_ops);

create trigger trg_set_created_by
  before insert or update on public.profiles
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

-- -----------------------------------------------------------------------------
-- 2. roles
-- -----------------------------------------------------------------------------
create table public.roles (
  id          uuid primary key default gen_random_uuid(),
  code        text not null,
  name        text not null,
  description text,
  is_system   boolean not null default false,
  precedence  smallint not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid references public.profiles (id) on delete set null,
  updated_by  uuid,
  constraint roles_code_key unique (code),
  constraint roles_name_key unique (name),
  constraint roles_code_format check (code ~ '^[A-Z][A-Z0-9_]{1,39}$'),
  constraint roles_name_not_blank check (char_length(btrim(name)) between 2 and 80),
  constraint roles_precedence_range check (precedence between 0 and 1000)
);
comment on table public.roles is
  'Application roles. The 11 system roles (is_system) are seeded by migration and cannot be deleted, renamed (code) or deactivated.';
comment on column public.roles.precedence is
  'Higher wins when resolving a user''s effective role in a showroom (SUPER_ADMIN 100 … VIEWER 10). Ties are resolved by role code.';

-- System roles are protected; app users can never mint system roles.
create function public.fn_roles_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null then
      new.is_system := false;
    end if;
    return new;
  elsif tg_op = 'UPDATE' then
    if old.is_system and (new.code <> old.code or not new.is_system or not new.is_active) then
      raise exception 'System role % cannot be renamed, demoted or deactivated.', old.code
        using errcode = 'MB020', hint = 'system_role_protected';
    end if;
    if not old.is_system and new.is_system and auth.uid() is not null then
      raise exception 'Only migrations can create system roles.'
        using errcode = 'MB020', hint = 'system_role_protected';
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System role % cannot be deleted.', old.code
        using errcode = 'MB020', hint = 'system_role_protected';
    end if;
    return old;
  end if;
  return null;
end;
$$;
comment on function public.fn_roles_guard() is
  'BEFORE INSERT/UPDATE/DELETE trigger on roles: protects system roles; app users cannot create system roles.';

create trigger trg_roles_guard
  before insert or update or delete on public.roles
  for each row execute function public.fn_roles_guard();
create trigger trg_set_created_by
  before insert or update on public.roles
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at
  before update on public.roles
  for each row execute function public.set_updated_at();

alter table public.roles enable row level security;

-- -----------------------------------------------------------------------------
-- 3. permissions — module × action catalogue (code-defined, migration-owned)
-- -----------------------------------------------------------------------------
create table public.permissions (
  id          uuid primary key default gen_random_uuid(),
  module      text not null,
  action      text not null,
  code        text generated always as (module || '.' || action) stored,
  description text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint permissions_module_action_key unique (module, action),
  constraint permissions_code_key unique (code),
  -- Canonical module keys: lib/core/constants/module_keys.dart (ModuleKeys.all).
  constraint permissions_module_known check (module in (
    'dashboard', 'showrooms', 'users', 'roles', 'vehicles', 'inventory', 'purchases',
    'suppliers', 'sales', 'customers', 'bookings', 'finance', 'accounting', 'expenses',
    'income', 'reports', 'documents', 'notifications', 'audit', 'settings', 'approvals'
  )),
  -- PermissionActions.all + the special showrooms.view_all (ALL SHOWROOMS mode).
  constraint permissions_action_known check (action in (
    'view', 'create', 'edit', 'delete', 'approve', 'export', 'print', 'view_all'
  )),
  constraint permissions_view_all_showrooms_only check (action <> 'view_all' or module = 'showrooms')
);
comment on table public.permissions is
  'Permission catalogue: every module.action pair from docs/phase-00/02-roles-permissions.md §2 plus showrooms.view_all. Written only by migrations.';
comment on column public.permissions.code is 'Derived permission key, e.g. sales.create (same string as PermissionKeys.code in Dart).';

create trigger trg_set_updated_at
  before update on public.permissions
  for each row execute function public.set_updated_at();

alter table public.permissions enable row level security;

-- -----------------------------------------------------------------------------
-- 4. role_permissions
-- -----------------------------------------------------------------------------
create table public.role_permissions (
  role_id       uuid not null references public.roles (id) on delete cascade,
  permission_id uuid not null references public.permissions (id) on delete cascade,
  granted_by    uuid references public.profiles (id) on delete set null,
  granted_at    timestamptz not null default now(),
  constraint role_permissions_pkey primary key (role_id, permission_id)
);
comment on table public.role_permissions is
  'Grants of permissions to roles (the module × role matrix). Seeded from docs/phase-00/02-roles-permissions.md §4; edited by Super Admin in Phase 6.';

create index idx_role_permissions_permission on public.role_permissions (permission_id);

-- Matrix invariant (02-roles-permissions §4): VIEWER never receives create,
-- edit, delete or approve — whoever edits the matrix.
create function public.fn_role_permissions_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_role_code text;
  v_action    text;
begin
  select r.code into v_role_code from public.roles r where r.id = new.role_id;
  select p.action into v_action from public.permissions p where p.id = new.permission_id;

  if v_role_code = 'VIEWER' and v_action in ('create', 'edit', 'delete', 'approve') then
    raise exception 'The VIEWER role is read-only and cannot be granted %.', v_action
      using errcode = 'MB021', hint = 'viewer_read_only';
  end if;
  if v_action = 'view_all' and v_role_code is distinct from 'SUPER_ADMIN' then
    raise exception 'ALL SHOWROOMS access (showrooms.view_all) is reserved for SUPER_ADMIN.'
      using errcode = 'MB021', hint = 'view_all_super_admin_only';
  end if;
  return new;
end;
$$;
comment on function public.fn_role_permissions_guard() is
  'BEFORE INSERT/UPDATE trigger on role_permissions: VIEWER stays read-only; showrooms.view_all only for SUPER_ADMIN.';

create trigger trg_role_permissions_guard
  before insert or update on public.role_permissions
  for each row execute function public.fn_role_permissions_guard();
create trigger trg_set_granted_by
  before insert or update on public.role_permissions
  for each row execute function public.fn_set_granted_by();

alter table public.role_permissions enable row level security;

-- -----------------------------------------------------------------------------
-- 5. user_roles — role assignments, global (showroom_id NULL) or per showroom
-- -----------------------------------------------------------------------------
create table public.user_roles (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  role_id     uuid not null references public.roles (id) on delete restrict,
  showroom_id uuid references public.showrooms (id) on delete restrict,
  granted_by  uuid references public.profiles (id) on delete set null,
  granted_at  timestamptz not null default now(),
  expires_on  date,
  updated_at  timestamptz not null default now(),
  constraint user_roles_assignment_key unique nulls not distinct (profile_id, role_id, showroom_id)
);
comment on table public.user_roles is
  'Role assignments. showroom_id NULL = global assignment; otherwise the role applies only in that showroom. Zero rows = no access.';
comment on column public.user_roles.expires_on is 'Optional last valid day (IST) of the assignment; enforced by the Phase 4 helpers.';

create index idx_user_roles_role on public.user_roles (role_id);
create index idx_user_roles_showroom on public.user_roles (showroom_id) where showroom_id is not null;

-- SUPER_ADMIN is a global role by definition (02-roles-permissions §1).
create function public.fn_user_roles_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.showroom_id is not null
     and exists (select 1 from public.roles r where r.id = new.role_id and r.code = 'SUPER_ADMIN') then
    raise exception 'SUPER_ADMIN must be assigned globally (without a showroom).'
      using errcode = 'MB022', hint = 'super_admin_is_global';
  end if;
  return new;
end;
$$;
comment on function public.fn_user_roles_guard() is
  'BEFORE INSERT/UPDATE trigger on user_roles: SUPER_ADMIN assignments are always global.';

create trigger trg_user_roles_guard
  before insert or update of role_id, showroom_id on public.user_roles
  for each row execute function public.fn_user_roles_guard();
create trigger trg_set_granted_by
  before insert or update on public.user_roles
  for each row execute function public.fn_set_granted_by();
create trigger trg_set_updated_at
  before update on public.user_roles
  for each row execute function public.set_updated_at();

alter table public.user_roles enable row level security;

-- -----------------------------------------------------------------------------
-- 6. user_showrooms — which showrooms a user may work in
-- -----------------------------------------------------------------------------
create table public.user_showrooms (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  showroom_id uuid not null references public.showrooms (id) on delete restrict,
  is_default  boolean not null default false,
  is_active   boolean not null default true,
  granted_by  uuid references public.profiles (id) on delete set null,
  granted_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint user_showrooms_assignment_key unique (profile_id, showroom_id),
  constraint user_showrooms_default_is_active check (not is_default or is_active)
);
comment on table public.user_showrooms is
  'Showroom access of each user. can_access_showroom() (Phase 4) = SUPER_ADMIN or an active row here. The single is_default row is the showroom auto-selected at login.';
comment on column public.user_showrooms.is_default is
  'At most one default per user (partial unique index). Replaces profiles.default_showroom_id from the Phase 0 plan so the default can never point at an unassigned showroom.';

create unique index uq_user_showrooms_one_default on public.user_showrooms (profile_id) where is_default;
create index idx_user_showrooms_showroom on public.user_showrooms (showroom_id);

create trigger trg_set_granted_by
  before insert or update on public.user_showrooms
  for each row execute function public.fn_set_granted_by();
create trigger trg_set_updated_at
  before update on public.user_showrooms
  for each row execute function public.set_updated_at();

alter table public.user_showrooms enable row level security;

-- -----------------------------------------------------------------------------
-- 7. Audit-column foreign keys for the 0002 tables (profiles now exists)
-- -----------------------------------------------------------------------------
alter table public.showrooms
  add constraint showrooms_created_by_fkey foreign key (created_by)
  references public.profiles (id) on delete set null;
alter table public.showroom_settings
  add constraint showroom_settings_created_by_fkey foreign key (created_by)
  references public.profiles (id) on delete set null;
alter table public.settings
  add constraint settings_created_by_fkey foreign key (created_by)
  references public.profiles (id) on delete set null;
alter table public.financial_years
  add constraint financial_years_created_by_fkey foreign key (created_by)
  references public.profiles (id) on delete set null,
  add constraint financial_years_closed_by_fkey foreign key (closed_by)
  references public.profiles (id) on delete set null;
alter table public.accounting_periods
  add constraint accounting_periods_created_by_fkey foreign key (created_by)
  references public.profiles (id) on delete set null,
  add constraint accounting_periods_locked_by_fkey foreign key (locked_by)
  references public.profiles (id) on delete set null;
alter table public.document_sequences
  add constraint document_sequences_created_by_fkey foreign key (created_by)
  references public.profiles (id) on delete set null;

-- -----------------------------------------------------------------------------
-- 8. Auth → profile synchronisation
-- -----------------------------------------------------------------------------

-- Creates the profile of every new auth user. Only the display name is taken
-- from user metadata; status defaults to active but access still requires
-- user_roles + user_showrooms rows granted by an administrator.
create function public.fn_handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    left(
      coalesce(
        nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
        nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
        'User'
      ),
      120
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
comment on function public.fn_handle_new_auth_user() is
  'AFTER INSERT trigger on auth.users: creates public.profiles. Never reads roles/showrooms from user metadata.';

create trigger trg_auth_users_create_profile
  after insert on auth.users
  for each row execute function public.fn_handle_new_auth_user();

-- Keeps profiles.email equal to the confirmed auth e-mail.
create function public.fn_sync_auth_user_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles p
     set email = new.email
   where p.id = new.id
     and p.email is distinct from new.email;
  return new;
end;
$$;
comment on function public.fn_sync_auth_user_email() is
  'AFTER UPDATE OF email trigger on auth.users: mirrors the e-mail into public.profiles.';

create trigger trg_auth_users_sync_email
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.fn_sync_auth_user_email();

-- -----------------------------------------------------------------------------
-- 9. current_profile_id() — base helper for the Phase 4 RLS functions
-- -----------------------------------------------------------------------------
create function public.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id from public.profiles p where p.id = (select auth.uid());
$$;
comment on function public.current_profile_id() is
  'profiles.id of the calling user (NULL when the JWT has no profile). SECURITY DEFINER so it works under deny-all RLS; returns only the caller''s own id.';

-- -----------------------------------------------------------------------------
-- 10. Privileges
-- -----------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke truncate, references, trigger on all tables in schema public from authenticated;
-- The permission catalogue is code-defined: only migrations change it.
revoke insert, update, delete on public.permissions from authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.fn_business_date(timestamptz) to authenticated, service_role;
grant execute on function public.fn_fy_start_date(date) to authenticated, service_role;
grant execute on function public.fn_fy_code(date) to authenticated, service_role;
grant execute on function public.fn_fy_short_code(text) to authenticated, service_role;
grant execute on function public.fn_is_gst_document(public.document_sequence_type) to authenticated, service_role;
grant execute on function public.fn_document_type_code(public.document_sequence_type) to authenticated, service_role;
grant execute on function public.current_profile_id() to authenticated, service_role;
