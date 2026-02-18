defmodule MoulaxWeb.DashboardControllerTest do
  use MoulaxWeb.ConnCase, async: true

  alias Moulax.Accounts.Account
  alias Moulax.Transactions.Transaction
  alias Moulax.Categories.Category
  alias Moulax.Imports.Import
  alias Moulax.Repo

  # ---------------------------------------------------------------------------
  # GET /api/v1/dashboard/summary
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/dashboard/summary" do
    test "returns net worth and per-account balances", %{conn: conn} do
      a1 =
        insert_account(%{
          name: "Checking",
          bank: "boursorama",
          type: "checking",
          initial_balance: "100.00"
        })

      a2 =
        insert_account(%{
          name: "Savings",
          bank: "boursorama",
          type: "savings",
          initial_balance: "500.00"
        })

      insert_tx(a1.id, "2026-02-01", "Salary", "2500.00")
      insert_tx(a1.id, "2026-02-05", "Groceries", "-150.00")
      insert_tx(a2.id, "2026-02-01", "Transfer", "1000.00")

      insert_import(a1.id, "completed")

      data =
        conn
        |> get(~p"/api/v1/dashboard/summary")
        |> json_response(200)

      assert data["currency"] == "EUR"
      assert Decimal.equal?(Decimal.new(data["net_worth"]), Decimal.new("3950.00"))
      assert length(data["accounts"]) == 2

      checking = Enum.find(data["accounts"], &(&1["name"] == "Checking"))
      savings = Enum.find(data["accounts"], &(&1["name"] == "Savings"))

      assert Decimal.equal?(Decimal.new(checking["balance"]), Decimal.new("2450.00"))
      assert checking["bank"] == "boursorama"
      assert checking["type"] == "checking"
      assert checking["last_import_at"] != nil

      assert Decimal.equal?(Decimal.new(savings["balance"]), Decimal.new("1500.00"))
      assert savings["last_import_at"] == nil
    end

    test "excludes archived accounts", %{conn: conn} do
      _archived = insert_account(%{name: "Archived", archived: true, initial_balance: "9999.00"})
      active = insert_account(%{name: "Active"})
      insert_tx(active.id, "2026-02-01", "Deposit", "100.00")

      data =
        conn
        |> get(~p"/api/v1/dashboard/summary")
        |> json_response(200)

      assert length(data["accounts"]) == 1
      assert hd(data["accounts"])["name"] == "Active"
    end

    test "returns empty state when no accounts exist", %{conn: conn} do
      data =
        conn
        |> get(~p"/api/v1/dashboard/summary")
        |> json_response(200)

      assert Decimal.equal?(Decimal.new(data["net_worth"]), Decimal.new("0"))
      assert data["accounts"] == []
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/dashboard/spending
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/dashboard/spending" do
    test "returns spending breakdown by category for a month", %{conn: conn} do
      account = insert_account()
      food = insert_category("Alimentation", "#4CAF50")
      transport = insert_category("Transport", "#2196F3")

      insert_tx(account.id, "2026-02-01", "Salary", "2500.00")
      insert_tx(account.id, "2026-02-05", "Groceries", "-200.00", food.id)
      insert_tx(account.id, "2026-02-06", "Metro", "-50.00", transport.id)
      insert_tx(account.id, "2026-02-07", "Unknown shop", "-100.00")

      data =
        conn
        |> get("/api/v1/dashboard/spending?month=2026-02")
        |> json_response(200)

      assert data["month"] == "2026-02"
      assert Decimal.equal?(Decimal.new(data["total_income"]), Decimal.new("2500.00"))
      assert Decimal.equal?(Decimal.new(data["total_expenses"]), Decimal.new("-350.00"))

      categories = Enum.map(data["by_category"], & &1["category"])
      assert "Alimentation" in categories
      assert "Transport" in categories
      assert "Uncategorized" in categories

      total_pct =
        Enum.reduce(data["by_category"], 0.0, fn c, acc -> acc + c["percentage"] end)

      assert_in_delta total_pct, 100.0, 0.5
    end

    test "excludes archived accounts from spending", %{conn: conn} do
      archived = insert_account(%{name: "Archived", archived: true})
      active = insert_account(%{name: "Active"})

      insert_tx(archived.id, "2026-02-01", "Ghost", "-500.00")
      insert_tx(active.id, "2026-02-01", "Real", "-100.00")

      data =
        conn
        |> get("/api/v1/dashboard/spending?month=2026-02")
        |> json_response(200)

      assert Decimal.equal?(Decimal.new(data["total_expenses"]), Decimal.new("-100.00"))
    end

    test "returns empty state for month with no data", %{conn: conn} do
      data =
        conn
        |> get("/api/v1/dashboard/spending?month=2020-01")
        |> json_response(200)

      assert Decimal.equal?(Decimal.new(data["total_expenses"]), Decimal.new("0"))
      assert Decimal.equal?(Decimal.new(data["total_income"]), Decimal.new("0"))
      assert data["by_category"] == []
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/dashboard/trends
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/dashboard/trends" do
    test "returns monthly income vs expenses over multiple months", %{conn: conn} do
      account = insert_account()
      {this_y, this_m} = current_year_month()
      {prev_y, prev_m} = shift_month(this_y, this_m, -1)

      this_date = date_string(this_y, this_m, 15)
      prev_date = date_string(prev_y, prev_m, 15)

      insert_tx(account.id, prev_date, "Prev Salary", "2500.00")
      insert_tx(account.id, prev_date, "Prev Rent", "-850.00")
      insert_tx(account.id, this_date, "Curr Salary", "2500.00")
      insert_tx(account.id, this_date, "Curr Rent", "-900.00")

      data =
        conn
        |> get("/api/v1/dashboard/trends?months=2")
        |> json_response(200)

      assert length(data["months"]) == 2

      [current, previous] = data["months"]
      assert Decimal.equal?(Decimal.new(current["income"]), Decimal.new("2500.00"))
      assert Decimal.equal?(Decimal.new(current["expenses"]), Decimal.new("-900.00"))
      assert Decimal.equal?(Decimal.new(current["net"]), Decimal.new("1600.00"))

      assert Decimal.equal?(Decimal.new(previous["income"]), Decimal.new("2500.00"))
      assert Decimal.equal?(Decimal.new(previous["expenses"]), Decimal.new("-850.00"))
    end

    test "fills in zeros for months with no data", %{conn: conn} do
      _account = insert_account()

      data =
        conn
        |> get("/api/v1/dashboard/trends?months=3")
        |> json_response(200)

      assert length(data["months"]) == 3

      Enum.each(data["months"], fn m ->
        assert Decimal.equal?(Decimal.new(m["income"]), Decimal.new("0"))
        assert Decimal.equal?(Decimal.new(m["expenses"]), Decimal.new("0"))
        assert Decimal.equal?(Decimal.new(m["net"]), Decimal.new("0"))
      end)
    end

    test "excludes archived accounts from trends", %{conn: conn} do
      archived = insert_account(%{name: "Archived", archived: true})
      active = insert_account(%{name: "Active"})

      {y, m} = current_year_month()
      d = date_string(y, m, 10)

      insert_tx(archived.id, d, "Ghost income", "1000.00")
      insert_tx(active.id, d, "Real income", "500.00")

      data =
        conn
        |> get("/api/v1/dashboard/trends?months=1")
        |> json_response(200)

      [month] = data["months"]
      assert Decimal.equal?(Decimal.new(month["income"]), Decimal.new("500.00"))
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/dashboard/top-expenses
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/dashboard/top-expenses" do
    test "returns top N expenses ordered by amount for a month", %{conn: conn} do
      account = insert_account(%{name: "My Account"})
      housing = insert_category("Logement", "#FF5722")

      insert_tx(account.id, "2026-02-05", "LOYER", "-850.00", housing.id)
      insert_tx(account.id, "2026-02-10", "Groceries", "-200.00")
      insert_tx(account.id, "2026-02-15", "Metro", "-50.00")
      insert_tx(account.id, "2026-02-01", "Salary", "2500.00")

      data =
        conn
        |> get("/api/v1/dashboard/top-expenses?month=2026-02&limit=2")
        |> json_response(200)

      assert data["month"] == "2026-02"
      assert length(data["expenses"]) == 2

      [first, second] = data["expenses"]
      assert first["label"] == "LOYER"
      assert Decimal.equal?(Decimal.new(first["amount"]), Decimal.new("-850.00"))
      assert first["category"] == "Logement"
      assert first["account"] == "My Account"

      assert second["label"] == "Groceries"
      assert Decimal.equal?(Decimal.new(second["amount"]), Decimal.new("-200.00"))
      assert second["category"] == "Uncategorized"
    end

    test "returns empty expenses for month with no data", %{conn: conn} do
      data =
        conn
        |> get("/api/v1/dashboard/top-expenses?month=2020-01")
        |> json_response(200)

      assert data["expenses"] == []
    end

    test "excludes archived accounts from top expenses", %{conn: conn} do
      archived = insert_account(%{name: "Archived", archived: true})
      active = insert_account(%{name: "Active"})

      insert_tx(archived.id, "2026-02-01", "Ghost expense", "-999.00")
      insert_tx(active.id, "2026-02-01", "Real expense", "-100.00")

      data =
        conn
        |> get("/api/v1/dashboard/top-expenses?month=2026-02&limit=5")
        |> json_response(200)

      assert length(data["expenses"]) == 1
      assert hd(data["expenses"])["label"] == "Real expense"
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp insert_account(attrs \\ %{}) do
    defaults = %{name: "Test Account", bank: "test", type: "checking"}

    %Account{}
    |> Account.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_category(name, color) do
    %Category{name: name, color: color}
    |> Repo.insert!()
  end

  defp insert_tx(account_id, date_str, label, amount_str, category_id \\ nil) do
    %Transaction{}
    |> Transaction.changeset(%{
      account_id: account_id,
      date: Date.from_iso8601!(date_str),
      label: label,
      original_label: label,
      amount: Decimal.new(amount_str),
      source: "manual",
      category_id: category_id
    })
    |> Repo.insert!()
  end

  defp insert_import(account_id, status) do
    %Import{}
    |> Import.changeset(%{account_id: account_id, filename: "test.csv", status: status})
    |> Repo.insert!()
  end

  defp current_year_month do
    today = Date.utc_today()
    {today.year, today.month}
  end

  defp shift_month(year, month, offset) do
    total = year * 12 + (month - 1) + offset
    {Integer.floor_div(total, 12), Integer.mod(total, 12) + 1}
  end

  defp date_string(year, month, day) do
    Date.new!(year, month, day) |> Date.to_iso8601()
  end
end
