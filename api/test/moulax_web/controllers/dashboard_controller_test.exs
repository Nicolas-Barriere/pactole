defmodule MoulaxWeb.DashboardControllerTest do
  use MoulaxWeb.ConnCase, async: true

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

      insert_transaction(%{
        account_id: a1.id,
        date: ~D[2026-02-01],
        label: "Salary",
        amount: Decimal.new("2500.00")
      })

      insert_transaction(%{
        account_id: a1.id,
        date: ~D[2026-02-05],
        label: "Groceries",
        amount: Decimal.new("-150.00")
      })

      insert_transaction(%{
        account_id: a2.id,
        date: ~D[2026-02-01],
        label: "Transfer",
        amount: Decimal.new("1000.00")
      })

      insert_import(%{account_id: a1.id, status: "completed"})

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

      insert_transaction(%{
        account_id: active.id,
        date: ~D[2026-02-01],
        label: "Deposit",
        amount: Decimal.new("100.00")
      })

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
    test "returns spending breakdown by tag for a month", %{conn: conn} do
      account = insert_account()
      food = insert_tag(%{name: "Alimentation", color: "#4CAF50"})
      transport = insert_tag(%{name: "Transport", color: "#2196F3"})

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Salary",
        amount: Decimal.new("2500.00")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-05],
        label: "Groceries",
        amount: Decimal.new("-200.00"),
        tag_ids: [food.id]
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-06],
        label: "Metro",
        amount: Decimal.new("-50.00"),
        tag_ids: [transport.id]
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-07],
        label: "Unknown shop",
        amount: Decimal.new("-100.00")
      })

      data =
        conn
        |> get("/api/v1/dashboard/spending?month=2026-02")
        |> json_response(200)

      assert data["month"] == "2026-02"
      assert Decimal.equal?(Decimal.new(data["total_income"]), Decimal.new("2500.00"))
      assert Decimal.equal?(Decimal.new(data["total_expenses"]), Decimal.new("-350.00"))

      tags = Enum.map(data["by_tag"], & &1["tag"])
      assert "Alimentation" in tags
      assert "Transport" in tags
      assert "Untagged" in tags
    end

    test "excludes archived accounts from spending", %{conn: conn} do
      archived = insert_account(%{name: "Archived", archived: true})
      active = insert_account(%{name: "Active"})

      insert_transaction(%{
        account_id: archived.id,
        date: ~D[2026-02-01],
        label: "Ghost",
        amount: Decimal.new("-500.00")
      })

      insert_transaction(%{
        account_id: active.id,
        date: ~D[2026-02-01],
        label: "Real",
        amount: Decimal.new("-100.00")
      })

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
      assert data["by_tag"] == []
    end

    test "uses current month when month is not provided", %{conn: conn} do
      account = insert_account()
      {year, month} = current_year_month()
      current_date = date_string(year, month, 10)

      insert_transaction(%{
        account_id: account.id,
        date: Date.from_iso8601!(current_date),
        label: "Current month expense",
        amount: Decimal.new("-42.00")
      })

      data =
        conn
        |> get("/api/v1/dashboard/spending")
        |> json_response(200)

      expected_month = "#{year}-#{String.pad_leading(Integer.to_string(month), 2, "0")}"
      assert data["month"] == expected_month
      assert Decimal.equal?(Decimal.new(data["total_expenses"]), Decimal.new("-42.00"))
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

      insert_transaction(%{
        account_id: account.id,
        date: Date.from_iso8601!(prev_date),
        label: "Prev Salary",
        amount: Decimal.new("2500.00")
      })

      insert_transaction(%{
        account_id: account.id,
        date: Date.from_iso8601!(prev_date),
        label: "Prev Rent",
        amount: Decimal.new("-850.00")
      })

      insert_transaction(%{
        account_id: account.id,
        date: Date.from_iso8601!(this_date),
        label: "Curr Salary",
        amount: Decimal.new("2500.00")
      })

      insert_transaction(%{
        account_id: account.id,
        date: Date.from_iso8601!(this_date),
        label: "Curr Rent",
        amount: Decimal.new("-900.00")
      })

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

      insert_transaction(%{
        account_id: archived.id,
        date: Date.from_iso8601!(d),
        label: "Ghost income",
        amount: Decimal.new("1000.00")
      })

      insert_transaction(%{
        account_id: active.id,
        date: Date.from_iso8601!(d),
        label: "Real income",
        amount: Decimal.new("500.00")
      })

      data =
        conn
        |> get("/api/v1/dashboard/trends?months=1")
        |> json_response(200)

      [month] = data["months"]
      assert Decimal.equal?(Decimal.new(month["income"]), Decimal.new("500.00"))
    end

    test "falls back to default month count for invalid months param", %{conn: conn} do
      data =
        conn
        |> get("/api/v1/dashboard/trends?months=not-a-number")
        |> json_response(200)

      assert length(data["months"]) == 12
    end

    test "accepts integer months when action is called directly", %{conn: conn} do
      data =
        conn
        |> MoulaxWeb.DashboardController.trends(%{"months" => 2})
        |> json_response(200)

      assert length(data["months"]) == 2
    end

    test "falls back for non-integer non-binary months when action is called directly", %{
      conn: conn
    } do
      data =
        conn
        |> MoulaxWeb.DashboardController.trends(%{"months" => %{}})
        |> json_response(200)

      assert length(data["months"]) == 12
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/dashboard/top-expenses
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/dashboard/top-expenses" do
    test "returns top N expenses ordered by amount for a month", %{conn: conn} do
      account = insert_account(%{name: "My Account"})
      housing = insert_tag(%{name: "Logement", color: "#FF5722"})

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-05],
        label: "LOYER",
        amount: Decimal.new("-850.00"),
        tag_ids: [housing.id]
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-10],
        label: "Groceries",
        amount: Decimal.new("-200.00")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-15],
        label: "Metro",
        amount: Decimal.new("-50.00")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Salary",
        amount: Decimal.new("2500.00")
      })

      data =
        conn
        |> get("/api/v1/dashboard/top-expenses?month=2026-02&limit=2")
        |> json_response(200)

      assert data["month"] == "2026-02"
      assert length(data["expenses"]) == 2

      [first, second] = data["expenses"]
      assert first["label"] == "LOYER"
      assert Decimal.equal?(Decimal.new(first["amount"]), Decimal.new("-850.00"))
      assert first["tags"] == ["Logement"]
      assert first["account"] == "My Account"

      assert second["label"] == "Groceries"
      assert Decimal.equal?(Decimal.new(second["amount"]), Decimal.new("-200.00"))
      assert second["tags"] == ["Untagged"]
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

      insert_transaction(%{
        account_id: archived.id,
        date: ~D[2026-02-01],
        label: "Ghost expense",
        amount: Decimal.new("-999.00")
      })

      insert_transaction(%{
        account_id: active.id,
        date: ~D[2026-02-01],
        label: "Real expense",
        amount: Decimal.new("-100.00")
      })

      data =
        conn
        |> get("/api/v1/dashboard/top-expenses?month=2026-02&limit=5")
        |> json_response(200)

      assert length(data["expenses"]) == 1
      assert hd(data["expenses"])["label"] == "Real expense"
    end

    test "uses defaults when month and limit are invalid or missing", %{conn: conn} do
      account = insert_account(%{name: "Defaults"})
      {year, month} = current_year_month()

      for day <- 1..6 do
        amount = Decimal.new("-#{day * 10}")

        insert_transaction(%{
          account_id: account.id,
          date: Date.from_iso8601!(date_string(year, month, day)),
          label: "Expense #{day}",
          amount: amount
        })
      end

      data =
        conn
        |> get("/api/v1/dashboard/top-expenses?limit=invalid")
        |> json_response(200)

      expected_month = "#{year}-#{String.pad_leading(Integer.to_string(month), 2, "0")}"
      assert data["month"] == expected_month
      assert length(data["expenses"]) == 5
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

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
