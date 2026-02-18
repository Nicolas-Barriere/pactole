defmodule Moulax.Dashboard do
  @moduledoc """
  Context for dashboard aggregations: net worth, spending breakdown,
  monthly trends, and top expenses. All heavy lifting is done in SQL
  via GROUP BY / SUM — nothing aggregated in memory.
  """
  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.Accounts.Account
  alias Moulax.Transactions.Transaction
  alias Moulax.Categories.Category
  alias Moulax.Imports.Import

  # ---------------------------------------------------------------------------
  # Summary
  # ---------------------------------------------------------------------------

  @doc """
  Returns net worth (sum of all non-archived account balances) and per-account
  balance / last-import metadata.
  """
  def summary do
    accounts =
      from(a in Account, where: a.archived == false, order_by: [asc: a.name])
      |> Repo.all()

    account_ids = Enum.map(accounts, & &1.id)

    balance_sums =
      from(t in Transaction,
        where: t.account_id in ^account_ids,
        group_by: t.account_id,
        select: {t.account_id, sum(t.amount)}
      )
      |> Repo.all()
      |> Map.new()

    last_imports =
      from(i in Import,
        where: i.account_id in ^account_ids and i.status == "completed",
        group_by: i.account_id,
        select: {i.account_id, max(i.inserted_at)}
      )
      |> Repo.all()
      |> Map.new()

    account_data =
      Enum.map(accounts, fn account ->
        tx_sum = Map.get(balance_sums, account.id) || Decimal.new(0)
        initial = account.initial_balance || Decimal.new(0)
        balance = Decimal.add(initial, tx_sum)
        last_import = Map.get(last_imports, account.id)

        %{
          id: account.id,
          name: account.name,
          bank: account.bank,
          type: account.type,
          balance: format_decimal(balance),
          last_import_at: format_datetime(last_import)
        }
      end)

    net_worth =
      Enum.reduce(account_data, Decimal.new(0), fn a, acc ->
        Decimal.add(acc, Decimal.new(a.balance))
      end)

    %{
      net_worth: format_decimal(net_worth),
      currency: "EUR",
      accounts: account_data
    }
  end

  # ---------------------------------------------------------------------------
  # Spending breakdown
  # ---------------------------------------------------------------------------

  @doc """
  Returns income, expense totals and per-category expense breakdown for a
  given month (format `"YYYY-MM"`).
  """
  def spending(month_str) do
    {date_from, date_to} = month_range(month_str)
    account_ids = non_archived_account_ids()

    total_expenses =
      from(t in Transaction,
        where:
          t.account_id in ^account_ids and
            t.date >= ^date_from and t.date <= ^date_to and t.amount < 0,
        select: sum(t.amount)
      )
      |> Repo.one() || Decimal.new(0)

    total_income =
      from(t in Transaction,
        where:
          t.account_id in ^account_ids and
            t.date >= ^date_from and t.date <= ^date_to and t.amount > 0,
        select: sum(t.amount)
      )
      |> Repo.one() || Decimal.new(0)

    by_category_raw =
      from(t in Transaction,
        left_join: c in Category,
        on: t.category_id == c.id,
        where:
          t.account_id in ^account_ids and
            t.date >= ^date_from and t.date <= ^date_to and t.amount < 0,
        group_by: [c.id, c.name, c.color],
        select: %{category: c.name, color: c.color, amount: sum(t.amount)},
        order_by: [asc: sum(t.amount)]
      )
      |> Repo.all()

    abs_total = Decimal.abs(total_expenses)

    by_category =
      Enum.map(by_category_raw, fn cat ->
        pct =
          if Decimal.eq?(abs_total, Decimal.new(0)) do
            0.0
          else
            Decimal.div(Decimal.abs(cat.amount), abs_total)
            |> Decimal.mult(100)
            |> Decimal.to_float()
            |> Float.round(1)
          end

        %{
          category: cat.category || "Uncategorized",
          color: cat.color || "#9E9E9E",
          amount: format_decimal(cat.amount),
          percentage: pct
        }
      end)

    %{
      month: month_str,
      total_expenses: format_decimal(total_expenses),
      total_income: format_decimal(total_income),
      by_category: by_category
    }
  end

  # ---------------------------------------------------------------------------
  # Trends
  # ---------------------------------------------------------------------------

  @doc """
  Returns monthly income vs expenses for the last `months_count` months
  (most recent first). Months with no transactions are filled in with zeros.
  """
  def trends(months_count) do
    today = Date.utc_today()
    month_list = generate_months(today, months_count)
    start_date = earliest_month_start(today, months_count)
    account_ids = non_archived_account_ids()

    raw =
      from(t in Transaction,
        where: t.account_id in ^account_ids and t.date >= ^start_date,
        group_by: fragment("to_char(?, 'YYYY-MM')", t.date),
        select: %{
          month: fragment("to_char(?, 'YYYY-MM')", t.date),
          income: sum(fragment("CASE WHEN ? > 0 THEN ? ELSE 0 END", t.amount, t.amount)),
          expenses: sum(fragment("CASE WHEN ? < 0 THEN ? ELSE 0 END", t.amount, t.amount))
        },
        order_by: [desc: fragment("to_char(?, 'YYYY-MM')", t.date)]
      )
      |> Repo.all()

    raw_map = Map.new(raw, &{&1.month, &1})

    months =
      Enum.map(month_list, fn m ->
        data = Map.get(raw_map, m, %{income: nil, expenses: nil})
        income = data.income || Decimal.new(0)
        expenses = data.expenses || Decimal.new(0)
        net = Decimal.add(income, expenses)

        %{
          month: m,
          income: format_decimal(income),
          expenses: format_decimal(expenses),
          net: format_decimal(net)
        }
      end)

    %{months: months}
  end

  # ---------------------------------------------------------------------------
  # Top expenses
  # ---------------------------------------------------------------------------

  @doc """
  Returns the `limit` largest expenses (most negative) for a given month.
  """
  def top_expenses(month_str, limit) do
    {date_from, date_to} = month_range(month_str)
    account_ids = non_archived_account_ids()

    expenses =
      from(t in Transaction,
        join: a in Account,
        on: t.account_id == a.id,
        left_join: c in Category,
        on: t.category_id == c.id,
        where:
          t.account_id in ^account_ids and
            t.date >= ^date_from and t.date <= ^date_to and t.amount < 0,
        order_by: [asc: t.amount],
        limit: ^limit,
        select: %{
          id: t.id,
          date: t.date,
          label: t.label,
          amount: t.amount,
          category: c.name,
          account: a.name
        }
      )
      |> Repo.all()
      |> Enum.map(fn e ->
        %{
          id: e.id,
          date: Date.to_iso8601(e.date),
          label: e.label,
          amount: format_decimal(e.amount),
          category: e.category || "Uncategorized",
          account: e.account
        }
      end)

    %{month: month_str, expenses: expenses}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp non_archived_account_ids do
    from(a in Account, where: a.archived == false, select: a.id)
    |> Repo.all()
  end

  defp month_range(month_str) do
    [year_str, m_str] = String.split(month_str, "-")
    year = String.to_integer(year_str)
    month = String.to_integer(m_str)
    date_from = Date.new!(year, month, 1)
    date_to = Date.new!(year, month, Date.days_in_month(date_from))
    {date_from, date_to}
  end

  defp generate_months(today, count) do
    for i <- 0..(count - 1) do
      d = shift_months_date(today, -i)
      month_string(d)
    end
  end

  defp earliest_month_start(today, count) do
    d = shift_months_date(today, -(count - 1))
    Date.new!(d.year, d.month, 1)
  end

  defp shift_months_date(date, offset) do
    total = date.year * 12 + (date.month - 1) + offset
    year = Integer.floor_div(total, 12)
    month = Integer.mod(total, 12) + 1
    Date.new!(year, month, 1)
  end

  defp month_string(date) do
    m = date.month |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{date.year}-#{m}"
  end

  defp format_decimal(nil), do: "0"
  defp format_decimal(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp format_decimal(other), do: to_string(other)

  defp format_datetime(nil), do: nil
  defp format_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt) <> "Z"
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
