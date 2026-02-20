defmodule Moulax.Tags.Tag do
  @moduledoc """
  Ecto schema for a tag (e.g. "Transport", "Alimentation").
  Transactions can have multiple tags via the transaction_tags join table.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :name, :color, :inserted_at, :updated_at]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tags" do
    field :name, :string
    field :color, :string

    timestamps()
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :color])
    |> validate_required([:name, :color])
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/)
    |> unique_constraint(:name, name: :categories_name_index)
  end
end
