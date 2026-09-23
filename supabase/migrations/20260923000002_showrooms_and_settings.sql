-- =============================================================================
-- MyBike · Phase 3 · 0002 — states, showrooms, settings, financial years,
--                            accounting periods, document numbering
-- -----------------------------------------------------------------------------
-- Design: docs/phase-00/05-database-plan.md §4.2, §8 and docs/phase-03/README.md
--
-- RLS is ENABLED on every table with NO policies yet (deny-all for API roles).
-- Phase 4 adds the policies (migration 0005). created_by / closed_by /
-- locked_by foreign keys to profiles are added in 0003 once profiles exists.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. states — GST state / union-territory codes (place of supply, IGST logic)
-- -----------------------------------------------------------------------------
create table public.states (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null,
  name               text not null,
  is_union_territory boolean not null default false,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint states_code_key unique (code),
  constraint states_name_key unique (name),
  constraint states_code_format check (code ~ '^[0-9]{2}$'),
  constraint states_name_not_blank check (char_length(btrim(name)) between 2 and 80)
);
comment on table public.states is
  'Indian states / union territories keyed by GST state code. Reference data maintained by migrations only.';
comment on column public.states.code is 'Two-digit GST state code (first two characters of a GSTIN).';
comment on column public.states.is_active is 'False for legacy codes kept only for historical GSTINs (e.g. 25, 28).';

create trigger trg_set_updated_at
  before update on public.states
  for each row execute function public.set_updated_at();

alter table public.states enable row level security;

-- -----------------------------------------------------------------------------
-- 2. showrooms — the tenants of the dealership
-- -----------------------------------------------------------------------------
create table public.showrooms (
  id             uuid primary key default gen_random_uuid(),
  code           text not null,
  name           text not null,
  legal_name     text,
  gstin          text,
  pan            text,
  address_line1  text,
  address_line2  text,
  city           text,
  state_code     text references public.states (code) on update cascade on delete restrict,
  pincode        text,
  phone          text,
  email          extensions.citext,
  invoice_prefix text not null,
  logo_path      text,
  opened_on      date,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid,
  updated_by     uuid,
  constraint showrooms_code_key unique (code),
  constraint showrooms_invoice_prefix_key unique (invoice_prefix),
  constraint showrooms_code_format check (code ~ '^[A-Z0-9][A-Z0-9-]{1,19}$'),
  constraint showrooms_name_not_blank check (char_length(btrim(name)) between 2 and 120),
  constraint showrooms_gstin_format
    check (gstin is null or gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'),
  constraint showrooms_pan_format check (pan is null or pan ~ '^[A-Z]{5}[0-9]{4}[A-Z]$'),
  -- A GSTIN embeds the state code (chars 1–2) and the PAN (chars 3–12).
  constraint showrooms_gstin_matches_state
    check (gstin is null or state_code is null or left(gstin, 2) = state_code),
  constraint showrooms_gstin_matches_pan
    check (gstin is null or pan is null or substr(gstin, 3, 10) = pan),
  constraint showrooms_pincode_format check (pincode is null or pincode ~ '^[1-9][0-9]{5}$'),
  constraint showrooms_phone_format check (phone is null or phone ~ '^\+?[0-9]{10,15}$'),
  constraint showrooms_email_format
    check (email is null or email::text ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  -- 2–3 characters keep every GST document number within 16 characters
  -- (CGST Rule 46(b)); see document_sequences below.
  constraint showrooms_invoice_prefix_format check (invoice_prefix ~ '^[A-Z0-9]{2,3}$')
);
comment on table public.showrooms is
  'Dealership showrooms (tenants). Every operational row carries showroom_id; RLS isolates showrooms (Phase 4). Showrooms are deactivated, never deleted.';
comment on column public.showrooms.code is 'Stable upper-case business code, e.g. INDORE-MAIN.';
comment on column public.showrooms.gstin is
  'GSTIN of the registration this showroom operates under. NOT unique: showrooms in the same state normally share the company GSTIN.';
comment on column public.showrooms.invoice_prefix is
  'Unique 2–3 character series prefix (e.g. IND). Seeds this showroom''s document series so invoice numbers never collide across showrooms sharing a GSTIN.';
comment on column public.showrooms.logo_path is 'Storage object path (bucket showroom-documents), never a public URL.';

create index idx_showrooms_is_active on public.showrooms (is_active);
create index idx_showrooms_state_code on public.showrooms (state_code);
create index idx_showrooms_gstin on public.showrooms (gstin) where gstin is not null;

create trigger trg_set_created_by
  before insert or update on public.showrooms
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at
  before update on public.showrooms
  for each row execute function public.set_updated_at();

alter table public.showrooms enable row level security;

-- -----------------------------------------------------------------------------
-- 3. showroom_settings — 1:1 operational settings per showroom
-- -----------------------------------------------------------------------------
create table public.showroom_settings (
  showroom_id                   uuid primary key references public.showrooms (id) on delete cascade,
  gst_enabled                   boolean not null default true,
  default_gst_rate              numeric(6,3),
  default_place_of_supply_state text references public.states (code) on update cascade on delete restrict,
  post_cogs_on_sale             boolean not null default true,
  valuation_method              public.stock_valuation_method not null default 'specific_id',
  allow_negative_stock          boolean not null default false,
  low_stock_threshold           integer not null default 5,
  booking_min_amount            numeric(14,2) not null default 0,
  booking_validity_days         integer not null default 30,
  discount_approval_threshold   numeric(14,2),
  round_off_enabled             boolean not null default true,
  invoice_terms                 text,
  invoice_footer                text,
  receipt_terms                 text,
  created_at                    timestamptz not null default now(),
  updated_at                    timestamptz not null default now(),
  created_by                    uuid,
  updated_by                    uuid,
  constraint showroom_settings_gst_rate_range
    check (default_gst_rate is null or default_gst_rate between 0 and 100),
  constraint showroom_settings_low_stock_nonneg check (low_stock_threshold >= 0),
  constraint showroom_settings_booking_min_nonneg check (booking_min_amount >= 0),
  constraint showroom_settings_booking_validity_range check (booking_validity_days between 1 and 365),
  constraint showroom_settings_discount_threshold_nonneg
    check (discount_approval_threshold is null or discount_approval_threshold >= 0)
);
comment on table public.showroom_settings is
  'Per-showroom operational settings (GST, COGS posting, valuation, booking rules, invoice texts). Created automatically with each showroom.';
comment on column public.showroom_settings.default_gst_rate is
  'Optional fallback GST rate. Deliberately has no default: rates come from configuration (tax_rates / HSN, Phase 14), never from code.';
comment on column public.showroom_settings.post_cogs_on_sale is 'Business decision B4: post COGS with every sale (default true).';

create index idx_showroom_settings_place_of_supply on public.showroom_settings (default_place_of_supply_state);

create trigger trg_set_created_by
  before insert or update on public.showroom_settings
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at
  before update on public.showroom_settings
  for each row execute function public.set_updated_at();

alter table public.showroom_settings enable row level security;

-- -----------------------------------------------------------------------------
-- 4. settings — company-wide key/value settings
-- -----------------------------------------------------------------------------
create table public.settings (
  id                 uuid primary key default gen_random_uuid(),
  key                text not null,
  value              jsonb not null,
  value_type         public.setting_value_type not null,
  scope              text not null default 'company',
  is_client_readable boolean not null default false,
  description        text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  created_by         uuid,
  updated_by         uuid,
  constraint settings_key_key unique (key),
  constraint settings_key_format check (key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  constraint settings_scope_company check (scope = 'company'),
  constraint settings_value_matches_type check (
       (value_type = 'string'  and jsonb_typeof(value) = 'string')
    or (value_type = 'number'  and jsonb_typeof(value) = 'number')
    or (value_type = 'boolean' and jsonb_typeof(value) = 'boolean')
    or (value_type = 'json'    and jsonb_typeof(value) in ('object', 'array'))
  )
);
comment on table public.settings is
  'Company-wide settings. Only rows with is_client_readable = true will ever be readable by app users (Phase 4 policy).';
comment on column public.settings.key is 'Dotted lower-case key, e.g. company.name.';

create trigger trg_set_created_by
  before insert or update on public.settings
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at
  before update on public.settings
  for each row execute function public.set_updated_at();

alter table public.settings enable row level security;

-- -----------------------------------------------------------------------------
-- 5. financial_years — Indian FY, 1 April → 31 March
-- -----------------------------------------------------------------------------
create table public.financial_years (
  id         uuid primary key default gen_random_uuid(),
  code       text not null,
  start_date date not null,
  end_date   date not null,
  is_active  boolean not null default true,
  is_closed  boolean not null default false,
  closed_by  uuid,
  closed_at  timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid,
  updated_by uuid,
  constraint financial_years_code_key unique (code),
  constraint financial_years_start_date_key unique (start_date),
  constraint financial_years_april_to_march check (
        extract(month from start_date) = 4
    and extract(day from start_date) = 1
    and end_date = (start_date + interval '1 year' - interval '1 day')::date
  ),
  constraint financial_years_code_matches_dates check (code = public.fn_fy_code(start_date)),
  constraint financial_years_closed_stamp check (not is_closed or closed_at is not null)
);
comment on table public.financial_years is
  'Indian financial years (G10). Created by fn_ensure_financial_year(); numbering and reports are FY-scoped. Unique 1-April start dates make overlaps impossible.';
comment on column public.financial_years.is_active is 'Selectable in the app (reports / pickers).';
comment on column public.financial_years.is_closed is 'Year-end closed: no new documents or postings (Phase 12).';

create trigger trg_set_created_by
  before insert or update on public.financial_years
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at
  before update on public.financial_years
  for each row execute function public.set_updated_at();

alter table public.financial_years enable row level security;

-- -----------------------------------------------------------------------------
-- 6. accounting_periods — 12 monthly periods per financial year
-- -----------------------------------------------------------------------------
create table public.accounting_periods (
  id                uuid primary key default gen_random_uuid(),
  financial_year_id uuid not null references public.financial_years (id) on delete restrict,
  period_no         smallint not null,
  start_date        date not null,
  end_date          date not null,
  status            public.accounting_period_status not null default 'open',
  locked_by         uuid,
  locked_at         timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid,
  updated_by        uuid,
  constraint accounting_periods_fy_period_key unique (financial_year_id, period_no),
  constraint accounting_periods_fy_start_key unique (financial_year_id, start_date),
  constraint accounting_periods_period_no_range check (period_no between 1 and 12),
  -- ::timestamp (without time zone) keeps the expression immutable and
  -- independent of the session TimeZone.
  constraint accounting_periods_whole_month check (
        start_date = date_trunc('month', start_date::timestamp)::date
    and end_date = (date_trunc('month', start_date::timestamp) + interval '1 month' - interval '1 day')::date
  ),
  constraint accounting_periods_lock_stamp check (status = 'open' or locked_at is not null)
);
comment on table public.accounting_periods is
  'Monthly accounting periods (period_no 1 = April). Posting functions reject non-open periods (Phase 12).';

-- Periods must lie inside their financial year and period_no must match the
-- month offset from April (a CHECK cannot look at the parent row).
create function public.fn_accounting_period_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_fy_start date;
  v_fy_end   date;
begin
  select fy.start_date, fy.end_date
    into v_fy_start, v_fy_end
    from public.financial_years fy
   where fy.id = new.financial_year_id;

  if new.start_date < v_fy_start or new.end_date > v_fy_end then
    raise exception 'Accounting period % – % is outside its financial year.', new.start_date, new.end_date
      using errcode = 'MB010', hint = 'period_outside_financial_year';
  end if;

  if new.period_no <> ((extract(year from age(new.start_date, v_fy_start)) * 12
                       + extract(month from age(new.start_date, v_fy_start)))::int + 1) then
    raise exception 'Accounting period number % does not match its start date %.', new.period_no, new.start_date
      using errcode = 'MB010', hint = 'period_number_mismatch';
  end if;

  return new;
end;
$$;
comment on function public.fn_accounting_period_guard() is
  'BEFORE INSERT/UPDATE trigger on accounting_periods: period inside its FY and period_no = month offset from April + 1.';

create trigger trg_accounting_period_guard
  before insert or update of financial_year_id, period_no, start_date, end_date on public.accounting_periods
  for each row execute function public.fn_accounting_period_guard();
create trigger trg_set_created_by
  before insert or update on public.accounting_periods
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at
  before update on public.accounting_periods
  for each row execute function public.set_updated_at();

alter table public.accounting_periods enable row level security;

-- -----------------------------------------------------------------------------
-- 7. document_sequences — gap-free numbering per showroom / FY / document type
-- -----------------------------------------------------------------------------
-- GST documents (tax invoice, credit/debit note, receipt voucher, delivery
-- challan for stock transfer) must carry a serial of at most 16 characters,
-- unique within the financial year for the GSTIN (CGST Rules 46(b), 50, 53,
-- 55). Format: {prefix}/{FY short}/{number}{suffix} → IND/26-27/00001.
-- (prefix, suffix) is unique per FY and type across ALL showrooms, so series
-- can never collide even when showrooms share one GSTIN.

-- Two-letter series code per document type ('' for the tax invoice, whose
-- series is the showroom prefix alone).
create function public.fn_document_type_code(p_doc_type public.document_sequence_type)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select case p_doc_type
    when 'sales_invoice'    then ''
    when 'purchase_invoice' then 'PI'
    when 'purchase_order'   then 'PO'
    when 'goods_receipt'    then 'GR'
    when 'purchase_return'  then 'PR'
    when 'quotation'        then 'QT'
    when 'booking'          then 'BK'
    when 'sales_order'      then 'SO'
    when 'delivery_note'    then 'DN'
    when 'sales_return'     then 'SR'
    when 'payment'          then 'PY'
    when 'receipt'          then 'RC'
    when 'credit_note'      then 'CN'
    when 'debit_note'       then 'DR'
    when 'contra'           then 'CT'
    when 'expense'          then 'EX'
    when 'income'           then 'IN'
    when 'journal'          then 'JV'
    when 'stock_transfer'   then 'ST'
    when 'stock_adjustment' then 'SA'
  end;
$$;
comment on function public.fn_document_type_code(public.document_sequence_type) is
  'Series code appended to the showroom prefix for each document type (empty for sales_invoice).';

-- Whether the document type is a GST document limited to 16 characters.
create function public.fn_is_gst_document(p_doc_type public.document_sequence_type)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select p_doc_type in ('sales_invoice', 'credit_note', 'debit_note', 'receipt', 'stock_transfer');
$$;
comment on function public.fn_is_gst_document(public.document_sequence_type) is
  'True for GST documents whose serial must not exceed 16 characters (CGST Rules 46/50/53/55).';

create table public.document_sequences (
  id                uuid primary key default gen_random_uuid(),
  showroom_id       uuid not null references public.showrooms (id) on delete restrict,
  financial_year_id uuid not null references public.financial_years (id) on delete restrict,
  doc_type          public.document_sequence_type not null,
  prefix            text not null,
  suffix            text,
  next_number       bigint not null default 1,
  padding           smallint not null default 5,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid,
  updated_by        uuid,
  constraint document_sequences_scope_key unique (showroom_id, doc_type, financial_year_id),
  constraint document_sequences_series_key
    unique nulls not distinct (financial_year_id, doc_type, prefix, suffix),
  constraint document_sequences_prefix_format check (prefix ~ '^[A-Z0-9][A-Z0-9-]{0,9}$'),
  constraint document_sequences_suffix_format check (suffix is null or suffix ~ '^[A-Z0-9-]{1,6}$'),
  constraint document_sequences_next_number_positive check (next_number >= 1),
  constraint document_sequences_padding_range check (padding between 3 and 8),
  -- prefix + '/' + 'YY-YY' + '/' + digits + suffix ≤ 16 for GST documents.
  constraint document_sequences_gst_length check (
    not public.fn_is_gst_document(doc_type)
    or char_length(prefix) + coalesce(char_length(suffix), 0) + padding + 7 <= 16
  )
);
comment on table public.document_sequences is
  'Numbering series per showroom / document type / financial year. Written only by fn_ensure_document_sequences() and fn_next_document_number(); clients cannot write (G1, security rule 7).';
comment on column public.document_sequences.next_number is 'Next number to issue; never decreases.';
comment on column public.document_sequences.padding is 'Minimum digits; GST documents raise MB004 instead of exceeding 16 characters.';

create index idx_document_sequences_fy on public.document_sequences (financial_year_id);

-- Guards: the scope of a series is immutable and next_number never goes back
-- (a lower number would re-issue an existing document number).
create function public.fn_document_sequences_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.showroom_id <> old.showroom_id
     or new.doc_type <> old.doc_type
     or new.financial_year_id <> old.financial_year_id then
    raise exception 'The showroom, document type and financial year of a numbering series cannot change.'
      using errcode = 'MB011', hint = 'sequence_scope_immutable';
  end if;
  if new.next_number < old.next_number then
    raise exception 'Document numbering cannot be moved backwards (would re-issue numbers).'
      using errcode = 'MB011', hint = 'sequence_cannot_decrease';
  end if;
  return new;
end;
$$;
comment on function public.fn_document_sequences_guard() is
  'BEFORE UPDATE trigger on document_sequences: immutable scope, monotonic next_number.';

create trigger trg_document_sequences_guard
  before update on public.document_sequences
  for each row execute function public.fn_document_sequences_guard();
create trigger trg_set_created_by
  before insert or update on public.document_sequences
  for each row execute function public.set_created_by();
create trigger trg_set_updated_at
  before update on public.document_sequences
  for each row execute function public.set_updated_at();

alter table public.document_sequences enable row level security;

-- -----------------------------------------------------------------------------
-- 8. Provisioning functions (server-side only; not executable by API roles)
-- -----------------------------------------------------------------------------

-- Creates the default series of every document type for one showroom in one
-- financial year. Idempotent; returns the number of series created.
create function public.fn_ensure_document_sequences(p_showroom_id uuid, p_financial_year_id uuid)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_created integer;
begin
  insert into public.document_sequences (showroom_id, financial_year_id, doc_type, prefix, padding)
  select s.id,
         p_financial_year_id,
         t.doc_type,
         s.invoice_prefix || public.fn_document_type_code(t.doc_type),
         case
           when public.fn_is_gst_document(t.doc_type)
             then least(5, 16 - 7 - char_length(s.invoice_prefix || public.fn_document_type_code(t.doc_type)))
           else 5
         end
    from public.showrooms s
   cross join unnest(enum_range(null::public.document_sequence_type)) as t (doc_type)
   where s.id = p_showroom_id
  on conflict do nothing;

  get diagnostics v_created = row_count;
  return v_created;
end;
$$;
comment on function public.fn_ensure_document_sequences(uuid, uuid) is
  'Idempotently creates the default numbering series (prefix = showroom invoice_prefix + type code) for a showroom and financial year.';

-- Creates the financial year containing p_date, its 12 monthly periods and the
-- numbering series of every existing showroom. Idempotent; returns the FY id.
create function public.fn_ensure_financial_year(p_date date)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_start date := public.fn_fy_start_date(p_date);
  v_fy_id uuid;
begin
  if p_date is null then
    raise exception 'A date is required to resolve the financial year.'
      using errcode = 'MB001', hint = 'financial_year_date_required';
  end if;

  insert into public.financial_years (code, start_date, end_date)
  values (public.fn_fy_code(v_start), v_start, (v_start + interval '1 year' - interval '1 day')::date)
  on conflict (start_date) do nothing;

  select fy.id into v_fy_id from public.financial_years fy where fy.start_date = v_start;

  insert into public.accounting_periods (financial_year_id, period_no, start_date, end_date)
  select v_fy_id,
         m.n + 1,
         (v_start + make_interval(months => m.n))::date,
         (v_start + make_interval(months => m.n + 1) - interval '1 day')::date
    from generate_series(0, 11) as m (n)
  on conflict do nothing;

  perform public.fn_ensure_document_sequences(s.id, v_fy_id)
     from public.showrooms s;

  return v_fy_id;
end;
$$;
comment on function public.fn_ensure_financial_year(date) is
  'Idempotently creates the Indian FY containing the date, its 12 open monthly periods and every showroom''s numbering series.';

-- Issues the next number of a series. The UPDATE takes a row lock that is held
-- until the calling transaction ends, so concurrent documents can never share
-- a number, and a rolled-back document leaves no gap. p_doc_date is required:
-- the FY is decided by the document's own (IST) date, never by the server clock.
create function public.fn_next_document_number(
  p_showroom_id uuid,
  p_doc_type    public.document_sequence_type,
  p_doc_date    date
)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_fy     public.financial_years%rowtype;
  v_seq    public.document_sequences%rowtype;
  v_digits text;
  v_number text;
begin
  if p_showroom_id is null or p_doc_type is null or p_doc_date is null then
    raise exception 'Showroom, document type and document date are required for numbering.'
      using errcode = 'MB003', hint = 'sequence_arguments_required';
  end if;

  select * into v_fy
    from public.financial_years fy
   where p_doc_date between fy.start_date and fy.end_date;
  if not found then
    raise exception 'No financial year is set up for %.', p_doc_date
      using errcode = 'MB001', hint = 'financial_year_not_found';
  end if;
  if v_fy.is_closed then
    raise exception 'Financial year % is closed.', v_fy.code
      using errcode = 'MB002', hint = 'financial_year_closed';
  end if;

  update public.document_sequences ds
     set next_number = ds.next_number + 1
   where ds.showroom_id = p_showroom_id
     and ds.doc_type = p_doc_type
     and ds.financial_year_id = v_fy.id
  returning ds.* into v_seq;
  if not found then
    raise exception 'Document numbering is not configured for % in %.', p_doc_type, v_fy.code
      using errcode = 'MB003', hint = 'sequence_not_configured';
  end if;

  -- v_seq holds the incremented row; the issued number is the previous value.
  v_digits := (v_seq.next_number - 1)::text;
  if char_length(v_digits) < v_seq.padding then
    v_digits := lpad(v_digits, v_seq.padding, '0');
  end if;
  v_number := v_seq.prefix || '/' || public.fn_fy_short_code(v_fy.code) || '/' || v_digits
              || coalesce(v_seq.suffix, '');

  if public.fn_is_gst_document(p_doc_type) and char_length(v_number) > 16 then
    raise exception 'Numbering series % is exhausted for % (GST numbers are limited to 16 characters).',
                    v_seq.prefix, v_fy.code
      using errcode = 'MB004', hint = 'sequence_exhausted';
  end if;

  return v_number;
end;
$$;
comment on function public.fn_next_document_number(uuid, public.document_sequence_type, date) is
  'Atomically issues the next document number ({prefix}/{YY-YY}/{number}{suffix}) for a showroom, type and document date. Internal: called by posting RPCs, never by clients.';

-- Every new showroom gets its settings row and the numbering series of every
-- open financial year. SECURITY DEFINER so the bootstrap cannot be blocked by
-- the caller's RLS scope; it touches only rows keyed by the new showroom.
create function public.fn_bootstrap_showroom()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.showroom_settings (showroom_id)
  values (new.id)
  on conflict (showroom_id) do nothing;

  perform public.fn_ensure_document_sequences(new.id, fy.id)
     from public.financial_years fy
    where not fy.is_closed;

  return new;
end;
$$;
comment on function public.fn_bootstrap_showroom() is
  'AFTER INSERT trigger on showrooms: creates showroom_settings and numbering series for every open FY.';

create trigger trg_showrooms_bootstrap
  after insert on public.showrooms
  for each row execute function public.fn_bootstrap_showroom();

-- -----------------------------------------------------------------------------
-- 9. Privileges
-- -----------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke truncate, references, trigger on all tables in schema public from authenticated;
-- Reference data and numbering are written only by migrations / SECURITY
-- DEFINER functions, never directly by app users.
revoke insert, update, delete on public.states, public.document_sequences from authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.fn_business_date(timestamptz) to authenticated, service_role;
grant execute on function public.fn_fy_start_date(date) to authenticated, service_role;
grant execute on function public.fn_fy_code(date) to authenticated, service_role;
grant execute on function public.fn_fy_short_code(text) to authenticated, service_role;
-- Evaluated inside document_sequences CHECK constraints.
grant execute on function public.fn_is_gst_document(public.document_sequence_type) to authenticated, service_role;
grant execute on function public.fn_document_type_code(public.document_sequence_type) to authenticated, service_role;
