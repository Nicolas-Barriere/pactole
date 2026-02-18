defmodule Moulax.TransactionsTest do
  use Moulax.DataCase, async: true

  alias Moulax.Transactions
  alias Moulax.Transactions.Transaction
  alias Moulax.Accounts.Account
  alias Moulax.Categories.Category
  alias Moulax.Repo

  describe "list_transactions/1" do
    test "returns paginated data and meta" do
      account = insert_account()
      _t1 = insert_transaction(account.id, ~D[2026-02-01], "Shop A", "-10.50", "manual")
      _t2 = insert_transaction(account.id, ~D[2026-02-02], "Shop B", "-20.00", "manual")

      result = Transactions.list_transactions(%{})
      assert length(result.data) == 2
      assert result.meta.page == 1
      assert result.meta.per_page == 50
      assert result.meta.total_count == 2
      assert result.meta.total_pages == 1
    end

    test "filters by account_id" do
      a1 = insert_account()
      a2 = insert_account()
      insert_transaction(a1.id, ~D[2026-02-01], "A", "-1", "manual")
      insert_transaction(a2.id, ~D[2026-02-01], "B", "-2", "manual")

      result = Transactions.list_transactions(%{"account_id" => a1.id})
      assert result.meta.total_count == 1
      assert hd(result.data).account_id == a1.id
    end

    test "filters by category_id" do
      account = insert_account()
      cat = insert_category()
      insert_transaction(account.id, ~D[2026-02-01], "X", "-1", "manual", cat.id)
      insert_transaction(account.id, ~D[2026-02-02], "Y", "-2", "manual", nil)

      result = Transactions.list_transactions(%{"category_id" => cat.id})
      assert result.meta.total_count == 1
      assert hd(result.data).category_id == cat.id
    end

    test "filters uncategorized with category_id uncategorized" do
      account = insert_account()
      insert_transaction(account.id, ~D[2026-02-01], "X", "-1", "manual", nil)
      cat = insert_category()
      insert_transaction(account.id, ~D[2026-02-02], "Y", "-2", "manual", cat.id)

      result = Transactions.list_transactions(%{"category_id" => "uncategorized"})
      assert result.meta.total_count == 1
      assert hd(result.data).category_id == nil
    end

    test "filters by date_from and date_to" do
      account = insert_account()
      insert_transaction(account.id, ~D[2026-01-15], "Old", "-1", "manual")
      insert_transaction(account.id, ~D[2026-02-10], "Mid", "-2", "manual")
      insert_transaction(account.id, ~D[2026-03-20], "New", "-3", "manual")

      result =
        Transactions.list_transactions(%{"date_from" => "2026-02-01", "date_to" => "2026-02-28"})

      assert result.meta.total_count == 1
      assert hd(result.data).date == "2026-02-10"
    end

    test "search is case-insensitive substring on label" do
      account = insert_account()
      insert_transaction(account.id, ~D[2026-02-01], "CARREFOUR City", "-10", "manual")
      insert_transaction(account.id, ~D[2026-02-02], "SNCF Train", "-20", "manual")

      result = Transactions.list_transactions(%{"search" => "carrefour"})
      assert result.meta.total_count == 1
      assert hd(result.data).label == "CARREFOUR City"

      result2 = Transactions.list_transactions(%{"search" => "SNCF"})
      assert result2.meta.total_count == 1
      assert hd(result2.data).label == "SNCF Train"
    end

    test "pagination with page and per_page" do
      account = insert_account()

      for i <- 1..5 do
        insert_transaction(account.id, ~D[2026-02-01], "Tx #{i}", "-#{i}", "manual")
      end

      result = Transactions.list_transactions(%{"page" => 2, "per_page" => 2})
      assert length(result.data) == 2
      assert result.meta.page == 2
      assert result.meta.per_page == 2
      assert result.meta.total_count == 5
      assert result.meta.total_pages == 3
    end

    test "default sort is date desc" do
      account = insert_account()
      insert_transaction(account.id, ~D[2026-02-01], "First", "-1", "manual")
      insert_transaction(account.id, ~D[2026-02-03], "Last", "-2", "manual")

      result = Transactions.list_transactions(%{})
      [first, second] = result.data
      assert first.date == "2026-02-03"
      assert second.date == "2026-02-01"
    end

    test "sort_by amount and sort_order asc" do
      account = insert_account()
      insert_transaction(account.id, ~D[2026-02-01], "Big", "-100", "manual")
      insert_transaction(account.id, ~D[2026-02-01], "Small", "-5", "manual")

      result = Transactions.list_transactions(%{"sort_by" => "amount", "sort_order" => "asc"})
      assert length(result.data) == 2

      # Asc by amount: -5 then -100 (smaller absolute first when asc on negative numbers: -100 < -5)
      assert hd(result.data).amount == "-100"
    end
  end

  describe "get_transaction/1" do
    test "returns transaction when found" do
      account = insert_account()
      tx = insert_transaction(account.id, ~D[2026-02-01], "Test", "-10", "manual")

      assert {:ok, got} = Transactions.get_transaction(tx.id)
      assert got.id == tx.id
      assert got.label == "Test"
      assert got.amount == "-10"
    end

    test "returns not_found when id does not exist" do
      assert {:error, :not_found} = Transactions.get_transaction(Ecto.UUID.generate())
    end
  end

  describe "create_transaction/1" do
    test "creates manual transaction with required fields" do
      account = insert_account()

      attrs = %{
        account_id: account.id,
        date: ~D[2026-02-15],
        label: "Manual entry",
        original_label: "Manual entry",
        amount: Decimal.new("-25.50"),
        source: "manual"
      }

      assert {:ok, tx} = Transactions.create_transaction(attrs)
      assert tx.label == "Manual entry"
      assert tx.amount == "-25.50"
      assert tx.source == "manual"
      assert tx.account_id == account.id
    end

    test "validates required fields" do
      assert {:error, changeset} = Transactions.create_transaction(%{})

      assert %{
               account_id: [_],
               date: [_],
               label: [_],
               original_label: [_],
               amount: [_],
               source: [_]
             } =
               errors_on(changeset)
    end
  end

  describe "update_transaction/2" do
    test "updates category and label" do
      account = insert_account()
      cat = insert_category()
      tx = insert_transaction(account.id, ~D[2026-02-01], "Old", "-10", "manual", nil)

      assert {:ok, updated} =
               Transactions.update_transaction(tx, %{category_id: cat.id, label: "New label"})

      assert updated.category_id == cat.id
      assert updated.label == "New label"
    end
  end

  describe "delete_transaction/1" do
    test "deletes by id" do
      account = insert_account()
      tx = insert_transaction(account.id, ~D[2026-02-01], "X", "-1", "manual")

      assert {:ok, _} = Transactions.delete_transaction(tx.id)
      assert {:error, :not_found} = Transactions.get_transaction(tx.id)
    end

    test "returns not_found when id does not exist" do
      assert {:error, :not_found} = Transactions.delete_transaction(Ecto.UUID.generate())
    end
  end

  describe "bulk_categorize/2" do
    test "updates category for multiple transactions" do
      account = insert_account()
      cat = insert_category()
      t1 = insert_transaction(account.id, ~D[2026-02-01], "A", "-1", "manual", nil)
      t2 = insert_transaction(account.id, ~D[2026-02-02], "B", "-2", "manual", nil)

      assert {:ok, 2} = Transactions.bulk_categorize([t1.id, t2.id], cat.id)

      assert {:ok, tx1} = Transactions.get_transaction(t1.id)
      assert tx1.category_id == cat.id
      assert {:ok, tx2} = Transactions.get_transaction(t2.id)
      assert tx2.category_id == cat.id
    end

    test "allows uncategorize with nil category_id" do
      account = insert_account()
      cat = insert_category()
      tx = insert_transaction(account.id, ~D[2026-02-01], "A", "-1", "manual", cat.id)

      assert {:ok, 1} = Transactions.bulk_categorize([tx.id], nil)
      assert {:ok, updated} = Transactions.get_transaction(tx.id)
      assert updated.category_id == nil
    end

    test "returns 0 when list is empty" do
      assert {:ok, 0} = Transactions.bulk_categorize([], Ecto.UUID.generate())
    end
  end

  defp insert_account do
    %Account{}
    |> Account.changeset(%{name: "Test", bank: "test", type: "checking"})
    |> Repo.insert!()
  end

  defp insert_category do
    %Category{name: "Test Cat", color: "#3b82f6"}
    |> Repo.insert!()
  end

  defp insert_transaction(account_id, date, label, amount_str, source, category_id \\ nil) do
    %Transaction{}
    |> Transaction.changeset(%{
      account_id: account_id,
      date: date,
      label: label,
      original_label: label,
      amount: Decimal.new(amount_str),
      source: source,
      category_id: category_id
    })
    |> Repo.insert!()
  end
end
