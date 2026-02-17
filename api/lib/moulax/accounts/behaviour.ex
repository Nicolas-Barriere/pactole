defmodule Moulax.Accounts.Behaviour do
  @moduledoc """
  Behaviour for the Accounts context. Implement this to provide account CRUD and listing,
  e.g. for production (Ecto/Repo) or testing (in-memory/fake).
  """
  alias Moulax.Accounts.Account

  @type account_id :: String.t()
  @type account_map :: %{
          id: String.t(),
          name: String.t(),
          bank: String.t(),
          type: String.t(),
          initial_balance: String.t(),
          currency: String.t(),
          balance: String.t(),
          transaction_count: non_neg_integer(),
          last_import_at: DateTime.t() | nil,
          archived: boolean()
        }

  @doc "Returns all non-archived accounts with computed balance, transaction_count, and last_import_at."
  @callback list_accounts() :: [account_map()]

  @doc "Returns a single account by ID with computed balance, or :not_found."
  @callback get_account(account_id()) :: {:ok, account_map()} | {:error, :not_found}

  @doc "Fetches a single account struct by ID (for update/archive)."
  @callback fetch_account(account_id()) :: {:ok, %Account{}} | {:error, :not_found}

  @doc "Creates a new account."
  @callback create_account(attrs :: map()) ::
          {:ok, %Account{}} | {:error, Ecto.Changeset.t()}

  @doc "Updates an account."
  @callback update_account(%Account{}, attrs :: map()) ::
          {:ok, %Account{}} | {:error, Ecto.Changeset.t()}

  @doc "Archives an account (soft delete). Accepts struct or ID."
  @callback archive_account(%Account{} | account_id()) ::
          {:ok, %Account{}} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
end
