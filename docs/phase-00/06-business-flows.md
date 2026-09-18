# PHASE 0 — 06 Business Flows (Inventory, Purchase, Sales, Accounting)

## 1. Vehicle lifecycle (individual unit tracking)

```
PURCHASED ─▶ IN_TRANSIT ─▶ RECEIVED ─▶ IN_STOCK ─┬─▶ RESERVED ─▶ SOLD ─▶ DELIVERED
                                                ├─▶ IN_TRANSIT (transfer) ─▶ IN_STOCK (other showroom)
                                                ├─▶ DAMAGED ─▶ (adjustment / repair) ─▶ IN_STOCK
                                                └─▶ RETURNED_TO_SUPPLIER
```

| Transition | Triggered by | Guard conditions | Side effects |
|-----------|--------------|------------------|--------------|
| → `PURCHASED` | PO confirmed / supplier invoice booked | PO approved, variant exists | commitment only |
| → `IN_TRANSIT` | Supplier dispatch recorded on PO/GRN | PO exists | — |
| → `RECEIVED` | `rpc_receive_purchase_order` | `purchases.create` permission, GRN matches PO (configurable tolerance) | create `vehicles` instance, `stock_ledger` (`purchase_receipt`), GRNI accrual if the invoice is not booked yet |
| → `IN_STOCK` | Receiving posted / transfer received | unit cost known | available for sale; ageing clock starts |
| → `RESERVED` | Booking created with a specific unit (or auto-allocation) | unit `IN_STOCK`, no active reservation | `vehicle_reservations` row + expiry job |
| → `SOLD` | `rpc_create_sale` posts the invoice | unit accessible to showroom, not already invoiced (unique partial index), price ≥ floor if configured | invoice + line, `stock_ledger` (`sale_issue`), COGS journal, reservation released |
| → `DELIVERED` | Delivery note completed | invoice `posted`, checklist + signature captured, documents verified | warranty start, RC/insurance tracking, notification |
| → `DAMAGED` | Stock adjustment (`reason = damage`) | `inventory.edit`, approval above threshold | adjustment out + inventory write-down journal |
| → `RETURNED_TO_SUPPLIER` | Purchase return posted | linked invoice | debit note + inventory reversal |
| Reservation released | Booking cancelled/expired or sale completed | — | `released_at` stamped, status back to `IN_STOCK` |

Every transition writes a `vehicle_status_history` row (append-only), so a unit's complete history exists
even before the generic audit log of Phase 20.

## 2. Inventory & stock model

| Concept | Implementation |
|---------|----------------|
| Serialised stock (vehicles) | one `vehicles` row per physical unit; quantity is implicitly 1; `status` drives availability |
| Quantity stock (spares/accessories) | `item_stock` per `(showroom_id, item_id)`: `qty_on_hand`, `qty_reserved`, `unit_cost_avg` |
| Single source of truth | `stock_ledger` (append-only). `item_stock` and `vehicles.status` are **derived**, updated by `trg_stock_ledger_apply` |
| Availability | spares: `available = qty_on_hand − qty_reserved`; vehicles: `IN_STOCK` with no active reservation |
| Valuation — vehicles | **specific identification** (each unit carries its own landed cost from its purchase invoice) |
| Valuation — spares/accessories | **weighted average** (`unit_cost_avg` recomputed on each receipt) |
| Landed cost build-up | purchase rate − discount + freight + capitalisable charges (setting `capitalize_freight`) |
| Stock adjustment | draft → approval (if a rule matches) → posted; direction in/out with reason; always journalised |
| Damaged/lost stock | adjustment with reason `damage`/`theft`; value written off to `Stock Adjustment` |
| Opening stock | FY opening adjustment (`reason_code = opening`) plus an opening journal, so stock and books agree from day 1 |
| Low stock | `item_stock.qty_on_hand <= items.reorder_level` (or the showroom default) → `low_stock` notification |
| Ageing | `v_stock_ageing` (days since receipt); vehicles > 90 days raise a financial alert |
| Negative stock | blocked by default (`allow_negative_stock = false`); if enabled the movement is still journalised and the row is flagged |

## 3. Stock transfer flow (showroom → showroom)

```
Draft ─▶ Pending approval ─▶ Approved ─▶ Dispatched (in_transit) ─▶ Received ─▶ Closed
  │             │                            │                        │
  └ cancelled   └ rejected                   └ rejected at gate       └ discrepancy adjustment
```

1. **Create** (`rpc_create_stock_transfer`): lines = vehicles and/or items; validates the source showroom
   holds the units, the user has `inventory.create` **for the source** and `inventory.view` for the
   destination; units are reserved so they cannot be double-allocated.
2. **Approve** (per `approval_rules`, e.g. value > ₹50,000): the approver needs `inventory.approve` in the
   source showroom; the destination manager is notified.
3. **Dispatch**: `stock_ledger` `transfer_out` rows at the source (value leaves source inventory); statuses
   → `in_transit`; `dispatched_by`/`dispatched_at` stamped; transport/document details recorded.
4. **Receive** (`rpc_receive_stock_transfer`): `stock_ledger` `transfer_in` rows at the destination with the
   **same unit cost** (no P&L impact, only inventory-account movement); statuses → `IN_STOCK`/`in_stock` with
   the new `showroom_id`; shortages/damage create a linked adjustment.
5. **History**: `stock_transfers`, `stock_transfer_items`, `stock_ledger`, `vehicle_status_history` and
   `audit_logs` form an immutable chain. A transfer is cancelled with a reason before dispatch, or reversed
   with a return transfer after receipt — never deleted.

Accounting (per showroom inventory accounts, via an in-transit clearing account):
```
Dispatch : Dr Inventory in Transit                    Cr Inventory – Vehicles/Spares (source showroom)
Receive  : Dr Inventory – Vehicles/Spares (dest.)     Cr Inventory in Transit
```
No income or expense is recognised, so transfers can never distort P&L.

## 4. Purchase flow

```
Requisition (optional) ─▶ Purchase Order ─▶ Supplier dispatch ─▶ GRN ─▶ Purchase Invoice ─▶ Payment
        │                       │                                │            │               │
        └ draft/cancelled       └ sent / partially received       └ GRNI       └ payable +     └ cash/bank
                                                                   accrual       input GST        │
                                                                              Purchase return / Debit note
```

| Step | Screen / RPC | Validations | Accounting |
|------|--------------|-------------|------------|
| PO | `purchase_orders` + items | supplier active, variant/item exists, qty > 0, rate > 0, approval above threshold | none (commitment memo) |
| GRN | `rpc_receive_purchase_order` | PO allows receiving, qty ≤ ordered (tolerance), VIN/chassis uniqueness, engine/motor numbers per fuel type | Dr Inventory (received-not-invoiced) / Cr GRNI when `post_grn_accrual = true` |
| Purchase invoice | `rpc_post_purchase_invoice` | supplier invoice number unique per supplier, GST recomputed server-side, interstate/intrastate by place of supply, GRN link | Dr Inventory (net of discount + capitalisable charges) · Dr Input CGST/SGST/IGST · Cr Supplier (or Cr GRNI) |
| Payment | `rpc_post_payment` (direction `outgoing`) | amount ≤ outstanding unless advance/on-account, mode-specific fields (cheque/UTR), idempotency key | Dr Supplier · Cr Cash/Bank |
| Partial/multiple payments | allocations per invoice | sum(allocations) ≤ payment amount | updates `paid_amount`/`balance_amount`, status `partially_paid`/`paid` |
| Purchase return | `purchase_returns` + posting RPC | qty ≤ purchased, vehicle not yet sold | Dr Supplier · Cr Inventory · Cr Input GST (reversal) → `debit_notes` |
| Supplier ledger | `v_supplier_ledger` | — | derived from journal lines (`party_type = 'supplier'`) |
| Outstanding | `v_payables` | — | invoice-wise + ageing buckets (0-30 / 31-60 / 61-90 / 90+) |

## 5. Sales flow

```
Enquiry ─▶ Quotation ─▶ Booking (+advance) ─▶ Sales Order ─▶ Sales Invoice ─▶ Payment/Finance ─▶ Delivery
              │              │                                    │
              └ expired      └ cancelled (refund/forfeit)          └ exchange, discount, accessories,
                                                                     insurance, RTO, other charges
```

| Step | Screen / RPC | Validations | Accounting |
|------|--------------|-------------|------------|
| Quotation | `quotations` + items | customer exists, price ≥ floor (or discount permission), GST by place of supply | none (memo only) |
| Booking | `bookings` + `booking_payments` | booking amount ≥ `booking_min_amount`, unit availability (specific VIN or variant-level), executive assigned, approval when discount exceeds threshold | Dr Cash/Bank · Cr Customer Advances |
| Booking cancellation | `rpc_cancel_booking` | refund/forfeit policy from settings | Dr Customer Advances · Cr Cash/Bank (refund) or Cr Other Income (forfeit) |
| Sales order | `sales_orders` + items | converts quotation/booking, applies advance as part payment, plans delivery | none yet (advance remains a liability) |
| Sales invoice | `rpc_create_sale` | vehicle available and not invoiced, VIN matches, prices/discounts re-validated server-side, GST recomputed, accessory/insurance/RTO lines valid, exchange valuation | **Dr Customer** · Cr Vehicle/Accessory/Service Sales (taxable) · Cr Output CGST/SGST/IGST · Cr charge income accounts · **and** Dr COGS · Cr Inventory (vehicles + spares) · round-off to `Round Off` |
| Payment / finance | `rpc_post_payment` (direction `incoming`) | amount ≤ balance unless advance; finance fields required when mode = `finance` | Dr Cash/Bank · Cr Customer; advances reclassified from Customer Advances to Customer when the invoice posts |
| Exchange (trade-in) | `sales_invoices.exchange_vehicle_id` + purchase of the used unit | valuation + ownership documents | Dr Inventory – Used Vehicles · Cr Customer (reduces receivable) |
| Delivery | `delivery_notes` | invoice posted, RC/insurance/warranty documents attached, checklist signed | status → `DELIVERED`, warranty start stamped, notification sent |
| Sales return / credit note | `sales_returns`, `credit_notes` | qty ≤ sold, reason required, approval per rules | Dr Sales Return · Dr Output GST · Cr Customer; inventory restored when goods come back |
| Customer ledger / outstanding | `v_customer_ledger`, `v_receivables` | — | derived from journal lines (`party_type = 'customer'`) |

### 5.1 Booking rules

| Rule | Behaviour |
|------|-----------|
| Minimum booking amount | from `showroom_settings.booking_min_amount`; server-validated |
| Unit allocation | specific VIN (hard reserve) or variant-level (soft, FIFO allocation at invoicing) |
| Validity | `booking_validity_days`; a `pg_cron` job expires stale bookings and releases reservations |
| Statuses | `pending` → `confirmed` → (`cancelled` \| `converted_to_sale`); `expired` from the job |
| Cancellation | reason mandatory; refund/forfeit per policy; advance liability cleared with a journal |
| Conversion | `rpc_create_sale` with `booking_id` → advance applied, booking marked `converted_to_sale`, vehicle status `SOLD` |
| Duplicate protection | one active booking per customer per variant (warning) and one active reservation per vehicle (DB index) |

## 6. Payment, expense, cash & bank flows

| Flow | Steps | Accounting |
|------|-------|------------|
| Customer receipt | select party → mode (cash/UPI/bank/cheque/card/finance) → amount → allocate to invoices/booking/on-account | Dr Cash/Bank · Cr Customer (or Cr Customer Advances for on-account/advance) |
| Supplier payment | select supplier → invoices → amount → mode | Dr Supplier · Cr Cash/Bank |
| Mixed payment | a single receipt with several modes → stored as multiple `payments` rows sharing a `receipt_group_id` (added in Phase 13) and one journal per mode | per-mode Dr Cash/Bank · Cr Customer |
| Expense | create (category, payee, GST, attachment) → approval if rule matches → pay (cash/bank) | Dr Expense (+ Dr Input GST) · Cr Cash/Bank or Cr Supplier |
| Other income | create (category, party, GST) → post | Dr Cash/Bank · Cr Income (+ Cr Output GST) |
| Contra | cash → bank or bank → cash | Dr Bank · Cr Cash (or reverse) |
| Cash handover | cashier closes the day; counter balance transfers to bank/main cash | contra entry + day-book report |
| Outstanding reports | receivable/payable ageing from `v_receivables`/`v_payables` | derived |

## 7. Accounting posting matrix (event → journal)

| Event | Debit | Credit | Source doc | Notes |
|-------|-------|--------|-----------|-------|
| Booking advance received | Cash / Bank | Customer Advances | `payments` | advance is a liability until invoiced |
| Vehicle sale invoiced | Customer (receivable) | Vehicle Sales (taxable value) | `sales_invoices` | per-line taxable amount |
| GST on sale (intra-state) | Customer | Output CGST + Output SGST | `sales_invoices` | split from the tax rate |
| GST on sale (inter-state) | Customer | Output IGST | `sales_invoices` | place of supply ≠ showroom state |
| Accessory / service / other charges | Customer | Accessory Sales / Service Income / Other Income | `sales_invoice_items`, `sales_invoice_charges` | separate revenue accounts per line type |
| Insurance / RTO collected | Customer | Insurance Charges Payable / RTO Charges Payable (pass-through) | `sales_invoice_charges` | expense recognised when actually paid to insurer/RTO |
| Invoice-level trade discount | — (net in taxable value) | — | invoice lines | discount applied before tax |
| Post-invoice cash discount | Discount Allowed (expense) | Customer | `payment_allocations.discount_allowed` | does not reduce GST already charged |
| Cost of goods sold | COGS | Inventory – Vehicles / Spares | `sales_invoices` (COGS entry) | disabled if `post_cogs_on_sale = false` |
| Round-off | Round Off (Dr or Cr) | Customer / Round Off | invoice | difference to nearest rupee |
| Customer receipt | Cash / Bank | Customer | `payments` | allocation reduces invoice balance |
| Advance applied to invoice | Customer Advances | Customer | `rpc_create_sale` | reclassifies the liability |
| Sales return / credit note | Sales Return + Output GST | Customer | `sales_returns`, `credit_notes` | inventory restored when goods return |
| Exchange (trade-in) | Inventory – Used Vehicles | Customer | invoice + used-vehicle purchase | reduces the amount payable |
| Purchase goods received (accrual) | Inventory (or Inventory in Transit) | Goods Received Not Invoiced | `goods_receipts` | when `post_grn_accrual = true` |
| Purchase invoice booked | Inventory (net) + Input CGST/SGST/IGST | Supplier (payable) or GRNI | `purchase_invoices` | freight capitalised or expensed per setting |
| Supplier payment | Supplier | Cash / Bank | `payments` | allocation reduces invoice balance |
| Purchase return / debit note | Supplier | Inventory + Input GST (reversal) | `purchase_returns`, `debit_notes` | — |
| Stock adjustment (loss/damage) | Stock Adjustment (expense) | Inventory | `stock_adjustments` | approval above threshold |
| Stock adjustment (found/surplus) | Inventory | Stock Adjustment (income) | `stock_adjustments` | — |
| Stock transfer dispatch/receive | Inventory in Transit / Inventory (dest.) | Inventory (source) / Inventory in Transit | `stock_transfers` | no P&L impact |
| Expense posted | Expense account (+ Input GST) | Cash/Bank or Supplier (payable) | `expenses` | approval workflow optional |
| Expense paid later | Supplier/Payable | Cash / Bank | `payments` | — |
| Other income | Cash / Bank | Income account (+ Output GST) | `income_entries` | — |
| Contra (cash ⇄ bank) | Bank / Cash | Cash / Bank | `contra_entries` | — |
| Opening balances (FY start) | per account nature | per account nature | `opening_balances` | posted as `opening` journal |
| Reversal of any entry | swap debit/credit of the original lines | — | `rpc_reverse_journal_entry` | links `reverses_entry_id` / `reversed_by_entry_id` |

Posting rules:
1. Every row above is created by a single RPC inside one transaction — never by multiple client calls.
2. Server re-computes tax, totals and round-off; client-sent amounts are treated as *intent*, not truth.
3. `journal_entries.source_type` + `source_id` link each entry back to its business document for drill-down.
4. Control accounts (Receivable/Payable/Inventory/Cash/Bank/GST) are flagged on `accounts` and can only be
   posted through the module RPCs, not by manual journal (guard in `rpc_post_journal`).

## 8. Period lock, correction and reversal policy

| Rule | Detail |
|------|--------|
| Periods | `accounting_periods` per month; `open` → `locked` → `closed`. Posting into non-open periods is rejected |
| Locking | `rpc_close_period` by Super Admin/Accountant with permission; audited with reason |
| Corrections | Always additive: reversal entry, credit note, debit note, or a new correcting document |
| No hard delete | `authenticated` has no DELETE grant on journal/ledger tables; immutability triggers are the second wall |
| Document cancellation | Allowed for `draft` documents; `posted` documents require a reversal/cancel RPC that keeps the original row with `status = cancelled` + reason + audit |
| FY close | Closing entry transfers Income/Expense balances to Retained Earnings; `financial_years.is_closed` blocks further posting |
| Back-dated entries | Rejected if the period is locked; if open, allowed with a warning and audit entry |

## 9. GST mechanics (configurable, never hardcoded)

| Aspect | Design |
|--------|--------|
| Rate source | `items.gst_rate` / `vehicle_variants` → resolved at line level with `tax_rates` for defaults; rates are data, not code |
| HSN/SAC | stored per item/variant (`hsn_sac_codes`), printed on invoices and used in GST reports |
| Intra-state (CGST + SGST) | when `place_of_supply_state_code = showroom.state_code`: tax split equally, each half posted to `Output CGST` / `Output SGST` |
| Inter-state (IGST) | otherwise: whole tax to `Output IGST` |
| Place of supply | customer state for B2C sales; shipping address state for inter-state business sales; purchase: supplier (or receiving) state |
| Taxable value | line `rate × qty − line discount`; tax computed per line; totals summed per tax bucket |
| Round-off | separate column + account, applied after tax |
| Exempt / nil / zero-rated | `tax_type` enum values (`exempt`, `nil_rated`) produce no tax lines but still appear in reports |
| Input tax | purchases and expenses post to `Input CGST/SGST/IGST`; only invoices with a supplier GSTIN are ITC-eligible (flag stored) |
| Reports | `v_gst_summary` → taxable sales/purchases, output tax, input tax, net liability, by period/showroom/HSN |
| Reverse charge / TDS | out of v1 scope (documented); would add dedicated accounts + a flag on the line |
| e-invoice / e-way bill | out of v1 scope; the invoice payload is already structured so an Edge Function can be added later |
| GSTIN validation | `ValidationRules.gstin` (15-char pattern + checksum) client-side **and** a DB `CHECK`/trigger format check |

## 10. Dashboard metric definitions (Phase 15)

| KPI | Formula / source |
|-----|------------------|
| Today's sales | `sum(sales_invoices.grand_total)` where `status in (posted, partially_paid, paid)` and `invoice_date = today` (selected showroom) |
| Monthly sales | same, `invoice_date` within the current month |
| Total sales (period) | same, over the selected date range |
| Today's collection | `sum(payments.amount)` where `direction = incoming`, `payment_date = today`, `status = posted` |
| Total purchase | `sum(purchase_invoices.grand_total)` over the range |
| Current stock (units) | count of `vehicles` with `status in (in_stock, reserved)` per showroom |
| Stock value | `sum(unit cost)` of in-stock vehicles + `sum(item_stock.qty_on_hand × unit_cost_avg)` |
| Receivable | closing balance of Receivable control accounts from journal lines (customer-wise drill-down) |
| Payable | closing balance of Payable control accounts |
| Cash balance | closing balance of `is_cash` accounts per showroom |
| Bank balance | closing balance of `is_bank` accounts (all bank accounts) |
| Profit (gross) | `v_profit_and_loss`: (Vehicle + Accessory + Service + Other income) − COGS for the range |
| Profit (net) | gross profit − operating expenses for the range |
| Sales trend / purchase trend / profit trend / expense trend | monthly buckets from `v_sales_summary`, `v_purchase_summary`, `v_profit_and_loss`, `v_expense_summary` |
| Showroom performance | per-showroom sales/purchase/profit table for the range (ALL SHOWROOMS mode) |
| Vehicle distribution | counts by brand/model/fuel type (petrol vs electric) |
| Payment distribution | `sum(payments.amount)` grouped by `payment_mode` |

Dashboard rules: all KPIs come from a **single RPC** (`rpc_dashboard_kpis`) to avoid N round-trips; the
selected showroom + date range + permissions always apply; ALL SHOWROOMS mode returns both consolidated
values and the per-showroom break-up; values are money-typed (`numeric`) and formatted by `FormattingService`
(Indian grouping, ₹ symbol, 2 decimals).

## 11. Report → data mapping (Phase 16 readiness)

| Report | Primary source |
|--------|----------------|
| Daily / Monthly / Yearly / Showroom / Brand / Model / Executive / Payment-wise / GST sales | `v_sales_summary` (+ `sales_invoices`, `sales_invoice_items`) |
| Purchase register, supplier-wise, vehicle purchase, showroom purchase | `v_purchase_summary` (+ `purchase_invoices`, items) |
| Current stock, stock movement, stock valuation, vehicle ageing, available/sold vehicles, transfer, damaged | `v_current_stock`, `stock_ledger`, `v_stock_valuation`, `v_stock_ageing`, `stock_transfers`, `stock_adjustments` |
| Cash book, bank book | `v_cash_book`, `v_bank_book` |
| Customer / supplier ledger | `v_customer_ledger`, `v_supplier_ledger` |
| General ledger | `v_general_ledger` |
| Trial balance / P&L / Balance sheet | `v_trial_balance`, `v_profit_and_loss`, `v_balance_sheet` |
| Receivable / Payable (+ageing) | `v_receivables`, `v_payables` |
| Expense / income registers | `v_expense_summary`, `v_income_summary`, `expenses`, `income_entries` |
| GST summary, input GST, output GST, taxable sales/purchases | `v_gst_summary`, `tax_ledger` view, journal lines with `tax_type` |
| Audit / activity reports | `audit_logs` (+ `auth_events`) |

Every report accepts: date range, showroom, user (executive/creator), brand/model, customer, supplier,
status, payment mode — all applied server-side inside the `security_invoker` views so RLS always applies.
Export formats (PDF / Excel / CSV) and printing are Phase 17.