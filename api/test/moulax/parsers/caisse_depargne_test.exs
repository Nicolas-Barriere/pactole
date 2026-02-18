defmodule Moulax.Parsers.CaisseDepargneTest do
  use ExUnit.Case, async: true

  alias Moulax.Parsers.CaisseDepargne
  alias Moulax.Parsers.ParseError

  @fixtures_path Path.expand("../../fixtures", __DIR__)

  defp fixture(name), do: File.read!(Path.join(@fixtures_path, name))

  describe "detect?/1" do
    test "returns true for Caisse d'Épargne CSV" do
      assert CaisseDepargne.detect?(fixture("ce_valid.csv"))
    end

    test "returns false for Boursorama CSV" do
      refute CaisseDepargne.detect?(fixture("boursorama_valid.csv"))
    end

    test "returns false for Revolut CSV" do
      refute CaisseDepargne.detect?(fixture("revolut_valid.csv"))
    end

    test "returns false for empty content" do
      refute CaisseDepargne.detect?("")
    end

    test "returns false for random text" do
      refute CaisseDepargne.detect?("hello;world\nfoo;bar")
    end
  end

  describe "parse/1" do
    test "parses a valid Caisse d'Épargne CSV" do
      assert {:ok, transactions} = CaisseDepargne.parse(fixture("ce_valid.csv"))
      assert length(transactions) == 4

      [first | _] = transactions
      assert first.date == ~D[2026-02-10]
      assert first.original_label == "VIR SEPA EMPLOYEUR"
      assert first.label == "EMPLOYEUR"
      assert first.amount == Decimal.new("2500.00")
      assert first.currency == "EUR"
      assert first.bank_reference == "123456"
    end

    test "parses debit as negative amount" do
      assert {:ok, transactions} = CaisseDepargne.parse(fixture("ce_valid.csv"))
      debit_txn = Enum.find(transactions, &(&1.original_label == "CARTE 11/02 MONOPRIX"))

      assert debit_txn.amount == Decimal.new("-32.10")
    end

    test "parses credit as positive amount" do
      assert {:ok, transactions} = CaisseDepargne.parse(fixture("ce_valid.csv"))
      credit_txn = Enum.find(transactions, &(&1.original_label == "VIR SEPA EMPLOYEUR"))

      assert Decimal.positive?(credit_txn.amount)
      assert credit_txn.amount == Decimal.new("2500.00")
    end

    test "parses DD/MM/YYYY date format" do
      assert {:ok, transactions} = CaisseDepargne.parse(fixture("ce_valid.csv"))
      dates = Enum.map(transactions, & &1.date)

      assert ~D[2026-02-10] in dates
      assert ~D[2026-02-11] in dates
      assert ~D[2026-02-12] in dates
      assert ~D[2026-02-13] in dates
    end

    test "stores bank_reference from Numéro d'opération" do
      assert {:ok, transactions} = CaisseDepargne.parse(fixture("ce_valid.csv"))
      refs = Enum.map(transactions, & &1.bank_reference)

      assert "123456" in refs
      assert "123457" in refs
      assert "123458" in refs
      assert "123459" in refs
    end

    test "returns empty list for header-only CSV" do
      header = "Date;Numéro d'opération;Libellé;Débit;Crédit;Détail\n"
      assert {:ok, []} = CaisseDepargne.parse(header)
    end

    test "returns error for empty file" do
      assert {:error, [%ParseError{row: 0, message: "empty file"}]} = CaisseDepargne.parse("")
    end

    test "returns error for missing required columns" do
      assert {:error, [%ParseError{row: 0, message: message}]} =
               CaisseDepargne.parse(fixture("ce_missing_columns.csv"))

      assert message =~ "missing required columns"
      assert message =~ "Débit"
      assert message =~ "Crédit"
    end

    test "returns errors for invalid dates" do
      assert {:error, errors} = CaisseDepargne.parse(fixture("ce_invalid_rows.csv"))
      date_error = Enum.find(errors, &(&1.message =~ "date"))
      assert date_error.row == 1
      assert date_error.message =~ "invalid date"
    end

    test "returns errors for invalid amounts" do
      assert {:error, errors} = CaisseDepargne.parse(fixture("ce_invalid_rows.csv"))
      amount_error = Enum.find(errors, &(&1.message =~ "amount"))
      assert amount_error.row == 3
      assert amount_error.message =~ "invalid amount"
    end

    test "returns errors for missing labels" do
      assert {:error, errors} = CaisseDepargne.parse(fixture("ce_invalid_rows.csv"))
      label_error = Enum.find(errors, &(&1.message =~ "label"))
      assert label_error.row == 2
      assert label_error.message =~ "missing label"
    end

    test "handles UTF-8 BOM" do
      bom_content = "\uFEFF" <> fixture("ce_valid.csv")
      assert {:ok, transactions} = CaisseDepargne.parse(bom_content)
      assert length(transactions) == 4
    end

    test "handles Windows-style line endings" do
      content = fixture("ce_valid.csv") |> String.replace("\n", "\r\n")
      assert {:ok, transactions} = CaisseDepargne.parse(content)
      assert length(transactions) == 4
    end

    test "handles Latin-1 encoded content" do
      latin1 =
        "Date;Num\xE9ro d'op\xE9ration;Libell\xE9;D\xE9bit;Cr\xE9dit;D\xE9tail\n10/02/2026;123456;CAF\xE9 DU COIN;-5.50;;\n"

      assert {:ok, [txn]} = CaisseDepargne.parse(latin1)
      assert txn.original_label =~ "CAF"
      assert txn.amount == Decimal.new("-5.50")
    end
  end

  describe "clean_label/1" do
    test "strips CARTE DD/MM prefix" do
      assert CaisseDepargne.clean_label("CARTE 10/02 CARREFOUR") == "CARREFOUR"
      assert CaisseDepargne.clean_label("CARTE 31/12 FNAC") == "FNAC"
    end

    test "strips VIR SEPA prefix" do
      assert CaisseDepargne.clean_label("VIR SEPA EMPLOYEUR") == "EMPLOYEUR"
    end

    test "strips VIREMENT SEPA prefix" do
      assert CaisseDepargne.clean_label("VIREMENT SEPA REMBOURSEMENT") == "REMBOURSEMENT"
    end

    test "leaves other labels unchanged" do
      assert CaisseDepargne.clean_label("PRLV SEPA FREE MOBILE") == "PRLV SEPA FREE MOBILE"
    end

    test "trims whitespace" do
      assert CaisseDepargne.clean_label("  SOME LABEL  ") == "SOME LABEL"
    end
  end
end
