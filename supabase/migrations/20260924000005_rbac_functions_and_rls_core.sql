-- =============================================================================
-- MyBike · Phase 4 · 0005 — RBAC helper functions + RLS policies
-- -----------------------------------------------------------------------------
-- Design: docs/phase-00/02-roles-permissions.md §5, 04-multishowroom-security.md §4,
--         docs/phase-04/README.md
--
-- Rules implemented here
--   * RLS is the authority (G1). Every policy is TO authenticated; anon has no
--     privileges at all (0001–0004).
--   * Permissions come from the module × role matrix (role_permissions), never
--     from hard-coded role lists. The only role identity used directly is
--     SUPER_ADMIN (is_super_admin), which by definition sees every showroom.
--   * has_permission_for(module, action, NULL) means "granted by a GLOBAL
--     assignment". Company-wide objects (roles, role matrix, settings, role and
--     showroom assignments, creating showrooms) require it, so a showroom-scoped
--     role can never change company-wide data.
--   * Nobody can change their own role or showroom assignments (anti-escalation).
--   * Deactivated users (profiles.is_active = false) and expired / inactive role
--     assignments grant nothing; a deactivated user can still read their own
--     profile so the app can explain why access is blocked.
--   * FORCE ROW LEVEL SECURITY is not used: on Supabase the table owner
--     (postgres) has BYPASSRLS, so FORCE would change nothing for the
--     SECURITY DEFINER paths; API roles are always subject to RLS.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Helper functions (SECURITY DEFINER: they read RBAC tables regardless of
--    the caller's RLS; they only ever answer questions about the caller)
-- -----------------------------------------------------------------------------

create function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
     where p.id = (select auth.uid())
       and p.is_active
  );
$$;
comment on function public.is_active_user() is
  'True when the caller has a profile with status active. Part of every policy, so a deactivated user''s live JWT sees nothing.';

create function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_active_user()
     and exists (
       select 1
         from public.user_roles ur
         join public.roles r on r.id = ur.role_id
        where ur.profile_id = (select auth.uid())
          and ur.showroom_id is null
          and r.code = 'SUPER_ADMIN'
          and r.is_active
          and (ur.expires_on is null or ur.expires_on >= public.fn_business_date())
     );
$$;
comment on function public.is_super_admin() is
  'True when the caller is an active user holding an active, unexpired global SUPER_ADMIN assignment.';

create function public.can_access_showroom(p_showroom_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_active_user()
     and (
       public.is_super_admin()
       or exists (
         select 1
           from public.user_showrooms us
           join public.showrooms s on s.id = us.showroom_id
          where us.profile_id = (select auth.uid())
            and us.showroom_id = p_showroom_id
            and us.is_active
            and s.is_active
       )
     );
$$;
comment on function public.can_access_showroom(uuid) is
  'RLS backbone: SUPER_ADMIN, or an active assignment to that showroom while the showroom is active.';

create function public.accessible_showroom_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(s.id order by s.code), '{}'::uuid[])
    from public.showrooms s
   where public.can_access_showroom(s.id);
$$;
comment on function public.accessible_showroom_ids() is
  'Showrooms the caller can access (all for SUPER_ADMIN). Used by the showroom picker, storage and dashboard RPCs.';

-- Permission granted by an active, unexpired assignment that applies to the
-- showroom: global assignments always apply; a showroom-scoped assignment
-- applies only to its own showroom. p_showroom_id NULL = global assignments
-- only (company-wide objects). A showroom the caller cannot access grants
-- nothing, whatever the roles say.
create function public.has_permission_for(p_module text, p_action text, p_showroom_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_active_user()
     and (p_showroom_id is null or public.can_access_showroom(p_showroom_id))
     and exists (
       select 1
         from public.user_roles ur
         join public.roles r on r.id = ur.role_id and r.is_active
         join public.role_permissions rp on rp.role_id = r.id
         join public.permissions p on p.id = rp.permission_id
        where ur.profile_id = (select auth.uid())
          and (ur.expires_on is null or ur.expires_on >= public.fn_business_date())
          and (ur.showroom_id is null or ur.showroom_id = p_showroom_id)
          and p.module = p_module
          and p.action = p_action
     );
$$;
comment on function public.has_permission_for(text, text, uuid) is
  'Showroom-scoped permission check for the caller. NULL showroom = granted by a global assignment only.';

-- Permission granted anywhere the caller can currently work (UI gating,
-- module-level checks). Scoped assignments count only while the caller can
-- still access their showroom.
create function public.has_permission(p_module text, p_action text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_active_user()
     and exists (
       select 1
         from public.user_roles ur
         join public.roles r on r.id = ur.role_id and r.is_active
         join public.role_permissions rp on rp.role_id = r.id
         join public.permissions p on p.id = rp.permission_id
        where ur.profile_id = (select auth.uid())
          and (ur.expires_on is null or ur.expires_on >= public.fn_business_date())
          and (ur.showroom_id is null or public.can_access_showroom(ur.showroom_id))
          and p.module = p_module
          and p.action = p_action
     );
$$;
comment on function public.has_permission(text, text) is
  'True when any usable assignment of the caller (global, or scoped to an accessible showroom) grants module.action.';

-- Whether the caller may see another user's profile and assignments:
-- users.view granted globally, or in a showroom the other user is assigned to.
create function public.can_view_profile(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.has_permission_for('users', 'view', null)
      or exists (
        select 1
          from public.user_showrooms us
         where us.profile_id = p_profile_id
           and us.is_active
           and public.has_permission_for('users', 'view', us.showroom_id)
      );
$$;
comment on function public.can_view_profile(uuid) is
  'users.view globally, or in a showroom the given profile is actively assigned to.';

-- -----------------------------------------------------------------------------
-- 2. Policies — reference data (Class B): readable by active users
-- -----------------------------------------------------------------------------
create policy states_select on public.states
  for select to authenticated
  using ((select public.is_active_user()));

create policy permissions_select on public.permissions
  for select to authenticated
  using ((select public.is_active_user()));

create policy financial_years_select on public.financial_years
  for select to authenticated
  using ((select public.is_active_user()));

create policy accounting_periods_select on public.accounting_periods
  for select to authenticated
  using ((select public.is_active_user()));
-- Financial years / periods are written only by server functions (Phase 12).

-- -----------------------------------------------------------------------------
-- 3. Policies — showrooms and their settings
-- -----------------------------------------------------------------------------
create policy showrooms_select on public.showrooms
  for select to authenticated
  using (public.can_access_showroom(id));

create policy showrooms_insert on public.showrooms
  for insert to authenticated
  with check ((select public.has_permission_for('showrooms', 'create', null)));

create policy showrooms_update on public.showrooms
  for update to authenticated
  using (public.has_permission_for('showrooms', 'edit', id))
  with check (public.has_permission_for('showrooms', 'edit', id));

-- Showrooms are deactivated, not deleted; FKs (restrict) also block deleting
-- a showroom that has data.
create policy showrooms_delete on public.showrooms
  for delete to authenticated
  using ((select public.has_permission_for('showrooms', 'delete', null)));

create policy showroom_settings_select on public.showroom_settings
  for select to authenticated
  using (public.can_access_showroom(showroom_id));

create policy showroom_settings_update on public.showroom_settings
  for update to authenticated
  using (public.has_permission_for('showrooms', 'edit', showroom_id))
  with check (public.has_permission_for('showrooms', 'edit', showroom_id));
-- Rows are created by the showroom bootstrap trigger and removed by cascade.

-- Numbering series are visible to users who can view the showroom's setup;
-- they are written only by SECURITY DEFINER functions (privileges revoked).
create policy document_sequences_select on public.document_sequences
  for select to authenticated
  using (public.has_permission_for('showrooms', 'view', showroom_id));

-- -----------------------------------------------------------------------------
-- 4. Policies — company settings
-- -----------------------------------------------------------------------------
create policy settings_select on public.settings
  for select to authenticated
  using (
    (select public.is_active_user())
    and (is_client_readable or (select public.has_permission_for('settings', 'view', null)))
  );

create policy settings_insert on public.settings
  for insert to authenticated
  with check ((select public.has_permission_for('settings', 'create', null)));

create policy settings_update on public.settings
  for update to authenticated
  using ((select public.has_permission_for('settings', 'edit', null)))
  with check ((select public.has_permission_for('settings', 'edit', null)));

create policy settings_delete on public.settings
  for delete to authenticated
  using ((select public.has_permission_for('settings', 'delete', null)));

-- -----------------------------------------------------------------------------
-- 5. Policies — identity and access
-- -----------------------------------------------------------------------------

-- Own profile always (even when deactivated), others via users.view.
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or public.can_view_profile(id));

-- Self-service: only full_name, phone and avatar_path (column privileges
-- below). Status, employee code and designation change through the Phase 6
-- user-management RPCs.
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = (select auth.uid()) and (select public.is_active_user()))
  with check (id = (select auth.uid()));
-- Profiles are created by the auth trigger and deleted by cascade from auth.users.

create policy roles_select on public.roles
  for select to authenticated
  using ((select public.is_active_user()));

create policy roles_insert on public.roles
  for insert to authenticated
  with check ((select public.has_permission_for('roles', 'create', null)));

create policy roles_update on public.roles
  for update to authenticated
  using ((select public.has_permission_for('roles', 'edit', null)))
  with check ((select public.has_permission_for('roles', 'edit', null)));

create policy roles_delete on public.roles
  for delete to authenticated
  using ((select public.has_permission_for('roles', 'delete', null)));

-- The matrix is readable by active users (the app derives menus from it);
-- editing it is roles.edit granted globally (Super Admin by default).
create policy role_permissions_select on public.role_permissions
  for select to authenticated
  using ((select public.is_active_user()));

create policy role_permissions_insert on public.role_permissions
  for insert to authenticated
  with check ((select public.has_permission_for('roles', 'edit', null)));

create policy role_permissions_delete on public.role_permissions
  for delete to authenticated
  using ((select public.has_permission_for('roles', 'edit', null)));

-- Role assignments: roles.edit granted globally, never on oneself. Scoped
-- delegation (e.g. a showroom manager assigning executives) arrives with the
-- Phase 6 RPCs, which check the grantable set.
create policy user_roles_select on public.user_roles
  for select to authenticated
  using (
    (profile_id = (select auth.uid()) and (select public.is_active_user()))
    or public.can_view_profile(profile_id)
  );

create policy user_roles_insert on public.user_roles
  for insert to authenticated
  with check (
    (select public.has_permission_for('roles', 'edit', null))
    and profile_id <> (select auth.uid())
  );

create policy user_roles_update on public.user_roles
  for update to authenticated
  using (
    (select public.has_permission_for('roles', 'edit', null))
    and profile_id <> (select auth.uid())
  )
  with check (
    (select public.has_permission_for('roles', 'edit', null))
    and profile_id <> (select auth.uid())
  );

create policy user_roles_delete on public.user_roles
  for delete to authenticated
  using (
    (select public.has_permission_for('roles', 'edit', null))
    and profile_id <> (select auth.uid())
  );

-- Showroom assignments: users.edit granted globally, never on oneself.
create policy user_showrooms_select on public.user_showrooms
  for select to authenticated
  using (
    (profile_id = (select auth.uid()) and (select public.is_active_user()))
    or public.can_view_profile(profile_id)
  );

create policy user_showrooms_insert on public.user_showrooms
  for insert to authenticated
  with check (
    (select public.has_permission_for('users', 'edit', null))
    and profile_id <> (select auth.uid())
  );

create policy user_showrooms_update on public.user_showrooms
  for update to authenticated
  using (
    (select public.has_permission_for('users', 'edit', null))
    and profile_id <> (select auth.uid())
  )
  with check (
    (select public.has_permission_for('users', 'edit', null))
    and profile_id <> (select auth.uid())
  );

create policy user_showrooms_delete on public.user_showrooms
  for delete to authenticated
  using (
    (select public.has_permission_for('users', 'edit', null))
    and profile_id <> (select auth.uid())
  );

-- -----------------------------------------------------------------------------
-- 6. Privileges
-- -----------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke truncate, references, trigger on all tables in schema public from authenticated;
revoke insert, update, delete on public.permissions, public.states, public.document_sequences from authenticated;
-- Server-maintained tables: no direct client writes even if a policy is added by mistake.
revoke insert, update, delete on public.financial_years, public.accounting_periods from authenticated;
revoke insert, delete on public.showroom_settings from authenticated;
-- Profiles: self-service columns only.
revoke insert, update, delete on public.profiles from authenticated;
grant update (full_name, phone, avatar_path) on public.profiles to authenticated;
-- role_permissions rows are granted or revoked, never edited.
revoke update on public.role_permissions from authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.fn_business_date(timestamptz) to authenticated, service_role;
grant execute on function public.fn_fy_start_date(date) to authenticated, service_role;
grant execute on function public.fn_fy_code(date) to authenticated, service_role;
grant execute on function public.fn_fy_short_code(text) to authenticated, service_role;
grant execute on function public.fn_is_gst_document(public.document_sequence_type) to authenticated, service_role;
grant execute on function public.fn_document_type_code(public.document_sequence_type) to authenticated, service_role;
grant execute on function public.current_profile_id() to authenticated, service_role;
-- RBAC helpers are evaluated inside policies on behalf of the caller.
grant execute on function public.is_active_user() to authenticated, service_role;
grant execute on function public.is_super_admin() to authenticated, service_role;
grant execute on function public.can_access_showroom(uuid) to authenticated, service_role;
grant execute on function public.accessible_showroom_ids() to authenticated, service_role;
grant execute on function public.has_permission_for(text, text, uuid) to authenticated, service_role;
grant execute on function public.has_permission(text, text) to authenticated, service_role;
grant execute on function public.can_view_profile(uuid) to authenticated, service_role;
