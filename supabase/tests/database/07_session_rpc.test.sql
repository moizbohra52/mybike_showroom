-- =============================================================================
-- 07 — Phase 5 rpc_get_my_session() (migration 0007), against the dev seed.
-- Single-showroom, multi-showroom, global, deactivated, role-less, no-profile
-- and anon callers.
-- Plan: 16 assertions
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

set local role authenticated;

-- Showroom manager IND: one showroom, scoped role only.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select is((select jsonb_path_query_array(public.rpc_get_my_session(), '$.showrooms[*].code')),
  '["INDORE-MAIN"]'::jsonb, 'single-showroom user: exactly IND');
select is((public.rpc_get_my_session() -> 'global_permissions'), '[]'::jsonb,
  'single-showroom user: no global permissions');
select ok((public.rpc_get_my_session() -> 'showrooms' -> 0 -> 'permissions') ? 'sales.approve',
  'single-showroom user: IND permissions include sales.approve');
select is((public.rpc_get_my_session() -> 'showrooms' -> 0 -> 'roles'), '["SHOWROOM_MANAGER"]'::jsonb,
  'single-showroom user: role shown per showroom');

-- Accountant: two showrooms.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000009","role":"authenticated"}', true);
select is((select jsonb_path_query_array(public.rpc_get_my_session(), '$.showrooms[*].code')),
  '["BHOPAL", "INDORE-MAIN"]'::jsonb, 'multi-showroom user: BPL and IND');
select is((select (s -> 'is_default')::boolean from jsonb_array_elements(public.rpc_get_my_session() -> 'showrooms') s
            where s ->> 'code' = 'INDORE-MAIN'), true,
  'multi-showroom user: default showroom flagged');

-- Super admin: every showroom and ALL SHOWROOMS.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((public.rpc_get_my_session() ->> 'is_super_admin')::boolean, true, 'super admin: flagged');
select is(jsonb_array_length(public.rpc_get_my_session() -> 'showrooms'), 3, 'super admin: all 3 showrooms');
select ok((public.rpc_get_my_session() -> 'global_permissions') ? 'showrooms.view_all',
  'super admin: global showrooms.view_all');

-- Admin: global role applies in every assigned showroom.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select ok((public.rpc_get_my_session() -> 'showrooms' -> 0 -> 'permissions') ? 'users.edit',
  'admin: global permissions appear in each showroom');

-- Deactivated: profile only.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000013","role":"authenticated"}', true);
select is((public.rpc_get_my_session() -> 'profile' ->> 'is_active')::boolean, false,
  'deactivated user: profile says inactive');
select is((public.rpc_get_my_session() -> 'showrooms'), '[]'::jsonb, 'deactivated user: no showrooms');
select is((public.rpc_get_my_session() -> 'global_permissions'), '[]'::jsonb, 'deactivated user: no permissions');

-- Role-less and profile-less callers.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000014","role":"authenticated"}', true);
select is((public.rpc_get_my_session() -> 'showrooms'), '[]'::jsonb, 'user without roles: no showrooms');

select set_config('request.jwt.claims', '{"sub":"0badbeef-0000-4000-8000-000000000000","role":"authenticated"}', true);
select is(public.rpc_get_my_session(), null::jsonb, 'JWT without profile: NULL');

reset role;
set local role anon;
select throws_ok($$ select public.rpc_get_my_session() $$, '42501', null, 'anon: cannot call');
reset role;

select * from finish();
rollback;
