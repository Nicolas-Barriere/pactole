defmodule Moulax.Parsers.RevolutTest do
  use ExUnit.Case, async: true

  alias Moulax.Parsers.Revolut
  alias Moulax.Parsers.ParseError

  @fixtures_path Path.expand("../../fixtures", __DIR__)

  defp fixture(name), do: File.read!(Path.join(@fixtures_path, name))

  describe "detect?/1" do
    test "returns true for Revolut CSV" do
      assert Revolut.detect?(fixture("revolut_valid.csv"))
    end

    test "returns false for Boursorama CSV" do
      refute Revolut.detect?(fixture("boursorama_valid.csv"))
    end

    test "returns false for empty content" do
      refute Revolut.detect?("")
    end

    test "returns false for random text" do
      refute Revolut.detect?("hello,world\nfoo,bar")
    end
  end

  describe "parse/1" do
    test "parses a valid Revolut CSV" do
      assert {:ok, transactions} = Revolut.parse(fixture("revolut_valid.csv"))
      assert length(transactions) == 4

      [first | _] = transactions
      assert first.date == ~D[2026-02-10]
      assert first.label == "Uber"
      assert first.original_label == "Uber"
      assert first.amount == Decimal.new("-12.50")
      assert first.currency == "EUR"
    end

    test "preserves currency per row" do
      assert {:ok, transactions} = Revolut.parse(fixture("revolut_valid.csv"))
      usd_txn = Enum.find(transactions, &(&1.currency == "USD"))

      assert usd_txn.label == "Amazon"
      assert usd_txn.amount == Decimal.new("-29.99")
    end

    test "skips non-COMPLETED transactions" do
      assert {:ok, transactions} = Revolut.parse(fixture("revolut_with_pending.csv"))
      assert length(transactions) == 2

      labels = Enum.map(transactions, & &1.label)
      assert "Uber" in labels
      assert "Spotify" in labels
      refute "Restaurant" in labels
      refute "To John Doe" in labels
    end

    test "generates fee transactions for non-zero fees" do
      assert {:ok, transactions} = Revolut.parse(fixture("revolut_with_fees.csv"))
      assert length(transactions) == 3

      fee_txn = Enum.find(transactions, &(&1.label =~ "Fee:"))
      assert fee_txn.amount == Decimal.new("-1.50")
      assert fee_txn.label == "Fee: Exchanged to USD"
      assert fee_txn.currency == "EUR"
    end

    test "does not generate fee transaction when fee is zero" do
      assert {:ok, transactions} = Revolut.parse(fixture("revolut_valid.csv"))
      refute Enum.any?(transactions, &(&1.label =~ "Fee:"))
    end

    test "returns empty list for header-only CSV" do
      header =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance\n"

      assert {:ok, []} = Revolut.parse(header)
    end

    test "returns error for empty file" do
      assert {:error, [%ParseError{row: 0, message: "empty file"}]} = Revolut.parse("")
    end

    test "returns error for missing required columns" do
      assert {:error, [%ParseError{row: 0, message: message}]} =
               Revolut.parse(fixture("revolut_missing_columns.csv"))

      assert message =~ "missing required columns"
      assert message =~ "Completed Date"
      assert message =~ "Fee"
    end

    test "returns errors for invalid dates" do
      assert {:error, errors} = Revolut.parse(fixture("revolut_invalid_rows.csv"))
      date_error = Enum.find(errors, &(&1.message =~ "date"))
      assert date_error.row == 1
      assert date_error.message =~ "invalid date"
    end

    test "returns errors for invalid amounts" do
      assert {:error, errors} = Revolut.parse(fixture("revolut_invalid_rows.csv"))
      amount_error = Enum.find(errors, &(&1.message =~ "amount"))
      assert amount_error.row == 2
      assert amount_error.message =~ "invalid amount"
    end

    test "returns errors for missing descriptions" do
      assert {:error, errors} = Revolut.parse(fixture("revolut_invalid_rows.csv"))
      desc_error = Enum.find(errors, &(&1.message =~ "description"))
      assert desc_error.row == 3
      assert desc_error.message =~ "missing description"
    end

    test "handles UTF-8 BOM" do
      bom_content = "\uFEFF" <> fixture("revolut_valid.csv")
      assert {:ok, transactions} = Revolut.parse(bom_content)
      assert length(transactions) == 4
    end

    test "handles Windows-style line endings" do
      content = fixture("revolut_valid.csv") |> String.replace("\n", "\r\n")
      assert {:ok, transactions} = Revolut.parse(content)
      assert length(transactions) == 4
    end
  end
end
