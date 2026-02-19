defmodule Moulax.DashboardTest do
  use Moulax.DataCase, async: true

  alias Moulax.Dashboard

  describe "summary/0" do
    test "returns net worth and account data" do
      a1 =
        insert_account(%{
          name: "Checking",
          bank: "boursorama",
          type: "checking",
          initial_balance: "100.00"
        })

      insert_transaction(%{
        account_id: a1.id,
        date: ~D[2026-02-01],
        label: "Salary",
        amount: Decimal.new("2500.00")
      })

      result = Dashboard.summary()
      assert result.net_worth == "2600.00"
      assert result.currency == "EUR"
      assert length(result.accounts) == 1
    end
  end

  describe "spending/1" do
    test "calculates correct income and expenses" do
      account = insert_account()
      food = insert_category(%{name: "Food", color: "#000000"})

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-15],
        label: "Salary",
        amount: Decimal.new("1000.00")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-10],
        label: "Market",
        amount: Decimal.new("-300.00"),
        category_id: food.id
      })

      result = Dashboard.spending("2026-02")
      assert result.month == "2026-02"
      assert result.total_income == "1000.00"
      assert result.total_expenses == "-300.00"

      [cat] = result.by_category
      assert cat.category == "Food"
      assert cat.amount == "-300.00"
      assert cat.percentage == 100.0
    end
  end

  describe "trends/1" do
    test "returns monthly aggregated trends with zero fillings" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        date: Date.utc_today(),
        label: "Current month income",
        amount: Decimal.new("1500.00")
      })

      result = Dashboard.trends(2)
      assert length(result.months) == 2

      [current, prev] = result.months
      assert current.income == "1500.00"
      assert prev.income == "0"
    end
  end

  describe "top_expenses/2" do
    test "returns top expenses constrained by limit" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Small",
        amount: Decimal.new("-50.00")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-02],
        label: "Large",
        amount: Decimal.new("-500.00")
      })

      result = Dashboard.top_expenses("2026-02", 1)
      assert length(result.expenses) == 1
      assert hd(result.expenses).label == "Large"
    end
  end
end
