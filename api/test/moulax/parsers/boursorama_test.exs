defmodule Moulax.Parsers.BoursoramaTest do
  use ExUnit.Case, async: true

  alias Moulax.Parsers.Boursorama
  alias Moulax.Parsers.ParseError

  @fixtures_path Path.expand("../../fixtures", __DIR__)

  defp fixture(name), do: File.read!(Path.join(@fixtures_path, name))

  describe "detect?/1" do
    test "returns true for Boursorama CSV" do
      assert Boursorama.detect?(fixture("boursorama_valid.csv"))
    end

    test "returns false for Revolut CSV" do
      refute Boursorama.detect?(fixture("revolut_sample.csv"))
    end

    test "returns false for empty content" do
      refute Boursorama.detect?("")
    end

    test "returns false for random text" do
      refute Boursorama.detect?("hello;world\nfoo;bar")
    end
  end

  describe "parse/1" do
    test "parses a valid Boursorama CSV" do
      assert {:ok, transactions} = Boursorama.parse(fixture("boursorama_valid.csv"))
      assert length(transactions) == 4

      [first | _] = transactions
      assert first.date == ~D[2026-02-10]
      assert first.original_label == "CARTE 10/02 CARREFOUR"
      assert first.label == "CARREFOUR"
      assert first.amount == Decimal.new("-45.32")
      assert first.currency == "EUR"
    end

    test "parses VIR SEPA label correctly" do
      assert {:ok, transactions} = Boursorama.parse(fixture("boursorama_valid.csv"))
      vir = Enum.find(transactions, &(&1.original_label == "VIR SEPA EMPLOYEUR"))

      assert vir.label == "EMPLOYEUR"
      assert vir.amount == Decimal.new("2500.00")
    end

    test "handles comma as decimal separator" do
      assert {:ok, transactions} = Boursorama.parse(fixture("boursorama_valid.csv"))
      first = List.first(transactions)

      assert first.amount == Decimal.new("-45.32")
    end

    test "returns empty list for header-only CSV" do
      header =
        "dateOp;dateVal;label;category;categoryParent;supplierFound;amount;accountNum;accountLabel;accountBalance\n"

      assert {:ok, []} = Boursorama.parse(header)
    end

    test "returns error for empty file" do
      assert {:error, [%ParseError{row: 0, message: "empty file"}]} = Boursorama.parse("")
    end

    test "returns error for missing required columns" do
      assert {:error, [%ParseError{row: 0, message: message}]} =
               Boursorama.parse(fixture("boursorama_missing_columns.csv"))

      assert message =~ "missing required columns"
      assert message =~ "amount"
    end

    test "returns errors for invalid dates" do
      assert {:error, errors} = Boursorama.parse(fixture("boursorama_invalid_rows.csv"))
      date_error = Enum.find(errors, &(&1.message =~ "date"))
      assert date_error.row == 1
      assert date_error.message =~ "invalid date"
    end

    test "returns errors for invalid amounts" do
      assert {:error, errors} = Boursorama.parse(fixture("boursorama_invalid_rows.csv"))
      amount_error = Enum.find(errors, &(&1.message =~ "amount"))
      assert amount_error.row == 2
      assert amount_error.message =~ "invalid amount"
    end

    test "returns errors for missing labels" do
      assert {:error, errors} = Boursorama.parse(fixture("boursorama_invalid_rows.csv"))
      label_error = Enum.find(errors, &(&1.message =~ "label"))
      assert label_error.row == 3
      assert label_error.message =~ "missing label"
    end

    test "handles UTF-8 BOM" do
      bom_content = "\uFEFF" <> fixture("boursorama_valid.csv")
      assert {:ok, transactions} = Boursorama.parse(bom_content)
      assert length(transactions) == 4
    end

    test "handles Windows-style line endings" do
      content = fixture("boursorama_valid.csv") |> String.replace("\n", "\r\n")
      assert {:ok, transactions} = Boursorama.parse(content)
      assert length(transactions) == 4
    end

    test "handles Latin-1 encoded content" do
      latin1 =
        "dateOp;dateVal;label;category;categoryParent;supplierFound;amount;accountNum;accountLabel;accountBalance\n2026-02-10;2026-02-10;CARTE 10/02 CAF\xE9;;;;-10,00;;;\n"

      assert {:ok, [txn]} = Boursorama.parse(latin1)
      assert txn.original_label =~ "CAF"
    end
  end

  describe "clean_label/1" do
    test "strips CARTE DD/MM prefix" do
      assert Boursorama.clean_label("CARTE 10/02 CARREFOUR") == "CARREFOUR"
      assert Boursorama.clean_label("CARTE 31/12 FNAC") == "FNAC"
    end

    test "strips VIR SEPA prefix" do
      assert Boursorama.clean_label("VIR SEPA EMPLOYEUR") == "EMPLOYEUR"
    end

    test "strips VIREMENT SEPA prefix" do
      assert Boursorama.clean_label("VIREMENT SEPA REMBOURSEMENT") == "REMBOURSEMENT"
    end

    test "leaves other labels unchanged" do
      assert Boursorama.clean_label("PRLV SEPA FREE MOBILE") == "PRLV SEPA FREE MOBILE"
    end

    test "trims whitespace" do
      assert Boursorama.clean_label("  SOME LABEL  ") == "SOME LABEL"
    end
  end
end
