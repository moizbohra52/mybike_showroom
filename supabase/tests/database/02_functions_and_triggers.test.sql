-- =============================================================================
-- MyBike · Phase 3 · database test 02 — functions and triggers (0001–0003)
-- -----------------------------------------------------------------------------
-- Behaviour of every Phase 3 function and trigger, exercised with throw-away
-- fixtures inside one transaction that is rolled back:
--
--   * Indian FY helpers: fn_fy_code, fn_fy_start_date, fn_fy_short_code,
--     fn_business_date (IST midnight on 31 March / 1 April, century roll-over)
--   * fn_ensure_financial_year: FY 2031-32 with 12 open periods (leap
--     February 2032), idempotency, series for every existing showroom
--   * fn_accounting_period_guard (MB010) and the whole-month CHECK
--   * fn_bootstrap_showroom: showroom_settings defaults and the 20 series of
--     every open FY (prefix = invoice_prefix + type code, GST padding)
--   * fn_next_document_number: format, gap-free increments, MB001–MB004, the
--     16-character GST limit, no truncation for non-GST documents
--   * fn_document_sequences_guard (MB011) and the cross-showroom series key
--   * set_created_by / set_updated_at / fn_set_granted_by
--   * auth.users → profiles triggers (create, e-mail sync, delete cascade)
--   * fn_roles_guard (MB020), fn_role_permissions_guard (MB021),
--     fn_user_roles_guard (MB022), current_profile_id()
--
-- Identity: an end-user JWT is simulated by setting request.jwt.claims only
-- (auth.uid() reads it); the role stays postgres so deny-all RLS (no policies
-- until Phase 4) does not block the fixture writes. Claims are cleared with
-- set_config('request.jwt.claims', '', true).
--
-- Fixtures (never collide with supabase/seed.sql; all rolled back):
--   showrooms  7e570000-0000-4000-8000-000000000001  T-ONE  prefix T1
--              7e570000-0000-4000-8000-000000000002  T-TWO  prefix T2X
--   auth users 7e570000-0000-4000-8000-0000000000a1..a3
--   financial years 2031-32 (fn_ensure_financial_year), 2040-41 (manual,
--   later closed), 2045-46 (manual, no series)
-- Seed fixtures used: superadmin ...001, admin ...002, manager.indore ...003,
-- norole ...014, showroom INDORE-MAIN 5a000000-...-000000000001.
--
-- Wall clock: numbering in the current FY uses fn_business_date(); the FY of
-- today exists after migration 0004. now() is constant in the transaction.
--
-- Plan: 82 assertions
--   FY helpers 10 · ensure FY 10 · period guard 5 · showroom bootstrap 7 ·
--   numbering 14 · sequence guard 5 · audit stamps 7 · auth triggers 7 ·
--   roles guard 8 · role_permissions guard 4 · user_roles guard 2 ·
--   current_profile_id 3
-- =============================================================================
begin;

create extension if not exists pgtap with schema extensions;

select plan(82);

-- -----------------------------------------------------------------------------
-- 1. Indian financial-year helpers (10)
-- -----------------------------------------------------------------------------
select is(
  public.fn_fy_code('2026-03-31'::date),
  '2025-26'::text,
  'fn_fy_code: 31 March 2026 belongs to FY 2025-26'
);

select is(
  public.fn_fy_code('2026-04-01'::date),
  '2026-27'::text,
  'fn_fy_code: 1 April 2026 starts FY 2026-27'
);

-- FY 2099-2100: (2099 + 1) % 100 = 0, zero-padded.
select is(
  public.fn_fy_code('2099-12-31'::date),
  '2099-00'::text,
  'fn_fy_code: century roll-over, 31 Dec 2099 is FY 2099-00'
);

select is(
  public.fn_fy_start_date('2026-03-31'::date),
  '2025-04-01'::date,
  'fn_fy_start_date: 31 March 2026 -> 1 April 2025'
);

select is(
  public.fn_fy_start_date('2026-04-01'::date),
  '2026-04-01'::date,
  'fn_fy_start_date: 1 April 2026 -> 1 April 2026'
);

select is(
  public.fn_fy_short_code('2026-27'),
  '26-27'::text,
  'fn_fy_short_code: 2026-27 -> 26-27'
);

select is(
  public.fn_fy_short_code('2099-00'),
  '99-00'::text,
  'fn_fy_short_code: 2099-00 -> 99-00'
);

-- 19:00 UTC = 00:30 IST on 1 April: the new FY has begun in India.
select is(
  public.fn_business_date('2026-03-31 19:00:00+00'::timestamptz),
  '2026-04-01'::date,
  'fn_business_date: 2026-03-31 19:00 UTC is 1 April in IST'
);

-- 18:00 UTC = 23:30 IST, still 31 March.
select is(
  public.fn_business_date('2026-03-31 18:00:00+00'::timestamptz),
  '2026-03-31'::date,
  'fn_business_date: 2026-03-31 18:00 UTC is still 31 March in IST'
);

select is(
  public.fn_business_date(),
  (now() at time zone 'Asia/Kolkata')::date,
  'fn_business_date: defaults to today in Asia/Kolkata'
);

-- -----------------------------------------------------------------------------
-- 2. fn_ensure_financial_year (10)
-- -----------------------------------------------------------------------------
create temp table t_fy_2031 as
  select public.fn_ensure_financial_year('2031-06-15'::date) as id;

select is(
  (select fy.id from public.financial_years fy where fy.code = '2031-32'),
  (select t.id from t_fy_2031 t),
  'fn_ensure_financial_year: creates FY 2031-32 and returns its id'
);

select results_eq(
  $$ select fy.code, fy.start_date, fy.end_date, fy.is_active, fy.is_closed
       from public.financial_years fy
      where fy.id = (select t.id from t_fy_2031 t) $$,
  $$ values ('2031-32'::text, '2031-04-01'::date, '2032-03-31'::date, true, false) $$,
  'fn_ensure_financial_year: FY 2031-32 runs 2031-04-01 .. 2032-03-31, active and open'
);

select results_eq(
  $$ select count(*)::int, (count(*) filter (where ap.status = 'open'))::int
       from public.accounting_periods ap
      where ap.financial_year_id = (select t.id from t_fy_2031 t) $$,
  $$ values (12, 12) $$,
  'fn_ensure_financial_year: exactly 12 accounting periods, all open'
);

select results_eq(
  $$ select ap.start_date, ap.end_date
       from public.accounting_periods ap
      where ap.financial_year_id = (select t.id from t_fy_2031 t)
        and ap.period_no = 1 $$,
  $$ values ('2031-04-01'::date, '2031-04-30'::date) $$,
  'fn_ensure_financial_year: period 1 is April 2031'
);

select results_eq(
  $$ select ap.start_date, ap.end_date
       from public.accounting_periods ap
      where ap.financial_year_id = (select t.id from t_fy_2031 t)
        and ap.period_no = 11 $$,
  $$ values ('2032-02-01'::date, '2032-02-29'::date) $$,
  'fn_ensure_financial_year: period 11 is February 2032 and ends on the leap day'
);

select results_eq(
  $$ select ap.start_date, ap.end_date
       from public.accounting_periods ap
      where ap.financial_year_id = (select t.id from t_fy_2031 t)
        and ap.period_no = 12 $$,
  $$ values ('2032-03-01'::date, '2032-03-31'::date) $$,
  'fn_ensure_financial_year: period 12 is March 2032'
);

select is(
  public.fn_ensure_financial_year('2031-06-15'::date),
  (select t.id from t_fy_2031 t),
  'fn_ensure_financial_year: a second call returns the same id'
);

select results_eq(
  $$ select (select count(*)::int from public.financial_years fy where fy.start_date = '2031-04-01'),
            (select count(*)::int from public.accounting_periods ap
              where ap.financial_year_id = (select t.id from t_fy_2031 t)) $$,
  $$ values (1, 12) $$,
  'fn_ensure_financial_year: repeat calls create no duplicate year or periods'
);

select set_eq(
  $$ select s.id::text, count(ds.id)::int
       from public.showrooms s
       left join public.document_sequences ds
         on ds.showroom_id = s.id
        and ds.financial_year_id = (select t.id from t_fy_2031 t)
      group by s.id $$,
  $$ select s.id::text, 20 from public.showrooms s $$,
  'fn_ensure_financial_year: every existing showroom gets its 20 numbering series for the new FY'
);

select throws_ok(
  $$ select public.fn_ensure_financial_year(null::date) $$,
  'MB001',
  'A date is required to resolve the financial year.',
  'fn_ensure_financial_year: a NULL date raises MB001'
);

-- -----------------------------------------------------------------------------
-- 3. Accounting-period guard (5) — on a manually created FY without periods
-- -----------------------------------------------------------------------------
insert into public.financial_years (code, start_date, end_date)
values ('2040-41', '2040-04-01', '2041-03-31');

select throws_ok(
  $$ insert into public.accounting_periods (financial_year_id, period_no, start_date, end_date)
     select fy.id, 1, '2040-03-01', '2040-03-31' from public.financial_years fy where fy.code = '2040-41' $$,
  'MB010',
  'Accounting period 2040-03-01 – 2040-03-31 is outside its financial year.',
  'accounting period guard: a period before its FY starts raises MB010'
);

select throws_ok(
  $$ insert into public.accounting_periods (financial_year_id, period_no, start_date, end_date)
     select fy.id, 2, '2040-04-01', '2040-04-30' from public.financial_years fy where fy.code = '2040-41' $$,
  'MB010',
  'Accounting period number 2 does not match its start date 2040-04-01.',
  'accounting period guard: a period_no that is not the month offset from April raises MB010'
);

select throws_ok(
  $$ insert into public.accounting_periods (financial_year_id, period_no, start_date, end_date)
     select fy.id, 1, '2040-04-01', '2040-04-15' from public.financial_years fy where fy.code = '2040-41' $$,
  '23514',
  'new row for relation "accounting_periods" violates check constraint "accounting_periods_whole_month"',
  'accounting periods: a period that is not a whole calendar month violates the CHECK (23514)'
);

select lives_ok(
  $$ insert into public.accounting_periods (financial_year_id, period_no, start_date, end_date)
     select fy.id, 1, '2040-04-01', '2040-04-30' from public.financial_years fy where fy.code = '2040-41' $$,
  'accounting period guard: April as period 1 of FY 2040-41 is accepted'
);

select throws_ok(
  $$ update public.accounting_periods ap
        set start_date = '2041-04-01', end_date = '2041-04-30'
       from public.financial_years fy
      where fy.id = ap.financial_year_id and fy.code = '2040-41' and ap.period_no = 1 $$,
  'MB010',
  'Accounting period 2041-04-01 – 2041-04-30 is outside its financial year.',
  'accounting period guard: moving a period past the end of its FY raises MB010'
);

-- -----------------------------------------------------------------------------
-- 4. Showroom bootstrap (7)
-- -----------------------------------------------------------------------------
-- Open FYs now: the current one, 2031-32 and 2040-41.
insert into public.showrooms (id, code, name, state_code, invoice_prefix)
values ('7e570000-0000-4000-8000-000000000001', 'T-ONE', 'Test Showroom One', '23', 'T1');

select is(
  (select count(*)::int from public.showroom_settings
    where showroom_id = '7e570000-0000-4000-8000-000000000001'),
  1,
  'bootstrap: a new showroom gets exactly one showroom_settings row'
);

select results_eq(
  $$ select gst_enabled, post_cogs_on_sale, valuation_method::text, booking_validity_days, default_gst_rate
       from public.showroom_settings
      where showroom_id = '7e570000-0000-4000-8000-000000000001' $$,
  $$ values (true, true, 'specific_id'::text, 30, null::numeric) $$,
  'bootstrap: settings defaults (GST on, COGS on sale, specific_id, 30-day bookings, no default GST rate)'
);

select set_eq(
  $$ select fy.code, count(ds.id)::int
       from public.financial_years fy
       left join public.document_sequences ds
         on ds.financial_year_id = fy.id
        and ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
      where not fy.is_closed
      group by fy.code $$,
  $$ select fy.code, 20 from public.financial_years fy where not fy.is_closed $$,
  'bootstrap: the new showroom gets 20 numbering series in every open FY'
);

-- Transcribed by hand: invoice_prefix T1 + type code; GST padding
-- least(5, 9 - length(prefix)) = 5 for every 2- or 4-character T1 prefix.
select set_eq(
  $$ select fy.code, ds.doc_type::text, ds.prefix, ds.padding::int
       from public.document_sequences ds
       join public.financial_years fy on fy.id = ds.financial_year_id
      where ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
        and not fy.is_closed $$,
  $$ select fy.code, v.doc_type, v.prefix, v.padding
       from public.financial_years fy
      cross join (values
        ('sales_invoice', 'T1', 5), ('purchase_invoice', 'T1PI', 5),
        ('purchase_order', 'T1PO', 5), ('goods_receipt', 'T1GR', 5),
        ('purchase_return', 'T1PR', 5), ('quotation', 'T1QT', 5),
        ('booking', 'T1BK', 5), ('sales_order', 'T1SO', 5),
        ('delivery_note', 'T1DN', 5), ('sales_return', 'T1SR', 5),
        ('payment', 'T1PY', 5), ('receipt', 'T1RC', 5),
        ('credit_note', 'T1CN', 5), ('debit_note', 'T1DR', 5),
        ('contra', 'T1CT', 5), ('expense', 'T1EX', 5),
        ('income', 'T1IN', 5), ('journal', 'T1JV', 5),
        ('stock_transfer', 'T1ST', 5), ('stock_adjustment', 'T1SA', 5)
      ) as v (doc_type, prefix, padding)
      where not fy.is_closed $$,
  'bootstrap: series prefixes are T1 + type code (T1, T1PO, T1RC, T1CN, T1DR, ...) with padding 5'
);

-- Close 2040-41, then bootstrap a showroom with a 3-character prefix.
update public.financial_years
   set is_closed = true, closed_at = now()
 where code = '2040-41';

insert into public.showrooms (id, code, name, state_code, invoice_prefix)
values ('7e570000-0000-4000-8000-000000000002', 'T-TWO', 'Test Showroom Two', '23', 'T2X');

select set_eq(
  $$ select fy.code, count(ds.id)::int
       from public.financial_years fy
       left join public.document_sequences ds
         on ds.financial_year_id = fy.id
        and ds.showroom_id = '7e570000-0000-4000-8000-000000000002'
      group by fy.code $$,
  $$ select fy.code, case when fy.is_closed then 0 else 20 end from public.financial_years fy $$,
  'bootstrap: 20 series in every open FY and none in the closed FY 2040-41'
);

select set_eq(
  $$ select ds.doc_type::text, ds.prefix, ds.padding::int
       from public.document_sequences ds
       join public.financial_years fy on fy.id = ds.financial_year_id
      where ds.showroom_id = '7e570000-0000-4000-8000-000000000002'
        and fy.code = public.fn_fy_code(public.fn_business_date())
        and ds.doc_type in ('sales_invoice', 'credit_note', 'debit_note', 'receipt', 'stock_transfer') $$,
  $$ values ('sales_invoice', 'T2X', 5), ('credit_note', 'T2XCN', 4), ('debit_note', 'T2XDR', 4),
            ('receipt', 'T2XRC', 4), ('stock_transfer', 'T2XST', 4) $$,
  'bootstrap: GST series of a 3-character prefix are padded to fit 16 characters (T2X 5, T2XRC 4)'
);

select is_empty(
  $$ select ds.showroom_id, ds.doc_type, ds.prefix, ds.padding
       from public.document_sequences ds
      where ds.showroom_id in ('7e570000-0000-4000-8000-000000000001',
                               '7e570000-0000-4000-8000-000000000002')
        and ds.padding <> case
              when ds.doc_type in ('sales_invoice', 'credit_note', 'debit_note', 'receipt', 'stock_transfer')
                then least(5, 9 - char_length(ds.prefix))
              else 5
            end $$,
  'bootstrap: padding is 5 for non-GST types and least(5, 9 - length(prefix)) for GST types'
);

-- -----------------------------------------------------------------------------
-- 5. fn_next_document_number (14)
-- -----------------------------------------------------------------------------
select is(
  public.fn_next_document_number('7e570000-0000-4000-8000-000000000001', 'sales_invoice', public.fn_business_date()),
  'T1/' || public.fn_fy_short_code(public.fn_fy_code(public.fn_business_date())) || '/00001',
  'numbering: the first tax invoice of the FY is T1/<YY-YY>/00001'
);

select is(
  public.fn_next_document_number('7e570000-0000-4000-8000-000000000001', 'sales_invoice', public.fn_business_date()),
  'T1/' || public.fn_fy_short_code(public.fn_fy_code(public.fn_business_date())) || '/00002',
  'numbering: the next tax invoice is T1/<YY-YY>/00002'
);

select is(
  (select ds.next_number
     from public.document_sequences ds
     join public.financial_years fy on fy.id = ds.financial_year_id
    where ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
      and ds.doc_type = 'sales_invoice'
      and fy.code = public.fn_fy_code(public.fn_business_date())),
  3::bigint,
  'numbering: next_number is 3 after issuing two numbers'
);

select throws_ok(
  $$ select public.fn_next_document_number('7e570000-0000-4000-8000-000000000001', 'sales_invoice', '2050-06-01') $$,
  'MB001',
  'No financial year is set up for 2050-06-01.',
  'numbering: a date without a financial year raises MB001'
);

select throws_ok(
  $$ select public.fn_next_document_number('7e570000-0000-4000-8000-000000000001', 'sales_invoice', '2040-06-01') $$,
  'MB002',
  'Financial year 2040-41 is closed.',
  'numbering: a closed financial year raises MB002 even though the series exists'
);

-- An open FY whose series were never created.
insert into public.financial_years (code, start_date, end_date)
values ('2045-46', '2045-04-01', '2046-03-31');

select throws_ok(
  $$ select public.fn_next_document_number('5a000000-0000-4000-8000-000000000001', 'sales_invoice', '2045-06-01') $$,
  'MB003',
  'Document numbering is not configured for sales_invoice in 2045-46.',
  'numbering: a missing series raises MB003'
);

select throws_ok(
  $$ select public.fn_next_document_number(null::uuid, 'sales_invoice', public.fn_business_date()) $$,
  'MB003',
  'Showroom, document type and document date are required for numbering.',
  'numbering: a NULL showroom raises MB003'
);

select throws_ok(
  $$ select public.fn_next_document_number('7e570000-0000-4000-8000-000000000001', 'sales_invoice', null::date) $$,
  'MB003',
  'Showroom, document type and document date are required for numbering.',
  'numbering: a NULL document date raises MB003'
);

-- GST series: prefix + suffix + padding + 7 ('/YY-YY/') <= 16.
select throws_ok(
  $$ update public.document_sequences ds
        set prefix = 'T1XYZ'
       from public.financial_years fy
      where fy.id = ds.financial_year_id and fy.code = '2031-32'
        and ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
        and ds.doc_type = 'sales_invoice' $$,
  '23514',
  'new row for relation "document_sequences" violates check constraint "document_sequences_gst_length"',
  'numbering: a GST series of 17 characters (T1XYZ, padding 5) violates the CHECK (23514)'
);

select lives_ok(
  $$ update public.document_sequences ds
        set prefix = 'T1XY'
       from public.financial_years fy
      where fy.id = ds.financial_year_id and fy.code = '2031-32'
        and ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
        and ds.doc_type = 'sales_invoice' $$,
  'numbering: a GST series of exactly 16 characters (T1XY, padding 5) is accepted'
);

-- Exhaustion of a GST series: 99999 still fits, 100000 would be 17 characters.
update public.document_sequences ds
   set next_number = 99999
  from public.financial_years fy
 where fy.id = ds.financial_year_id
   and fy.code = public.fn_fy_code(public.fn_business_date())
   and ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
   and ds.doc_type = 'receipt';

select is(
  public.fn_next_document_number('7e570000-0000-4000-8000-000000000001', 'receipt', public.fn_business_date()),
  'T1RC/' || public.fn_fy_short_code(public.fn_fy_code(public.fn_business_date())) || '/99999',
  'numbering: receipt 99999 is issued (16 characters)'
);

select throws_ok(
  $$ select public.fn_next_document_number('7e570000-0000-4000-8000-000000000001', 'receipt', public.fn_business_date()) $$,
  'MB004',
  'Numbering series T1RC is exhausted for ' || public.fn_fy_code(public.fn_business_date())
    || ' (GST numbers are limited to 16 characters).',
  'numbering: receipt 100000 would exceed 16 characters and raises MB004'
);

select is(
  (select ds.next_number
     from public.document_sequences ds
     join public.financial_years fy on fy.id = ds.financial_year_id
    where ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
      and ds.doc_type = 'receipt'
      and fy.code = public.fn_fy_code(public.fn_business_date())),
  100000::bigint,
  'numbering: the failed MB004 call consumed no number'
);

update public.document_sequences ds
   set next_number = 1234567
  from public.financial_years fy
 where fy.id = ds.financial_year_id
   and fy.code = public.fn_fy_code(public.fn_business_date())
   and ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
   and ds.doc_type = 'purchase_order';

select is(
  public.fn_next_document_number('7e570000-0000-4000-8000-000000000001', 'purchase_order', public.fn_business_date()),
  'T1PO/' || public.fn_fy_short_code(public.fn_fy_code(public.fn_business_date())) || '/1234567',
  'numbering: non-GST numbers grow beyond the padding without truncation (T1PO/<YY-YY>/1234567)'
);

-- -----------------------------------------------------------------------------
-- 6. document_sequences guard (5)
-- -----------------------------------------------------------------------------
select throws_ok(
  $$ update public.document_sequences ds
        set next_number = 2
       from public.financial_years fy
      where fy.id = ds.financial_year_id
        and fy.code = public.fn_fy_code(public.fn_business_date())
        and ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
        and ds.doc_type = 'sales_invoice' $$,
  'MB011',
  'Document numbering cannot be moved backwards (would re-issue numbers).',
  'sequence guard: decreasing next_number raises MB011'
);

select throws_ok(
  $$ update public.document_sequences ds
        set doc_type = 'quotation'
       from public.financial_years fy
      where fy.id = ds.financial_year_id
        and fy.code = public.fn_fy_code(public.fn_business_date())
        and ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
        and ds.doc_type = 'sales_invoice' $$,
  'MB011',
  'The showroom, document type and financial year of a numbering series cannot change.',
  'sequence guard: changing doc_type raises MB011'
);

select throws_ok(
  $$ update public.document_sequences ds
        set showroom_id = '7e570000-0000-4000-8000-000000000002'
       from public.financial_years fy
      where fy.id = ds.financial_year_id
        and fy.code = public.fn_fy_code(public.fn_business_date())
        and ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
        and ds.doc_type = 'sales_invoice' $$,
  'MB011',
  'The showroom, document type and financial year of a numbering series cannot change.',
  'sequence guard: changing showroom_id raises MB011'
);

select throws_ok(
  $$ update public.document_sequences ds
        set financial_year_id = (select t.id from t_fy_2031 t)
       from public.financial_years fy
      where fy.id = ds.financial_year_id
        and fy.code = public.fn_fy_code(public.fn_business_date())
        and ds.showroom_id = '7e570000-0000-4000-8000-000000000001'
        and ds.doc_type = 'sales_invoice' $$,
  'MB011',
  'The showroom, document type and financial year of a numbering series cannot change.',
  'sequence guard: changing financial_year_id raises MB011'
);

-- T-TWO's purchase-order series takes T-ONE's prefix T1PO (suffix NULL in both).
select throws_ok(
  $$ update public.document_sequences ds
        set prefix = 'T1PO'
       from public.financial_years fy
      where fy.id = ds.financial_year_id
        and fy.code = public.fn_fy_code(public.fn_business_date())
        and ds.showroom_id = '7e570000-0000-4000-8000-000000000002'
        and ds.doc_type = 'purchase_order' $$,
  '23505',
  'duplicate key value violates unique constraint "document_sequences_series_key"',
  'sequence series: the same FY / type / prefix / suffix in two showrooms is rejected (23505)'
);

-- -----------------------------------------------------------------------------
-- 7. Audit stamps: set_created_by, set_updated_at, fn_set_granted_by (7)
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

insert into public.settings (key, value, value_type, created_by, updated_by, created_at)
values ('test.jwt_stamped', '"x"', 'string',
        'a0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002',
        '2000-01-01T00:00:00Z');

select results_eq(
  $$ select created_by, created_at, updated_by from public.settings where key = 'test.jwt_stamped' $$,
  $$ values ('a0000000-0000-4000-8000-000000000001'::uuid, now(), 'a0000000-0000-4000-8000-000000000001'::uuid) $$,
  'set_created_by: with a JWT the insert is stamped with auth.uid() and now(), client values ignored'
);

select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);

update public.settings
   set description = 'changed',
       created_by  = 'a0000000-0000-4000-8000-000000000003',
       created_at  = '1999-01-01T00:00:00Z'
 where key = 'test.jwt_stamped';

select results_eq(
  $$ select created_by, created_at, updated_by from public.settings where key = 'test.jwt_stamped' $$,
  $$ values ('a0000000-0000-4000-8000-000000000001'::uuid, now(), 'a0000000-0000-4000-8000-000000000002'::uuid) $$,
  'set_created_by: an update sets updated_by = auth.uid() and keeps created_by / created_at'
);

select set_config('request.jwt.claims', '', true);

insert into public.settings (key, value, value_type, created_by, created_at, updated_at)
values ('test.server_stamped', '"x"', 'string',
        'a0000000-0000-4000-8000-000000000003', '2000-01-01T00:00:00Z', '2000-01-01T00:00:00Z');

select results_eq(
  $$ select created_by, updated_by, created_at, updated_at from public.settings where key = 'test.server_stamped' $$,
  $$ values ('a0000000-0000-4000-8000-000000000003'::uuid, 'a0000000-0000-4000-8000-000000000003'::uuid,
             '2000-01-01T00:00:00Z'::timestamptz, '2000-01-01T00:00:00Z'::timestamptz) $$,
  'set_created_by: without a JWT explicit created_by / created_at are kept and updated_by defaults to created_by'
);

update public.settings
   set description = 'changed',
       created_by  = 'a0000000-0000-4000-8000-000000000002',
       updated_by  = 'a0000000-0000-4000-8000-000000000002'
 where key = 'test.server_stamped';

select results_eq(
  $$ select created_by, updated_by, created_at, updated_at from public.settings where key = 'test.server_stamped' $$,
  $$ values ('a0000000-0000-4000-8000-000000000003'::uuid, 'a0000000-0000-4000-8000-000000000002'::uuid,
             '2000-01-01T00:00:00Z'::timestamptz, now()) $$,
  'set_updated_at: an update stamps updated_at = now(); created_by stays immutable without a JWT'
);

select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

insert into public.user_showrooms (profile_id, showroom_id, granted_by, granted_at)
values ('a0000000-0000-4000-8000-000000000014', '7e570000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000002', '2000-01-01T00:00:00Z');

select results_eq(
  $$ select granted_by, granted_at from public.user_showrooms
      where profile_id = 'a0000000-0000-4000-8000-000000000014'
        and showroom_id = '7e570000-0000-4000-8000-000000000001' $$,
  $$ values ('a0000000-0000-4000-8000-000000000001'::uuid, now()) $$,
  'fn_set_granted_by: with a JWT granted_by = auth.uid() and granted_at = now()'
);

select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);

update public.user_showrooms
   set granted_by = 'a0000000-0000-4000-8000-000000000003',
       granted_at = '1999-01-01T00:00:00Z',
       is_active  = false
 where profile_id = 'a0000000-0000-4000-8000-000000000014'
   and showroom_id = '7e570000-0000-4000-8000-000000000001';

select results_eq(
  $$ select granted_by, granted_at, is_active from public.user_showrooms
      where profile_id = 'a0000000-0000-4000-8000-000000000014'
        and showroom_id = '7e570000-0000-4000-8000-000000000001' $$,
  $$ values ('a0000000-0000-4000-8000-000000000001'::uuid, now(), false) $$,
  'fn_set_granted_by: granted_by / granted_at are immutable on update'
);

select set_config('request.jwt.claims', '', true);

insert into public.user_showrooms (profile_id, showroom_id, granted_by, granted_at)
values ('a0000000-0000-4000-8000-000000000014', '7e570000-0000-4000-8000-000000000002',
        'a0000000-0000-4000-8000-000000000002', '2000-01-01T00:00:00Z');

select results_eq(
  $$ select granted_by, granted_at from public.user_showrooms
      where profile_id = 'a0000000-0000-4000-8000-000000000014'
        and showroom_id = '7e570000-0000-4000-8000-000000000002' $$,
  $$ values ('a0000000-0000-4000-8000-000000000002'::uuid, now()) $$,
  'fn_set_granted_by: without a JWT an explicit granted_by is kept, granted_at is always now()'
);

-- -----------------------------------------------------------------------------
-- 8. auth.users -> profiles triggers (7)
-- -----------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data)
values ('7e570000-0000-4000-8000-0000000000a1', 'test.user@example.test',
        '{"full_name":"Test User","role":"SUPER_ADMIN"}');

select results_eq(
  $$ select full_name, email::text from public.profiles where id = '7e570000-0000-4000-8000-0000000000a1' $$,
  $$ values ('Test User'::text, 'test.user@example.test'::text) $$,
  'auth trigger: a new auth user gets a profile with full_name from metadata and the same e-mail'
);

select results_eq(
  $$ select status::text, is_active from public.profiles where id = '7e570000-0000-4000-8000-0000000000a1' $$,
  $$ values ('active'::text, true) $$,
  'auth trigger: the new profile is active'
);

select is(
  (select count(*)::int from public.user_roles where profile_id = '7e570000-0000-4000-8000-0000000000a1'),
  0,
  'auth trigger: a role in user metadata grants no user_roles row (fail closed)'
);

insert into auth.users (id, email, raw_user_meta_data)
values ('7e570000-0000-4000-8000-0000000000a2', 'no.name@example.test', '{}');

select is(
  (select full_name from public.profiles where id = '7e570000-0000-4000-8000-0000000000a2'),
  'no.name'::text,
  'auth trigger: without full_name the profile is named after the e-mail local part'
);

insert into auth.users (id, email, raw_user_meta_data)
values ('7e570000-0000-4000-8000-0000000000a3', 'blank.name@example.test', '{"full_name":"   "}');

select is(
  (select full_name from public.profiles where id = '7e570000-0000-4000-8000-0000000000a3'),
  'blank.name'::text,
  'auth trigger: a blank full_name also falls back to the e-mail local part'
);

update auth.users
   set email = 'renamed.user@example.test'
 where id = '7e570000-0000-4000-8000-0000000000a1';

select is(
  (select email::text from public.profiles where id = '7e570000-0000-4000-8000-0000000000a1'),
  'renamed.user@example.test'::text,
  'auth trigger: changing auth.users.email updates profiles.email'
);

delete from auth.users where id = '7e570000-0000-4000-8000-0000000000a1';

select is(
  (select count(*)::int from public.profiles where id = '7e570000-0000-4000-8000-0000000000a1'),
  0,
  'auth trigger: deleting the auth user deletes the profile'
);

-- -----------------------------------------------------------------------------
-- 9. roles guard (8)
-- -----------------------------------------------------------------------------
select throws_ok(
  $$ delete from public.roles where code = 'VIEWER' $$,
  'MB020',
  'System role VIEWER cannot be deleted.',
  'roles guard: deleting the system role VIEWER raises MB020'
);

select throws_ok(
  $$ update public.roles set code = 'VIEWER_X' where code = 'VIEWER' $$,
  'MB020',
  'System role VIEWER cannot be renamed, demoted or deactivated.',
  'roles guard: changing the code of a system role raises MB020'
);

select throws_ok(
  $$ update public.roles set is_active = false where code = 'VIEWER' $$,
  'MB020',
  'System role VIEWER cannot be renamed, demoted or deactivated.',
  'roles guard: deactivating a system role raises MB020'
);

select throws_ok(
  $$ update public.roles set is_system = false where code = 'VIEWER' $$,
  'MB020',
  'System role VIEWER cannot be renamed, demoted or deactivated.',
  'roles guard: demoting a system role (is_system = false) raises MB020'
);

select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

insert into public.roles (code, name, is_system, precedence)
values ('T_ROLE', 'Test Role', true, 5);

select is(
  (select is_system from public.roles where code = 'T_ROLE'),
  false,
  'roles guard: a role inserted with a JWT is never a system role'
);

select throws_ok(
  $$ update public.roles set is_system = true where code = 'T_ROLE' $$,
  'MB020',
  'Only migrations can create system roles.',
  'roles guard: promoting a role to system with a JWT raises MB020'
);

select lives_ok(
  $$ delete from public.roles where code = 'T_ROLE' $$,
  'roles guard: a non-system role can be deleted'
);

select is(
  (select count(*)::int from public.roles where code = 'T_ROLE'),
  0,
  'roles guard: the deleted non-system role is gone'
);

select set_config('request.jwt.claims', '', true);

-- -----------------------------------------------------------------------------
-- 10. role_permissions guard (4)
-- -----------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.role_permissions (role_id, permission_id)
     select r.id, p.id from public.roles r, public.permissions p
      where r.code = 'VIEWER' and p.code = 'sales.create' $$,
  'MB021',
  'The VIEWER role is read-only and cannot be granted create.',
  'role_permissions guard: VIEWER cannot be granted sales.create (MB021)'
);

select throws_ok(
  $$ insert into public.role_permissions (role_id, permission_id)
     select r.id, p.id from public.roles r, public.permissions p
      where r.code = 'ADMIN' and p.code = 'showrooms.view_all' $$,
  'MB021',
  'ALL SHOWROOMS access (showrooms.view_all) is reserved for SUPER_ADMIN.',
  'role_permissions guard: showrooms.view_all is reserved for SUPER_ADMIN (MB021)'
);

select lives_ok(
  $$ insert into public.role_permissions (role_id, permission_id)
     select r.id, p.id from public.roles r, public.permissions p
      where r.code = 'VIEWER' and p.code = 'dashboard.print' $$,
  'role_permissions guard: VIEWER can be granted a read-type action (dashboard.print)'
);

select throws_ok(
  $$ update public.role_permissions rp
        set permission_id = (select p.id from public.permissions p where p.code = 'sales.edit')
      where rp.role_id = (select r.id from public.roles r where r.code = 'VIEWER')
        and rp.permission_id = (select p.id from public.permissions p where p.code = 'dashboard.print') $$,
  'MB021',
  'The VIEWER role is read-only and cannot be granted edit.',
  'role_permissions guard: re-pointing a VIEWER grant to sales.edit raises MB021'
);

-- -----------------------------------------------------------------------------
-- 11. user_roles guard (2)
-- -----------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.user_roles (profile_id, role_id, showroom_id)
     select 'a0000000-0000-4000-8000-000000000014', r.id, '5a000000-0000-4000-8000-000000000001'
       from public.roles r where r.code = 'SUPER_ADMIN' $$,
  'MB022',
  'SUPER_ADMIN must be assigned globally (without a showroom).',
  'user_roles guard: SUPER_ADMIN with a showroom raises MB022'
);

select throws_ok(
  $$ update public.user_roles ur
        set showroom_id = '5a000000-0000-4000-8000-000000000001'
      where ur.profile_id = 'a0000000-0000-4000-8000-000000000001'
        and ur.role_id = (select r.id from public.roles r where r.code = 'SUPER_ADMIN') $$,
  'MB022',
  'SUPER_ADMIN must be assigned globally (without a showroom).',
  'user_roles guard: moving a global SUPER_ADMIN assignment into a showroom raises MB022'
);

-- -----------------------------------------------------------------------------
-- 12. current_profile_id() (3)
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);

select is(
  public.current_profile_id(),
  'a0000000-0000-4000-8000-000000000003'::uuid,
  'current_profile_id: returns the profile id of the JWT subject (manager.indore)'
);

select set_config('request.jwt.claims',
  '{"sub":"7e570000-0000-4000-8000-0000000000ff","role":"authenticated"}', true);

select is(
  public.current_profile_id(),
  null::uuid,
  'current_profile_id: NULL for a JWT subject without a profile'
);

select set_config('request.jwt.claims', '', true);

select is(
  public.current_profile_id(),
  null::uuid,
  'current_profile_id: NULL without a JWT'
);

select * from finish();

rollback;
