defmodule MoulaxWeb.ImportController do
  use MoulaxWeb, :controller

  alias Moulax.Imports
  alias Moulax.Accounts

  @doc """
  POST /api/v1/accounts/:account_id/imports — Upload CSV file (multipart).
  """
  def create(conn, %{"account_id" => account_id} = params) do
    with {:ok, _account} <- Accounts.fetch_account(account_id),
         {:ok, {filename, content}} <- extract_file(params),
         {:ok, import_record} <- Imports.create_import(account_id, filename),
         {:ok, result} <- Imports.process_import(import_record, content) do
      conn
      |> put_status(:created)
      |> json(result)
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Account not found"}})

      {:error, :no_file} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: %{detail: "No CSV file provided"}})

      {:error, %{status: "failed"} = result} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(result)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  @doc """
  GET /api/v1/imports/:id — Get import status & results.
  """
  def show(conn, %{"id" => id}) do
    case Imports.get_import(id) do
      {:ok, import_data} ->
        json(conn, import_data)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Not Found"}})
    end
  end

  @doc """
  POST /api/v1/imports/detect — Detect bank from CSV file without creating an import.
  """
  def detect(conn, params) do
    with {:ok, {_filename, content}} <- extract_file(params) do
      case Moulax.Parsers.detect_parser(content) do
        {:ok, parser} ->
          json(conn, %{data: %{detected_bank: parser.bank()}})

        :error ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{status: "failed", error_details: [%{message: "Unknown CSV format"}]})
      end
    else
      {:error, :no_file} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: %{detail: "No CSV file provided"}})
    end
  end

  @doc """
  GET /api/v1/accounts/:account_id/imports — List imports for account.
  """
  def index(conn, %{"account_id" => account_id}) do
    with {:ok, _account} <- Accounts.fetch_account(account_id) do
      imports = Imports.list_imports_for_account(account_id)
      json(conn, %{data: imports})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{errors: %{detail: "Account not found"}})
    end
  end

  defp extract_file(%{"file" => %Plug.Upload{filename: filename, path: path}}) do
    case File.read(path) do
      {:ok, content} -> {:ok, {filename, content}}
      {:error, _} -> {:error, :no_file}
    end
  end

  defp extract_file(_), do: {:error, :no_file}

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
