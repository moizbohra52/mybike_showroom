# PHASE 0 — 05 Database Plan (PostgreSQL / Supabase)

> This is the **design**; only the Phase 3 subset (extensions, showrooms, profiles, roles,
> permissions, user mappings, settings) is implemented in Phase 3. Later phases add their own
> migrations. Nothing here is created before its phase.

## 1. Conventions

| Item | Convention |
|------|-----------|
| Primary key | `id uuid primary key default gen_random_uuid()` (uuid v7-style ordering not required; `created_at` indexes handle ordering) |
| Timestamps | `created_at timestamptz not null default now()`, `updated_at timestamptz not null default now()` maintained by trigger `set_updated_at()` |
| Audit columns | `created_by uuid references profiles(id)`, `updated_by uuid`, plus domain-specific `posted_by`, `approved_by`, `received_by`, `cancelled_by` |
| Tenancy | `showroom_id uuid not null references showrooms(id)` on every operational table (indexed) |
| Soft delete | Operational masters use `is_active boolean` / `status`; **financial and ledger tables are never soft-deleted, they are reversed** |
| Money | `numeric(14,2)` (line amounts), `numeric(16,2)` (document totals) — never `float`/`double` |
| Quantities | `numeric(14,3)` (spares), `integer` (vehicles = 1) |
| Rates/percent | `numeric(6,3)` (e.g. GST 18.000, discount 2.500) |
| Enums | PostgreSQL `enum` types for closed sets (statuses, modes); lookup tables for open/editable sets (categories, HSN) |
| Naming | `snake_case`, plural table names, singular enum types, `idx_*` indexes, `trg_*` triggers, `fn_*` functions, `v_*` views, `mv_*` materialised views, `rpc_*` client-callable functions |
| Money precision in Dart | read as `String`/`num` and converted to a decimal-safe representation (`DecimalSafe` in `core/utils`) before arithmetic |
| FKs | `on delete restrict` by default (financial/document rows), `on delete cascade` only for pure child rows (e.g. `sales_invoice_items`), `on delete set null` for optional references (e.g. `approved_by`) |
| Constraints | `CHECK` for numeric ranges (`qty >= 0`, `amount >= 0`, `debit >= 0 and credit >= 0`), `UNIQUE` for natural keys, `EXCLUDE` where overlap matters (periods) |
| Indexes | every FK; composite `(showroom_id, status, created_at desc)` on list screens; `pg_trgm` GIN indexes for search columns; partial indexes for `status in ('available','reserved')` |
| Comments | every table gets `comment on table ... is '...'` (self-documenting DB, helps later audits) |

## 2. Extensions & global objects

```sql
create extension if not exists pgcrypto;     -- gen_random_uuid()
create extension if not exists pg_trgm;      -- fuzzy search indexes
create extension if not exists btree_gin;    -- composite GIN support
create extension if not exists citext;       -- case-insensitive email/GSTIN comparisons
create extension if not exists pg_cron;      -- scheduled jobs (Supabase: via dashboard)
create extension if not exists pg_net;       -- DB → Edge Function webhooks (notifications)
```

Phase 3 creates only `pgcrypto`, `citext` and `pg_trgm`, `with schema extensions`. The others are added by the
phase that first uses them.

Shared triggers/functions created in Phase 3:
`set_updated_at()`, `set_created_by()`, `fn_set_granted_by()`; later: `fn_audit_row()` (Phase 20),
`fn_assert_active_period(date)`, `fn_assert_journal_balanced()` (Phase 12).

## 3. Enum catalogue

| Enum | Values |
|------|--------|
| `user_status` | `invited, active, suspended, deactivated` |
| `fuel_type` | `petrol, electric, cng, hybrid` |
| `vehicle_category` | `motorcycle, scooter, moped, e_scooter, e_motorcycle, bicycle` |
| `vehicle_status` | `purchased, in_transit, received, in_stock, reserved, transferred, sold, delivered, damaged, returned_to_supplier` |
| `stock_movement_type` | `purchase_receipt, sale_issue, transfer_out, transfer_in, adjustment_in, adjustment_out, return_in, return_out, damage, opening` |
| `transfer_status` | `draft, dispatched, in_transit, received, cancelled, rejected` |
| `purchase_order_status` | `draft, sent, partially_received, received, cancelled, closed` |
| `purchase_invoice_status` | `draft, posted, partially_paid, paid, cancelled` |
| `quotation_status` | `draft, sent, accepted, rejected, expired, converted` |
| `booking_status` | `pending, confirmed, cancelled, converted_to_sale, expired` |
| `sales_order_status` | `draft, confirmed, invoiced, delivered, cancelled` |
| `sales_invoice_status` | `draft, posted, partially_paid, paid, cancelled` |
| `payment_direction` | `incoming, outgoing` |
| `payment_mode` | `cash, upi, bank_transfer, cheque, card, finance, wallet, adjustment, other` |
| `payment_status` | `draft, posted, bounced, cancelled` |
| `party_type` | `customer, supplier, financier, employee, other` |
| `account_type` | `asset, liability, equity, income, expense` |
| `account_nature` | `debit, credit` |
| `journal_source_type` | `opening, sale, sale_return, purchase, purchase_return, receipt, payment, expense, income, contra, credit_note, debit_note, stock_adjustment, transfer, payroll, manual, reversal` |
| `journal_status` | `draft, posted, reversed` |
| `expense_status` | `draft, pending_approval, approved, rejected, paid, cancelled` |
| `approval_status` | `pending, approved, rejected, cancelled, expired` |
| `document_type` | `customer_kyc, vehicle_document, purchase_invoice, sales_invoice, receipt, insurance, rc, warranty, permit, other` |
| `notification_type` | `new_sale, new_purchase, payment_received, payment_pending, expense, low_stock, stock_received, vehicle_sold, approval_required, stock_transfer, financial_alert, system` |
| `tax_type` | `cgst, sgst, igst, cess, exempt, nil_rated` |
| `accounting_period_status` | `open, locked, closed` |
| `audit_action` | `insert, update, delete, approve, reject, cancel, post, reverse, login, logout, export, print` |

## 4. Table inventory

### 4.1 Identity & access (Phase 3–6)

| Table | Key columns | Constraints / indexes |
|-------|-------------|----------------------|
| `profiles` | `id = auth.users.id` PK, `employee_code`, `full_name`, `email citext`, `phone`, `designation`, `avatar_path`, `status user_status`, `is_active bool` **generated** (`status = 'active'`), `last_login_at` | unique `email`, unique `employee_code` (nullable), index `(is_active)`, trigram `full_name`; no `default_showroom_id` (default = `user_showrooms.is_default`) |
| `roles` | `id`, `code`, `name`, `description`, `is_system bool`, `precedence int`, `is_active` | unique `code`; system roles not deletable |
| `permissions` | `id`, `module`, `action`, `code` (`module.action`), `description` | unique `code`, unique `(module, action)` |
| `role_permissions` | `role_id`, `permission_id` | PK `(role_id, permission_id)`, FKs cascade |
| `user_roles` | `id`, `profile_id`, `role_id`, `showroom_id` (nullable = global), `granted_by`, `granted_at`, `expires_on` | unique nulls not distinct `(profile_id, role_id, showroom_id)`; `SUPER_ADMIN` only global (trigger) |
| `user_showrooms` | `id`, `profile_id`, `showroom_id`, `is_default bool`, `is_active bool`, `granted_by`, `granted_at` | unique `(profile_id, showroom_id)`, at most **one default** per profile (partial unique index), `CHECK (not is_default or is_active)`, index `(showroom_id)` |
| `auth_events` *(deferred from Phase 3 to a later phase)* | `id`, `profile_id`, `event` (`login`, `logout`, `failed_login`, `password_reset`), `platform`, `app_version`, `ip`, `created_at` | index `(profile_id, created_at desc)`; append-only |

### 4.2 Showrooms, financial years, settings (Phase 3, 7, 14)

| Table | Key columns | Constraints / indexes |
|-------|-------------|----------------------|
| `showrooms` | `id`, `code` (upper case), `name`, `legal_name`, `gstin`, `pan`, `address_line1/2`, `city`, `state_code → states(code)`, `pincode`, `phone`, `email citext`, `invoice_prefix` (2–3 chars), `logo_path`, `opened_on`, `is_active` (no `fy_start_month`: FY fixed April–March) | unique `code`, **unique `invoice_prefix`**; `gstin` **not unique** (showrooms in one state share the company GSTIN), GSTIN/PAN/state consistency CHECKs; index `(is_active)`, `(state_code)`, partial `(gstin)` |
| `showroom_settings` | `showroom_id` PK/FK, `gst_enabled`, `default_gst_rate`, `default_place_of_supply_state`, `post_cogs_on_sale`, `valuation_method` (`specific_id`\|`weighted_avg`), `allow_negative_stock`, `low_stock_threshold`, `booking_min_amount`, `booking_validity_days`, `discount_approval_threshold`, `round_off_enabled`, `invoice_terms`, `invoice_footer`, `receipt_terms` | 1:1 with showroom |
| `bank_accounts` | `id`, `showroom_id`, `account_name`, `bank_name`, `account_number`, `ifsc`, `branch`, `upi_id`, `opening_balance numeric(16,2)`, `current_balance numeric(16,2)`, `gl_account_id → accounts`, `is_active` | index `(showroom_id, is_active)`; balance maintained only by posting functions |
| `cash_accounts` | `id`, `showroom_id`, `name` (`Main Counter`, `Service Counter`), `gl_account_id`, `opening_balance`, `current_balance`, `is_active`, `assigned_to` | unique `(showroom_id, name)` |
| `financial_years` | `id`, `code` (`2026-27`), `start_date`, `end_date`, `is_active`, `is_closed`, `closed_by`, `closed_at` | unique `code`, unique `start_date`, `CHECK` 1 April → 31 March and `code = fn_fy_code(start_date)` |
| `accounting_periods` | `id`, `financial_year_id`, `period_no` (1 = April), `start_date`, `end_date`, `status accounting_period_status`, `locked_by`, `locked_at` | unique `(financial_year_id, period_no)`, `(financial_year_id, start_date)`; whole-month CHECK + guard trigger; posting functions reject non-open periods |
| `document_sequences` | `id`, `showroom_id`, `doc_type`, `financial_year_id`, `prefix`, `next_number bigint`, `padding smallint`, `suffix` (no `reset_policy`: rows are per FY) | unique `(showroom_id, doc_type, financial_year_id)`, unique `(financial_year_id, doc_type, prefix, suffix)` across showrooms, GST length ≤ 16 CHECK; written only by `fn_ensure_document_sequences()` / `fn_next_document_number()` |
| `settings` | `id`, `key` unique, `value jsonb`, `value_type`, `scope` (`company`), `is_client_readable bool`, `description`, `updated_by` | client reads only `is_client_readable = true` rows (e.g. theme defaults) |
| `app_error_log` *(deferred from Phase 3 to a later phase)* | `id`, `trace_code`, `profile_id`, `showroom_id`, `module`, `error_code`, `message`, `platform`, `app_version`, `git_sha`, `payload jsonb`, `created_at` | Super Admin read-only; retention job |

### 4.3 Vehicle / item masters (Phase 8)

| Table | Key columns | Constraints / indexes |
|-------|-------------|----------------------|
| `vehicle_brands` | `id`, `code`, `name citext`, `country`, `logo_path`, `sort_order`, `is_active` | unique `name`; trigram index on `name` |
| `vehicle_models` | `id`, `brand_id`, `name citext`, `category vehicle_category`, `is_active` | unique `(brand_id, name)`; index `(brand_id)` |
| `vehicle_variants` | `id`, `model_id`, `name`, `fuel_type fuel_type`, `transmission`, `engine_cc`, `motor_power_kw`, `battery_capacity_kwh`, `range_km`, `charging_time_hours`, `charging_type`, `mileage_kmpl`, `ex_showroom_price`, `is_active` | unique `(model_id, name, fuel_type)`; `CHECK (fuel_type <> 'electric' OR battery_capacity_kwh IS NOT NULL)` |
| `items` | `id`, `sku citext`, `name`, `item_type` (`accessory`,`spare_part`,`service`,`other_charge`), `brand_id`, `category`, `unit`, `hsn_sac_code`, `gst_rate`, `purchase_price`, `selling_price`, `mrp`, `reorder_level`, `attributes jsonb`, `is_active` | unique `sku`; trigram `name`; index `(item_type, is_active)` |
| `hsn_sac_codes` | `id`, `code`, `description`, `kind` (`goods`,`service`), `default_gst_rate`, `is_active` | unique `code` |
| `tax_rates` | `id`, `name`, `rate_percent numeric(6,3)`, `applies_to` (`goods`,`service`,`all`), `effective_from`, `is_active` | unique `(name, effective_from)` |
| `item_batches` *(reserved for future batch/IMEI tracking)* | `id`, `item_id`, `showroom_id`, `batch_no`, `expiry_date`, `qty` | unique `(item_id, showroom_id, batch_no)` — created only if the business requires it |
| `states` *(created in Phase 3: `showrooms.state_code` references it)* | `id`, `code` (GST state code), `name`, `is_union_territory`, `is_active` | unique `code` — used for place-of-supply / IGST decisions |

### 4.4 Inventory & stock (Phase 9)

| Table | Key columns | Constraints / indexes |
|-------|-------------|----------------------|
| `vehicles` | `id`, `showroom_id`, `variant_id`, `fuel_type`, `vin`, `chassis_number`, `engine_number`, `motor_number`, `battery_number`, `battery_capacity_kwh`, `motor_power_kw`, `range_km`, `charging_time_hours`, `color`, `manufacturing_year`, `model_year`, `purchase_price`, `dealer_price`, `selling_price`, `gst_rate`, `status vehicle_status`, `ownership` (`new`,`used`,`demo`), `purchase_invoice_id`, `purchase_item_id`, `warranty_start`, `warranty_end`, `insurance_expiry`, `rc_number`, `odometer_km`, `is_active`, `remarks` | **unique partial** `vin` where `status not in ('sold','delivered','returned_to_supplier')`; same for `chassis_number`; index `(showroom_id, status)`, `(variant_id)`, `(fuel_type, status)`; trigram on `vin`/`chassis_number`; `CHECK (fuel_type <> 'electric' OR battery_number IS NOT NULL)` |
| `vehicle_status_history` | `id`, `vehicle_id`, `showroom_id`, `from_status`, `to_status`, `changed_by`, `changed_at`, `reason`, `reference_type`, `reference_id` | append-only, index `(vehicle_id, changed_at desc)` |
| `vehicle_reservations` | `id`, `vehicle_id`, `showroom_id`, `reserved_for_type` (`booking`,`sales_order`), `reserved_for_id`, `reserved_by`, `reserved_at`, `expires_at`, `released_at`, `release_reason` | unique partial index on `vehicle_id` where `released_at is null` → **one active reservation per vehicle** |
| `item_stock` | `id`, `showroom_id`, `item_id`, `qty_on_hand numeric(14,3)`, `qty_reserved numeric(14,3)`, `unit_cost_avg numeric(14,4)`, `last_movement_at` | unique `(showroom_id, item_id)`, `CHECK (qty_on_hand >= 0)` unless `allow_negative_stock` (enforced in RPC) |
| `stock_ledger` | `id`, `showroom_id`, `movement_type stock_movement_type`, `entry_kind` (`vehicle`,`item`), `vehicle_id`, `item_id`, `qty`, `unit_cost`, `value`, `from_showroom_id`, `to_showroom_id`, `reference_type`, `reference_id`, `reference_no`, `remarks`, `created_by`, `created_at` | `CHECK ((vehicle_id is not null) <> (item_id is not null))`; composite index `(showroom_id, created_at desc)`; `(vehicle_id)`; `(item_id, created_at desc)`; **append-only (no UPDATE/DELETE)** |
| `stock_adjustments` | `id`, `showroom_id`, `adjustment_no`, `adjustment_date`, `reason_code` (`physical_count`,`damage`,`theft`,`expiry`,`correction`,`opening`), `total_value`, `status` (`draft`,`pending_approval`,`approved`,`posted`,`cancelled`), `approved_by`, `journal_entry_id`, `notes` | unique `(showroom_id, adjustment_no)`; index `(showroom_id, status, adjustment_date desc)` |
| `stock_adjustment_items` | `id`, `adjustment_id`, `entry_kind`, `vehicle_id`, `item_id`, `qty`, `unit_cost`, `value`, `direction` (`in`,`out`), `reason` | FK cascade on delete of draft adjustment |
| `stock_transfers` | `id`, `transfer_no`, `source_showroom_id`, `destination_showroom_id`, `transfer_date`, `status transfer_status`, `approved_by`, `dispatched_by`, `dispatched_at`, `received_by`, `received_at`, `remarks`, `journal_entry_id`, `created_by` | unique `transfer_no` per FY; index `(source_showroom_id, status)`, `(destination_showroom_id, status)`; `CHECK (source_showroom_id <> destination_showroom_id)` |
| `stock_transfer_items` | `id`, `transfer_id`, `entry_kind`, `vehicle_id`, `item_id`, `qty`, `unit_cost`, `value` | index `(transfer_id)`, `(vehicle_id)` |
| `stock_valuation` *(view or materialised)* | `showroom_id`, `quantity`, `value` grouped by kind/category | refreshed on demand; powers stock value KPIs |

### 4.5 Parties — customers, suppliers, financiers (Phase 10, 11)

| Table | Key columns | Constraints / indexes |
|-------|-------------|----------------------|
| `customers` | `id`, `showroom_id` (owning), `code`, `name`, `mobile citext`, `alt_mobile`, `email citext`, `dob`, `gender`, `gstin`, `pan`, `aadhaar_last4`, `address_line1/2`, `city`, `state_code`, `pincode`, `customer_type` (`individual`,`business`,`government`), `reference`, `credit_limit`, `credit_days`, `is_active`, `notes` | unique `(showroom_id, code)`; unique partial `(showroom_id, mobile)` where `is_active`; trigram on `name`/`mobile`; index `(showroom_id, is_active)` |
| `customer_addresses` | `id`, `customer_id`, `label`, `is_default`, address fields | index `(customer_id)` |
| `suppliers` | `id`, `name`, `company`, `contact_person`, `mobile citext`, `email`, `gstin`, `pan`, `address fields`, `state_code`, `bank_name`, `bank_account_number`, `ifsc`, `payment_terms_days`, `credit_limit`, `is_active`, `notes` | unique partial `gstin`; unique partial `mobile`; trigram `name`; suppliers are company-wide (multi-showroom) with per-showroom transactions |
| `supplier_showroom_links` | `id`, `supplier_id`, `showroom_id`, `is_preferred` | unique `(supplier_id, showroom_id)` |
| `financiers` | `id`, `name`, `contact_person`, `mobile`, `email`, `is_active` | used for finance-company sales (`finance` payment mode), settlement tracking |
| `party_contacts` | `id`, `party_type`, `party_id`, `name`, `designation`, `phone`, `email` | optional multi-contact support |

> **RLS nuance for company-wide parties:** `suppliers`/`financiers` are shared master data. Their read policy is
> `has_permission('suppliers','view') AND (owner_showroom_id IS NULL OR can_access_showroom(owner_showroom_id))`,
> while **transactions** (purchase invoices, payments, ledgers) stay strictly showroom-scoped. Customers are
> showroom-scoped by default (`showroom_id NOT NULL`), matching dealership reality. If customers must be shared
> across showrooms, the documented extension is `owner_showroom_id IS NULL` + `customer_showroom_links`.

### 4.6 Purchase (Phase 10)

| Table | Key columns | Constraints / indexes |
|-------|-------------|----------------------|
| `purchase_orders` | `id`, `showroom_id`, `po_no`, `po_date`, `supplier_id`, `expected_date`, `status purchase_order_status`, `sub_total`, `discount_total`, `tax_total`, `round_off`, `grand_total`, `terms`, `approved_by`, `approved_at`, `created_by` | unique `(showroom_id, po_no)`; index `(showroom_id, status, po_date desc)`, `(supplier_id)` |
| `purchase_order_items` | `id`, `po_id`, `entry_kind` (`vehicle`,`item`), `variant_id`, `item_id`, `description`, `hsn_sac_code`, `qty`, `qty_received`, `rate`, `discount_percent`, `discount_amount`, `tax_rate`, `tax_amount`, `line_total` | index `(po_id)`, `(variant_id)`, `(item_id)`; `CHECK (qty > 0)` |
| `goods_receipts` (GRN) | `id`, `showroom_id`, `grn_no`, `grn_date`, `supplier_id`, `po_id`, `supplier_invoice_no`, `supplier_invoice_date`, `status` (`draft`,`received`,`invoiced`,`cancelled`), `received_by`, `remarks`, `journal_entry_id` (GRNI accrual) | unique `(showroom_id, grn_no)`; index `(showroom_id, status, grn_date desc)`, `(po_id)` |
| `goods_receipt_items` | `id`, `grn_id`, `po_item_id`, `entry_kind`, `variant_id`, `item_id`, `qty`, `unit_cost`, `value`, `vehicle_id` (created instance) | index `(grn_id)`, `(vehicle_id)` |
| `purchase_invoices` | `id`, `showroom_id`, `invoice_no`, `invoice_date`, `financial_year_id`, `supplier_invoice_no`, `supplier_invoice_date`, `supplier_id`, `po_id`, `grn_id`, `status purchase_invoice_status`, `place_of_supply_state_code`, `is_interstate`, `sub_total`, `discount_total`, `taxable_total`, `cgst_total`, `sgst_total`, `igst_total`, `cess_total`, `freight_total`, `other_charges_total`, `round_off`, `grand_total`, `paid_amount`, `balance_amount`, `journal_entry_id`, `posted_by`, `posted_at`, `created_by` | unique `(showroom_id, financial_year_id, invoice_no)`; unique partial `(supplier_id, supplier_invoice_no)`; index `(showroom_id, status, invoice_date desc)`, `(supplier_id, invoice_date desc)` |
| `purchase_invoice_items` | `id`, `invoice_id`, `entry_kind`, `variant_id`, `item_id`, `vehicle_id`, `description`, `hsn_sac_code`, `qty`, `rate`, `discount_percent`, `discount_amount`, `taxable_amount`, `tax_rate`, `cgst_amount`, `sgst_amount`, `igst_amount`, `cess_amount`, `line_total`, `inventory_account_id` | index `(invoice_id)`, `(vehicle_id)`, `(item_id)`; unique partial `vehicle_id` → a vehicle cannot be purchased twice |
| `purchase_returns` | `id`, `showroom_id`, `return_no`, `return_date`, `supplier_id`, `purchase_invoice_id`, `reason`, `taxable_total`, `tax_total`, `grand_total`, `status` (`draft`,`posted`,`cancelled`), `debit_note_no`, `journal_entry_id` | unique `(showroom_id, return_no)` |
| `purchase_return_items` | `id`, `return_id`, `entry_kind`, `variant_id`, `item_id`, `vehicle_id`, `qty`, `rate`, `tax_rate`, `tax_amount`, `line_total` | index `(return_id)`, `(vehicle_id)` |

### 4.7 Sales, bookings & delivery (Phase 11)

| Table | Key columns | Constraints / indexes |
|-------|-------------|----------------------|
| `quotations` | `id`, `showroom_id`, `quotation_no`, `quotation_date`, `valid_until`, `customer_id`, `sales_executive_id`, `status quotation_status`, `sub_total`, `discount_total`, `tax_total`, `insurance_amount`, `rto_amount`, `accessory_total`, `other_charges`, `round_off`, `grand_total`, `terms`, `converted_sales_order_id` | unique `(showroom_id, quotation_no)`; index `(showroom_id, status, quotation_date desc)`, `(customer_id)` |
| `quotation_items` | `id`, `quotation_id`, `entry_kind`, `variant_id`, `vehicle_id`, `item_id`, `description`, `hsn_sac_code`, `qty`, `rate`, `discount_percent`, `discount_amount`, `taxable_amount`, `tax_rate`, `tax_amount`, `line_total` | index `(quotation_id)` |
| `bookings` | `id`, `showroom_id`, `booking_no`, `booking_date`, `customer_id`, `variant_id`, `vehicle_id` (reserved unit, nullable), `sales_executive_id`, `booking_amount`, `payment_mode`, `expected_delivery_date`, `status booking_status`, `notes`, `cancelled_reason`, `cancelled_at`, `converted_sales_order_id`, `expires_at` | unique `(showroom_id, booking_no)`; index `(showroom_id, status, booking_date desc)`, `(customer_id)`, `(vehicle_id)` |
| `booking_payments` | `id`, `booking_id`, `payment_id`, `amount`, `allocated_at` | link table; refunds stored as negative allocations |
| `sales_orders` | `id`, `showroom_id`, `order_no`, `order_date`, `customer_id`, `booking_id`, `quotation_id`, `sales_executive_id`, `status sales_order_status`, `delivery_date`, `delivered_by`, `delivery_address`, `delivery_notes`, money columns (as quotation), `sales_invoice_id` | unique `(showroom_id, order_no)`; index `(showroom_id, status, order_date desc)` |
| `sales_order_items` | `id`, `sales_order_id`, `entry_kind`, `variant_id`, `vehicle_id`, `item_id`, `description`, `hsn_sac_code`, `qty`, `rate`, `discount_percent`, `discount_amount`, `taxable_amount`, `tax_rate`, `cgst_amount`, `sgst_amount`, `igst_amount`, `cess_amount`, `line_total`, `cost_amount` | index `(sales_order_id)`, `(vehicle_id)` |
| `sales_invoices` | `id`, `showroom_id`, `invoice_no`, `invoice_date`, `financial_year_id`, `customer_id`, `booking_id`, `sales_order_id`, `sales_executive_id`, `place_of_supply_state_code`, `is_interstate`, `invoice_type` (`tax_invoice`,`proforma`,`credit_note`), `status sales_invoice_status`, money columns (`sub_total`, `discount_total`, `taxable_total`, `cgst_total`, `sgst_total`, `igst_total`, `cess_total`, `insurance_total`, `rto_total`, `accessory_total`, `other_charges_total`, `round_off`, `grand_total`, `paid_amount`, `balance_amount`, `cost_total`, `gross_profit`), `exchange_vehicle_id`, `exchange_value`, `finance_company_id`, `finance_amount`, `payment_terms`, `delivery_date`, `journal_entry_id`, `cogs_journal_entry_id`, `posted_by`, `posted_at`, `cancelled_reason` | unique `(showroom_id, financial_year_id, invoice_no)`; index `(showroom_id, status, invoice_date desc)`, `(customer_id, invoice_date desc)`, `(sales_executive_id)` |
| `sales_invoice_items` | `id`, `invoice_id`, `entry_kind` (`vehicle`,`item`,`service`,`charge`), `variant_id`, `vehicle_id`, `item_id`, `description`, `hsn_sac_code`, `qty`, `rate`, `discount_percent`, `discount_amount`, `taxable_amount`, `tax_rate`, `cgst_amount`, `sgst_amount`, `igst_amount`, `cess_amount`, `line_total`, `cost_amount`, `revenue_account_id` | index `(invoice_id)`, `(vehicle_id)`, `(item_id)`; **unique partial `vehicle_id`** → a vehicle cannot be invoiced twice |
| `sales_invoice_charges` | `id`, `invoice_id`, `charge_type` (`insurance`,`rto`,`accessories`,`other`,`extended_warranty`,`handling`), `description`, `taxable_amount`, `tax_rate`, `tax_amount`, `amount`, `income_account_id`, `is_pass_through bool` | index `(invoice_id)` |
| `delivery_notes` | `id`, `showroom_id`, `delivery_no`, `delivery_date`, `sales_invoice_id`, `customer_id`, `vehicle_id`, `delivered_by`, `received_by_name`, `odometer_km`, `checklist jsonb`, `signature_path`, `remarks` | unique `(showroom_id, delivery_no)`; index `(sales_invoice_id)` |
| `sales_returns` | `id`, `showroom_id`, `return_no`, `return_date`, `customer_id`, `sales_invoice_id`, `reason`, money columns, `credit_note_no`, `status`, `journal_entry_id` | unique `(showroom_id, return_no)` |
| `sales_return_items` | `id`, `return_id`, `entry_kind`, `variant_id`, `item_id`, `vehicle_id`, `qty`, `rate`, `tax_rate`, `tax_amount`, `line_total` | index `(return_id)`, `(vehicle_id)` |

### 4.8 Accounting — double-entry core (Phase 12)

| Table | Key columns | Constraints / indexes |
|-------|-------------|----------------------|
| `account_groups` | `id`, `code`, `name`, `parent_id` (self FK), `account_type account_type`, `nature account_nature`, `is_system bool`, `is_active` | unique `code`; supports the Assets/Liabilities/Equity/Income/Expense tree |
| `accounts` | `id`, `code citext`, `name`, `group_id`, `account_type`, `nature`, `showroom_id` (nullable = company-wide), flags `is_control_account`, `is_cash`, `is_bank`, `is_tax`, `is_receivable`, `is_payable`, `is_inventory`, `is_system`, `opening_balance numeric(16,2)`, `opening_nature`, `is_active` | unique `(coalesce(showroom_id, …), code)`; index `(account_type)`, `(showroom_id)` |
| `journal_entries` | `id`, `entry_no`, `entry_date`, `financial_year_id`, `showroom_id`, `source_type journal_source_type`, `source_id`, `source_no`, `narration`, `status journal_status`, `total_debit`, `total_credit`, `reverses_entry_id`, `reversed_by_entry_id`, `posted_by`, `posted_at`, `created_by` | unique `(showroom_id, financial_year_id, entry_no)`; `CHECK (total_debit = total_credit)`; index `(showroom_id, entry_date desc)`, `(source_type, source_id)`, `(financial_year_id, status)` |
| `journal_entry_lines` | `id`, `entry_id`, `line_no`, `account_id`, `debit numeric(16,2)`, `credit numeric(16,2)`, `party_type`, `party_id`, `showroom_id`, `vehicle_id`, `item_id`, `tax_type`, `hsn_sac_code`, `cost_center`, `narration` | `CHECK ((debit > 0 and credit = 0) or (credit > 0 and debit = 0))`; index `(entry_id)`, `(account_id)`, `(party_type, party_id)`, `(showroom_id)`; **append-only** |
| `opening_balances` | `id`, `financial_year_id`, `showroom_id`, `account_id`, `amount`, `nature`, `party_type`, `party_id`, `created_by` | unique `(financial_year_id, showroom_id, account_id, party_type, party_id)`; converted into an `opening` journal entry when the FY opens |
| `accounting_periods` | see §4.2 | posting functions reject non-`open` periods |

> **Ledgers are views, never tables.** `v_customer_ledger`, `v_supplier_ledger`, `v_general_ledger`,
> `v_cash_book`, `v_bank_book`, `v_trial_balance`, `v_receivables`, `v_payables` are derived from
> `journal_entry_lines` joined with `journal_entries`, `accounts` and party tables. One source of truth
> makes "ledger ≠ journal" structurally impossible, opening balances are journal rows, and closing
> balances are always reproducible. `mv_account_balances` is introduced only if Phase 23 profiling
> proves it necessary.

### 4.9 Finance — payments, receipts, cash/bank, notes (Phase 13)

| Table | Key columns | Constraints / indexes |
|-------|-------------|----------------------|
| `payments` | `id`, `showroom_id`, `payment_no`, `payment_date`, `direction payment_direction`, `party_type`, `party_id`, `customer_id`, `supplier_id`, `amount numeric(16,2)`, `unallocated_amount`, `payment_mode`, `cash_account_id`, `bank_account_id`, `instrument_no`, `instrument_date`, `bank_name`, `upi_reference`, `card_last4`, `financier_id`, `status payment_status`, `remarks`, `attachment_path`, `journal_entry_id`, `posted_by`, `posted_at`, `idempotency_key uuid`, `created_by` | unique `(showroom_id, payment_no)`; unique partial `idempotency_key`; index `(showroom_id, payment_date desc)`, `(customer_id, payment_date desc)`, `(supplier_id, payment_date desc)`, `(payment_mode)`; `CHECK (amount <> 0)` |
| `payment_allocations` | `id`, `payment_id`, `allocatable_type` (`sales_invoice`,`purchase_invoice`,`booking`,`expense`,`opening_balance`,`on_account`), `allocatable_id`, `amount`, `discount_allowed`, `allocated_by`, `allocated_at` | index `(payment_id)`, `(allocatable_type, allocatable_id)`; `CHECK (amount <> 0)`; allocation sum validated inside `rpc_post_payment` |
| `contra_entries` | `id`, `showroom_id`, `contra_no`, `contra_date`, `from_account_id`, `to_account_id`, `amount`, `remarks`, `journal_entry_id`, `created_by` | unique `(showroom_id, contra_no)`; `CHECK (from_account_id <> to_account_id)` |
| `credit_notes` | `id`, `showroom_id`, `note_no`, `note_date`, `customer_id`, `sales_invoice_id`, `amount`, `taxable_amount`, `tax_amount`, `reason`, `journal_entry_id`, `status` (`draft`,`posted`,`cancelled`) | unique `(showroom_id, note_no)` |
| `debit_notes` | `id`, `showroom_id`, `note_no`, `note_date`, `supplier_id`, `purchase_invoice_id`, `amount`, `taxable_amount`, `tax_amount`, `reason`, `journal_entry_id`, `status` | unique `(showroom_id, note_no)` |
| `expense_categories` | `id`, `code`, `name`, `default_account_id`, `requires_approval bool`, `is_active` | global master: Rent, Electricity, Salary, Transport, Fuel, Marketing, Repair, Maintenance, Office, Internet, Phone, Miscellaneous |
| `expenses` | `id`, `showroom_id`, `expense_no`, `expense_date`, `category_id`, `payee_type` (`supplier`,`employee`,`other`), `payee_id`, `payee_name`, `description`, `amount`, `taxable_amount`, `tax_rate`, `tax_amount`, `payment_mode`, `cash_account_id`, `bank_account_id`, `status expense_status`, `approved_by`, `approved_at`, `paid_at`, `payment_id`, `attachment_path`, `journal_entry_id`, `created_by` | unique `(showroom_id, expense_no)`; index `(showroom_id, status, expense_date desc)`, `(category_id)`; `CHECK (amount > 0)` |
| `income_categories` | `id`, `code`, `name`, `default_account_id`, `is_active` | global master: Service income, Scrap, Commission, Other |
| `income_entries` | `id`, `showroom_id`, `income_no`, `income_date`, `category_id`, `party_type`, `party_id`, `description`, `amount`, `taxable_amount`, `tax_rate`, `tax_amount`, `payment_mode`, `cash_account_id`, `bank_account_id`, `status` (`draft`,`posted`,`cancelled`), `journal_entry_id`, `created_by` | unique `(showroom_id, income_no)`; index `(showroom_id, income_date desc)` |

### 4.10 Documents, notifications, audit, approvals (Phases 18–21)

| Table | Key columns | Constraints / indexes |
|-------|-------------|----------------------|
| `documents` | `id`, `showroom_id`, `document_type document_type`, `bucket`, `path`, `file_name`, `mime_type`, `size_bytes`, `checksum_sha256`, `entity_type` (`customer`,`vehicle`,`sales_invoice`,`purchase_invoice`,`payment`,`expense`,`showroom`,`profile`,`other`), `entity_id`, `issued_date`, `expiry_date`, `is_verified`, `verified_by`, `uploaded_by`, `created_at` | unique `(bucket, path)`; index `(showroom_id, document_type)`, `(entity_type, entity_id)`, `(expiry_date)`; file bytes never stored in Postgres |
| `document_reminders` | `id`, `document_id`, `remind_on`, `sent_at`, `channel` | powers insurance/RC/warranty expiry alerts |
| `notifications` | `id`, `showroom_id`, `profile_id` (recipient), `role_code` (nullable = role broadcast), `type notification_type`, `title`, `body`, `entity_type`, `entity_id`, `action_route`, `payload jsonb`, `is_read`, `read_at`, `created_by`, `created_at` | index `(profile_id, is_read, created_at desc)`, `(showroom_id, created_at desc)`, `(role_code, created_at desc)`; Realtime-enabled |
| `device_tokens` | `id`, `profile_id`, `platform` (`android`,`ios`,`web`), `token text`, `device_label`, `app_version`, `is_active`, `last_seen_at` | unique `(profile_id, token)`; Windows has no FCM token, so no row is created there |
| `notification_preferences` | `id`, `profile_id`, `type`, `in_app bool`, `push bool` | unique `(profile_id, type)` |
| `audit_logs` | `id`, `showroom_id`, `profile_id`, `action audit_action`, `module`, `table_name`, `record_id`, `record_no`, `old_value jsonb`, `new_value jsonb`, `changed_fields text[]`, `platform`, `app_version`, `created_at` | index `(showroom_id, created_at desc)`, `(table_name, record_id)`, `(profile_id, created_at desc)`, `(module, action)`; **append-only, written by `fn_audit_row()`** |
| `approval_rules` | `id`, `showroom_id` (nullable = company default), `module`, `action` (`create`,`edit`,`delete`,`approve`), `condition jsonb` (e.g. `{"amount_gte": 50000}`), `required_role_code`, `approval_level smallint`, `is_active` | unique `(coalesce(showroom_id,…), module, action, approval_level)` |
| `approval_requests` | `id`, `showroom_id`, `module`, `entity_type`, `entity_id`, `requested_by`, `requested_at`, `amount`, `reason`, `status approval_status`, `current_level`, `decided_at`, `decided_by`, `decision_notes`, `payload jsonb` (pending changes) | index `(showroom_id, status, requested_at desc)`, `(entity_type, entity_id)`; Realtime-enabled for the approval queue |
| `approval_steps` | `id`, `request_id`, `level`, `approver_role_code`, `approver_profile_id`, `status approval_status`, `acted_at`, `remarks` | unique `(request_id, level)` |

## 5. Views, RPCs, triggers

### 5.1 Views (read models)

| View | Purpose |
|------|---------|
| `v_current_stock` | available/reserved/in-transit/sold vehicle counts + values per showroom |
| `v_stock_ageing` | days in stock per vehicle with 0–30 / 31–60 / 61–90 / 90+ buckets |
| `v_stock_valuation` | quantity + value by kind/category/showroom |
| `v_customer_ledger` / `v_supplier_ledger` | party-wise journal lines with running balance (opening + movements) |
| `v_general_ledger` | account-wise lines with running balance |
| `v_cash_book` / `v_bank_book` | cash/bank account movements with running balance incl. contra |
| `v_trial_balance` | opening + period debit/credit + closing per account |
| `v_profit_and_loss` | income/expense totals for a period, including COGS |
| `v_balance_sheet` | asset/liability/equity closing balances + retained earnings as of a date |
| `v_receivables` / `v_payables` | invoice-wise outstanding with ageing buckets |
| `v_sales_summary` | invoice aggregates by showroom/user/brand/model/day/month/FY/payment mode |
| `v_purchase_summary` | invoice aggregates by showroom/supplier/day/month |
| `v_gst_summary` | taxable value + CGST/SGST/IGST split, input vs output, by period and showroom |
| `v_expense_summary` / `v_income_summary` | category-wise totals by period/showroom |
| `v_document_expiry` | documents expiring within N days |

All views use `security_invoker = true` (PostgreSQL 15+/Supabase) so the **caller's RLS applies inside
the view**. A `security_definer` view would bypass RLS and leak other showrooms — forbidden.

### 5.2 RPC functions (client-callable, `security definer`, permission-checked)

| RPC | Responsibility |
|-----|----------------|
| `fn_next_document_number(showroom, doc_type, doc_date)` *(Phase 3; internal, **not** client-callable — called inside the posting RPCs below)* | atomic sequence increment → formatted document number |
| `rpc_receive_purchase_order(po, items jsonb, …)` | GRN + vehicle/item instances + `stock_ledger` + GRNI accrual entry |
| `rpc_post_purchase_invoice(payload jsonb)` | validates items/GST, posts invoice, inventory + input-tax + payable journal, links GRN |
| `rpc_create_sale(payload jsonb)` | validate vehicle availability/price → reserve → invoice → stock issue → COGS → sales+tax journal (one transaction) |
| `rpc_post_payment(payload jsonb)` | payment + allocations (invoice/booking/on-account) + journal + invoice paid/balance update |
| `rpc_create_stock_transfer(payload)` / `rpc_receive_stock_transfer(id, …)` | dispatch/approve/receive with two-sided ledger rows and inventory-account moves |
| `rpc_post_stock_adjustment(adjustment_id)` | posts adjustment with reason code + inventory ↔ adjustment journal |
| `rpc_post_expense(payload)` / `rpc_approve_expense(id)` / `rpc_pay_expense(id, payment)` | expense lifecycle with approval rules + journal |
| `rpc_post_income(payload jsonb)` | other-income posting + journal |
| `rpc_post_contra(payload jsonb)` | cash ⇄ bank transfer |
| `rpc_post_journal(payload jsonb)` | manual journal (Accountant/Super Admin, non-control accounts only) |
| `rpc_reverse_journal_entry(entry_id, reason)` | creates the reversing entry and links both directions |
| `rpc_cancel_document(type, id, reason)` | cancels documents with reversal when money already moved (never a hard delete) |
| `rpc_dashboard_kpis(showroom nullable, from, to)` | consolidated or per-showroom KPI payload in one round trip |
| `rpc_submit_for_approval(payload)` / `rpc_decide_approval(request_id, decision, remarks)` | approval workflow entry points |
| `rpc_close_period(period_id)` / `rpc_reopen_period(period_id, reason)` | period lock/unlock with audit |
| `rpc_mark_notifications_read(ids uuid[])` | bulk read-state update (own rows only) |

Every RPC: `security definer`, `set search_path = ''`, explicit `has_permission_for(...)` check, typed
parameters, `RAISE EXCEPTION` with a stable SQLSTATE + friendly message (mapped by `ErrorMapper`), and a
`jsonb` return shaped for the client.

### 5.3 Triggers

| Trigger | Tables | Behaviour |
|---------|--------|-----------|
| `trg_set_updated_at` | all tables with `updated_at` | `updated_at = now()` |
| `trg_set_created_by` | operational tables | sets `created_by`/`updated_by` from `auth.uid()` (= `profiles.id`), ignores client values, keeps `created_*` immutable |
| `trg_vehicle_status_history` | `vehicles` | inserts a history row on status change |
| `trg_assert_journal_balanced` | `journal_entry_lines` | deferred constraint trigger: header totals must match lines and balance |
| `trg_journal_immutable` | `journal_entries`, `journal_entry_lines` | blocks UPDATE/DELETE when posted; only `draft → posted` allowed |
| `trg_assert_open_period` | `journal_entries` | rejects posting into locked/closed periods |
| `trg_ledger_immutable` | `stock_ledger`, `audit_logs`, `auth_events` | blocks UPDATE/DELETE entirely |
| `trg_audit_row` | audited business tables | writes old/new JSON to `audit_logs` (Phase 20) |
| `trg_stock_ledger_apply` | `stock_ledger` | applies movements to `vehicles.status`, `item_stock.qty_on_hand`, `unit_cost_avg` — the **only** place stock math happens |
| `trg_invoice_totals_guard` | `sales_invoices`, `purchase_invoices` | prevents `paid_amount`/`balance_amount` drifting from allocations |
| `trg_notify_on_event` | sales/purchase/payment/approval tables | enqueues `notifications` rows and calls the FCM edge function via `pg_net` (Phase 18) |
| `trg_prevent_self_privilege` | `user_roles`, `role_permissions` | rejects grants beyond the caller's grantable set (Super Admin exempt) |

## 6. Migration plan (Supabase CLI, timestamp-prefixed, ordered)

Location: `supabase/migrations/`. One migration set per phase; a migration that has reached a shared
environment is never edited — corrections arrive as new migrations. File names are timestamp-prefixed
(`YYYYMMDDHHMMSS_<name>.sql`); the CLI applies them in timestamp order and `supabase db push` refuses a
migration older than the last applied one, so `<ts>` below is assigned when the file is written.

> **As built:** Phase 3 deviations from this plan (renumbering, columns, constraints, deferred seeds) are
> listed in [`docs/phase-03/README.md` §7](../phase-03/README.md#7-deviations-from-the-phase-0-plan).

| # | File | Phase | Contents |
|---|------|-------|----------|
| 0001 | `20260923000001_extensions_and_helpers.sql` | 3 | extensions (schema `extensions`), enum types, `set_updated_at()`, `set_created_by()`, `fn_set_granted_by()`, IST / FY date helpers |
| 0002 | `20260923000002_showrooms_and_settings.sql` | 3 | `states`, `showrooms`, `showroom_settings`, `settings`, `financial_years`, `accounting_periods`, `document_sequences`, numbering + FY functions, showroom bootstrap trigger |
| 0003 | `20260923000003_identity_and_rbac.sql` | 3 | `profiles`, `roles`, `permissions`, `role_permissions`, `user_roles`, `user_showrooms`, auth triggers, `current_profile_id()` |
| 0004 | `20260923000004_seed_reference_data.sql` | 3 | **seed reference data**: states, permissions, 11 system roles, role_permissions matrix, company settings, current FY + periods |
| 0005 | `<ts>_rbac_functions_and_rls_core.sql` | 4 | `is_active_user()`, `is_super_admin()`, `has_permission()`, `has_permission_for()`, `can_access_showroom()`, `accessible_showroom_ids()` + RLS policies for every table created so far (FORCE decided here) |
| 0006 | `<ts>_storage_buckets_and_policies.sql` | 4 | buckets + storage policies |
| — | `<ts>_users_module.sql` | 6 | user/role views + RPCs (`rpc_assign_user_role`, `rpc_set_user_showrooms`) |
| — | `<ts>_vehicle_master.sql` | 8 | brands/models/variants/items/tax tables + RLS + HSN/SAC seeds |
| — | `<ts>_inventory.sql` | 9 | vehicles, status history, reservations, item_stock, stock_ledger, adjustments, transfers + triggers + RLS |
| — | `<ts>_parties.sql` | 10/11 | customers, addresses, suppliers, financiers, links + RLS |
| — | `<ts>_purchase.sql` | 10 | PO, GRN, purchase invoices/returns + RPCs + RLS |
| — | `<ts>_sales.sql` | 11 | quotations, bookings, sales orders, invoices, charges, delivery notes, returns + RPCs + RLS |
| — | `<ts>_accounting_core.sql` | 12 | account_groups, accounts, journal entries/lines, opening balances + triggers + RLS + CoA seeds |
| — | `<ts>_finance.sql` | 13 | payments, allocations, contra, credit/debit notes, expenses, income + RPCs + RLS + category seeds |
| — | `<ts>_gst_and_reports.sql` | 14/16 | GST views, report views, `rpc_dashboard_kpis` |
| — | `<ts>_documents.sql` | 19 | documents, reminders + RLS |
| — | `<ts>_notifications.sql` | 18 | notifications, device_tokens, preferences + realtime publication |
| — | `<ts>_audit.sql` | 20 | audit_logs + `fn_audit_row()` attached to audited tables |
| — | `<ts>_approvals.sql` | 21 | approval rules/requests/steps + engine RPCs |
| — | `<ts>_performance.sql` | 23 | extra indexes, materialised views, `pg_cron` jobs |
| — | `<ts>_hardening.sql` | 24 | RLS/privilege fixes discovered by the security audit |

Verification after every migration (part of each phase's test commands):
`supabase db lint` · `select tablename from pg_tables where schemaname = 'public' and not rowsecurity;`
(must return no business tables) · `select * from pg_policies where schemaname = 'public';`

## 7. Seed data plan (idempotent, re-runnable)

| Seed | Where / phase | Contents |
|------|---------------|----------|
| Permissions | 0004 · Phase 3 | every `module.action` combination from `02-roles-permissions.md` (21 × 7) + `showrooms.view_all` = 148 |
| Roles | 0004 · Phase 3 | 11 `is_system = true` roles with precedence and the matrix from `02-roles-permissions.md` (592 grants) |
| Account groups | with the CoA tables · Phase 12 | Assets → Current Assets (Cash, Bank, Inventory, Receivables) + Fixed Assets; Liabilities → Payables, Loans, GST Payable, Customer Advances; Equity → Capital, Drawings, Retained Earnings; Income → Vehicle Sales, Accessory Sales, Service Income, Insurance Commission, RTO Charges, Other Income, Discount Received; Expenses → COGS, Rent, Salary, Electricity, Transport, Fuel, Marketing, Repair & Maintenance, Office, Internet, Phone, Bank Charges, Discount Allowed, Stock Adjustment, Miscellaneous |
| Accounts | with the CoA tables · Phase 12 | control accounts per showroom (Cash, Bank per bank account, Inventory – Vehicles, Inventory – Spares, Input CGST/SGST/IGST, Output CGST/SGST/IGST, Round Off, Receivable control, Payable control) + company-wide nominal accounts |
| Categories | with their tables · Phase 13 | expense + income categories from §4.9 |
| HSN/SAC | with the HSN/tax tables · Phase 8 | two-wheeler HSN (8711…), spares (8714…), service SAC (9987…), accessories — rates configurable, never hardcoded |
| States | 0004 · Phase 3 | 39 GST state codes (37 active, legacy 25/28 inactive) for place of supply |
| Financial year | 0004 · Phase 3 | current Indian FY + 12 monthly `accounting_periods` (`open`) via `fn_ensure_financial_year()` |
| Document sequences | trigger / function · Phase 3 | not seeded rows: all 20 types per showroom per FY, created by the showroom bootstrap trigger and `fn_ensure_financial_year()` |
| Settings | 0004 · Phase 3 | 6 company keys (`company.name`, `company.currency_code`, `company.locale`, `company.timezone`, `ui.default_theme_mode`, `security.signed_url_ttl_seconds`); per-showroom defaults (round-off, COGS posting, valuation method, booking validity) are `showroom_settings` column defaults; approval thresholds Phase 21 |
| Demo data | `supabase/seed.sql` · Phase 3 | **dev/local only** (never staging/prod): 3 showrooms (INDORE-MAIN, BHOPAL, UJJAIN), 14 users (one per role + multi-showroom, deactivated and no-role cases); sample vehicles/items/customers arrive with their tables (Phases 8–11) |

## 8. Financial year, numbering, rounding

- `financial_years.code` = `YYYY-YY` (e.g. `2026-27`), 1 April → 31 March.
- Document numbers: `{prefix}/{FY short}/{number}{suffix}` → e.g. `IND/26-27/00001`; prefix = showroom
  `invoice_prefix` + type code; GST documents ≤ 16 characters (as built: `docs/phase-03/README.md` §4).
- Uniqueness is enforced by `(showroom_id, financial_year_id, invoice_no)` plus a row lock inside
  `fn_next_document_number()`, so concurrent sales can never duplicate a number.
- Round-off: the `round_off` column stores the difference to the nearest rupee (configurable) and posts to
  the `Round Off` account.
- Money rounding: line taxable amounts to 2 decimals, tax computed per line on the taxable amount (standard
  for GST invoices), totals summed, round-off applied last.

## 9. Performance & volume notes

- Growth tables: `stock_ledger`, `journal_entry_lines`, `audit_logs`, `payments` → append-only with
  `(showroom_id, created_at desc)` indexes; **monthly range partitioning** is a Phase 23 decision if any
  exceeds ~20M rows (not v1 work).
- Report aggregates come from `security_invoker` views; heavy ones become materialised views refreshed by
  `pg_cron` (`refresh materialized view concurrently`).
- `statement_timeout` (~15 s) and `lock_timeout` are set per role to protect the database.
- Every list screen must use keyset pagination past page ~20 to avoid expensive `offset` scans.

## 10. Backup, retention & compliance

| Item | Policy |
|------|--------|
| Database backup | Supabase automated daily + PITR on production; weekly logical dump to storage |
| Environment flow | `supabase db push` dev → staging → prod from the same migrations directory; data never moves automatically |
| Audit retention | `audit_logs` ≥ 8 years (statutory); `app_error_log` 90 days |
| Document retention | KYC/invoice PDFs ≥ 8 years; `imports-temp` lifecycle rule of 7 days |
| Deletion policy | customers/suppliers with transactions are deactivated, never deleted |