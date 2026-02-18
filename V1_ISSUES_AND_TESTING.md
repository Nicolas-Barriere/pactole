# Moulax V1 — GitHub issues: steps and testing guide

This document maps each [GitHub issue](https://github.com/Nicolas-Barriere/moulax/issues) to concrete steps and what you can test at each step (automated and manual).

**Note:** Ports in this doc use the default from `.env.example` (Backend: 4001, Frontend: 3005). Adjust if your `.env` differs.

---

## When can I use the app?

| You want to… | Available when | Right now |
|--------------|-----------------|-----------|
| **Use the app in the browser (UI)** | After **#14 (App shell)** and the relevant **frontend** issues (#15–#19) are done. | **No.** The frontend has only placeholder pages: they show static text (“Aucun compte”, “Graphique à venir”) and **do not call the API**. So you cannot create accounts, import CSV, or see data in the UI yet. |
| **Use the backend via API (Postman/curl)** | After the corresponding **backend** issue is closed. | **Partly.** You can use **Accounts** (`/api/v1/accounts`), **Transactions** (`/api/v1/transactions`), and **Categorization rules** (`/api/v1/categorization-rules`) now. **Categories** API (#6) is not in the router yet (PR open). |
| **Import CSV from the UI** | After **#12 (Import pipeline)** and **#16 (CSV Import flow)**. | **No.** No import API or UI. |
| **See dashboard with real data** | After **#13 (Dashboard API)** and **#19 (Dashboard page)**. | **No.** Dashboard API and chart UI are not implemented. |

**Summary:** Functionality is **implemented on the backend** for accounts, transactions, and rules, but the **frontend does not use it yet** (issues #14–#19 are the UI work). So today you can only “use” the app via **API calls** (e.g. create an account with `POST /api/v1/accounts`). The next step to make the app usable in the browser is implementing **#14 (App shell)** and **#15 (Accounts page)** so you can at least list and create accounts from the UI.

---

## 1. [#1 — Scaffold Elixir Phoenix backend](https://github.com/Nicolas-Barriere/moulax/issues/1)

**Scope:** Phoenix API app in `api/`, PostgreSQL, CORS, `/api/v1` scope.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `cd api && mix test` — default tests pass. |
| **Automated** | `cd api && mix compile --warnings-as-errors` — no warnings. |
| **Manual** | `mix phx.server` (or `make dev`), then `GET http://localhost:4001/api/v1` (or any route under `/api/v1`) returns JSON (e.g. 404 with JSON body). |
| **Manual** | From browser or Postman, call API from `http://localhost:3005` and confirm no CORS errors. |

---

## 2. [#2 — Scaffold Next.js frontend](https://github.com/Nicolas-Barriere/moulax/issues/2)

**Scope:** Next.js App Router in `web/`, Tailwind, dark mode, API client, Recharts, app shell placeholder.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `cd web && pnpm run build` — build succeeds. |
| **Automated** | `cd web && pnpm lint` — no lint errors. |
| **Manual** | `pnpm dev` (or `make dev`), open `http://localhost:3005` — app loads, dark theme, base layout/sidebar visible. |
| **Manual** | Confirm API client base URL points to backend (e.g. `http://localhost:4001/api/v1`). |

---

## 3. [#3 — Docker Compose setup](https://github.com/Nicolas-Barriere/moulax/issues/3)

**Scope:** `docker-compose.yml` (Postgres, backend, frontend), Makefile, README.

### What to test

| Type | How to test |
|------|-------------|
| **Manual** | `make setup` (or `docker compose up --build`) — all services start without error. |
| **Manual** | Frontend at configured port (e.g. `http://localhost:3005`), backend at e.g. `http://localhost:4001`. |
| **Manual** | `make test` — backend tests run inside container. |
| **Manual** | `make logs` — logs from db, backend, web. `make stop` / `make clean` behave as expected. |

---

## 4. [#4 — Database schema & migrations](https://github.com/Nicolas-Barriere/moulax/issues/4)

**Scope:** Ecto migrations for `accounts`, `categories`, `categorization_rules`, `transactions`, `imports`; seed categories.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `mix ecto.reset` — runs cleanly (drop, create, migrate, seed). |
| **Automated** | `mix test` — any migration/Repo tests pass. |
| **Manual** | After `mix ecto.setup` or seed: DB has 9 default categories (Alimentation, Transport, Logement, etc.). |
| **Manual** | Inspect DB (e.g. `make shell.db` then `\dt`) — all 5 tables exist with expected columns. |

---

## 5. [#5 — Accounts context — CRUD API](https://github.com/Nicolas-Barriere/moulax/issues/5)

**Scope:** `Moulax.Accounts` context, Account schema, REST: list, create, get, update, archive.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `mix test` — Accounts context and account controller tests pass. |
| **Manual** | `GET /api/v1/accounts` — 200, list (possibly empty). |
| **Manual** | `POST /api/v1/accounts` with valid JSON (name, bank, type, initial_balance, currency) — 201, returns account with `balance`, `transaction_count`, `last_import_at`. |
| **Manual** | `GET /api/v1/accounts/:id` — 200, computed balance correct. `PUT` update, `DELETE` archive; list excludes archived. |

---

## 6. [#6 — Categories context — CRUD API](https://github.com/Nicolas-Barriere/moulax/issues/6)

**Scope:** `Moulax.Categories` context, Category schema, REST: list, create, update, delete (with nullify on transactions).

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `mix test` — Categories context and category controller tests; unique name; delete nullifies transactions. |
| **Manual** | `GET /api/v1/categories` — 200, seeded categories. |
| **Manual** | `POST /api/v1/categories` (name, color hex) — 201. `PUT /api/v1/categories/:id`, `DELETE` — 200; after delete, related transactions have `category_id` null. |

---

## 7. [#7 — Categorization rules — CRUD API & matching engine](https://github.com/Nicolas-Barriere/moulax/issues/7)

**Scope:** `Moulax.Categories.Rules`, CategorizationRule schema, `match_category/1`, REST for rules.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `mix test` — Rules context and controller; `match_category/1` (priority, case-insensitive, no match → nil). |
| **Manual** | `GET/POST/PUT/DELETE /api/v1/categorization-rules` — CRUD works; response includes category embed (id, name, color). |
| **Manual** | Create rule e.g. keyword "SNCF" → Transport; assert matching label returns Transport. |

---

## 8. [#8 — Transactions context — CRUD API with pagination, search & filters](https://github.com/Nicolas-Barriere/moulax/issues/8)

**Scope:** `Moulax.Transactions` context, list with filters/pagination/search/sort, get, create, update, delete, bulk_categorize.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `mix test` — Transactions context and controller; filters (account_id, category_id, date range, search), pagination meta, bulk_categorize. |
| **Manual** | `GET /api/v1/transactions?page=1&per_page=50` — 200, `data` + `meta` (total_count, total_pages). |
| **Manual** | `GET /api/v1/transactions?search=carrefour&category_id=...&date_from=...&date_to=...&sort_by=date&sort_order=desc` — results and order correct. |
| **Manual** | `POST /api/v1/accounts/:account_id/transactions`, `PUT /api/v1/transactions/:id`, `PATCH /api/v1/transactions/bulk-categorize`, `DELETE` — all behave as specified. |

---

## 9. [#9 — CSV Parser behaviour & Boursorama parser](https://github.com/Nicolas-Barriere/moulax/issues/9)

**Scope:** `Moulax.Parsers.Parser` behaviour, `detect?/1`, `parse/1`, ParseError; Boursorama parser and `Moulax.Parsers.detect_parser/1`.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `mix test` — Parser behaviour, Boursorama `detect?/1` (true for Boursorama CSV, false for others), `parse/1` (valid CSV → transactions; bad rows → errors). |
| **Manual** | (When import exists) Upload a Boursorama CSV; parser is detected and transactions created. |

---

## 10. [#10 — CSV Parser: Revolut](https://github.com/Nicolas-Barriere/moulax/issues/10)

**Scope:** Revolut CSV format support: `detect?/1` and `parse/1`.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `mix test` — Revolut parser tests (detect + parse, edge cases). |
| **Manual** | Upload a Revolut CSV; Revolut parser is used and transactions appear. |

---

## 11. [#11 — CSV Parser: Caisse d'Épargne](https://github.com/Nicolas-Barriere/moulax/issues/11)

**Scope:** Caisse d'Épargne CSV format support.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `mix test` — Caisse d'Épargne parser tests. |
| **Manual** | Upload a Caisse d'Épargne CSV; parser detected and transactions created. |

---

## 12. [#12 — Import pipeline — upload, parse, deduplicate, store](https://github.com/Nicolas-Barriere/moulax/issues/12)

**Scope:** `Moulax.Imports` (create_import, process_import, get_import, list_imports_for_account), upload API, dedup, categorization rules applied.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `mix test` — Imports context and controller; full pipeline; duplicate detection; rules applied; unknown format / empty file handling. |
| **Manual** | `POST /api/v1/accounts/:account_id/imports` (multipart CSV) — 201, import record with status; then `GET /api/v1/imports/:id` — status, rows_imported/skipped/errored, error_details. |
| **Manual** | Re-upload same file — rows skipped (dedup). Upload non-CSV or unknown format — clear error. |

---

## 13. [#13 — Dashboard API endpoints](https://github.com/Nicolas-Barriere/moulax/issues/13)

**Scope:** `GET /api/v1/dashboard/summary`, `.../spending?month=`, `.../trends?months=`, `.../top-expenses?month=&limit=`.

### What to test

| Type | How to test |
|------|-------------|
| **Automated** | `mix test` — Dashboard controller/context; summary with multiple accounts; spending by category; trends; top expenses; archived excluded; empty state. |
| **Manual** | `GET /api/v1/dashboard/summary` — net_worth, accounts with balance. |
| **Manual** | `GET /api/v1/dashboard/spending?month=2026-02` — by_category, total_expenses, total_income. |
| **Manual** | `GET /api/v1/dashboard/trends?months=12` — months array with income/expenses/net. |
| **Manual** | `GET /api/v1/dashboard/top-expenses?month=2026-02&limit=5` — largest expenses. |

---

## 14. [#14 — App shell — layout, sidebar, dark theme](https://github.com/Nicolas-Barriere/moulax/issues/14)

**Scope:** Root layout, sidebar (Dashboard, Accounts, Transactions, Categories), dark mode, toasts, loading states, API client.

### What to test

| Type | How to test |
|------|-------------|
| **Manual** | Open app — sidebar with links to `/`, `/accounts`, `/transactions`, `/categories`; active route highlighted. |
| **Manual** | Default is dark theme; palette matches spec (e.g. slate-900 background). |
| **Manual** | Resize to small screen — sidebar collapses to top bar (or responsive behaviour as designed). |
| **Manual** | Trigger a toast (e.g. after save) and a loading state — both visible and correct. |
| **Manual** | API client: base URL and error handling work for a sample GET. |

---

## 15. [#15 — Accounts page — list, create, edit, archive](https://github.com/Nicolas-Barriere/moulax/issues/15)

**Scope:** `/accounts` list with cards, `/accounts/:id` detail with edit/archive/import section, create/edit form.

### What to test

| Type | How to test |
|------|-------------|
| **Manual** | `/accounts` — grid of account cards (name, bank, type, balance, transaction count, last import). |
| **Manual** | “Add Account” → form (name, bank, type, initial balance, currency); submit → new account in list. |
| **Manual** | Click card → `/accounts/:id` — header, edit (name/type/initial balance), archive with confirmation. |
| **Manual** | Account detail shows recent transactions and import history; “Import CSV” navigates to import flow. |

---

## 16. [#16 — CSV Import flow — upload, review, confirm](https://github.com/Nicolas-Barriere/moulax/issues/16)

**Scope:** Select account → upload CSV → see import result (rows imported/skipped/errored), “View Transactions” / “Import Another”.

### What to test

| Type | How to test |
|------|-------------|
| **Manual** | From account detail or standalone: select account, choose CSV, upload — result screen shows totals and errors. |
| **Manual** | “View Transactions” → transaction list for that account. “Import Another” resets flow. |
| **Manual** | Empty file / unknown format → error before or after upload. Large file → progress or clear feedback. |

---

## 17. [#17 — Transactions page — table, search, filters, bulk categorize](https://github.com/Nicolas-Barriere/moulax/issues/17)

**Scope:** `/transactions`: paginated table, filters (account, category, date range), search, sort, inline category edit, bulk categorize, manual entry.

### What to test

| Type | How to test |
|------|-------------|
| **Manual** | Table shows date, label, amount, category, account; sort by date/amount/label; pagination and total count. |
| **Manual** | Filters: account, category (incl. “Uncategorized”), date range; URL updates; back button restores state. |
| **Manual** | Search: type in label, results update (debounced); term highlighted. |
| **Manual** | Click category cell → dropdown → select category → save (optimistic feedback). |
| **Manual** | Select rows → action bar → choose category → “Apply” → bulk update. “Add Transaction” → form (date, label, amount, category, account). |

---

## 18. [#18 — Categories & rules management page](https://github.com/Nicolas-Barriere/moulax/issues/18)

**Scope:** `/categories`: list categories (create/edit/delete), list rules (create/edit/delete), optional “Re-apply rules to uncategorized”.

### What to test

| Type | How to test |
|------|-------------|
| **Manual** | Categories: list with color and name; add (name + color picker), edit, delete with confirmation (and transaction count warning). |
| **Manual** | Rules: table (keyword, category, priority); add/edit/delete; sorted by priority. Optional: “Test rule” with sample label. |
| **Manual** | “Re-apply rules to all uncategorized” (if implemented) — count of recategorized transactions. |

---

## 19. [#19 — Dashboard page — net worth, charts, month navigation](https://github.com/Nicolas-Barriere/moulax/issues/19)

**Scope:** `/`: net worth, account cards, month selector, spending by category (pie/bar), income vs expenses trend, top 5 expenses, empty state.

### What to test

| Type | How to test |
|------|-------------|
| **Manual** | Net worth header and account cards match `/api/v1/dashboard/summary`. |
| **Manual** | Month selector changes month; spending chart and top expenses update (match `/dashboard/spending` and `/dashboard/top-expenses`). |
| **Manual** | Trend chart matches `/dashboard/trends`; tooltips show values. |
| **Manual** | No accounts/transactions: empty state with CTA to create account and import. |

---

## Quick reference — test commands

| Scope | Command |
|-------|--------|
| Backend tests | `make test.backend` or `docker compose exec backend mix test` |
| Backend compile | `docker compose exec backend mix compile --warnings-as-errors` |
| Frontend lint | `make test.web` or `docker compose exec web pnpm lint` |
| Frontend build | `docker compose exec web pnpm run build` |
| DB reset | `make db.reset` |
| Full stack | `make setup` then open Frontend URL and Backend URL from Make output |

---

## Issue status (as of doc creation)

- **Closed (done):** #1, #2, #3, #4, #5, #7, #8  
- **Open / in progress:** #6 (Categories API — PR open), #9–#19  

For current status and links, see [GitHub Issues](https://github.com/Nicolas-Barriere/moulax/issues).
