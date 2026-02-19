defmodule Moulax.Parsers.Boursorama do
  @moduledoc """
  CSV parser for Boursorama / BoursoBank exports.

  Expected format: semicolon-separated with headers including
  `dateOp`, `dateVal`, `label`, `amount`, among others.
  Fields may be quoted with double quotes.

  Supports both legacy Boursorama exports and the newer BoursoBank format
  which uses `"Supplier | Raw description"` labels.
  """

  @behaviour Moulax.Parsers.Parser

  alias Moulax.Parsers.ParseError

  @required_headers ~w(dateOp dateVal label amount)

  @impl true
  def bank, do: "boursorama"

  @impl true
  def detect?(content) when is_binary(content) do
    case first_line(content) do
      nil ->
        false

      line ->
        headers = split_row(line)
        Enum.all?(@required_headers, &(&1 in headers))
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

  defp first_line(content) do
    content
    |> String.split(~r/\r?\n/, parts: 2, trim: true)
    |> List.first()
  end

  defp split_row(line) do
    line
    |> String.split(";")
    |> Enum.map(&strip_quotes/1)
  end

  defp strip_quotes("\"" <> rest), do: String.trim_trailing(rest, "\"")
  defp strip_quotes(field), do: field

  defp column_index_map(headers) do
    headers
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
    with {:ok, date} <- parse_date(field_at(fields, col_map, "dateOp"), row_idx),
         {:ok, amount} <- parse_amount(field_at(fields, col_map, "amount"), row_idx),
         {:ok, original_label} <- parse_label(field_at(fields, col_map, "label"), row_idx) do
      {:ok,
       %{
         date: date,
         amount: amount,
         original_label: original_label,
         label: clean_label(original_label),
         currency: "EUR"
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
    case Date.from_iso8601(String.trim(date_str)) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, %ParseError{row: row_idx, message: "invalid date: #{date_str}"}}
    end
  end

  defp parse_amount(nil, row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing amount"}}

  defp parse_amount("", row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing amount"}}

  defp parse_amount(amount_str, row_idx) do
    normalized =
      amount_str
      |> String.trim()
      |> String.replace(~r/\s+/, "")
      |> String.replace(",", ".")

    case Decimal.parse(normalized) do
      {decimal, ""} ->
        {:ok, decimal}

      :error ->
        {:error, %ParseError{row: row_idx, message: "invalid amount: #{amount_str}"}}

      _ ->
        {:error, %ParseError{row: row_idx, message: "invalid amount: #{amount_str}"}}
    end
  end

  defp parse_label(nil, row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing label"}}

  defp parse_label("", row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing label"}}

  defp parse_label(label, _row_idx),
    do: {:ok, String.trim(label)}

  @doc """
  Extracts a clean merchant/supplier name from transaction labels.

  For BoursoBank format (`"Supplier | Raw description"`), returns the supplier part.
  For legacy Boursorama format, strips prefixes like "CARTE DD/MM", "VIR SEPA",
  and suffixes like "CB*XXXX".
  """
  def clean_label(label) do
    case String.split(label, " | ", parts: 2) do
      [supplier, _raw] ->
        String.trim(supplier)

      [single] ->
        single
        |> String.replace(~r/^CARTE \d{2}\/\d{2}(\/\d{2})?\s*/, "")
        |> String.replace(~r/^VIR(EMENT)? SEPA\s*/i, "")
        |> String.replace(~r/\s+CB\*\d+\s*$/, "")
        |> String.trim()
    end
  end

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
