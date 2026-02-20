defmodule Moulax.Transactions do
  @moduledoc """
  Context for transactions: list (paginated, filterable, searchable), CRUD, and bulk tag.
  """
  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.Transactions.Transaction
  alias Moulax.Accounts.Account
  alias Moulax.Tags.Tag
  alias Moulax.Tags.TransactionTag

  @default_per_page 50
  @default_sort_by "date"
  @default_sort_order "desc"

  @doc """
  Returns paginated transactions with optional filters.

  Options (all optional):
  - `account_id` — filter by account UUID
  - `tag_id` — filter by tag UUID; use `"untagged"` to filter transactions with no tags
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
      |> preload([:account, :tags])
      |> apply_filter_account(opts)
      |> apply_filter_tag(opts)
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

  defp apply_filter_tag(query, opts) do
    case opts["tag_id"] || opts[:tag_id] do
      "untagged" ->
        from(t in query,
          left_join: tt in TransactionTag,
          on: tt.transaction_id == t.id,
          where: is_nil(tt.id)
        )

      nil ->
        query

      id when is_binary(id) ->
        from(t in query,
          join: tt in TransactionTag,
          on: tt.transaction_id == t.id,
          where: tt.tag_id == ^id
        )
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
        escaped =
          term
          |> String.replace("\\", "\\\\")
          |> String.replace("%", "\\%")
          |> String.replace("_", "\\_")

        pattern = "%#{escaped}%"
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
    case Repo.get(Transaction, id) |> Repo.preload([:account, :tags]) do
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
      {:ok, tx} -> {:ok, transaction_to_response(Repo.preload(tx, [:account, :tags]))}
      error -> error
    end
  end

  @doc """
  Updates a transaction (e.g. label). Returns `{:ok, transaction_map}` or `{:error, changeset}`.
  """
  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, tx} -> {:ok, transaction_to_response(Repo.preload(tx, [:account, :tags]))}
      error -> error
    end
  end

  @doc """
  Sets the tags for a transaction (replaces existing tags).
  """
  def set_transaction_tags(transaction_id, tag_ids) when is_list(tag_ids) do
    valid_tag_ids =
      tag_ids
      |> Enum.uniq()
      |> then(fn ids ->
        from(t in Tag, where: t.id in ^ids, select: t.id) |> Repo.all()
      end)

    if tag_ids != [] && valid_tag_ids == [] do
      {:error, :invalid_tags}
    else
      Repo.transaction(fn ->
        from(tt in TransactionTag, where: tt.transaction_id == ^transaction_id)
        |> Repo.delete_all()

        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        entries =
          Enum.map(valid_tag_ids, fn tag_id ->
            %{
              id: Ecto.UUID.generate(),
              transaction_id: transaction_id,
              tag_id: tag_id,
              inserted_at: now,
              updated_at: now
            }
          end)

        if entries != [] do
          Repo.insert_all(TransactionTag, entries)
        end
      end)
    end
  end

  @doc """
  Bulk assign tags to multiple transactions by IDs.
  Given a list of transaction IDs and tag_ids, sets those tags on all transactions.
  Returns `{:ok, updated_count}`.
  """
  def bulk_tag(transaction_ids, tag_ids) when is_list(transaction_ids) and is_list(tag_ids) do
    ids = Enum.filter(transaction_ids, &is_binary/1)

    if ids == [] do
      {:ok, 0}
    else
      Repo.transaction(fn ->
        from(tt in TransactionTag, where: tt.transaction_id in ^ids)
        |> Repo.delete_all()

        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        unique_tag_ids = Enum.uniq(tag_ids)

        entries =
          for tx_id <- ids, tag_id <- unique_tag_ids do
            %{
              id: Ecto.UUID.generate(),
              transaction_id: tx_id,
              tag_id: tag_id,
              inserted_at: now,
              updated_at: now
            }
          end

        if entries != [] do
          Repo.insert_all(TransactionTag, entries)
        end

        length(ids)
      end)
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
      tags: Enum.map(tx.tags, &tag_ref/1),
      bank_reference: tx.bank_reference,
      source: tx.source
    }
  end

  defp account_ref(nil), do: nil
  defp account_ref(%Account{} = a), do: %{id: a.id, name: a.name, bank: a.bank, type: a.type}

  defp tag_ref(%Tag{} = t), do: %{id: t.id, name: t.name, color: t.color}

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
