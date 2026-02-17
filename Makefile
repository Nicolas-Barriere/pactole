.PHONY: help setup dev stop restart logs clean test test.backend test.web db.reset db.migrate shell.backend shell.web shell.db

# ── Help ──────────────────────────────────────────────────

help: ## Show this help
	@grep -E '^[a-zA-Z_.-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Setup ─────────────────────────────────────────────────

setup: ## Build and start all services for the first time
	docker compose build
	docker compose up -d
	@echo ""
	@echo "✓ Moulax is starting up!"
	@echo "  Frontend:  http://localhost:3000"
	@echo "  Backend:   http://localhost:4000"
  @echo "  Database:  localhost:$${DB_PORT:-5434}"
	@echo ""
	@echo "Run 'make logs' to follow the logs."

# ── Development ───────────────────────────────────────────

dev: ## Start all services (build if needed)
	docker compose up -d --build
	@echo ""
	@echo "✓ Moulax is running!"
	@echo "  Frontend:  http://localhost:3000"
	@echo "  Backend:   http://localhost:4000"

dev.logs: ## Start all services with logs in foreground
	docker compose up --build

stop: ## Stop all services
	docker compose down

restart: ## Restart all services
	docker compose restart

logs: ## Follow logs from all services
	docker compose logs -f

logs.backend: ## Follow backend logs only
	docker compose logs -f backend

logs.web: ## Follow frontend logs only
	docker compose logs -f web

logs.db: ## Follow database logs only
	docker compose logs -f db

# ── Testing ───────────────────────────────────────────────

test: test.backend ## Run all tests

test.backend: ## Run backend (Elixir) tests
	docker compose exec backend mix test

test.web: ## Run frontend (Next.js) linter
	docker compose exec web pnpm lint

# ── Database ──────────────────────────────────────────────

db.reset: ## Drop, create, and migrate the database
	docker compose exec backend mix ecto.reset

db.migrate: ## Run pending database migrations
	docker compose exec backend mix ecto.migrate

db.seed: ## Run database seeds
	docker compose exec backend mix run priv/repo/seeds.exs

# ── Shells ────────────────────────────────────────────────

shell.backend: ## Open an IEx shell in the backend container
	docker compose exec backend iex -S mix

shell.web: ## Open a shell in the frontend container
	docker compose exec web sh

shell.db: ## Open psql in the database container
	docker compose exec db psql -U postgres -d moulax_dev

# ── Cleanup ───────────────────────────────────────────────

clean: ## Stop services and remove all volumes (fresh start)
	docker compose down -v
	@echo "✓ All containers and volumes removed."

.DEFAULT_GOAL := help
