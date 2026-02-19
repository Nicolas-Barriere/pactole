defmodule Moulax.Transactions do
  @moduledoc """
  Context for transactions: list (paginated, filterable, searchable), CRUD, and bulk categorize.
  """
  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.Transactions.Transaction
  alias Moulax.Accounts.Account
  alias Moulax.Categories.Category

  @default_per_page 50
  @default_sort_by "date"
  @default_sort_order "desc"

  @doc """
  Returns paginated transactions with optional filters.

  Options (all optional):
  - `account_id` — filter by account UUID
  - `category_id` — filter by category UUID; use `"uncategorized"` (string) to filter where category_id is nil
  - `date_from` — filter date >= (Date or ISO date string)
  - `date_to` — filter date <= (Date or ISO date string)
  - `search` — case-insensitive substring search on label
  - `page` — page number (default 1)
  - `per_page` — page size (default 50)
  - `sort_by` — "date" | "amount" | "label" (default "date")
  - `sort_order` — "asc" | "desc" (default "desc")

  Returns `%{data: [transaction_map, ...], meta: %{page, per_page, total_count, total_pages}}`.
  """
  def list_transactions(opts \\ []) do
    per_page = min(to_int(opts["per_page"] || opts[:per_page], @default_per_page), 100)
    page = max(to_int(opts["page"] || opts[:page], 1), 1)
    sort_by = opts["sort_by"] || opts[:sort_by] || @default_sort_by
    sort_order = opts["sort_order"] || opts[:sort_order] || @default_sort_order

    base =
      Transaction
      |> preload([:account, :category])
      |> apply_filter_account(opts)
      |> apply_filter_category(opts)
      |> apply_filter_date_from(opts)
      |> apply_filter_date_to(opts)
      |> apply_filter_search(opts)
      |> apply_sort(sort_by, sort_order)

    total_count = Repo.aggregate(base, :count)

    data =
      base
      |> offset(^((page - 1) * per_page))
      |> limit(^per_page)
      |> Repo.all()
      |> Enum.map(&transaction_to_response/1)

    total_pages = ceil(total_count / per_page)

    %{
      data: data,
      meta: %{
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages
      }
    }
  end

  defp apply_filter_account(query, opts) do
    case opts["account_id"] || opts[:account_id] do
      nil -> query
      id -> where(query, [t], t.account_id == ^id)
    end
  end

  defp apply_filter_category(query, opts) do
    case opts["category_id"] || opts[:category_id] do
      "uncategorized" ->
        where(query, [t], is_nil(t.category_id))

      nil ->
        query

      id when is_binary(id) ->
        where(query, [t], t.category_id == ^id)
    end
  end

  defp apply_filter_date_from(query, opts) do
    case opts["date_from"] || opts[:date_from] do
      nil ->
        query

      %Date{} = d ->
        where(query, [t], t.date >= ^d)

      str when is_binary(str) ->
        case Date.from_iso8601(str) do
          {:ok, d} -> where(query, [t], t.date >= ^d)
          _ -> query
        end
    end
  end

  defp apply_filter_date_to(query, opts) do
    case opts["date_to"] || opts[:date_to] do
      nil ->
        query

      %Date{} = d ->
        where(query, [t], t.date <= ^d)

      str when is_binary(str) ->
        case Date.from_iso8601(str) do
          {:ok, d} -> where(query, [t], t.date <= ^d)
          _ -> query
        end
    end
  end

  defp apply_filter_search(query, opts) do
    case opts["search"] || opts[:search] do
      nil ->
        query

      "" ->
        query

      term ->
        pattern = "%#{String.replace(term, "%", "\\%")}%"
        where(query, [t], ilike(t.label, ^pattern))
    end
  end

  defp apply_sort(query, "amount", "asc"), do: order_by(query, [t], asc: t.amount)
  defp apply_sort(query, "amount", _), do: order_by(query, [t], desc: t.amount)
  defp apply_sort(query, "label", "asc"), do: order_by(query, [t], asc: t.label)
  defp apply_sort(query, "label", _), do: order_by(query, [t], desc: t.label)
  defp apply_sort(query, _sort_by, "asc"), do: order_by(query, [t], asc: t.date)
  defp apply_sort(query, _sort_by, _), do: order_by(query, [t], desc: t.date)

  @doc """
  Fetches a single transaction by ID. Returns `{:ok, transaction_map}` or `{:error, :not_found}`.
  """
  def get_transaction(id) do
    case Repo.get(Transaction, id) |> Repo.preload([:account, :category]) do
      nil -> {:error, :not_found}
      tx -> {:ok, transaction_to_response(tx)}
    end
  end

  @doc """
  Fetches a single transaction struct by ID (for update/delete). Returns `{:ok, transaction}` or `{:error, :not_found}`.
  """
  def fetch_transaction(id) do
    case Repo.get(Transaction, id) do
      nil -> {:error, :not_found}
      tx -> {:ok, tx}
    end
  end

  @doc """
  Creates a transaction. For manual entry, pass source: "manual".
  Returns `{:ok, transaction_map}` or `{:error, changeset}`.
  """
  def create_transaction(attrs) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, tx} -> {:ok, transaction_to_response(Repo.preload(tx, [:account, :category]))}
      error -> error
    end
  end

  @doc """
  Updates a transaction (e.g. category_id, label). Returns `{:ok, transaction_map}` or `{:error, changeset}`.
  """
  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, tx} -> {:ok, transaction_to_response(Repo.preload(tx, [:account, :category]))}
      error -> error
    end
  end

  @doc """
  Deletes a transaction. Returns `{:ok, transaction}` or `{:error, :not_found}`.
  """
  def delete_transaction(id) when is_binary(id) do
    case Repo.get(Transaction, id) do
      nil -> {:error, :not_found}
      tx -> Repo.delete(tx)
    end
  end

  def delete_transaction(%Transaction{} = transaction) do
    Repo.delete(transaction)
  end

  @doc """
  Bulk assign category to multiple transactions by IDs.
  Given a list of transaction IDs and a category_id, updates all those transactions.
  Returns `{:ok, updated_count}` or `{:error, reason}`.
  """
  def bulk_categorize(transaction_ids, category_id) when is_list(transaction_ids) do
    ids = Enum.filter(transaction_ids, &is_binary/1)

    if ids == [] do
      {:ok, 0}
    else
      # Allow nil category_id to uncategorize
      query = from t in Transaction, where: t.id in ^ids

      {count, _} =
        Repo.update_all(query,
          set: [
            category_id: category_id,
            updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
          ]
        )

      {:ok, count}
    end
  end

  defp transaction_to_response(%Transaction{} = tx) do
    %{
      id: tx.id,
      account_id: tx.account_id,
      account: account_ref(tx.account),
      date: Date.to_iso8601(tx.date),
      label: tx.label,
      original_label: tx.original_label,
      amount: format_decimal(tx.amount),
      currency: tx.currency,
      category_id: tx.category_id,
      category: category_ref(tx.category),
      bank_reference: tx.bank_reference,
      source: tx.source
    }
  end

  defp account_ref(nil), do: nil
  defp account_ref(%Account{} = a), do: %{id: a.id, name: a.name, bank: a.bank, type: a.type}

  defp category_ref(nil), do: nil
  defp category_ref(%Category{} = c), do: %{id: c.id, name: c.name, color: c.color}

  defp format_decimal(nil), do: nil
  defp format_decimal(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp format_decimal(other), do: to_string(other)

  defp to_int(val, _default) when is_integer(val), do: val

  defp to_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp to_int(_, default), do: default
end
