-- =============================================================================
-- MyBike · Phase 5 · 0007 — rpc_get_my_session()
-- -----------------------------------------------------------------------------
-- One round trip after sign-in: profile, accessible showrooms and the
-- effective permissions per showroom, computed server-side with the same rules
-- as the RLS helpers (0005). The client uses it for navigation and UI gating
-- only; RLS stays the authority (G1).
--
-- Returns NULL when the JWT has no profile. A deactivated user gets the
-- profile (so the app can say why) with no showrooms and no permissions.
-- =============================================================================

create function public.rpc_get_my_session()
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
    -- Usable assignments of an active caller with the permissions they carry.
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
               where public.can_access_showroom(s.id)),
             '[]'::jsonb)
         )
    from me;
$$;
comment on function public.rpc_get_my_session() is
  'Session payload for the signed-in user: profile, is_super_admin, global_permissions and accessible showrooms with their effective roles/permissions. NULL when the JWT has no profile.';

revoke execute on function public.rpc_get_my_session() from public, anon;
grant execute on function public.rpc_get_my_session() to authenticated, service_role;
