defmodule MoulaxWeb.AccountController do
  use MoulaxWeb, :controller

  alias Moulax.Accounts
  alias Moulax.Accounts.Account

  @doc """
  GET /api/v1/accounts — List all (non-archived) accounts.
  """
  def index(conn, _params) do
    accounts = Accounts.list_accounts()
    json(conn, accounts)
  end

  @doc """
  POST /api/v1/accounts — Create account.
  """
  def create(conn, %{} = params) do
    case Accounts.create_account(params) do
      {:ok, %Account{} = account} ->
        {:ok, enriched} = Accounts.get_account(account.id)

        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/v1/accounts/#{account.id}")
        |> json(enriched)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  @doc """
  GET /api/v1/accounts/:id — Get account with computed balance.
  """
  def show(conn, %{"id" => id}) do
    case Accounts.get_account(id) do
      {:ok, account} ->
        json(conn, account)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Not Found"}})
    end
  end

  @doc """
  PUT /api/v1/accounts/:id — Update account.
  """
  def update(conn, %{"id" => id} = params) do
    with {:ok, account} <- Accounts.fetch_account(id),
         {:ok, %Account{} = updated} <- Accounts.update_account(account, params) do
      {:ok, enriched} = Accounts.get_account(updated.id)
      json(conn, enriched)
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
  DELETE /api/v1/accounts/:id — Archive account (soft delete).
  """
  def delete(conn, %{"id" => id}) do
    case Accounts.archive_account(id) do
      {:ok, _account} ->
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
