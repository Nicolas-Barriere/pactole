defmodule Moulax.Categories.Category do
  @moduledoc """
  Ecto schema for a spending category.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "categories" do
    field :name, :string
    field :color, :string

    timestamps()
  end
end
