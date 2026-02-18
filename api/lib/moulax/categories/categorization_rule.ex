defmodule Moulax.Categories.CategorizationRule do
  @moduledoc """
  Ecto schema for a categorization rule (keyword → category).
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Moulax.Categories.Category

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          keyword: String.t(),
          category_id: Ecto.UUID.t(),
          priority: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "categorization_rules" do
    field :keyword, :string
    field :priority, :integer

    belongs_to :category, Category

    timestamps()
  end

  @required_fields [:keyword, :category_id]
  @optional_fields [:priority]

  @doc false
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:category_id)
    |> put_priority_default()
  end

  defp put_priority_default(changeset) do
    case get_field(changeset, :priority) do
      nil -> put_change(changeset, :priority, 0)
      _ -> changeset
    end
  end
end
