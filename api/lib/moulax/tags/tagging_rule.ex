defmodule Moulax.Tags.TaggingRule do
  @moduledoc """
  Ecto schema for a tagging rule (keyword -> tag).
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Moulax.Tags.Tag

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          keyword: String.t(),
          tag_id: Ecto.UUID.t(),
          priority: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tagging_rules" do
    field :keyword, :string
    field :priority, :integer

    belongs_to :tag, Tag

    timestamps()
  end

  @required_fields [:keyword, :tag_id]
  @optional_fields [:priority]

  @doc false
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:tag_id, name: :categorization_rules_category_id_fkey)
    |> put_priority_default()
  end

  defp put_priority_default(changeset) do
    case get_field(changeset, :priority) do
      nil -> put_change(changeset, :priority, 0)
      _ -> changeset
    end
  end
end
