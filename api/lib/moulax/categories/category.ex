defmodule Moulax.Categories.Category do
  @moduledoc """
  Ecto schema for a spending/income category.
  """
  use Ecto.Schema

  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :name, :color, :inserted_at, :updated_at]}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "categories" do
    field :name, :string
    field :color, :string

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :color])
    |> validate_required([:name, :color])
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/)
    |> unique_constraint(:name)
  end
end
