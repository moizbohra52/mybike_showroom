-- =============================================================================
-- MyBike · Phase 4 · 0006 — storage buckets + storage.objects policies
-- -----------------------------------------------------------------------------
-- Design: docs/phase-00/04-multishowroom-security.md §5, docs/phase-04/README.md
--
-- Path conventions (built by StorageService, never taken raw from the user):
--   showroom-documents  {showroom_id}/{module}/{entity_id}/{uuid}-{file}
--   vehicle-images      {showroom_id}/{vehicle_id}/{uuid}.{ext}      (public read)
--   invoice-pdfs        {showroom_id}/{sales|purchases}/{invoice_id}/{uuid}.pdf
--   customer-kyc        {showroom_id}/customers/{customer_id}/{uuid}-{doc}.{ext}
--   avatars             {profile_id}/{uuid}.{ext}
--   imports-temp        {profile_id}/{uuid}
-- A path whose first segment is not a valid uuid never matches a policy.
-- invoice-pdfs are written only by Edge Functions (service_role bypasses RLS),
-- so there is no client write policy. Downloads use short-lived signed URLs.
-- =============================================================================

-- Returns NULL instead of raising for text that is not a uuid (path segments).
create function public.fn_try_uuid(p_value text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when p_value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then p_value::uuid
  end;
$$;
comment on function public.fn_try_uuid(text) is
  'Text → uuid, or NULL when the text is not a uuid. Lets storage policies read ids from object paths safely.';

-- -----------------------------------------------------------------------------
-- 1. Buckets (idempotent; re-running corrects limits and visibility)
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('showroom-documents', 'showroom-documents', false, 10485760,
   array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']),
  ('vehicle-images', 'vehicle-images', true, 5242880,
   array['image/jpeg', 'image/png', 'image/webp']),
  ('invoice-pdfs', 'invoice-pdfs', false, 10485760,
   array['application/pdf']),
  ('customer-kyc', 'customer-kyc', false, 10485760,
   array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']),
  ('avatars', 'avatars', false, 2097152,
   array['image/jpeg', 'image/png', 'image/webp']),
  ('imports-temp', 'imports-temp', false, 20971520,
   array['text/csv', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- -----------------------------------------------------------------------------
-- 2. showroom-documents — module permission in the path's showroom
-- -----------------------------------------------------------------------------
create policy showroom_documents_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'showroom-documents'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for((storage.foldername(name))[2], 'view',
                                  public.fn_try_uuid((storage.foldername(name))[1]))
  );

create policy showroom_documents_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'showroom-documents'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for((storage.foldername(name))[2], 'create',
                                  public.fn_try_uuid((storage.foldername(name))[1]))
  );

create policy showroom_documents_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'showroom-documents'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for((storage.foldername(name))[2], 'edit',
                                  public.fn_try_uuid((storage.foldername(name))[1]))
  )
  with check (
    bucket_id = 'showroom-documents'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for((storage.foldername(name))[2], 'edit',
                                  public.fn_try_uuid((storage.foldername(name))[1]))
  );

create policy showroom_documents_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'showroom-documents'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for((storage.foldername(name))[2], 'delete',
                                  public.fn_try_uuid((storage.foldername(name))[1]))
  );

-- -----------------------------------------------------------------------------
-- 3. vehicle-images — public catalogue read (public URLs); inventory writes
-- -----------------------------------------------------------------------------
create policy vehicle_images_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'vehicle-images'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.can_access_showroom(public.fn_try_uuid((storage.foldername(name))[1]))
  );

create policy vehicle_images_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'vehicle-images'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for('inventory', 'edit', public.fn_try_uuid((storage.foldername(name))[1]))
  );

create policy vehicle_images_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'vehicle-images'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for('inventory', 'edit', public.fn_try_uuid((storage.foldername(name))[1]))
  )
  with check (
    bucket_id = 'vehicle-images'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for('inventory', 'edit', public.fn_try_uuid((storage.foldername(name))[1]))
  );

create policy vehicle_images_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'vehicle-images'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for('inventory', 'delete', public.fn_try_uuid((storage.foldername(name))[1]))
  );

-- -----------------------------------------------------------------------------
-- 4. invoice-pdfs — read with sales.view / purchases.view in that showroom;
--    written by Edge Functions only
-- -----------------------------------------------------------------------------
create policy invoice_pdfs_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'invoice-pdfs'
    and (storage.foldername(name))[2] in ('sales', 'purchases')
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for((storage.foldername(name))[2], 'view',
                                  public.fn_try_uuid((storage.foldername(name))[1]))
  );

-- -----------------------------------------------------------------------------
-- 5. customer-kyc — customers.* in that showroom
-- -----------------------------------------------------------------------------
create policy customer_kyc_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'customer-kyc'
    and (storage.foldername(name))[2] = 'customers'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for('customers', 'view', public.fn_try_uuid((storage.foldername(name))[1]))
  );

create policy customer_kyc_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'customer-kyc'
    and (storage.foldername(name))[2] = 'customers'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for('customers', 'create', public.fn_try_uuid((storage.foldername(name))[1]))
  );

create policy customer_kyc_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'customer-kyc'
    and (storage.foldername(name))[2] = 'customers'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for('customers', 'edit', public.fn_try_uuid((storage.foldername(name))[1]))
  )
  with check (
    bucket_id = 'customer-kyc'
    and (storage.foldername(name))[2] = 'customers'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for('customers', 'edit', public.fn_try_uuid((storage.foldername(name))[1]))
  );

create policy customer_kyc_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'customer-kyc'
    and (storage.foldername(name))[2] = 'customers'
    and public.fn_try_uuid((storage.foldername(name))[1]) is not null
    and public.has_permission_for('customers', 'delete', public.fn_try_uuid((storage.foldername(name))[1]))
  );

-- -----------------------------------------------------------------------------
-- 6. avatars — owner writes; owner + users who can view the profile read
-- -----------------------------------------------------------------------------
create policy avatars_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (public.fn_try_uuid((storage.foldername(name))[1]) is not null
          and public.can_view_profile(public.fn_try_uuid((storage.foldername(name))[1])))
    )
  );

create policy avatars_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.is_active_user())
  );

create policy avatars_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.is_active_user())
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy avatars_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.is_active_user())
  );

-- -----------------------------------------------------------------------------
-- 7. imports-temp — private scratch space of each user
-- -----------------------------------------------------------------------------
create policy imports_temp_all on storage.objects
  for all to authenticated
  using (
    bucket_id = 'imports-temp'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.is_active_user())
  )
  with check (
    bucket_id = 'imports-temp'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.is_active_user())
  );

-- -----------------------------------------------------------------------------
-- 8. Privileges
-- -----------------------------------------------------------------------------
revoke execute on function public.fn_try_uuid(text) from public, anon;
grant execute on function public.fn_try_uuid(text) to authenticated, service_role;
