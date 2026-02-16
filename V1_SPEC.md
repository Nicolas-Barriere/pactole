# Moulax V1 — Specification

> **Goal:** Know where your money is. One dashboard, all accounts, zero fluff.

**Stack:** Elixir (Phoenix) backend + Next.js frontend + PostgreSQL  
**Data ingestion:** CSV import only  
**Target:** Self-hosted, single user  

---

## Scope — What V1 does

V1 answers one question: **"Where is my money, and where does it go?"**

Nothing else. No AI, no projections, no investment advice, no chatbot. Just clean data in, clear dashboard out.

---

## Features

### 1. CSV Import

**Upload a CSV from any supported bank and have transactions parsed and stored.**

- Upload via drag-and-drop or file picker in the UI
- Backend detects the bank format automatically based on column headers / structure
- Supported banks for V1:
  - **Boursorama** (checking + savings)
  - **Revolut**
  - **Caisse d'Épargne**
- Each CSV is tied to an **account** (user creates accounts manually first)
- Duplicate detection: if the same transaction (date + amount + label) already exists, skip it
- Import history: track when each import happened and how many transactions were added
- Validation errors surfaced clearly ("row 42: missing amount", "unknown date format")

**CSV Parser design:**
- One parser module per bank, implementing a common behaviour (`Moulax.Parsers.Parser`)
- Each parser normalizes rows into a unified `Transaction` struct:
  ```
  %Transaction{
    date: Date,
    label: String,
    amount: Decimal,
    currency: String (default "EUR"),
    original_label: String (raw from CSV),
    category: String | nil,
    bank_reference: String | nil
  }
  ```
- Adding a new bank = adding a new parser module (no other changes needed)

### 2. Accounts

**Represent each real-world bank account as an entity in the system.**

- User creates accounts manually: name, bank, type, initial balance
- Account types: `checking`, `savings`, `brokerage`, `crypto`
- Each account shows:
  - Current balance (initial balance + sum of all transactions)
  - Number of transactions
  - Last import date
- User can edit or archive accounts (soft delete)

### 3. Transaction List

**Browse, search, and manually categorize transactions.**

- Paginated table of all transactions (filterable by account, date range, category)
- Search by label (full-text)
- Each transaction shows: date, label, amount, category, account
- Inline category editing: click on category cell to assign/change
- Bulk category assignment: select multiple transactions, assign category at once
- Manual transaction entry: add a transaction by hand (for cash expenses)

### 4. Categories

**A flat list of spending categories the user defines.**

- Default seed categories: `Alimentation`, `Transport`, `Logement`, `Loisirs`, `Santé`, `Abonnements`, `Revenus`, `Épargne`, `Autres`
- User can create, rename, and delete custom categories
- Each category has a name and a color (for charts)
- **Rule-based auto-categorization:**
  - User defines keyword rules: "SNCF" → `Transport`, "CARREFOUR" → `Alimentation`
  - Rules applied automatically on import
  - Rules are simple substring matches on the transaction label
  - Rule management UI: list, create, edit, delete

### 5. Dashboard

**The main screen. At a glance: where is my money and where does it go.**

- **Net worth bar:** sum of all account balances, prominently displayed
- **Account cards:** one card per account showing name, bank, balance, last sync date
- **Monthly spending breakdown:** bar or pie chart of expenses by category for the selected month
- **Monthly trend:** line chart showing total income vs. total expenses over the last 6–12 months
- **Month selector:** navigate between months to see historical data
- **Top expenses:** list of the 5 largest expenses this month

---

## What V1 does NOT do

Explicitly out of scope — to resist temptation:

- No AI / LLM integration
- No chatbot
- No investment tracking or portfolio views
- No Monte Carlo simulations or projections
- No budget goals or alerts
- No subscription detection
- No browser automation or bank scraping
- No Open Banking
- No multi-user / auth (single user, runs locally)
- No mobile app
- No recurring transaction detection
- No export functionality

---

## Data Model

```
accounts
├── id (UUID)
├── name (String) — e.g. "Boursorama Checking"
├── bank (String) — e.g. "boursorama"
├── type (Enum) — checking | savings | brokerage | crypto
├── initial_balance (Decimal)
├── currency (String, default "EUR")
├── archived (Boolean, default false)
├── inserted_at / updated_at

transactions
├── id (UUID)
├── account_id (FK → accounts)
├── date (Date)
├── label (String) — cleaned/normalized label
├── original_label (String) — raw from CSV
├── amount (Decimal) — negative = expense, positive = income
├── currency (String)
├── category_id (FK → categories, nullable)
├── bank_reference (String, nullable) — dedup key from bank
├── source (Enum) — csv_import | manual
├── inserted_at / updated_at
├── UNIQUE(account_id, date, amount, original_label) — dedup constraint

categories
├── id (UUID)
├── name (String)
├── color (String) — hex color
├── inserted_at / updated_at

categorization_rules
├── id (UUID)
├── keyword (String) — substring to match in transaction label
├── category_id (FK → categories)
├── priority (Integer, default 0) — higher = applied first
├── inserted_at / updated_at

imports
├── id (UUID)
├── account_id (FK → accounts)
├── filename (String)
├── rows_total (Integer)
├── rows_imported (Integer)
├── rows_skipped (Integer) — duplicates
├── rows_errored (Integer)
├── status (Enum) — pending | processing | completed | failed
├── error_details (JSONB, nullable)
├── inserted_at / updated_at
```

---

## API Design (Phoenix REST)

All routes prefixed with `/api/v1`.

### Accounts
| Method | Path | Description |
|--------|------|-------------|
| GET | `/accounts` | List all accounts |
| POST | `/accounts` | Create account |
| GET | `/accounts/:id` | Get account with balance |
| PUT | `/accounts/:id` | Update account |
| DELETE | `/accounts/:id` | Archive account |

### Transactions
| Method | Path | Description |
|--------|------|-------------|
| GET | `/accounts/:account_id/transactions` | List transactions (paginated, filterable) |
| POST | `/accounts/:account_id/transactions` | Create manual transaction |
| PUT | `/transactions/:id` | Update transaction (category, label) |
| PATCH | `/transactions/bulk-categorize` | Assign category to multiple transactions |
| DELETE | `/transactions/:id` | Delete transaction |

### CSV Import
| Method | Path | Description |
|--------|------|-------------|
| POST | `/accounts/:account_id/imports` | Upload CSV file |
| GET | `/imports/:id` | Get import status & details |
| GET | `/accounts/:account_id/imports` | List imports for account |

### Categories
| Method | Path | Description |
|--------|------|-------------|
| GET | `/categories` | List all categories |
| POST | `/categories` | Create category |
| PUT | `/categories/:id` | Update category |
| DELETE | `/categories/:id` | Delete category |

### Categorization Rules
| Method | Path | Description |
|--------|------|-------------|
| GET | `/categorization-rules` | List all rules |
| POST | `/categorization-rules` | Create rule |
| PUT | `/categorization-rules/:id` | Update rule |
| DELETE | `/categorization-rules/:id` | Delete rule |

### Dashboard
| Method | Path | Description |
|--------|------|-------------|
| GET | `/dashboard/summary` | Net worth + account balances |
| GET | `/dashboard/spending?month=2026-02` | Spending by category for month |
| GET | `/dashboard/trends?months=12` | Monthly income vs. expenses |
| GET | `/dashboard/top-expenses?month=2026-02` | Top 5 expenses for month |

---

## Frontend Pages (Next.js)

```
/                     → Dashboard (default landing page)
/accounts             → Account list + create
/accounts/:id         → Account detail + transaction list + import
/transactions         → Global transaction list (all accounts)
/categories           → Category + rule management
/import               → CSV upload flow (select account → upload → review → confirm)
```

### UI Direction
- Dark mode by default (financial apps look better dark)
- Clean, card-based layout
- Minimal navigation: sidebar with 4 items (Dashboard, Accounts, Transactions, Categories)
- Charts: use Recharts or Chart.js
- Tables: sortable, filterable, paginated
- Toast notifications for import results
- French language UI (with English fallback)

---

## Project Structure

```
moulax/
├── backend/                    # Elixir Phoenix app
│   ├── lib/
│   │   ├── moulax/
│   │   │   ├── accounts/       # Account context
│   │   │   ├── transactions/   # Transaction context
│   │   │   ├── categories/     # Category + rules context
│   │   │   ├── imports/        # Import context + processing
│   │   │   └── parsers/        # CSV parsers (one per bank)
│   │   │       ├── parser.ex           # Behaviour definition
│   │   │       ├── boursorama.ex
│   │   │       ├── revolut.ex
│   │   │       └── caisse_depargne.ex
│   │   └── moulax_web/
│   │       ├── controllers/
│   │       └── router.ex
│   ├── priv/repo/migrations/
│   ├── test/
│   └── mix.exs
├── frontend/                   # Next.js app
│   ├── src/
│   │   ├── app/                # App router pages
│   │   ├── components/         # Shared UI components
│   │   ├── lib/                # API client, utils
│   │   └── types/              # TypeScript types
│   ├── package.json
│   └── next.config.js
├── MEETING_NOTES.md
├── V1_SPEC.md
└── README.md
```

---

## CSV Format Examples

### Boursorama
```csv
dateOp;dateVal;label;category;categoryParent;supplierFound;amount;accountNum;accountLabel;accountBalance
2026-02-10;2026-02-10;CARTE 10/02 CARREFOUR;;;;;;-45.32;;;
```

### Revolut
```csv
Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance
CARD_PAYMENT,Current,2026-02-10 10:30:00,2026-02-10 10:30:00,Uber,-12.50,0.00,EUR,COMPLETED,1234.56
```

### Caisse d'Épargne
```csv
Date;Numéro d'opération;Libellé;Débit;Crédit;Détail
10/02/2026;123456;VIR SEPA EMPLOYEUR;;;+2500.00;Salaire
```

> **Note:** These formats should be validated against real exports. The parser tests should use anonymized real-world CSV samples.

---

## Definition of Done (V1)

- [ ] User can create and manage accounts
- [ ] User can upload a Boursorama CSV and see transactions appear
- [ ] User can upload a Revolut CSV and see transactions appear
- [ ] User can upload a Caisse d'Épargne CSV and see transactions appear
- [ ] Duplicate transactions are detected and skipped on re-import
- [ ] Import errors are surfaced clearly
- [ ] User can browse transactions with pagination, search, and filters
- [ ] User can assign categories to transactions (single and bulk)
- [ ] User can define keyword-based auto-categorization rules
- [ ] Rules are applied automatically during CSV import
- [ ] Dashboard shows net worth, account balances, spending by category, monthly trends
- [ ] User can navigate between months on the dashboard
- [ ] UI is responsive and usable on desktop
- [ ] Backend has test coverage on parsers and core business logic
- [ ] App runs locally with `docker-compose up` (Elixir + Postgres + Next.js)
