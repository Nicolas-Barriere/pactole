defmodule MoulaxWeb.CategorizationRuleController do
  use MoulaxWeb, :controller

  alias Moulax.Categories.Rules

  @doc """
  GET /api/v1/categorization-rules — List all rules (ordered by priority desc).
  """
  def index(conn, _params) do
    rules = Rules.list_rules()
    json(conn, rules)
  end

  @doc """
  POST /api/v1/categorization-rules — Create rule.
  Params: keyword, category_id, optional priority.
  """
  def create(conn, params) do
    attrs = map_params_to_attrs(params)

    case Rules.create_rule(attrs) do
      {:ok, rule} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/v1/categorization-rules/#{rule.id}")
        |> json(rule)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  @doc """
  PUT /api/v1/categorization-rules/:id — Update rule.
  """
  def update(conn, %{"id" => id} = params) do
    attrs = map_params_to_attrs(params)

    with {:ok, rule} <- Rules.fetch_rule(id),
         {:ok, updated} <- Rules.update_rule(rule, attrs) do
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
  DELETE /api/v1/categorization-rules/:id — Delete rule.
  """
  def delete(conn, %{"id" => id}) do
    case Rules.delete_rule(id) do
      {:ok, _rule} ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Not Found"}})
    end
  end

  defp map_params_to_attrs(params) do
    params
    |> Map.take(["keyword", "category_id", "priority"])
    |> Map.reject(fn {_, v} -> v == nil or v == "" end)
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
