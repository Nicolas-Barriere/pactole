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

    test "returns true for French-locale Revolut CSV" do
      assert Revolut.detect?(fixture("revolut_fr_valid.csv"))
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

    test "skips rows when state is empty" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,0.00,EUR,,100.00\n"

      assert {:ok, []} = Revolut.parse(csv)
    end

    test "skips rows when duplicate state header points to missing field" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance,State\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,0.00,EUR,COMPLETED,100.00\n"

      assert {:ok, []} = Revolut.parse(csv)
    end

    test "returns missing date when duplicate completed-date header points to missing field" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance,Completed Date\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,0.00,EUR,COMPLETED,100.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing date"}]} = Revolut.parse(csv)
    end

    test "returns missing date when completed date is empty" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance\n" <>
          "CARD,Current,2026-02-10 10:00:00,,Coffee,-3.50,0.00,EUR,COMPLETED,100.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing date"}]} = Revolut.parse(csv)
    end

    test "returns missing amount when amount is empty" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,,0.00,EUR,COMPLETED,100.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing amount"}]} = Revolut.parse(csv)
    end

    test "returns missing amount when duplicate amount header points to missing field" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance,Amount\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,0.00,EUR,COMPLETED,100.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing amount"}]} = Revolut.parse(csv)
    end

    test "returns invalid amount when amount has trailing garbage" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50abc,0.00,EUR,COMPLETED,100.00\n"

      assert {:error, [%ParseError{row: 1, message: message}]} = Revolut.parse(csv)
      assert message =~ "invalid amount"
    end

    test "returns missing description when duplicate description header points to missing field" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance,Description\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,0.00,EUR,COMPLETED,100.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing description"}]} = Revolut.parse(csv)
    end

    test "returns missing currency when currency is empty" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,0.00,,COMPLETED,100.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing currency"}]} = Revolut.parse(csv)
    end

    test "returns missing currency when duplicate currency header points to missing field" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance,Currency\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,0.00,EUR,COMPLETED,100.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing currency"}]} = Revolut.parse(csv)
    end

    test "treats empty fee as zero" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,,EUR,COMPLETED,100.00\n"

      assert {:ok, [txn]} = Revolut.parse(csv)
      assert txn.label == "Coffee"
      assert txn.amount == Decimal.new("-3.50")
    end

    test "treats missing fee as zero when duplicate fee header points to missing field" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance,Fee\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,0.00,EUR,COMPLETED,100.00\n"

      assert {:ok, [txn]} = Revolut.parse(csv)
      assert txn.label == "Coffee"
      assert txn.amount == Decimal.new("-3.50")
    end

    test "returns invalid fee for non-numeric fee" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,oops,EUR,COMPLETED,100.00\n"

      assert {:error, [%ParseError{row: 1, message: message}]} = Revolut.parse(csv)
      assert message =~ "invalid fee"
    end

    test "returns invalid fee when fee has trailing garbage" do
      csv =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,Coffee,-3.50,1.5oops,EUR,COMPLETED,100.00\n"

      assert {:error, [%ParseError{row: 1, message: message}]} = Revolut.parse(csv)
      assert message =~ "invalid fee"
    end

    test "handles Latin-1 encoded content" do
      latin1 =
        "Type,Product,Started Date,Completed Date,Description,Amount,Fee,Currency,State,Balance\n" <>
          "CARD,Current,2026-02-10 10:00:00,2026-02-10 10:01:00,CAF\xE9,-3.50,0.00,EUR,COMPLETED,100.00\n"

      assert {:ok, [txn]} = Revolut.parse(latin1)
      assert txn.label =~ "CAF"
    end
  end

  describe "parse/1 with French-locale export" do
    test "parses a French-locale Revolut CSV" do
      assert {:ok, transactions} = Revolut.parse(fixture("revolut_fr_valid.csv"))
      assert length(transactions) == 5

      [first | _] = transactions
      assert first.date == ~D[2025-06-19]
      assert first.label == "Recharge via *5935"
      assert first.amount == Decimal.new("330.00")
      assert first.currency == "EUR"
    end

    test "handles TERMINÉ as completed state" do
      assert {:ok, transactions} = Revolut.parse(fixture("revolut_fr_valid.csv"))

      exchange = Enum.find(transactions, &(&1.label == "Change en GBP"))
      assert exchange.amount == Decimal.new("-339.63")
    end

    test "skips non-TERMINÉ rows in French export" do
      csv =
        "Type,Produit,Date de début,Date de fin,Description,Montant,Frais,Devise,État,Solde\n" <>
          "Ajout de fonds,Valeur actuelle,2025-06-19 15:51:42,2025-06-19 15:52:30,Recharge,330.00,0.00,EUR,TERMINÉ,330.00\n" <>
          "Paiement,Valeur actuelle,2025-06-20 10:00:00,,Restaurant,-25.00,0.00,EUR,EN ATTENTE,305.00\n"

      assert {:ok, [txn]} = Revolut.parse(csv)
      assert txn.label == "Recharge"
    end

    test "returns error for missing columns in French export" do
      csv = "Type,Produit,Description,Montant\nAjout,Valeur,Recharge,10.00\n"

      assert {:error, [%Moulax.Parsers.ParseError{row: 0, message: message}]} =
               Revolut.parse(csv)

      assert message =~ "missing required columns"
    end
  end
end
