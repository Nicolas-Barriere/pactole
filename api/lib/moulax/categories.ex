defmodule Moulax.Categories do
  @moduledoc """
  Context for managing spending/income categories.
  """

  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.Categories.Category

  @doc """
  Returns all categories ordered by name.
  """
  def list_categories do
    Category
    |> order_by(asc: :name)
    |> Repo.all()
  end

  @doc """
  Gets a single category by ID.

  Returns `{:ok, category}` or `{:error, :not_found}`.
  """
  def get_category(id) do
    case Repo.get(Category, id) do
      nil -> {:error, :not_found}
      category -> {:ok, category}
    end
  end

  @doc """
  Creates a new category.
  """
  def create_category(attrs \\ %{}) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a category.
  """
  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a category. Nullifies `category_id` on associated transactions first.
  """
  def delete_category(%Category{} = category) do
    Repo.transaction(fn ->
      from(t in "transactions",
        where: t.category_id == type(^category.id, :binary_id)
      )
      |> Repo.update_all(set: [category_id: nil])

      Repo.delete!(category)
    end)
  end
end
