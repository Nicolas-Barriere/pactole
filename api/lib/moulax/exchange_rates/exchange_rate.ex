defmodule Moulax.ExchangeRates.ExchangeRate do
  @moduledoc """
  Ecto schema for currency exchange rates persisted with EUR as pivot.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          from_currency: String.t(),
          to_currency: String.t(),
          rate: Decimal.t(),
          fetched_at: NaiveDateTime.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "exchange_rates" do
    field :from_currency, :string
    field :to_currency, :string
    field :rate, :decimal
    field :fetched_at, :naive_datetime

    timestamps()
  end

  @required_fields [:from_currency, :to_currency, :rate, :fetched_at]

  @doc false
  def changeset(exchange_rate, attrs) do
    exchange_rate
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:from_currency, :to_currency])
  end
end
