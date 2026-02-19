defmodule Moulax.Parsers.CaisseDepargne do
  @moduledoc """
  CSV parser for Caisse d'Épargne exports.

  Expected format: semicolon-separated with headers including
  `Date`, `Numéro d'opération`, `Libellé`, `Débit`, `Crédit`, `Détail`.

  Date format is DD/MM/YYYY. Amount is determined by Débit (negative)
  or Crédit (positive) columns. The `Numéro d'opération` is stored as
  `bank_reference` for deduplication.
  """

  @behaviour Moulax.Parsers.Parser

  alias Moulax.Parsers.ParseError

  @required_headers ["Date", "Numéro d'opération", "Libellé", "Débit", "Crédit"]

  @impl true
  def bank, do: "caisse_depargne"

  @impl true
  def detect?(content) when is_binary(content) do
    case first_line(content) do
      nil ->
        false

      line ->
        headers = split_row(line)
        Enum.all?(@required_headers, fn h -> Enum.any?(headers, &(String.trim(&1) == h)) end)
    end
  end

  @impl true
  def parse(content) when is_binary(content) do
    content = normalize_encoding(content)

    case String.split(content, ~r/\r?\n/, trim: true) do
      [] ->
        {:error, [%ParseError{row: 0, message: "empty file"}]}

      [_header_only] ->
        {:ok, []}

      [header | rows] ->
        headers = split_row(header)
        col_map = column_index_map(headers)

        case validate_headers(col_map) do
          :ok ->
            {transactions, errors} = parse_rows(rows, col_map)

            if errors == [] do
              {:ok, transactions}
            else
              {:error, errors}
            end

          {:error, missing} ->
            message = "missing required columns: #{Enum.join(missing, ", ")}"
            {:error, [%ParseError{row: 0, message: message}]}
        end
    end
  end

  @doc """
  Strips common Caisse d'Épargne prefixes from transaction labels.

  Removes patterns like "CARTE DD/MM", "VIR SEPA", "VIREMENT SEPA".
  """
  def clean_label(label) do
    label
    |> String.replace(~r/^CARTE \d{2}\/\d{2}\s*/, "")
    |> String.replace(~r/^VIR(EMENT)? SEPA\s*/i, "")
    |> String.trim()
  end

  defp first_line(content) do
    content
    |> String.split(~r/\r?\n/, parts: 2, trim: true)
    |> List.first()
  end

  defp split_row(line), do: String.split(line, ";")

  defp column_index_map(headers) do
    headers
    |> Enum.map(&String.trim/1)
    |> Enum.with_index()
    |> Map.new()
  end

  defp validate_headers(col_map) do
    missing = Enum.reject(@required_headers, &Map.has_key?(col_map, &1))

    if missing == [], do: :ok, else: {:error, missing}
  end

  defp parse_rows(rows, col_map) do
    rows
    |> Enum.with_index(1)
    |> Enum.reject(fn {row, _idx} -> String.trim(row) == "" end)
    |> Enum.reduce({[], []}, fn {row, idx}, {txns, errs} ->
      fields = split_row(row)

      case parse_row(fields, col_map, idx) do
        {:ok, txn} -> {[txn | txns], errs}
        {:error, error} -> {txns, [error | errs]}
      end
    end)
    |> then(fn {txns, errs} -> {Enum.reverse(txns), Enum.reverse(errs)} end)
  end

  defp parse_row(fields, col_map, row_idx) do
    with {:ok, date} <- parse_date(field_at(fields, col_map, "Date"), row_idx),
         {:ok, amount} <- parse_amount(fields, col_map, row_idx),
         {:ok, original_label} <- parse_label(field_at(fields, col_map, "Libellé"), row_idx) do
      bank_ref = field_at(fields, col_map, "Numéro d'opération")

      {:ok,
       %{
         date: date,
         amount: amount,
         original_label: original_label,
         label: clean_label(original_label),
         currency: "EUR",
         bank_reference: if(bank_ref, do: String.trim(bank_ref))
       }}
    end
  end

  defp field_at(fields, col_map, name) do
    case Map.get(col_map, name) do
      nil -> nil
      idx -> Enum.at(fields, idx)
    end
  end

  defp parse_date(nil, row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing date"}}

  defp parse_date("", row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing date"}}

  defp parse_date(date_str, row_idx) do
    trimmed = String.trim(date_str)

    case Regex.run(~r/^(\d{2})\/(\d{2})\/(\d{4})$/, trimmed) do
      [_, day, month, year] ->
        case Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day)) do
          {:ok, date} -> {:ok, date}
          {:error, _} -> {:error, %ParseError{row: row_idx, message: "invalid date: #{date_str}"}}
        end

      nil ->
        {:error, %ParseError{row: row_idx, message: "invalid date: #{date_str}"}}
    end
  end

  defp parse_amount(fields, col_map, row_idx) do
    debit = field_at(fields, col_map, "Débit") |> to_string() |> String.trim()
    credit = field_at(fields, col_map, "Crédit") |> to_string() |> String.trim()

    cond do
      debit != "" -> parse_decimal(debit, :debit, row_idx)
      credit != "" -> parse_decimal(credit, :credit, row_idx)
      true -> {:error, %ParseError{row: row_idx, message: "missing amount"}}
    end
  end

  defp parse_decimal(str, direction, row_idx) do
    normalized =
      str
      |> String.replace(~r/\s+/, "")
      |> String.replace(",", ".")
      |> String.replace("+", "")

    case Decimal.parse(normalized) do
      {decimal, ""} ->
        amount =
          case direction do
            :debit -> if Decimal.positive?(decimal), do: Decimal.negate(decimal), else: decimal
            :credit -> Decimal.abs(decimal)
          end

        {:ok, amount}

      _ ->
        {:error, %ParseError{row: row_idx, message: "invalid amount: #{str}"}}
    end
  end

  defp parse_label(nil, row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing label"}}

  defp parse_label("", row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing label"}}

  defp parse_label(label, _row_idx),
    do: {:ok, String.trim(label)}

  defp normalize_encoding(content) do
    if String.valid?(content) do
      String.replace_prefix(content, "\uFEFF", "")
    else
      content
      |> :binary.bin_to_list()
      |> Enum.map(fn byte -> <<byte::utf8>> end)
      |> IO.iodata_to_binary()
    end
  end
end
