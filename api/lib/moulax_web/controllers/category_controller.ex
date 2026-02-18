defmodule MoulaxWeb.CategoryController do
  use MoulaxWeb, :controller

  alias Moulax.Categories
  alias Moulax.Categories.Category

  @doc """
  GET /api/v1/categories — List all categories.
  """
  def index(conn, _params) do
    categories = Categories.list_categories()
    json(conn, categories)
  end

  @doc """
  POST /api/v1/categories — Create category.
  """
  def create(conn, %{} = params) do
    case Categories.create_category(params) do
      {:ok, %Category{} = category} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/v1/categories/#{category.id}")
        |> json(category)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  @doc """
  GET /api/v1/categories/:id — Get category.
  """
  def show(conn, %{"id" => id}) do
    case Categories.get_category(id) do
      {:ok, category} ->
        json(conn, category)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Not Found"}})
    end
  end

  @doc """
  PUT /api/v1/categories/:id — Update category.
  """
  def update(conn, %{"id" => id} = params) do
    with {:ok, category} <- Categories.get_category(id),
         {:ok, %Category{} = updated} <- Categories.update_category(category, params) do
      json(conn, updated)
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Not Found"}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  @doc """
  DELETE /api/v1/categories/:id — Delete category.
  """
  def delete(conn, %{"id" => id}) do
    case Categories.get_category(id) do
      {:ok, category} ->
        {:ok, _} = Categories.delete_category(category)
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Not Found"}})
    end
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
