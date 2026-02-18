defmodule Moulax.Imports do
  @moduledoc """
  Context for CSV imports: create import records, run the import pipeline
  (detect parser → parse → deduplicate → categorize → insert), and query imports.
  """
  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.Imports.Import
  alias Moulax.Parsers
  alias Moulax.Categories.Rules
  alias Moulax.Transactions.Transaction

  @doc """
  Creates an import record with status `pending`.
  """
  def create_import(account_id, filename) do
    %Import{}
    |> Import.changeset(%{account_id: account_id, filename: filename})
    |> Repo.insert()
  end

  @doc """
  Runs the full import pipeline:
  1. Detect parser from CSV content
  2. Parse CSV into normalized rows
  3. For each row: deduplicate, categorize, insert
  4. Update import record with counts and status

  Returns `{:ok, import_map}` or `{:error, reason}`.
  """
  def process_import(%Import{} = import_record, csv_content) when is_binary(csv_content) do
    import_record
    |> set_status("processing")
    |> run_pipeline(csv_content)
  end

  @doc """
  Gets an import by ID with formatted response.
  Returns `{:ok, import_map}` or `{:error, :not_found}`.
  """
  def get_import(id) do
    case Repo.get(Import, id) do
      nil -> {:error, :not_found}
      record -> {:ok, import_to_response(record)}
    end
  end

  @doc """
  Lists all imports for a given account, most recent first.
  """
  def list_imports_for_account(account_id) do
    Import
    |> where([i], i.account_id == ^account_id)
    |> order_by([i], desc: i.inserted_at)
    |> Repo.all()
    |> Enum.map(&import_to_response/1)
  end

  # -- Pipeline internals --

  defp set_status(import_record, status) do
    import_record
    |> Import.changeset(%{status: status})
    |> Repo.update!()
  end

  defp run_pipeline(import_record, csv_content) do
    with {:ok, parser} <- detect_parser(csv_content),
         {:ok, rows} <- parse_csv(parser, csv_content) do
      {imported, skipped, errored, error_details} =
        process_rows(import_record.account_id, rows)

      total = imported + skipped + errored

      updated =
        import_record
        |> Import.changeset(%{
          status: "completed",
          rows_total: total,
          rows_imported: imported,
          rows_skipped: skipped,
          rows_errored: errored,
          error_details: error_details
        })
        |> Repo.update!()

      {:ok, import_to_response(updated)}
    else
      {:error, :unknown_format} ->
        fail_import(import_record, "Unknown CSV format — no parser matched")

      {:error, parse_errors} when is_list(parse_errors) ->
        error_details =
          Enum.map(parse_errors, fn e -> %{"row" => e.row, "message" => e.message} end)

        fail_import(import_record, "CSV parsing failed", error_details)
    end
  end

  defp detect_parser(csv_content) do
    case Parsers.detect_parser(csv_content) do
      {:ok, parser} -> {:ok, parser}
      :error -> {:error, :unknown_format}
    end
  end

  defp parse_csv(parser, csv_content) do
    parser.parse(csv_content)
  end

  defp process_rows(account_id, rows) do
    rows
    |> Enum.with_index(2)
    |> Enum.reduce({0, 0, 0, []}, fn {row, row_index}, {imported, skipped, errored, errors} ->
      category_id = Rules.match_category(row.label)

      attrs = %{
        account_id: account_id,
        date: row.date,
        label: row.label,
        original_label: row.original_label,
        amount: row.amount,
        currency: row[:currency] || "EUR",
        bank_reference: row[:bank_reference],
        category_id: category_id,
        source: "csv_import"
      }

      case insert_transaction(attrs) do
        {:ok, _tx} ->
          {imported + 1, skipped, errored, errors}

        {:duplicate, _} ->
          {imported, skipped + 1, errored, errors}

        {:error, changeset} ->
          msg = changeset_error_message(changeset)
          detail = %{"row" => row_index, "message" => msg}
          {imported, skipped, errored + 1, errors ++ [detail]}
      end
    end)
  end

  defp insert_transaction(attrs) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, tx} ->
        {:ok, tx}

      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if duplicate_error?(errors) do
          {:duplicate, changeset}
        else
          {:error, changeset}
        end
    end
  end

  defp duplicate_error?(errors) do
    Enum.any?(errors, fn
      {_field, {_msg, [constraint: :unique, constraint_name: _]}} -> true
      _ -> false
    end)
  end

  defp fail_import(import_record, message, error_details \\ []) do
    updated =
      import_record
      |> Import.changeset(%{
        status: "failed",
        rows_total: 0,
        rows_imported: 0,
        rows_skipped: 0,
        rows_errored: 0,
        error_details: [%{"row" => 0, "message" => message} | error_details]
      })
      |> Repo.update!()

    {:error, import_to_response(updated)}
  end

  defp changeset_error_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end

  defp import_to_response(%Import{} = record) do
    %{
      id: record.id,
      account_id: record.account_id,
      filename: record.filename,
      status: record.status,
      rows_total: record.rows_total,
      rows_imported: record.rows_imported,
      rows_skipped: record.rows_skipped,
      rows_errored: record.rows_errored,
      error_details: record.error_details || [],
      inserted_at: format_datetime(record.inserted_at)
    }
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt) <> "Z"
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
