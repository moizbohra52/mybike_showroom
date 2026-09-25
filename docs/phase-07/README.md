# Phase 7 — Showroom management

## Screens

| Screen | What it shows / does |
|--------|----------------------|
| **Showrooms** (`/showrooms`) | Showrooms the caller can access (Super Admin also sees inactive ones); table on wide screens, cards on phones; **New showroom** with `showrooms.create` |
| **Showroom** (`/showrooms/:id`) — Overview | Profile (code, legal name, address, phone, email, opened on) and GST (GSTIN, PAN, state); **Edit**; **Deactivate / Activate** |
| Settings | GST registered, round-off, minimum booking amount, booking validity, discount approval threshold, low-stock alert, negative stock, valuation method, COGS posting; **Edit** |
| Invoice | Invoice prefix, invoice / receipt texts (**Edit**), the next number of every document series of the open financial year (e.g. `IND/26-27/00001`) |
| Bank | Bank accounts; the default one is printed on invoices; add / edit / remove |
| Users | Staff of the showroom (with `users.view`); **Assign user** with a first role; a user opens the Phase 6 user page for role changes |

Edit actions need `showrooms.edit` in that showroom (ADMIN / SUPER_ADMIN by default); the session hides them
otherwise and RLS refuses them anyway. Money fields (booking minimum, discount threshold) stay text from the database
(`::text` in the select) to the form and back — never a `double` (G5).

## Database (`20260924000009_showroom_admin.sql`)

| Object | Rule |
|--------|------|
| `bank_accounts` | per showroom: holder, bank, account number (9–18 digits, unique per showroom), IFSC (`AAAA0XXXXXX`), branch, UPI ID, `is_default` (one per showroom; a new default clears the old one). Read: anyone who can access the showroom (invoices print it). Write: `showrooms.edit` in the showroom. Phase 13 adds the ledger link and balances. |
| `rpc_create_showroom(jsonb)` | `showrooms.create` granted globally; inserts (code / prefix upper-cased, blanks → NULL) and assigns a non-owner creator to the new showroom so they can read it back (the Phase 4 note). Settings and numbering come from the existing bootstrap trigger. |
| `trg_showrooms_sync_prefix` | the invoice prefix may change **until the first document number is issued** (MB012 afterwards); the showroom's numbering series follow the new prefix and GST padding is recomputed |
| `rpc_get_my_session()` | lists **active** showrooms only |

GST consistency stays in the Phase 3 constraints (GSTIN format, state code = GSTIN chars 1–2, PAN = chars 3–12,
unique invoice prefix); the form checks the same rules before sending.

## Deactivation and the switcher

- Deactivating a showroom is a status change (`showrooms.edit`); its records stay.
- It leaves every switcher at once (`rpc_get_my_session` → active only). Its staff lose access to it through
  `can_access_showroom`; someone who worked only there gets the "No showroom is assigned" screen.
- Only the Super Admin still sees an inactive showroom and can reactivate it.
- Create / edit / (de)activate reload the session (`SessionController.refresh()`): the current showroom is kept while
  it is still available, otherwise the start-up rule applies (single showroom → auto, else the picker).
- Switching showroom: showroom-scoped screens watch `currentSelectionProvider`; the Users list follows the switch.
  Later modules use the same provider.

## Tests

- DB: `supabase/tests/database/09_showroom_admin.test.sql` (33): create (who may, creator assigned, bootstrap,
  unique prefix, GSTIN/state), edit and settings (manager / accountant refused, admin allowed), prefix change before
  and after the first number, clients never write numbering, bank accounts (single default, IFSC, duplicates, staff
  read, manager refused, Bhopal manager cannot read / change / delete Indore's), deactivation and reactivation
  (admin switcher, owner-only visibility, viewer left without a showroom, back after reactivation). Opening the bank
  accounts read policy to everyone fails the isolation test.
- Flutter: `test/features/showrooms/showrooms_admin_test.dart` (13): permission-gated actions, invoice preview,
  exact money display, IFSC validation, deactivation flow + session reload, create with GSTIN/state/PAN checks,
  switcher moving the users list, session refresh (keep / fall back / block), validators.
- Dev seed: bank accounts for Indore (HDFC, default) and Bhopal (SBI).

## Known limits

- **Logo upload** is not built: it needs a file-picker dependency and matters only once invoices are printed
  (Phase 11 / 17); `showrooms.logo_path` and the `showroom-documents` bucket are ready.
- **Cash accounts / ledger links** of bank accounts come with accounting (Phases 12–13).
- Deactivating a showroom does not yet check for open stock, bookings or unpaid invoices (those tables arrive in
  Phases 9–13; the check belongs there).
- Changing the valuation method after stock exists is not guarded yet (Phase 9).
