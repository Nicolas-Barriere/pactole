# Pactole

> Know where your money is. One dashboard, all accounts, zero fluff.

Pactole is a self-hosted personal finance aggregator. Import CSV statements from your banks, auto-categorize transactions, and track balances and spending trends across accounts from a single dashboard.

## Tech Stack

| Layer | Technology |
| --- | --- |
| Frontend | Next.js 16, React 19, TypeScript, Tailwind CSS 4 |
| Backend | Elixir 1.15, Phoenix 1.8, Ecto |
| Database | PostgreSQL 18 |
| Infra | Docker Compose + Makefile |

## Current Features

### Dashboard and analytics

- Portfolio overview with all active accounts and computed balances.
- Net worth display with optional conversion to a base currency.
- Monthly navigation to analyze a specific month.
- Spending breakdown by tag (pie chart with percentages).
- Income vs expenses trend over the last 12 months (bar chart).
- Top 5 expenses for the selected month.
- Quick drill-down links from dashboard cards/charts to detailed views.

### Accounts

- Create and edit accounts with bank, account type, currency, and initial balance.
- Supported account types: checking, savings, brokerage, crypto.
- Automatic account balance computation from initial balance + transactions.
- Account detail page with recent transactions and import history.
- Inline update for initial balance from the account detail view.
- Soft archive flow (account hidden from main lists while data is preserved).

### Transactions

- Global transaction list across all accounts.
- Manual transaction creation.
- Server-side pagination (50 rows/page), sorting, and filtering.
- Filters by account, tag (including untagged), date range, and text search on label.
- Inline tag editing directly from the transaction table.
- Bulk tagging action for selected transactions.
- Origin tracking per transaction (manual vs CSV import) with links to related import runs.

### CSV import workflow

- Drag-and-drop or file picker upload for CSV files.
- Bank detection before import (`/imports/detect`) and parser routing.
- Supported bank parsers: Boursorama, Revolut, Caisse d'Epargne.
- Smart account routing:
  - auto-import when exactly one matching account exists for the detected bank,
  - account chooser when multiple accounts match,
  - quick account creation when none match.
- Import result summary with totals (added, replaced, ignored, errors).
- Row-level import details with status filtering (added/updated/ignored/error).
- Import history timelines:
  - per-account import history on account pages,
  - global import history on the import page with infinite loading.
- Dedicated import detail page with:
  - run metadata and status,
  - per-row status and error details,
  - links between replaced rows and replacement import runs.

### Tags and auto-tagging rules

- Full tag CRUD (name + color).
- Full tagging rule CRUD (keyword, linked tag, priority).
- Auto-tagging on imported transactions.
- Reapply rules action on untagged existing transactions.

### Multi-currency

- Accounts and transactions store their original currency.
- Display toggle between:
  - native values,
  - converted values in a base currency.
- Currency and exchange-rate endpoints available to power conversions.
- Explicit UI hints where dashboard aggregations currently assume mono-currency inputs.

### User experience

- Clean empty states for first-time setup (create account / import CSV).
- Toast feedback for create/update/import/tagging actions.
- Focused finance-first UI with no authentication flow (single-user self-hosted usage).

## Quick Start

### Prerequisites

- Docker + Docker Compose v2+

### Setup

```bash
git clone https://github.com/Nicolas-Barriere/pactole.git
cd pactole

# Optional: customize exposed ports
cp .env.example .env

make setup
```

When containers are up:

- Frontend: `http://localhost:3005`
- Backend API base URL: `http://localhost:4001/api/v1`
- PostgreSQL: `localhost:5434` (`postgres` / `postgres`, db: `pactole_dev`)

Edit `.env` to override `WEB_PORT`, `BACKEND_PORT`, and `DB_PORT`.

## Common Commands

Run `make help` for the full list. Most used:

```bash
make dev            # start all services in background (build if needed)
make dev.logs       # start all services in foreground
make stop           # stop all services
make logs           # follow logs from all services
make test.backend   # run backend tests
make test.web       # run frontend lint
make db.migrate     # apply pending migrations
make db.reset       # drop + recreate + migrate + seed
make shell.backend  # open IEx in backend container
make shell.db       # open psql in db container
```

## Local Development (without Docker)

Backend:

```bash
cd api
mix deps.get
mix ecto.setup
mix phx.server
```

Frontend:

```bash
cd web
pnpm install
pnpm dev
```

## Project Structure

```text
pactole/
├── api/               # Phoenix API
├── web/               # Next.js frontend
├── docker-compose.yml # Full stack orchestration
├── Makefile           # Dev commands
└── README.md
```

## Supported Banks (CSV Import)

- Boursorama
- Revolut
- Caisse d'Epargne

## License

Private project.
