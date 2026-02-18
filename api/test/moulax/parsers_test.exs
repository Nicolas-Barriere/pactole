defmodule Moulax.ParsersTest do
  use ExUnit.Case, async: true

  alias Moulax.Parsers

  @fixtures_path Path.expand("../fixtures", __DIR__)

  defp fixture(name), do: File.read!(Path.join(@fixtures_path, name))

  describe "detect_parser/1" do
    test "detects Boursorama parser" do
      assert {:ok, Moulax.Parsers.Boursorama} =
               Parsers.detect_parser(fixture("boursorama_valid.csv"))
    end

    test "detects Boursorama parser for real BoursoBank export" do
      assert {:ok, Moulax.Parsers.Boursorama} =
               Parsers.detect_parser(fixture("boursobank_real_export.csv"))
    end

    test "detects parser even with UTF-8 BOM prefix" do
      bom_content = "\uFEFF" <> fixture("boursobank_real_export.csv")

      assert {:ok, Moulax.Parsers.Boursorama} =
               Parsers.detect_parser(bom_content)
    end

    test "returns :error for unknown CSV format" do
      assert :error = Parsers.detect_parser("unknown;format\n1;2")
    end

    test "detects Revolut parser" do
      assert {:ok, Moulax.Parsers.Revolut} =
               Parsers.detect_parser(fixture("revolut_sample.csv"))
    end

    test "detects Revolut parser for French-locale export" do
      assert {:ok, Moulax.Parsers.Revolut} =
               Parsers.detect_parser(fixture("revolut_fr_valid.csv"))
    end

    test "detects Caisse d'Épargne parser" do
      assert {:ok, Moulax.Parsers.CaisseDepargne} =
               Parsers.detect_parser(fixture("ce_valid.csv"))
    end

    test "returns :error for empty content" do
      assert :error = Parsers.detect_parser("")
    end
  end
end
