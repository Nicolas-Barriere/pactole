defmodule Moulax.Transactions.Transaction do
  @moduledoc """
  Ecto schema for a transaction (bank or manual).
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Moulax.Accounts.Account
  alias Moulax.Currencies
  alias Moulax.Imports.Import
  alias Moulax.Tags.Tag

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          account_id: Ecto.UUID.t(),
          date: Date.t(),
          label: String.t(),
          original_label: String.t(),
          amount: Decimal.t(),
          currency: String.t(),
          bank_reference: String.t() | nil,
          source: String.t(),
          import_id: Ecto.UUID.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field :date, :date
    field :label, :string
    field :original_label, :string
    field :amount, :decimal
    field :currency, :string
    field :bank_reference, :string
    field :source, :string

    belongs_to :account, Account
    belongs_to :import, Import
    many_to_many :tags, Tag, join_through: "transaction_tags"

    timestamps()
  end

  @required_fields [:account_id, :date, :label, :original_label, :amount, :source]
  @optional_fields [:currency, :bank_reference, :import_id]

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:source, ["csv_import", "manual"])
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:import_id)
    |> unique_constraint([:account_id, :date, :amount, :original_label],
      name: :transactions_account_date_amount_original_label_index
    )
    |> put_currency_default()
    |> validate_inclusion(:currency, Currencies.codes())
  end

  defp put_currency_default(changeset) do
    case get_field(changeset, :currency) do
      nil -> put_change(changeset, :currency, "EUR")
      "" -> put_change(changeset, :currency, "EUR")
      _ -> changeset
    end
  end
end
