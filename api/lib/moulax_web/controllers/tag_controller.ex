defmodule MoulaxWeb.TagController do
  use MoulaxWeb, :controller

  alias Moulax.Tags
  alias Moulax.Tags.Tag

  @doc """
  GET /api/v1/tags — List all tags.
  """
  def index(conn, _params) do
    tags = Tags.list_tags()
    json(conn, tags)
  end

  @doc """
  POST /api/v1/tags — Create tag.
  """
  def create(conn, %{} = params) do
    case Tags.create_tag(params) do
      {:ok, %Tag{} = tag} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/v1/tags/#{tag.id}")
        |> json(tag)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  @doc """
  GET /api/v1/tags/:id — Get tag.
  """
  def show(conn, %{"id" => id}) do
    case Tags.get_tag(id) do
      {:ok, tag} ->
        json(conn, tag)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Not Found"}})
    end
  end

  @doc """
  PUT /api/v1/tags/:id — Update tag.
  """
  def update(conn, %{"id" => id} = params) do
    with {:ok, tag} <- Tags.get_tag(id),
         {:ok, %Tag{} = updated} <- Tags.update_tag(tag, params) do
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
  DELETE /api/v1/tags/:id — Delete tag.
  """
  def delete(conn, %{"id" => id}) do
    case Tags.get_tag(id) do
      {:ok, tag} ->
        {:ok, _} = Tags.delete_tag(tag)
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
