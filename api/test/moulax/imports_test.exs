defmodule Moulax.ImportsTest do
  use Moulax.DataCase, async: true

  alias Moulax.Imports
  alias Moulax.Imports.Import
  alias Moulax.Transactions.Transaction

  setup do
    %{account: insert_account(%{name: "Test Account", bank: "boursorama", type: "checking"})}
  end

  describe "create_import/2" do
    test "creates an import record with pending status", %{account: account} do
      assert {:ok, %Import{} = import_record} =
               Imports.create_import(account.id, "test.csv")

      assert import_record.account_id == account.id
      assert import_record.filename == "test.csv"
      assert import_record.status == "pending"
      assert import_record.rows_total == 0
    end
  end

  describe "process_import/2 with Boursorama CSV" do
    test "imports valid CSV rows", %{account: account} do
      csv = File.read!(Path.join([__DIR__, "..", "fixtures", "boursorama_valid.csv"]))
      {:ok, import_record} = Imports.create_import(account.id, "boursorama.csv")

      assert {:ok, result} = Imports.process_import(import_record, csv)

      assert result.status == "completed"
      assert result.rows_total == 4
      assert result.rows_imported == 4
      assert result.rows_skipped == 0
      assert result.rows_errored == 0

      txs = Repo.all(from t in Transaction, where: t.account_id == ^account.id)
      assert length(txs) == 4
      assert Enum.all?(txs, &(&1.source == "csv_import"))
    end

    test "applies categorization rules during import — highest priority wins", %{account: account} do
      groceries = insert_category(%{name: "Groceries", color: "#22c55e"})
      transport = insert_category(%{name: "Transport", color: "#3b82f6"})
      restaurants = insert_category(%{name: "Restaurants", color: "#ef4444"})

      # The Boursorama parser extracts the supplier as the cleaned label (before " | ").
      # Row 1 cleaned label: "Carrefour" — matches both "carrefour" (p10) and "carre" (p5).
      # Groceries wins because priority 10 > 5.
      insert_rule(%{keyword: "carrefour", category_id: groceries.id, priority: 10})
      insert_rule(%{keyword: "carre", category_id: transport.id, priority: 5})

      # Row 3 cleaned label: "Le Petit Paris" — matches "paris" → restaurants
      insert_rule(%{keyword: "paris", category_id: restaurants.id, priority: 8})

      csv = File.read!(Path.join([__DIR__, "..", "fixtures", "boursorama_valid.csv"]))
      {:ok, import_record} = Imports.create_import(account.id, "boursorama.csv")
      assert {:ok, _result} = Imports.process_import(import_record, csv)

      # Row 1 cleaned label "Carrefour" — highest priority rule wins
      carrefour_tx =
        Repo.one!(
          from t in Transaction,
            where: t.account_id == ^account.id and ilike(t.label, "%Carrefour%")
        )

      assert carrefour_tx.category_id == groceries.id

      # Row 3 cleaned label "Le Petit Paris" — matches "paris" rule
      restaurant_tx =
        Repo.one!(
          from t in Transaction,
            where: t.account_id == ^account.id and ilike(t.label, "%Petit Paris%")
        )

      assert restaurant_tx.category_id == restaurants.id

      # Row 4 cleaned label "Free" — no matching rule → uncategorized
      free_tx =
        Repo.one!(
          from t in Transaction,
            where: t.account_id == ^account.id and ilike(t.label, "%Free%")
        )

      assert free_tx.category_id == nil
    end

    test "deduplicates — importing same file twice skips all rows", %{account: account} do
      csv = File.read!(Path.join([__DIR__, "..", "fixtures", "boursorama_valid.csv"]))

      {:ok, import1} = Imports.create_import(account.id, "first.csv")
      assert {:ok, result1} = Imports.process_import(import1, csv)
      assert result1.rows_imported == 4

      {:ok, import2} = Imports.create_import(account.id, "second.csv")
      assert {:ok, result2} = Imports.process_import(import2, csv)
      assert result2.rows_imported == 0
      assert result2.rows_skipped == 4
    end

    test "deduplicates across partial overlap — imports only new rows", %{account: account} do
      # First import: all 4 rows from boursorama_valid.csv
      csv_full = File.read!(Path.join([__DIR__, "..", "fixtures", "boursorama_valid.csv"]))
      {:ok, import1} = Imports.create_import(account.id, "full.csv")
      assert {:ok, result1} = Imports.process_import(import1, csv_full)
      assert result1.rows_imported == 4

      # Second import: partial overlap — rows 1,2 are duplicates; rows 3,4 are new
      csv_overlap =
        File.read!(Path.join([__DIR__, "..", "fixtures", "boursorama_partial_overlap.csv"]))

      {:ok, import2} = Imports.create_import(account.id, "overlap.csv")
      assert {:ok, result2} = Imports.process_import(import2, csv_overlap)
      assert result2.rows_imported == 2
      assert result2.rows_skipped == 2
      assert result2.rows_errored == 0

      # Total transactions in DB should be 6 (4 original + 2 new)
      total = Repo.aggregate(from(t in Transaction, where: t.account_id == ^account.id), :count)
      assert total == 6
    end
  end

  describe "process_import/2 with Revolut CSV" do
    test "imports valid Revolut CSV", %{account: account} do
      csv = File.read!(Path.join([__DIR__, "..", "fixtures", "revolut_valid.csv"]))
      {:ok, import_record} = Imports.create_import(account.id, "revolut.csv")

      assert {:ok, result} = Imports.process_import(import_record, csv)

      assert result.status == "completed"
      assert result.rows_imported > 0
    end

    test "Revolut fee transactions are not considered duplicates of parent", %{account: account} do
      csv = File.read!(Path.join([__DIR__, "..", "fixtures", "revolut_with_fees.csv"]))
      {:ok, import1} = Imports.create_import(account.id, "revolut_fees.csv")
      assert {:ok, result1} = Imports.process_import(import1, csv)
      first_import_count = result1.rows_imported
      assert first_import_count > 0

      {:ok, import2} = Imports.create_import(account.id, "revolut_fees2.csv")
      assert {:ok, result2} = Imports.process_import(import2, csv)
      # Second import should skip all rows (deduplication), not fail
      assert result2.rows_skipped == first_import_count
      assert result2.rows_imported == 0
    end
  end

  describe "process_import/2 with Caisse d'Épargne CSV" do
    test "imports valid CE CSV", %{account: account} do
      csv = File.read!(Path.join([__DIR__, "..", "fixtures", "ce_valid.csv"]))
      {:ok, import_record} = Imports.create_import(account.id, "ce.csv")

      assert {:ok, result} = Imports.process_import(import_record, csv)

      assert result.status == "completed"
      assert result.rows_imported > 0
    end
  end

  describe "process_import/2 error handling" do
    test "returns error for unknown CSV format", %{account: account} do
      csv = "foo,bar,baz\n1,2,3\n"
      {:ok, import_record} = Imports.create_import(account.id, "unknown.csv")

      assert {:error, result} = Imports.process_import(import_record, csv)

      assert result.status == "failed"
      assert [%{"message" => msg} | _] = result.error_details
      assert msg =~ "Unknown CSV format"
    end

    test "returns error for empty content", %{account: account} do
      {:ok, import_record} = Imports.create_import(account.id, "empty.csv")

      assert {:error, result} = Imports.process_import(import_record, "")

      assert result.status == "failed"
    end

    test "handles CSV with only headers and no data rows", %{account: account} do
      csv =
        "dateOp;dateVal;label;category;categoryParent;supplierFound;amount;accountNum;accountLabel;accountBalance\n"

      {:ok, import_record} = Imports.create_import(account.id, "headers_only.csv")

      assert {:ok, result} = Imports.process_import(import_record, csv)

      assert result.status == "completed"
      assert result.rows_total == 0
      assert result.rows_imported == 0
    end
  end

  describe "get_import/1" do
    test "returns import by id", %{account: account} do
      {:ok, import_record} = Imports.create_import(account.id, "test.csv")

      assert {:ok, result} = Imports.get_import(import_record.id)
      assert result.id == import_record.id
      assert result.filename == "test.csv"
    end

    test "returns error for non-existent id" do
      assert {:error, :not_found} = Imports.get_import(Ecto.UUID.generate())
    end
  end

  describe "list_imports_for_account/1" do
    test "returns all imports for an account", %{account: account} do
      {:ok, _i1} = Imports.create_import(account.id, "first.csv")
      {:ok, _i2} = Imports.create_import(account.id, "second.csv")

      imports = Imports.list_imports_for_account(account.id)
      assert length(imports) == 2
      filenames = Enum.map(imports, & &1.filename)
      assert "first.csv" in filenames
      assert "second.csv" in filenames
    end

    test "returns empty list for account with no imports", %{account: account} do
      assert Imports.list_imports_for_account(account.id) == []
    end
  end
end
