-- =============================================================================
-- 06 — Phase 4 storage buckets + storage.objects policies (migration 0006)
-- -----------------------------------------------------------------------------
-- Object rows are inserted as postgres (as the Storage API would after an
-- upload) and read / written back as API roles. Covers bucket setup,
-- showroom path isolation (S8), module permissions, own-folder buckets,
-- malformed paths, deactivated users and anon.
-- Plan: 22 assertions
-- =============================================================================
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

-- IND 5a…001, BPL 5a…002 · users 002 admin, 003 manager IND, 006 sales exec IND,
-- 010 cashier IND, 013 inactive
insert into storage.objects (bucket_id, name) values
  ('showroom-documents', '5a000000-0000-4000-8000-000000000001/customers/c1/a.pdf'),
  ('showroom-documents', '5a000000-0000-4000-8000-000000000002/customers/c2/b.pdf'),
  ('showroom-documents', 'not-a-uuid/customers/c9/z.pdf'),
  ('customer-kyc', '5a000000-0000-4000-8000-000000000001/customers/c1/kyc.pdf'),
  ('customer-kyc', '5a000000-0000-4000-8000-000000000002/customers/c2/kyc.pdf'),
  ('invoice-pdfs', '5a000000-0000-4000-8000-000000000001/sales/i1/inv.pdf'),
  ('invoice-pdfs', '5a000000-0000-4000-8000-000000000001/purchases/p1/pinv.pdf'),
  ('avatars', 'a0000000-0000-4000-8000-000000000006/me.png'),
  ('imports-temp', 'a0000000-0000-4000-8000-000000000006/f.csv'),
  ('imports-temp', 'a0000000-0000-4000-8000-000000000010/g.csv'),
  ('vehicle-images', '5a000000-0000-4000-8000-000000000002/v1/img.png');

select set_eq($$ select id from storage.buckets $$,
  $$ values ('showroom-documents'), ('vehicle-images'), ('invoice-pdfs'), ('customer-kyc'),
            ('avatars'), ('imports-temp') $$,
  'buckets: the 6 planned buckets exist');
select set_eq($$ select id from storage.buckets where public $$, $$ values ('vehicle-images') $$,
  'buckets: only the vehicle catalogue is public');

-- Showroom manager IND: customers VCEX, sales VCEAXP, purchases VX, inventory VCEX.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
set local role authenticated;

select set_eq($$ select name from storage.objects where bucket_id = 'showroom-documents' $$,
  $$ values ('5a000000-0000-4000-8000-000000000001/customers/c1/a.pdf') $$,
  'isolation (S8): showroom documents of IND only');
select set_eq($$ select name from storage.objects where bucket_id = 'customer-kyc' $$,
  $$ values ('5a000000-0000-4000-8000-000000000001/customers/c1/kyc.pdf') $$,
  'isolation: customer KYC of IND only');
select set_eq($$ select name from storage.objects where bucket_id = 'invoice-pdfs' $$,
  $$ values ('5a000000-0000-4000-8000-000000000001/sales/i1/inv.pdf'),
            ('5a000000-0000-4000-8000-000000000001/purchases/p1/pinv.pdf') $$,
  'invoice PDFs: sales.view and purchases.view in IND show both');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('showroom-documents', '5a000000-0000-4000-8000-000000000001/customers/c3/new.pdf') $$,
  'upload: customers.create in IND allows an IND customer document');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('showroom-documents', '5a000000-0000-4000-8000-000000000002/customers/c3/x.pdf') $$,
  '42501', null,
  'upload: a document under showroom BPL is refused');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('showroom-documents', 'not-a-uuid/customers/c3/x.pdf') $$,
  '42501', null,
  'upload: a path without a showroom uuid is refused');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('invoice-pdfs', '5a000000-0000-4000-8000-000000000001/sales/i2/x.pdf') $$,
  '42501', null,
  'upload: invoice PDFs are written by Edge Functions only');
select results_eq($$ with d as (delete from storage.objects
                       where bucket_id = 'showroom-documents'
                         and name = '5a000000-0000-4000-8000-000000000001/customers/c1/a.pdf' returning 1)
           select count(*)::int from d $$, $$ values (0) $$,
  'delete: without customers.delete the document stays');
select is_empty($$ select 1 from storage.objects where bucket_id = 'vehicle-images' $$,
  'vehicle images: another showroom''s objects are not listed through the API');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('vehicle-images', '5a000000-0000-4000-8000-000000000002/v2/x.png') $$,
  '42501', null,
  'vehicle images: cannot upload into another showroom');

-- Sales executive IND: sales VCEX, customers VCEX, no purchases.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000006","role":"authenticated"}', true);
select set_eq($$ select name from storage.objects where bucket_id = 'invoice-pdfs' $$,
  $$ values ('5a000000-0000-4000-8000-000000000001/sales/i1/inv.pdf') $$,
  'invoice PDFs: without purchases.view only sales invoices are visible');
select set_eq($$ select name from storage.objects where bucket_id = 'avatars' $$,
  $$ values ('a0000000-0000-4000-8000-000000000006/me.png') $$,
  'avatars: own avatar is visible');
select set_eq($$ select name from storage.objects where bucket_id = 'imports-temp' $$,
  $$ values ('a0000000-0000-4000-8000-000000000006/f.csv') $$,
  'imports-temp: only own scratch files are visible');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('imports-temp', 'a0000000-0000-4000-8000-000000000006/h.csv') $$,
  'imports-temp: upload into own folder');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('imports-temp', 'a0000000-0000-4000-8000-000000000010/h.csv') $$,
  '42501', null,
  'imports-temp: upload into another user''s folder is refused');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars', 'a0000000-0000-4000-8000-000000000003/x.png') $$,
  '42501', null,
  'avatars: cannot upload another user''s avatar');

-- Admin: global roles, assigned to every showroom.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select set_eq($$ select name from storage.objects where bucket_id = 'showroom-documents' $$,
  $$ values ('5a000000-0000-4000-8000-000000000001/customers/c1/a.pdf'),
            ('5a000000-0000-4000-8000-000000000002/customers/c2/b.pdf'),
            ('5a000000-0000-4000-8000-000000000001/customers/c3/new.pdf') $$,
  'admin: documents of all assigned showrooms, never a malformed path');
select set_eq($$ select name from storage.objects where bucket_id = 'avatars' $$,
  $$ values ('a0000000-0000-4000-8000-000000000006/me.png') $$,
  'avatars: users.view shows other users'' avatars');

select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000013","role":"authenticated"}', true);
select is_empty($$ select 1 from storage.objects $$, 'deactivated user: sees no object at all');

reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select is_empty($$ select 1 from storage.objects $$, 'anon: sees no object at all');
reset role;

select * from finish();
rollback;
