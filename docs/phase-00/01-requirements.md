# PHASE 0 — 01 Requirements Breakdown

## 1. Business context

| Aspect | Detail |
|--------|--------|
| Business | Multi-showroom two-wheeler dealership |
| Products sold | Petrol bikes, Electric bikes, Accessories, Spare parts |
| Services | Service jobs billed as income lines (service income, labour, spare consumption) |
| Organisation | 1 owner/company → N showrooms (Indore Main, Bhopal, …) |
| Users | Owner/Super Admin, Admin, Showroom Manager, Sales team, Purchase, Inventory, Accounts, Cashier, Service, Viewer |
| Compliance | India: GST (CGST/SGST/IGST), INR, Indian FY (Apr–Mar), UTC `timestamptz` in DB + IST display |
| Currency | INR, 2 decimals, Indian digit grouping (₹ 12,34,567.89) |
| Scale target (v1) | ≤ 25 showrooms, ≤ 500 users, ≤ 100k vehicles lifetime, ≤ 2M stock/journal rows → pagination + keyset paging + indexes mandatory |

## 2. Module list (26 modules)

| # | Module | Purpose | Key entities | Phase |
|---|--------|---------|--------------|-------|
| 1 | Auth | Login, logout, session, password reset | Supabase Auth users, `profiles` | 5 |
| 2 | Dashboard | KPIs + charts per showroom / ALL SHOWROOMS | aggregated views/RPC | 15 |
| 3 | Showroom | Showroom master, GST/bank/invoice settings, activate/deactivate | `showrooms`, `showroom_settings` | 7 |
| 4 | Users | User CRUD, activate/deactivate, showroom assignment | `profiles`, `user_showrooms` | 6 |
| 5 | Roles | Roles CRUD, permission mapping | `roles`, `role_permissions` | 6 |
| 6 | Permissions | Permission catalogue (module × action), UI gating | `permissions` | 6 |
| 7 | Vehicles | Brand → Model → Variant → vehicle master (EV + Petrol specs) | `vehicle_brands/models/variants`, `vehicles` | 8 |
| 8 | Inventory | Stock entry, status, movement ledger, adjustment, transfer, valuation, ageing | `vehicle_stock`, `stock_ledger`, `stock_transfers`, `stock_adjustments` | 9 |
| 9 | Suppliers | Supplier master + ledger/outstanding profile | `suppliers` | 10 |
| 10 | Purchases | PO → GRN → purchase invoice → payment → return | `purchase_orders/items`, `purchase_invoices`, `goods_receipts` | 10 |
| 11 | Customers | Customer master + 360° profile (purchases, payments, ledger, docs) | `customers`, `customer_addresses` | 11 |
| 12 | Bookings | Booking with advance, statuses, conversion to sale | `bookings`, `booking_payments` | 11 |
| 13 | Sales | Quotation → Sales order → Invoice → delivery; discount/insurance/RTO/accessories/exchange | `quotations`, `sales_orders/items`, `sales_invoices`, `sales_invoice_charges` | 11 |
| 14 | Finance | Payments, receipts, allocations, cash & bank, contra, credit/debit note, outstanding | `payments`, `payment_allocations`, `cash_accounts`, `bank_accounts`, `contra_entries` | 13 |
| 15 | Accounting | CoA, groups, journals, double entry, ledgers, period close | `account_groups`, `accounts`, `journal_entries`, `journal_entry_lines`, `accounting_periods` | 12 |
| 16 | Expenses | Expense entry, approval, payment, receipt attachment, showroom allocation | `expenses`, `expense_categories` | 13 |
| 17 | Income | Non-sales income (service, scrap, other) with accounting | `income_entries`, `income_categories` | 13 |
| 18 | GST & Tax | Configurable rates, CGST/SGST/IGST, taxable value, round-off, GST reports | `tax_rates`, `hsn_sac_codes` | 14 |
| 19 | Reports | Sales/Purchase/Stock/Ledger/Cash/Bank/TB/P&L/BS/Receivable/Payable/GST/Expense | views + RPC + PDF/Excel/CSV | 16, 17 |
| 20 | Documents | Supabase Storage documents (RC, insurance, invoices, warranty, KYC) | `documents`, storage buckets | 19 |
| 21 | Notifications | FCM push + in-app notification centre, read/unread, role/showroom targeting | `notifications`, `device_tokens` | 18 |
| 22 | Audit Logs | Immutable trail of create/update/delete/approve/payment/login… | `audit_logs` (trigger-written) | 20 |
| 23 | Approvals | Configurable approval workflow (expense, discount, purchase, payment, stock adjustment/transfer) | `approval_requests`, `approval_steps`, `approval_rules` | 21 |
| 24 | Search & Filters | Reusable search/sort/filter/pagination/date-showroom-status filters | shared query builder | 22 |
| 25 | Settings | Company, GST, FY, numbering, theme, notification, approval thresholds | `settings`, `document_sequences`, `financial_years` | 7, 14 |
| 26 | Platform/Core | Config, theme, routing, network, storage, validators, formatting, PDF/export, connectivity | `core/*`, `common/*` | 1, 2 |

## 3. Functional requirements (highlights)

- **FR-AUTH**: email/password login via Supabase Auth; session persistence + auto refresh; logout clears session and cached sensitive data; Admin-initiated password reset (Edge Function) and self-service email reset.
- **FR-SHOWROOM**: create/edit/activate showroom (code, GSTIN, address, bank, invoice prefix, FY start); users assigned to 1..N showrooms; showroom switcher; `ALL SHOWROOMS` consolidated mode for authorised roles.
- **FR-RBAC**: permissions at module level with actions `view, create, edit, delete, approve, export, print`; role→permission mapping editable by Super Admin; user→role mapping optionally showroom-scoped; UI hides/blocks, DB enforces.
- **FR-VEHICLE**: unique VIN/chassis per active stock; Petrol vs Electric conditional specifications; duplicate validation (VIN, chassis, engine/motor number) client-side **and** DB unique index.
- **FR-STOCK**: every physical unit individually tracked (purchase → stock → reserved → transferred → sold → delivered) with immutable `stock_ledger`; valuation = specific identification for vehicles, weighted-average for spares/accessories; low-stock alert; ageing report.
- **FR-TRANSFER**: source → destination transfer with `in_transit` state, dispatch/receive actors, remarks, full history, accounting-neutral (inventory value moves between showroom inventory accounts, no P&L impact).
- **FR-PURCHASE**: PO (optional) → GRN → purchase invoice (with GST) → payment (cash/credit/partial) → return; supplier ledger & outstanding; GRNI accrual when goods are received before invoice.
- **FR-SALES**: quotation → booking (advance, expected delivery, executive) → sales invoice (discount, accessories, insurance, RTO, other charges, exchange) → payment (cash/UPI/bank/card/finance/mixed/part) → delivery with document checklist.
- **FR-ACCOUNTING**: full double entry; every financial event posts its journal **atomically inside a DB function**; posted entries immutable; corrections by reversal; period lock; FY-aware numbering; trial balance always balanced (DB-enforced).
- **FR-GST**: rates configurable per item/HSN; intra-state (CGST+SGST) vs inter-state (IGST) by place of supply; input vs output tax accounts; taxable value + round-off; GST reports ready for returns.
- **FR-CASH-BANK**: multiple cash counters and bank accounts per showroom; day book; today's collection/expense; contra transfers; reconciliation flag.
- **FR-REPORTS**: every report supports date range, showroom, user, brand/model, customer/supplier, status filters; export PDF/Excel/CSV; printable A4/A5 invoice and receipt templates.
- **FR-NOTIFY**: push + in-app for new sale, new purchase, payment received/pending, expense, low stock, stock received, vehicle sold, approval required, stock transfer, financial alerts.
- **FR-AUDIT**: who/what/when/before/after/showroom for all mutations incl. login/logout; readable only by privileged roles; never editable.
- **FR-DOCS**: private storage, per-showroom folder isolation, signed URLs, expiry reminders (insurance/RC/warranty).

## 4. Non-functional requirements

| ID | Requirement |
|----|-------------|
| NFR-1 | **Security**: RLS on every business table; least privilege; no service key client-side; secrets only in Edge Function env; sensitive actions audited |
| NFR-2 | **Correctness**: money in `numeric`, DB-enforced invariants (balanced journals, non-negative stock, unique VIN, unique invoice number per FY/showroom) |
| NFR-3 | **Performance**: lists paginated (≤ 50 rows/page, keyset for deep paging); dashboard first paint < 1.5 s on 4G; filters indexed; debounced search 350 ms |
| NFR-4 | **Scalability**: multi-showroom growth without schema change; `stock_ledger`/`journal_entry_lines` partition-ready if volume demands |
| NFR-5 | **Cross-platform**: one codebase for Android, iOS, Web (Chromium/Edge/Safari) and Windows 10+; platform gaps isolated behind interfaces |
| NFR-6 | **Offline tolerance**: online-first; explicit network error states; no silent data loss; retry with idempotency keys on money writes |
| NFR-7 | **Maintainability**: feature-sliced modules, public reusable widgets/services, analyzer clean, generated code where it removes boilerplate |
| NFR-8 | **Observability (DevOps)**: dev/staging/prod Supabase projects, versioned migrations, structured debug logging, audit trail in prod |
| NFR-9 | **Accessibility/UX**: touch targets ≥ 44 px, text contrast ≥ 4.5:1, keyboard navigation on desktop/web, light + dark themes |
| NFR-10 | **Localisation-readiness**: all user-facing strings centralised (English v1) so Hindi/regional can be added without refactor |

## 5. Explicitly out of scope for v1

- Payroll / HR / attendance and statutory filing integrations (e-invoice IRN, e-way bill, GSTR filing APIs).
- Manufacturing/BOM and work-in-progress costing.
- Workshop job-card time tracking with technician productivity analytics.
- Customer mobile app / dealer or supplier self-service portal.
- Multi-company / multi-tenant SaaS (single company, multi-showroom only).
- Full offline write-through sync engine with conflict resolution — online-first in v1.
- Native Windows/Linux push notifications (Firebase Messaging has no Windows support → realtime in-app notification centre instead, see `03-architecture.md`).

## 6. Constraints & assumptions

| # | Assumption (default taken; confirmable in `10-open-questions.md`) |
|---|------------|
| A1 | Single legal company; GSTIN per showroom; invoices issued per showroom. |
| A2 | One stock location per showroom (extra locations modelled as showrooms). |
| A3 | Vehicles are serialised inventory (VIN-level); accessories/spares are quantity inventory. |
| A4 | Payroll handled outside the system; owner draws entered as expenses. |
| A5 | Double-entry accounting with COGS posting on sale (toggle in settings). |
| A6 | Roles are showroom-scoped by default; `SUPER_ADMIN` is global. |
| A7 | Migration of legacy Excel/Tally data is a separate later task (import tooling in Phase 22+ if needed). |