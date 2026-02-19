defmodule Moulax.Parsers.BoursoramaTest do
  use ExUnit.Case, async: true

  alias Moulax.Parsers.Boursorama
  alias Moulax.Parsers.ParseError

  @fixtures_path Path.expand("../../fixtures", __DIR__)

  defp fixture(name), do: File.read!(Path.join(@fixtures_path, name))

  describe "detect?/1" do
    test "returns true for BoursoBank CSV" do
      assert Boursorama.detect?(fixture("boursorama_valid.csv"))
    end

    test "returns true for legacy Boursorama CSV without quotes" do
      legacy = "dateOp;dateVal;label;amount\n2026-02-10;2026-02-10;CARTE 10/02 SHOP;-10,00\n"
      assert Boursorama.detect?(legacy)
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
    test "parses a valid BoursoBank CSV with quoted fields" do
      assert {:ok, transactions} = Boursorama.parse(fixture("boursorama_valid.csv"))
      assert length(transactions) == 4

      [first | _] = transactions
      assert first.date == ~D[2026-02-10]
      assert first.original_label == "Carrefour | CARTE 10/02/26 CARREFOUR CB*1234"
      assert first.label == "Carrefour"
      assert first.amount == Decimal.new("-45.32")
      assert first.currency == "EUR"
    end

    test "extracts supplier name from pipe-separated label" do
      assert {:ok, transactions} = Boursorama.parse(fixture("boursorama_valid.csv"))

      vir = Enum.find(transactions, &String.contains?(&1.original_label, "VIR SEPA"))
      assert vir.label == "Employeur SA"
      assert vir.amount == Decimal.new("2500.00")
    end

    test "handles comma as decimal separator" do
      assert {:ok, transactions} = Boursorama.parse(fixture("boursorama_valid.csv"))
      first = List.first(transactions)
      assert first.amount == Decimal.new("-45.32")
    end

    test "parses legacy Boursorama format without quotes" do
      legacy =
        "dateOp;dateVal;label;category;categoryParent;supplierFound;amount;accountNum;accountLabel;accountBalance\n" <>
          "2026-02-10;2026-02-10;CARTE 10/02 CARREFOUR;;;;-45,32;;;\n" <>
          "2026-02-09;2026-02-09;VIR SEPA EMPLOYEUR;;;;2500.00;;;\n"

      assert {:ok, [first, second]} = Boursorama.parse(legacy)
      assert first.original_label == "CARTE 10/02 CARREFOUR"
      assert first.label == "CARREFOUR"
      assert second.original_label == "VIR SEPA EMPLOYEUR"
      assert second.label == "EMPLOYEUR"
    end

    test "returns empty list for header-only CSV" do
      header =
        "dateOp;dateVal;label;category;categoryParent;supplierFound;amount;comment;accountNum;accountLabel;accountbalance\n"

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
        "dateOp;dateVal;label;amount\n2026-02-10;2026-02-10;CARTE 10/02 CAF\xE9;-10,00\n"

      assert {:ok, [txn]} = Boursorama.parse(latin1)
      assert txn.original_label =~ "CAF"
    end

    test "parses a real BoursoBank export" do
      assert {:ok, transactions} = Boursorama.parse(fixture("boursobank_real_export.csv"))
      assert length(transactions) == 13

      first = List.first(transactions)
      assert first.date == ~D[2026-01-27]
      assert first.original_label == "TfL | CARTE 25/01/26 TFL TRAVEL CH CB*5935"
      assert first.label == "TfL"
      assert first.amount == Decimal.new("-3.23")
      assert first.currency == "EUR"

      youtube = Enum.find(transactions, &(&1.label == "YouTube"))
      assert youtube.date == ~D[2026-01-19]
      assert youtube.amount == Decimal.new("-2.31")

      vir = Enum.find(transactions, &(&1.label == "Vir Cheh"))
      assert vir.amount == Decimal.new("1.00")

      sncf_txns = Enum.filter(transactions, &(&1.label == "SNCF"))
      assert length(sncf_txns) == 2

      cheque = Enum.find(transactions, &String.contains?(&1.label, "Remise"))
      assert cheque.label == "Remise Chèque N.7239954"
      assert cheque.amount == Decimal.new("40.00")

      tisseo = Enum.find(transactions, &String.contains?(&1.original_label, "Tisséo"))
      assert tisseo.label == "Tisséo"
      assert tisseo.amount == Decimal.new("-1.80")
    end

    test "parses a real BoursoBank export with BOM prefix" do
      bom_content = "\uFEFF" <> fixture("boursobank_real_export.csv")
      assert {:ok, transactions} = Boursorama.parse(bom_content)
      assert length(transactions) == 13
    end

    test "returns missing date when duplicate dateOp header points to missing field" do
      csv =
        "dateOp;dateVal;label;amount;dateOp\n" <>
          "2026-02-10;2026-02-10;Coffee;-10.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing date"}]} = Boursorama.parse(csv)
    end

    test "returns missing date when date is empty" do
      csv =
        "dateOp;dateVal;label;amount\n" <>
          ";2026-02-10;Coffee;-10.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing date"}]} = Boursorama.parse(csv)
    end

    test "returns missing amount when duplicate amount header points to missing field" do
      csv =
        "dateOp;dateVal;label;amount;amount\n" <>
          "2026-02-10;2026-02-10;Coffee;-10.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing amount"}]} = Boursorama.parse(csv)
    end

    test "returns missing amount when amount is empty" do
      csv =
        "dateOp;dateVal;label;amount\n" <>
          "2026-02-10;2026-02-10;Coffee;\n"

      assert {:error, [%ParseError{row: 1, message: "missing amount"}]} = Boursorama.parse(csv)
    end

    test "returns invalid amount when amount has trailing garbage" do
      csv =
        "dateOp;dateVal;label;amount\n" <>
          "2026-02-10;2026-02-10;Coffee;-10.00abc\n"

      assert {:error, [%ParseError{row: 1, message: message}]} = Boursorama.parse(csv)
      assert message =~ "invalid amount"
    end

    test "returns missing label when duplicate label header points to missing field" do
      csv =
        "dateOp;dateVal;label;amount;label\n" <>
          "2026-02-10;2026-02-10;Coffee;-10.00\n"

      assert {:error, [%ParseError{row: 1, message: "missing label"}]} = Boursorama.parse(csv)
    end
  end

  describe "clean_label/1" do
    test "extracts supplier from BoursoBank pipe format" do
      assert Boursorama.clean_label("Carrefour | CARTE 10/02/26 CARREFOUR CB*1234") ==
               "Carrefour"

      assert Boursorama.clean_label("YouTube | CARTE 15/01/26 Google YouTube Su CB*5935") ==
               "YouTube"

      assert Boursorama.clean_label("Vir Cheh | VIR Cheh") == "Vir Cheh"
    end

    test "strips CARTE DD/MM prefix (legacy format)" do
      assert Boursorama.clean_label("CARTE 10/02 CARREFOUR") == "CARREFOUR"
      assert Boursorama.clean_label("CARTE 31/12 FNAC") == "FNAC"
    end

    test "strips CARTE DD/MM/YY prefix" do
      assert Boursorama.clean_label("CARTE 10/02/26 CARREFOUR CB*1234") == "CARREFOUR"
    end

    test "strips VIR SEPA prefix" do
      assert Boursorama.clean_label("VIR SEPA EMPLOYEUR") == "EMPLOYEUR"
    end

    test "strips VIREMENT SEPA prefix" do
      assert Boursorama.clean_label("VIREMENT SEPA REMBOURSEMENT") == "REMBOURSEMENT"
    end

    test "strips CB*XXXX suffix" do
      assert Boursorama.clean_label("CARTE 10/02/26 SOME SHOP CB*5935") == "SOME SHOP"
    end

    test "leaves other labels unchanged" do
      assert Boursorama.clean_label("PRLV SEPA FREE MOBILE") == "PRLV SEPA FREE MOBILE"
    end

    test "trims whitespace" do
      assert Boursorama.clean_label("  SOME LABEL  ") == "SOME LABEL"
    end
  end
end
