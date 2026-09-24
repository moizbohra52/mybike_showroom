-- =============================================================================
-- MyBike · Phase 6 · 0008 — user, role and permission administration
-- -----------------------------------------------------------------------------
-- Design: docs/phase-06/README.md
--
-- Delegation rules (RLS stays the authority, G1)
--   * Rank = highest precedence among a user's roles that apply in a scope:
--     global roles + roles of that showroom (NULL scope = global roles only).
--   * A caller manages a user IN a scope when they hold users.edit there and
--     outrank the user there (roles, showroom removal in that showroom).
--   * Changes that reach every showroom of the user (status, profile, password,
--     adding a showroom, global roles) need the caller to outrank the user in
--     EVERY scope the user has. An unassigned user belongs to global user
--     administrators or to whoever created them (admin-users Edge Function).
--   * A role can be granted in a scope only when it ranks below the caller.
--   * Roles and the matrix need roles.* granted globally and apply only to
--     roles ranking below the caller; a permission can be granted only by
--     someone holding it globally. SUPER_ADMIN is exempt from rank; its own
--     matrix row is locked (it always holds every permission).
--   * Nobody changes their own assignments or status (0005 rule, kept).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Constraints
-- -----------------------------------------------------------------------------

-- Only the system SUPER_ADMIN role ranks at 100.
alter table public.roles
  add constraint roles_custom_precedence_below_owner check (is_system or precedence < 100);

-- A showroom-scoped role needs a membership of that showroom; removing the
-- membership removes the user's roles there.
alter table public.user_roles
  add constraint user_roles_membership_fkey foreign key (profile_id, showroom_id)
  references public.user_showrooms (profile_id, showroom_id) on delete cascade;

alter table public.profiles
  add constraint profiles_designation_length
  check (designation is null or char_length(btrim(designation)) between 1 and 80);

-- Who onboarded the user. Only the service role can write auth app_metadata,
-- so invited_by comes from the admin-users Edge Function alone. GoTrue applies
-- app_metadata in an UPDATE after the INSERT, hence both triggers; the value
-- is set once and never changes afterwards.
alter table public.profiles
  add column invited_by uuid references public.profiles (id) on delete set null;
comment on column public.profiles.invited_by is
  'Profile that created this user via the admin-users Edge Function (auth app_metadata.invited_by, service role only). Set once; lets the creator assign the new, still unassigned user.';

-- -----------------------------------------------------------------------------
-- 2. Rank and delegation helpers
-- -----------------------------------------------------------------------------

-- Not granted to API roles: it answers questions about any user and is only
-- called from the SECURITY DEFINER helpers below. p_usable_only = false counts
-- inactive and expired assignments too (conservative for the target user).
create function public.fn_role_rank(p_profile_id uuid, p_showroom_id uuid, p_usable_only boolean)
returns integer
language sql
stable
set search_path = ''
as $$
  select coalesce(max(r.precedence), -1)::integer
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
   where ur.profile_id = p_profile_id
     and (ur.showroom_id is null or ur.showroom_id = p_showroom_id)
     and (not p_usable_only
          or (r.is_active and (ur.expires_on is null or ur.expires_on >= public.fn_business_date())));
$$;
comment on function public.fn_role_rank(uuid, uuid, boolean) is
  'Highest role precedence of a user in a scope (global roles + roles of the showroom; NULL = global only); -1 without roles. Internal.';

create function public.my_role_rank(p_showroom_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when public.is_active_user()
              then public.fn_role_rank((select auth.uid()), p_showroom_id, true)
              else -1 end;
$$;
comment on function public.my_role_rank(uuid) is
  'The caller''s rank in a scope from usable assignments (NULL = global roles only); -1 when inactive or without roles.';

create function public.can_manage_user_in(p_profile_id uuid, p_showroom_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(p_profile_id <> (select auth.uid()), false)
     and public.is_active_user()
     and (
       public.is_super_admin()
       or (public.has_permission_for('users', 'edit', p_showroom_id)
           and public.fn_role_rank(p_profile_id, p_showroom_id, false)
             < public.fn_role_rank((select auth.uid()), p_showroom_id, true))
     );
$$;
comment on function public.can_manage_user_in(uuid, uuid) is
  'Caller may change another user''s access in one scope: users.edit there and a higher rank there (NULL = global scope). Never oneself.';

create function public.can_manage_user(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(p_profile_id <> (select auth.uid()), false)
     and public.is_active_user()
     and exists (select 1 from public.profiles p where p.id = p_profile_id)
     and (
       public.is_super_admin()
       or (
         -- outranks the user in every showroom they belong to …
         not exists (select 1
                       from public.user_showrooms us
                      where us.profile_id = p_profile_id
                        and not public.can_manage_user_in(p_profile_id, us.showroom_id))
         -- … and globally when they hold global roles …
         and (not exists (select 1
                            from public.user_roles ur
                           where ur.profile_id = p_profile_id and ur.showroom_id is null)
              or public.can_manage_user_in(p_profile_id, null))
         -- … and an unassigned user belongs to global user admins or its creator.
         and (exists (select 1 from public.user_showrooms us where us.profile_id = p_profile_id)
              or exists (select 1 from public.user_roles ur where ur.profile_id = p_profile_id)
              or public.has_permission_for('users', 'edit', null)
              or (public.has_permission('users', 'edit')
                  and exists (select 1 from public.profiles p
                               where p.id = p_profile_id and p.invited_by = (select auth.uid()))))
       )
     );
$$;
comment on function public.can_manage_user(uuid) is
  'Caller may change what affects all of a user''s showrooms (status, profile, password, new showroom, global roles). Never oneself.';

create function public.can_assign_role(p_role_id uuid, p_showroom_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_active_user()
     and exists (
       select 1
         from public.roles r
        where r.id = p_role_id
          and r.is_active
          and (public.is_super_admin()
               or (public.has_permission_for('users', 'edit', p_showroom_id)
                   and r.precedence < public.fn_role_rank((select auth.uid()), p_showroom_id, true)))
     );
$$;
comment on function public.can_assign_role(uuid, uuid) is
  'Caller may grant this active role in the scope (NULL = globally): users.edit there and the role ranks below the caller.';

create function public.can_edit_role(p_role_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_permission_for('roles', 'edit', null)
     and (public.is_super_admin()
          or exists (select 1
                       from public.roles r
                      where r.id = p_role_id
                        and r.precedence < public.fn_role_rank((select auth.uid()), null, true)));
$$;
comment on function public.can_edit_role(uuid) is
  'Caller may edit this role and its permissions: roles.edit granted globally and the role ranks below the caller (SUPER_ADMIN: any role).';

-- -----------------------------------------------------------------------------
-- 3. Guards
-- -----------------------------------------------------------------------------

-- 0003 guard + the SUPER_ADMIN matrix lock (now also on DELETE).
create or replace function public.fn_role_permissions_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_role_id       uuid;
  v_permission_id uuid;
  v_role_code     text;
  v_action        text;
begin
  if tg_op = 'DELETE' then
    v_role_id := old.role_id;
    v_permission_id := old.permission_id;
  else
    v_role_id := new.role_id;
    v_permission_id := new.permission_id;
  end if;
  select r.code into v_role_code from public.roles r where r.id = v_role_id;
  select p.action into v_action from public.permissions p where p.id = v_permission_id;

  if v_role_code = 'SUPER_ADMIN' and auth.uid() is not null then
    raise exception 'The Super Admin role always holds every permission.'
      using errcode = 'MB021', hint = 'super_admin_matrix_locked';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
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
  'BEFORE INSERT/UPDATE/DELETE trigger on role_permissions: SUPER_ADMIN row locked for app users; VIEWER stays read-only; showrooms.view_all only for SUPER_ADMIN.';

drop trigger trg_role_permissions_guard on public.role_permissions;
create trigger trg_role_permissions_guard
  before insert or update or delete on public.role_permissions
  for each row execute function public.fn_role_permissions_guard();

-- Profile trigger: also records invited_by (column added in section 1).
create or replace function public.fn_handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, invited_by)
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
    ),
    (select p.id from public.profiles p
      where p.id = public.fn_try_uuid(new.raw_app_meta_data ->> 'invited_by'))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
comment on function public.fn_handle_new_auth_user() is
  'AFTER INSERT trigger on auth.users: creates public.profiles (invited_by from app_metadata). Never reads roles/showrooms from metadata.';

create function public.fn_sync_auth_user_invited_by()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles p
     set invited_by = i.id
    from (select x.id from public.profiles x
           where x.id = public.fn_try_uuid(new.raw_app_meta_data ->> 'invited_by')
             and x.id <> new.id) i
   where p.id = new.id
     and p.invited_by is null;
  return new;
end;
$$;
comment on function public.fn_sync_auth_user_invited_by() is
  'AFTER UPDATE OF raw_app_meta_data trigger on auth.users: fills profiles.invited_by once from app_metadata.invited_by.';

create trigger trg_auth_users_sync_invited_by
  after update of raw_app_meta_data on auth.users
  for each row
  when (new.raw_app_meta_data ->> 'invited_by' is distinct from old.raw_app_meta_data ->> 'invited_by')
  execute function public.fn_sync_auth_user_invited_by();

-- -----------------------------------------------------------------------------
-- 4. Policies (replace the 0005 global-only versions)
-- -----------------------------------------------------------------------------
drop policy user_roles_insert on public.user_roles;
drop policy user_roles_update on public.user_roles;
drop policy user_roles_delete on public.user_roles;
drop policy user_showrooms_insert on public.user_showrooms;
drop policy user_showrooms_update on public.user_showrooms;
drop policy user_showrooms_delete on public.user_showrooms;
drop policy roles_insert on public.roles;
drop policy roles_update on public.roles;
drop policy roles_delete on public.roles;
drop policy role_permissions_insert on public.role_permissions;
drop policy role_permissions_delete on public.role_permissions;

-- Assignments are granted or revoked, never edited.
revoke update on public.user_roles, public.user_showrooms from authenticated;

create policy user_showrooms_insert on public.user_showrooms
  for insert to authenticated
  with check (public.can_manage_user_in(profile_id, showroom_id) and public.can_manage_user(profile_id));

create policy user_showrooms_delete on public.user_showrooms
  for delete to authenticated
  using (public.can_manage_user_in(profile_id, showroom_id));

create policy user_roles_insert on public.user_roles
  for insert to authenticated
  with check (
    public.can_assign_role(role_id, showroom_id)
    and case when showroom_id is null then public.can_manage_user(profile_id)
             else public.can_manage_user_in(profile_id, showroom_id) end
  );

create policy user_roles_delete on public.user_roles
  for delete to authenticated
  using (public.can_manage_user_in(profile_id, showroom_id));

create policy roles_insert on public.roles
  for insert to authenticated
  with check (
    (select public.has_permission_for('roles', 'create', null))
    and ((select public.is_super_admin()) or precedence < (select public.my_role_rank(null)))
  );

create policy roles_update on public.roles
  for update to authenticated
  using (public.can_edit_role(id))
  with check ((select public.is_super_admin()) or precedence < (select public.my_role_rank(null)));

create policy roles_delete on public.roles
  for delete to authenticated
  using ((select public.has_permission_for('roles', 'delete', null)) and public.can_edit_role(id));

create policy role_permissions_insert on public.role_permissions
  for insert to authenticated
  with check (
    public.can_edit_role(role_id)
    and ((select public.is_super_admin())
         or exists (select 1
                      from public.permissions p
                     where p.id = permission_id
                       and public.has_permission_for(p.module, p.action, null)))
  );

create policy role_permissions_delete on public.role_permissions
  for delete to authenticated
  using (public.can_edit_role(role_id));

-- -----------------------------------------------------------------------------
-- 5. RPCs
-- -----------------------------------------------------------------------------

-- Profile fields an administrator maintains. Self-service stays the 0005
-- column privileges (full_name, phone, avatar_path).
create function public.rpc_admin_update_user(
  p_profile_id    uuid,
  p_full_name     text,
  p_phone         text,
  p_designation   text,
  p_employee_code text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_manage_user(p_profile_id) then
    raise exception 'You cannot manage this user.' using errcode = '42501';
  end if;
  update public.profiles
     set full_name     = btrim(p_full_name),
         phone         = nullif(btrim(p_phone), ''),
         designation   = nullif(btrim(p_designation), ''),
         employee_code = nullif(upper(btrim(p_employee_code)), '')
   where id = p_profile_id;
end;
$$;
comment on function public.rpc_admin_update_user(uuid, text, text, text, text) is
  'Updates another user''s name, phone, designation and employee code; requires can_manage_user().';

-- Activate / deactivate. is_active_user() inside every policy makes a
-- deactivated user's live JWT see nothing immediately.
create function public.rpc_admin_set_user_status(p_profile_id uuid, p_status public.user_status)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_manage_user(p_profile_id) then
    raise exception 'You cannot manage this user.' using errcode = '42501';
  end if;
  if p_status is null or p_status = 'invited' then
    raise exception 'Choose active, suspended or deactivated.' using errcode = '22023';
  end if;
  update public.profiles set status = p_status where id = p_profile_id;
end;
$$;
comment on function public.rpc_admin_set_user_status(uuid, public.user_status) is
  'Sets another user''s status (active / suspended / deactivated); requires can_manage_user().';

-- User detail for the admin screens: profile, assignments in showrooms the
-- caller can access, and what the caller may change. The flags are UI hints;
-- the policies above decide. NULL when the caller cannot view the user.
create function public.rpc_get_user_access(p_profile_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with target as (
    select p.*, public.can_manage_user(p.id) as can_manage
      from public.profiles p
     where p.id = p_profile_id
       and (p.id = (select auth.uid()) or public.can_view_profile(p.id))
  ),
  assignment as (
    select ur.id, ur.showroom_id, ur.expires_on, r.id as role_id, r.code, r.name, r.precedence,
           r.is_active and (ur.expires_on is null or ur.expires_on >= public.fn_business_date()) as is_usable
      from target t
      join public.user_roles ur on ur.profile_id = t.id
      join public.roles r on r.id = ur.role_id
  ),
  membership as (
    select us.showroom_id, us.is_active, s.code, s.name, s.is_active as showroom_is_active,
           public.can_manage_user_in(t.id, us.showroom_id) as can_manage
      from target t
      join public.user_showrooms us on us.profile_id = t.id
      join public.showrooms s on s.id = us.showroom_id
     where public.can_access_showroom(us.showroom_id)
  )
  select jsonb_build_object(
           'profile', jsonb_build_object(
             'id', t.id, 'full_name', t.full_name, 'email', t.email, 'phone', t.phone,
             'designation', t.designation, 'employee_code', t.employee_code,
             'status', t.status, 'is_active', t.is_active, 'created_at', t.created_at),
           'is_self', t.id = (select auth.uid()),
           'can_manage', t.can_manage,
           'global', jsonb_build_object(
             'can_manage', public.can_manage_user_in(t.id, null),
             'roles', coalesce((
               select jsonb_agg(jsonb_build_object(
                        'assignment_id', a.id, 'role_id', a.role_id, 'code', a.code, 'name', a.name,
                        'expires_on', a.expires_on, 'is_usable', a.is_usable)
                      order by a.precedence desc, a.code)
                 from assignment a where a.showroom_id is null), '[]'::jsonb),
             'grantable_roles', coalesce((
               select jsonb_agg(jsonb_build_object('id', r.id, 'code', r.code, 'name', r.name)
                      order by r.precedence desc, r.code)
                 from public.roles r
                where t.can_manage
                  and public.can_assign_role(r.id, null)
                  and not exists (select 1 from assignment a
                                   where a.showroom_id is null and a.role_id = r.id)), '[]'::jsonb)),
           'showrooms', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'id', m.showroom_id, 'code', m.code, 'name', m.name,
                      'is_active', m.is_active and m.showroom_is_active,
                      'can_manage', m.can_manage,
                      'roles', coalesce((
                        select jsonb_agg(jsonb_build_object(
                                 'assignment_id', a.id, 'role_id', a.role_id, 'code', a.code, 'name', a.name,
                                 'expires_on', a.expires_on, 'is_usable', a.is_usable)
                               order by a.precedence desc, a.code)
                          from assignment a where a.showroom_id = m.showroom_id), '[]'::jsonb),
                      'grantable_roles', coalesce((
                        select jsonb_agg(jsonb_build_object('id', r.id, 'code', r.code, 'name', r.name)
                               order by r.precedence desc, r.code)
                          from public.roles r
                         where m.can_manage
                           and public.can_assign_role(r.id, m.showroom_id)
                           and not exists (select 1 from assignment a
                                            where a.showroom_id = m.showroom_id and a.role_id = r.id)),
                        '[]'::jsonb))
                    order by m.code)
               from membership m), '[]'::jsonb),
           'hidden_showroom_count', (
             select count(*)::integer
               from public.user_showrooms us
              where us.profile_id = t.id
                and not public.can_access_showroom(us.showroom_id)),
           'addable_showrooms', coalesce((
             select jsonb_agg(jsonb_build_object('id', s.id, 'code', s.code, 'name', s.name) order by s.code)
               from public.showrooms s
              where t.can_manage
                and s.is_active
                and public.can_access_showroom(s.id)
                and public.can_manage_user_in(t.id, s.id)
                and not exists (select 1 from public.user_showrooms us
                                 where us.profile_id = t.id and us.showroom_id = s.id)), '[]'::jsonb)
         )
    from target t;
$$;
comment on function public.rpc_get_user_access(uuid) is
  'Admin user detail: profile, global and per-showroom roles (accessible showrooms only), and what the caller may change (UI hints; RLS decides). NULL when not viewable.';

-- Roles the caller may grant in a scope (NULL = globally); the create-user
-- form lists them. Same rule as the user_roles insert policy.
create function public.rpc_grantable_roles(p_showroom_id uuid)
returns table (id uuid, code text, name text)
language sql
stable
set search_path = ''
as $$
  select r.id, r.code, r.name
    from public.roles r
   where public.can_assign_role(r.id, p_showroom_id)
   order by r.precedence desc, r.code;
$$;
comment on function public.rpc_grantable_roles(uuid) is
  'Roles the caller may grant in the scope (NULL = globally), highest rank first.';

-- -----------------------------------------------------------------------------
-- 6. Privileges
-- -----------------------------------------------------------------------------
revoke execute on function public.fn_role_rank(uuid, uuid, boolean) from public, anon, authenticated;
revoke execute on function public.fn_sync_auth_user_invited_by() from public, anon, authenticated;
revoke execute on function public.my_role_rank(uuid) from public, anon;
revoke execute on function public.can_manage_user_in(uuid, uuid) from public, anon;
revoke execute on function public.can_manage_user(uuid) from public, anon;
revoke execute on function public.can_assign_role(uuid, uuid) from public, anon;
revoke execute on function public.can_edit_role(uuid) from public, anon;
revoke execute on function public.rpc_admin_update_user(uuid, text, text, text, text) from public, anon;
revoke execute on function public.rpc_admin_set_user_status(uuid, public.user_status) from public, anon;
revoke execute on function public.rpc_get_user_access(uuid) from public, anon;
revoke execute on function public.rpc_grantable_roles(uuid) from public, anon;

grant execute on function public.my_role_rank(uuid) to authenticated, service_role;
grant execute on function public.can_manage_user_in(uuid, uuid) to authenticated, service_role;
grant execute on function public.can_manage_user(uuid) to authenticated, service_role;
grant execute on function public.can_assign_role(uuid, uuid) to authenticated, service_role;
grant execute on function public.can_edit_role(uuid) to authenticated, service_role;
grant execute on function public.rpc_admin_update_user(uuid, text, text, text, text) to authenticated, service_role;
grant execute on function public.rpc_admin_set_user_status(uuid, public.user_status) to authenticated, service_role;
grant execute on function public.rpc_get_user_access(uuid) to authenticated, service_role;
grant execute on function public.rpc_grantable_roles(uuid) to authenticated, service_role;
