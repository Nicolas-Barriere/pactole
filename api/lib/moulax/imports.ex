defmodule Moulax.Imports do
  @moduledoc """
  Context for CSV imports: create import records, run the import pipeline
  (detect parser -> parse -> deduplicate -> tag -> insert), and query imports.
  """
  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.Imports.Import
  alias Moulax.Parsers
  alias Moulax.Tags.Tag
  alias Moulax.Tags.Rules
  alias Moulax.Tags.TransactionTag
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
  3. For each row: deduplicate, tag, insert
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
      {imported, skipped, errored, error_details, row_details} =
        process_rows(import_record.account_id, import_record.id, rows)

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

      response = import_to_response(updated) |> Map.put(:row_details, row_details)
      {:ok, response}
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

  defp process_rows(account_id, import_id, rows) do
    tag_names = load_tag_names()

    {imported, skipped, errored, errors_rev, details_rev} =
      rows
      |> Enum.with_index(2)
      |> Enum.reduce({0, 0, 0, [], []}, fn {row, row_index},
                                           {imported, skipped, errored, errors, details} ->
        tag_ids = Rules.match_tags(row.label)

        attrs = %{
          account_id: account_id,
          import_id: import_id,
          date: row.date,
          label: row.label,
          original_label: row.original_label,
          amount: row.amount,
          currency: row[:currency] || "EUR",
          bank_reference: row[:bank_reference],
          source: "csv_import"
        }

        tag_label =
          case tag_ids do
            [] -> nil
            ids -> ids |> Enum.map(&tag_names[&1]) |> Enum.reject(&is_nil/1) |> Enum.join(", ")
          end

        base_detail = %{
          "row" => row_index,
          "date" => to_string(row.date),
          "label" => row.label,
          "amount" => to_string(row.amount),
          "tags" => tag_label
        }

        case insert_transaction(attrs) do
          {:ok, tx} ->
            if tag_ids != [] do
              insert_transaction_tags(tx.id, tag_ids)
            end

            detail = Map.put(base_detail, "status", "added")
            {imported + 1, skipped, errored, errors, [detail | details]}

          {:duplicate, _} ->
            detail = Map.put(base_detail, "status", "skipped")
            {imported, skipped + 1, errored, errors, [detail | details]}

          {:error, changeset} ->
            msg = changeset_error_message(changeset)
            error = %{"row" => row_index, "message" => msg}
            detail = base_detail |> Map.put("status", "error") |> Map.put("error", msg)
            {imported, skipped, errored + 1, [error | errors], [detail | details]}
        end
      end)

    {imported, skipped, errored, Enum.reverse(errors_rev), Enum.reverse(details_rev)}
  end

  defp load_tag_names do
    Tag
    |> Repo.all()
    |> Map.new(fn tag -> {tag.id, tag.name} end)
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

  defp insert_transaction_tags(transaction_id, tag_ids) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    entries =
      tag_ids
      |> Enum.uniq()
      |> Enum.map(fn tag_id ->
        %{
          id: Ecto.UUID.generate(),
          transaction_id: transaction_id,
          tag_id: tag_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(TransactionTag, entries)
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
