defmodule Moulax.Accounts.Account do
  @moduledoc """
  Ecto schema for a bank account.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          bank: String.t(),
          type: String.t(),
          initial_balance: Decimal.t(),
          currency: String.t(),
          archived: boolean(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "accounts" do
    field :name, :string
    field :bank, :string
    field :type, :string
    field :initial_balance, :decimal
    field :currency, :string
    field :archived, :boolean

    timestamps()
  end

  @required_fields [:name, :bank, :type]
  @optional_fields [:initial_balance, :currency, :archived]

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:type, ["checking", "savings", "brokerage", "crypto"])
    |> put_defaults()
  end

  defp put_defaults(changeset) do
    changeset
    |> put_change(:initial_balance, get_field(changeset, :initial_balance) || Decimal.new(0))
    |> put_change(:currency, get_field(changeset, :currency) || "EUR")
    |> put_change(:archived, get_field(changeset, :archived) || false)
  end
end
