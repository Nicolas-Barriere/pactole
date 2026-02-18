defmodule Moulax.Accounts do
  @moduledoc """
  Context for managing bank accounts. Implements `Moulax.Accounts.Behaviour`.
  """
  @behaviour Moulax.Accounts.Behaviour

  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.Accounts.Account

  @doc """
  Returns all non-archived accounts with computed balance, transaction_count, and last_import_at.
  """
  def list_accounts do
    Account
    |> where([a], a.archived == false)
    |> order_by([a], asc: a.name)
    |> Repo.all()
    |> Enum.map(&enrich_account/1)
  end

  @doc """
  Gets a single account by ID with computed balance, transaction_count, and last_import_at.

  Returns `{:ok, account_map}` or `{:error, :not_found}`.
  """
  def get_account(id) do
    case Repo.get(Account, id) do
      nil -> {:error, :not_found}
      account -> {:ok, enrich_account(account)}
    end
  end

  @doc """
  Fetches a single account struct by ID (for update/archive). Returns `{:ok, account}` or `{:error, :not_found}`.
  """
  def fetch_account(id) do
    case Repo.get(Account, id) do
      nil -> {:error, :not_found}
      account -> {:ok, account}
    end
  end

  @doc """
  Creates a new account.
  """
  def create_account(attrs \\ %{}) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an account.
  """
  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Archives an account (soft delete). Sets `archived: true`.
  Accepts either an `%Account{}` struct or an ID string. Returns `{:ok, account}` or `{:error, :not_found}` when called with an ID.
  """
  def archive_account(%Account{} = account) do
    account
    |> Account.changeset(%{archived: true})
    |> Repo.update()
  end

  def archive_account(id) when is_binary(id) do
    case Repo.get(Account, id) do
      nil -> {:error, :not_found}
      account -> archive_account(account)
    end
  end

  defp enrich_account(account) do
    balance = compute_balance(account)
    tx_count = transaction_count(account.id)
    last_import = last_import_at(account.id)

    %{
      id: account.id,
      name: account.name,
      bank: account.bank,
      type: account.type,
      initial_balance: format_decimal(account.initial_balance),
      currency: account.currency,
      balance: format_decimal(balance),
      transaction_count: tx_count,
      last_import_at: format_datetime(last_import),
      archived: account.archived
    }
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt) <> "Z"
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp compute_balance(account) do
    sum =
      from(t in "transactions",
        where: t.account_id == type(^account.id, :binary_id),
        select: sum(t.amount)
      )
      |> Repo.one()

    initial = account.initial_balance || Decimal.new(0)
    sum_decimal = sum || Decimal.new(0)
    Decimal.add(initial, sum_decimal)
  end

  defp transaction_count(account_id) do
    from(t in "transactions",
      where: t.account_id == type(^account_id, :binary_id),
      select: count()
    )
    |> Repo.one()
  end

  defp last_import_at(account_id) do
    from(i in "imports",
      where: i.account_id == type(^account_id, :binary_id) and i.status == "completed",
      order_by: [desc: i.inserted_at],
      limit: 1,
      select: i.inserted_at
    )
    |> Repo.one()
  end

  defp format_decimal(nil), do: "0.00"
  defp format_decimal(%Decimal{} = d), do: Decimal.to_string(d, :normal)
  defp format_decimal(other), do: to_string(other)
end
