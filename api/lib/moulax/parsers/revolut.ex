defmodule Moulax.Parsers.Revolut do
  @moduledoc """
  Parser for Revolut CSV and XLSX exports.

  Expected format: headers including `Type`, `Product`, `Started Date`,
  `Completed Date`, `Description`, `Amount`, `Fee`, `Currency`, `State`, `Balance`.

  Supports both English and French (fr-fr) localized exports.
  Only completed rows (State = "COMPLETED" or État = "TERMINÉ") are imported.
  Non-zero fees generate an additional transaction.
  """

  @behaviour Moulax.Parsers.Parser

  alias Moulax.Parsers.ParseError
  alias Moulax.Parsers.Xlsx

  @canonical_headers [
    "Type",
    "Product",
    "Started Date",
    "Completed Date",
    "Description",
    "Amount",
    "Fee",
    "Currency",
    "State",
    "Balance"
  ]

  @impl true
  def bank, do: "revolut"

  @fr_to_en %{
    "Produit" => "Product",
    "Date de début" => "Started Date",
    "Date de fin" => "Completed Date",
    "Montant" => "Amount",
    "Frais" => "Fee",
    "Devise" => "Currency",
    "État" => "State",
    "Solde" => "Balance"
  }

  @completed_states ~w(COMPLETED TERMINÉ)

  @impl true
  def detect?(content) when is_binary(content) do
    if Xlsx.xlsx?(content) do
      detect_xlsx(content)
    else
      detect_csv(content)
    end
  end

  @impl true
  def parse(content) when is_binary(content) do
    if Xlsx.xlsx?(content) do
      parse_xlsx(content)
    else
      parse_csv(content)
    end
  end

  defp detect_csv(content) do
    case first_line(content) do
      nil ->
        false

      line ->
        headers =
          line
          |> split_row()
          |> Enum.map(&normalize_header/1)

        Enum.all?(@canonical_headers, &(&1 in headers))
    end
  end

  defp detect_xlsx(content) do
    case Xlsx.rows(content) do
      {:ok, [header | _rows]} ->
        headers = Enum.map(header, &normalize_header/1)
        Enum.all?(@canonical_headers, &(&1 in headers))

      _ ->
        false
    end
  end

  defp parse_csv(content) do
    content = normalize_encoding(content)

    case String.split(content, ~r/\r?\n/, trim: true) do
      [] ->
        {:error, [%ParseError{row: 0, message: "empty file"}]}

      [header | rows] ->
        parse_rows_with_header(split_row(header), rows, &split_row/1)
    end
  end

  defp parse_xlsx(content) do
    case Xlsx.rows(content) do
      {:ok, []} ->
        {:error, [%ParseError{row: 0, message: "empty file"}]}

      {:ok, [header | rows]} ->
        parse_rows_with_header(header, rows, &normalize_xlsx_row/1)

      :error ->
        {:error, [%ParseError{row: 0, message: "empty file"}]}
    end
  end

  defp parse_rows_with_header(headers, rows, row_to_fields) do
    col_map = column_index_map(headers)

    case validate_headers(col_map) do
      :ok ->
        {transactions, errors} = parse_rows(rows, col_map, row_to_fields)

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

  defp first_line(content) do
    content
    |> String.split(~r/\r?\n/, parts: 2, trim: true)
    |> List.first()
  end

  defp split_row(line), do: String.split(line, ",")

  defp normalize_header(header) do
    trimmed =
      header
      |> normalize_text()
      |> String.trim()

    mapped =
      case header_token(trimmed) do
        "type" -> "Type"
        "product" -> "Product"
        "produit" -> "Product"
        "starteddate" -> "Started Date"
        "datededebut" -> "Started Date"
        "completeddate" -> "Completed Date"
        "datedefin" -> "Completed Date"
        "description" -> "Description"
        "amount" -> "Amount"
        "montant" -> "Amount"
        "fee" -> "Fee"
        "frais" -> "Fee"
        "currency" -> "Currency"
        "devise" -> "Currency"
        "state" -> "State"
        "etat" -> "State"
        "tat" -> "State"
        "balance" -> "Balance"
        "solde" -> "Balance"
        _ -> trimmed
      end

    Map.get(@fr_to_en, mapped, mapped)
  end

  defp column_index_map(headers) do
    headers
    |> Enum.map(&normalize_header/1)
    |> Enum.with_index()
    |> Map.new()
  end

  defp validate_headers(col_map) do
    missing = Enum.reject(@canonical_headers, &Map.has_key?(col_map, &1))

    if missing == [], do: :ok, else: {:error, missing}
  end

  defp parse_rows(rows, col_map, row_to_fields) do
    rows
    |> Enum.with_index(1)
    |> Enum.reduce({[], []}, fn {row, idx}, {txns, errs} ->
      fields = row_to_fields.(row)

      if row_empty?(fields) do
        {txns, errs}
      else
        case field_at(fields, col_map, "State") do
          state when state in [nil, ""] ->
            {txns, errs}

          state ->
            if completed_state?(state) do
              case parse_row(fields, col_map, idx) do
                {:ok, new_txns} -> {new_txns ++ txns, errs}
                {:error, error} -> {txns, [error | errs]}
              end
            else
              {txns, errs}
            end
        end
      end
    end)
    |> then(fn {txns, errs} -> {Enum.reverse(txns), Enum.reverse(errs)} end)
  end

  defp normalize_xlsx_row(fields) when is_list(fields) do
    Enum.map(fields, fn
      nil -> ""
      value when is_binary(value) -> value
      value -> to_string(value)
    end)
  end

  defp row_empty?(fields) do
    Enum.all?(fields, &(String.trim(&1) == ""))
  end

  defp parse_row(fields, col_map, row_idx) do
    with {:ok, date} <- parse_date(field_at(fields, col_map, "Completed Date"), row_idx),
         {:ok, amount} <- parse_amount(field_at(fields, col_map, "Amount"), row_idx),
         {:ok, label} <- parse_label(field_at(fields, col_map, "Description"), row_idx),
         {:ok, currency} <- parse_currency(field_at(fields, col_map, "Currency"), row_idx),
         {:ok, fee} <- parse_fee(field_at(fields, col_map, "Fee"), row_idx) do
      main = %{
        date: date,
        amount: amount,
        original_label: label,
        label: label,
        currency: currency
      }

      if Decimal.compare(fee, Decimal.new("0")) != :eq do
        fee_txn = %{
          date: date,
          amount: Decimal.negate(Decimal.abs(fee)),
          original_label: "Fee: #{label}",
          label: "Fee: #{label}",
          currency: currency
        }

        {:ok, [main, fee_txn]}
      else
        {:ok, [main]}
      end
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
    trimmed =
      date_str
      |> normalize_text()
      |> String.trim()

    date_part =
      case String.split(trimmed, " ", parts: 2) do
        [d, _time] -> d
        [d] -> d
      end

    case Date.from_iso8601(date_part) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> parse_excel_date(trimmed, row_idx, date_str)
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
      {decimal, ""} -> {:ok, decimal}
      :error -> {:error, %ParseError{row: row_idx, message: "invalid amount: #{amount_str}"}}
      _ -> {:error, %ParseError{row: row_idx, message: "invalid amount: #{amount_str}"}}
    end
  end

  defp parse_label(nil, row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing description"}}

  defp parse_label("", row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing description"}}

  defp parse_label(label, _row_idx),
    do: {:ok, String.trim(label)}

  defp parse_currency(nil, row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing currency"}}

  defp parse_currency("", row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing currency"}}

  defp parse_currency(currency, _row_idx),
    do: {:ok, String.trim(currency)}

  defp parse_fee(nil, _row_idx), do: {:ok, Decimal.new("0")}
  defp parse_fee("", _row_idx), do: {:ok, Decimal.new("0")}

  defp parse_fee(fee_str, row_idx) do
    normalized =
      fee_str
      |> String.trim()
      |> String.replace(~r/\s+/, "")
      |> String.replace(",", ".")

    case Decimal.parse(normalized) do
      {decimal, ""} -> {:ok, decimal}
      :error -> {:error, %ParseError{row: row_idx, message: "invalid fee: #{fee_str}"}}
      _ -> {:error, %ParseError{row: row_idx, message: "invalid fee: #{fee_str}"}}
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

  defp parse_excel_date(value, row_idx, original) do
    case Float.parse(value) do
      {serial, ""} ->
        days = trunc(serial)
        {:ok, Date.add(~D[1899-12-30], days)}

      _ ->
        {:error, %ParseError{row: row_idx, message: "invalid date: #{original}"}}
    end
  end

  defp completed_state?(state) do
    normalized =
      state
      |> normalize_text()
      |> String.trim()

    normalized in @completed_states or header_token(normalized) in ["completed", "termine", "termin"]
  end

  defp normalize_text(value) when is_binary(value) do
    value
    |> then(fn text ->
      Regex.replace(~r/_x([0-9A-Fa-f]{4})_/, text, fn _, hex ->
      codepoint = String.to_integer(hex, 16)
      if codepoint < 32, do: "", else: <<codepoint::utf8>>
      end)
    end)
    |> String.replace("Ã©", "é")
    |> String.replace("Ã¨", "è")
    |> String.replace("Ãª", "ê")
    |> String.replace("Ã«", "ë")
    |> String.replace("Ã ", "à")
    |> String.replace("Ã¢", "â")
    |> String.replace("Ã¹", "ù")
    |> String.replace("Ã»", "û")
    |> String.replace("Ã§", "ç")
    |> String.replace("Ã‰", "É")
    |> String.replace("Â", "")
  end

  defp header_token(value) do
    value
    |> String.downcase()
    |> String.replace("é", "e")
    |> String.replace("è", "e")
    |> String.replace("ê", "e")
    |> String.replace("ë", "e")
    |> String.replace("à", "a")
    |> String.replace("â", "a")
    |> String.replace("ù", "u")
    |> String.replace("û", "u")
    |> String.replace("î", "i")
    |> String.replace("ï", "i")
    |> String.replace("ô", "o")
    |> String.replace("ç", "c")
    |> String.replace(~r/[^a-z0-9]/u, "")
  end
end
