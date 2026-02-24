defmodule MoulaxWeb.TransactionController do
  use MoulaxWeb, :controller

  alias Moulax.Transactions

  @doc """
  GET /api/v1/accounts/:account_id/transactions or GET /api/v1/transactions — List transactions (paginated, filterable).
  Nested route provides account_id from path; global route may pass account_id and other filters as query params.
  """
  def index(conn, params) do
    opts =
      Map.take(
        params,
        ~w(account_id import_id tag_id date_from date_to search page per_page sort_by sort_order)
      )

    result = Transactions.list_transactions(opts)
    json(conn, result)
  end

  @doc """
  GET /api/v1/transactions/:id — Get a single transaction.
  """
  def show(conn, %{"id" => id}) do
    case Transactions.get_transaction(id) do
      {:ok, transaction} ->
        json(conn, transaction)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Not Found"}})
    end
  end

  @doc """
  POST /api/v1/accounts/:account_id/transactions — Create manual transaction.
  Params: date, label, original_label (or use label), amount, optional currency, tag_ids, bank_reference.
  """
  def create(conn, %{"account_id" => account_id} = params) do
    attrs = map_create_params(params, account_id)
    tag_ids = params["tag_ids"] || []

    case Transactions.create_transaction(attrs) do
      {:ok, transaction} ->
        if tag_ids != [] do
          Transactions.set_transaction_tags(transaction.id, tag_ids)
        end

        {:ok, transaction} = Transactions.get_transaction(transaction.id)

        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/v1/transactions/#{transaction.id}")
        |> json(transaction)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  @doc """
  PUT /api/v1/transactions/:id — Update transaction (manual fields + tags).
  """
  def update(conn, %{"id" => id} = params) do
    attrs = map_update_params(params)
    tag_ids = params["tag_ids"]

    with {:ok, transaction} <- Transactions.fetch_transaction(id),
         :ok <- ensure_manual_editable(transaction, attrs),
         {:ok, _updated} <- Transactions.update_transaction(transaction, attrs),
         :ok <- maybe_set_tags(id, tag_ids) do
      {:ok, refreshed} = Transactions.get_transaction(id)
      json(conn, refreshed)
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Not Found"}})

      {:error, :invalid_tags} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{tag_ids: ["contain invalid tag IDs"]}})

      {:error, :manual_only} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{detail: "Only manual transactions can be edited"}})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  @doc """
  PATCH /api/v1/transactions/bulk-tag — Bulk assign tags to multiple transactions.
  Params: transaction_ids (array of UUIDs), tag_ids (array of tag UUIDs, empty to untag).
  """
  def bulk_tag(conn, params) do
    ids = params["transaction_ids"] || []
    tag_ids = params["tag_ids"] || []

    case Transactions.bulk_tag(ids, tag_ids) do
      {:ok, count} ->
        json(conn, %{updated_count: count})
    end
  end

  @doc """
  DELETE /api/v1/transactions/:id — Delete manual transaction.
  """
  def delete(conn, %{"id" => id}) do
    with {:ok, transaction} <- Transactions.fetch_transaction(id),
         :ok <- ensure_manual_deletable(transaction),
         {:ok, _transaction} <- Transactions.delete_transaction(transaction) do
      send_resp(conn, :no_content, "")
    else
      {:error, :manual_only} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{detail: "Only manual transactions can be deleted"}})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Not Found"}})
    end
  end

  defp maybe_set_tags(_id, nil), do: :ok

  defp maybe_set_tags(id, tag_ids) when is_list(tag_ids) do
    case Transactions.set_transaction_tags(id, tag_ids) do
      {:ok, _} -> :ok
      {:error, :invalid_tags} -> {:error, :invalid_tags}
    end
  end

  defp ensure_manual_editable(_transaction, attrs) when map_size(attrs) == 0, do: :ok
  defp ensure_manual_editable(%{source: "manual"}, _attrs), do: :ok
  defp ensure_manual_editable(_transaction, _attrs), do: {:error, :manual_only}

  defp ensure_manual_deletable(%{source: "manual"}), do: :ok
  defp ensure_manual_deletable(_transaction), do: {:error, :manual_only}

  defp map_create_params(params, account_id) do
    base =
      params
      |> Map.take(~w(date label original_label amount currency bank_reference))
      |> Map.reject(fn {_, v} -> v == nil or v == "" end)

    base
    |> Map.put("account_id", account_id)
    |> Map.put("source", "manual")
    |> Map.update("original_label", base["label"], & &1)
  end

  defp map_update_params(params) do
    params
    |> Map.take(~w(account_id date label amount currency bank_reference))
    |> Map.reject(fn {_, v} -> v == nil end)
    |> maybe_set_original_label()
  end

  defp maybe_set_original_label(%{"label" => label} = attrs), do: Map.put(attrs, "original_label", label)
  defp maybe_set_original_label(attrs), do: attrs

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
