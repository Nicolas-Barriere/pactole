defmodule Moulax.Parsers.Revolut do
  @moduledoc """
  CSV parser for Revolut exports.

  Expected format: comma-separated with headers including
  `Type`, `Product`, `Started Date`, `Completed Date`, `Description`,
  `Amount`, `Fee`, `Currency`, `State`, `Balance`.

  Only rows with State = "COMPLETED" are imported.
  Non-zero fees generate an additional transaction.
  """

  @behaviour Moulax.Parsers.Parser

  alias Moulax.Parsers.ParseError

  @required_headers [
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

  defp split_row(line), do: String.split(line, ",")

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

      case field_at(fields, col_map, "State") do
        state when state in [nil, ""] ->
          {txns, errs}

        state ->
          if String.trim(state) == "COMPLETED" do
            case parse_row(fields, col_map, idx) do
              {:ok, new_txns} -> {new_txns ++ txns, errs}
              {:error, error} -> {txns, [error | errs]}
            end
          else
            {txns, errs}
          end
      end
    end)
    |> then(fn {txns, errs} -> {Enum.reverse(txns), Enum.reverse(errs)} end)
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
    trimmed = String.trim(date_str)

    date_part =
      case String.split(trimmed, " ", parts: 2) do
        [d, _time] -> d
        [d] -> d
      end

    case Date.from_iso8601(date_part) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, %ParseError{row: row_idx, message: "invalid date: #{date_str}"}}
    end
  end

  defp parse_amount(nil, row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing amount"}}

  defp parse_amount("", row_idx),
    do: {:error, %ParseError{row: row_idx, message: "missing amount"}}

  defp parse_amount(amount_str, row_idx) do
    case Decimal.parse(String.trim(amount_str)) do
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
    case Decimal.parse(String.trim(fee_str)) do
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
end
