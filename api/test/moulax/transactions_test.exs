defmodule Moulax.TransactionsTest do
  use Moulax.DataCase, async: true

  alias Moulax.Transactions
  alias Moulax.Transactions.Transaction

  describe "list_transactions/1" do
    test "returns paginated data and meta" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Shop A",
        amount: Decimal.new("-10.50")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-02],
        label: "Shop B",
        amount: Decimal.new("-20.00")
      })

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
      insert_transaction(%{account_id: a1.id, label: "A", amount: Decimal.new("-1")})
      insert_transaction(%{account_id: a2.id, label: "B", amount: Decimal.new("-2")})

      result = Transactions.list_transactions(%{"account_id" => a1.id})
      assert result.meta.total_count == 1
      assert hd(result.data).account_id == a1.id
    end

    test "filters by category_id" do
      account = insert_account()
      cat = insert_category()

      insert_transaction(%{
        account_id: account.id,
        label: "X",
        amount: Decimal.new("-1"),
        category_id: cat.id
      })

      insert_transaction(%{account_id: account.id, label: "Y", amount: Decimal.new("-2")})

      result = Transactions.list_transactions(%{"category_id" => cat.id})
      assert result.meta.total_count == 1
      assert hd(result.data).category_id == cat.id
    end

    test "filters uncategorized with category_id uncategorized" do
      account = insert_account()
      cat = insert_category()

      insert_transaction(%{account_id: account.id, label: "X", amount: Decimal.new("-1")})

      insert_transaction(%{
        account_id: account.id,
        label: "Y",
        amount: Decimal.new("-2"),
        category_id: cat.id
      })

      result = Transactions.list_transactions(%{"category_id" => "uncategorized"})
      assert result.meta.total_count == 1
      assert hd(result.data).category_id == nil
    end

    test "filters by date_from and date_to with ISO strings" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-01-15],
        label: "Old",
        amount: Decimal.new("-1")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-10],
        label: "Mid",
        amount: Decimal.new("-2")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-03-20],
        label: "New",
        amount: Decimal.new("-3")
      })

      result =
        Transactions.list_transactions(%{"date_from" => "2026-02-01", "date_to" => "2026-02-28"})

      assert result.meta.total_count == 1
      assert hd(result.data).date == "2026-02-10"
    end

    test "accepts Date structs for date_from/date_to filters" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-01-15],
        label: "Old",
        amount: Decimal.new("-1")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-10],
        label: "Mid",
        amount: Decimal.new("-2")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-03-20],
        label: "New",
        amount: Decimal.new("-3")
      })

      result =
        Transactions.list_transactions(%{date_from: ~D[2026-02-01], date_to: ~D[2026-02-28]})

      assert result.meta.total_count == 1
      assert hd(result.data).label == "Mid"
    end

    test "invalid date_from and date_to are silently ignored" do
      account = insert_account()
      insert_transaction(%{account_id: account.id, label: "A", amount: Decimal.new("-1")})

      result =
        Transactions.list_transactions(%{"date_from" => "not-a-date", "date_to" => "also-bad"})

      assert result.meta.total_count == 1
    end

    test "search is case-insensitive substring on label" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "CARREFOUR City",
        amount: Decimal.new("-10")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-02],
        label: "SNCF Train",
        amount: Decimal.new("-20")
      })

      result = Transactions.list_transactions(%{"search" => "carrefour"})
      assert result.meta.total_count == 1
      assert hd(result.data).label == "CARREFOUR City"

      result2 = Transactions.list_transactions(%{"search" => "SNCF"})
      assert result2.meta.total_count == 1
      assert hd(result2.data).label == "SNCF Train"
    end

    test "search with SQL wildcard % character is treated as literal" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        label: "100% organic",
        amount: Decimal.new("-5")
      })

      insert_transaction(%{
        account_id: account.id,
        label: "Regular shop",
        amount: Decimal.new("-10")
      })

      result = Transactions.list_transactions(%{"search" => "100%"})
      assert result.meta.total_count == 1
      assert hd(result.data).label == "100% organic"
    end

    test "search with SQL wildcard _ character is treated as literal" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        label: "SHOP_ONLINE",
        amount: Decimal.new("-5")
      })

      insert_transaction(%{
        account_id: account.id,
        label: "SHOP ONLINE",
        amount: Decimal.new("-10")
      })

      result = Transactions.list_transactions(%{"search" => "SHOP_"})
      assert result.meta.total_count == 1
      assert hd(result.data).label == "SHOP_ONLINE"
    end

    test "ignores empty search term" do
      account = insert_account()
      insert_transaction(%{account_id: account.id, label: "A", amount: Decimal.new("-1")})
      insert_transaction(%{account_id: account.id, label: "B", amount: Decimal.new("-2")})

      result = Transactions.list_transactions(%{"search" => ""})
      assert result.meta.total_count == 2
    end

    test "pagination with page and per_page" do
      account = insert_account()

      for i <- 1..5 do
        insert_transaction(%{
          account_id: account.id,
          label: "Tx #{i}",
          amount: Decimal.new("-#{i}")
        })
      end

      result = Transactions.list_transactions(%{"page" => 2, "per_page" => 2})
      assert length(result.data) == 2
      assert result.meta.page == 2
      assert result.meta.per_page == 2
      assert result.meta.total_count == 5
      assert result.meta.total_pages == 3
    end

    test "invalid page/per_page values fall back to defaults" do
      result = Transactions.list_transactions(%{"page" => "bad", "per_page" => "bad"})
      assert result.meta.page == 1
      assert result.meta.per_page == 50
    end

    test "per_page is capped at 100" do
      result = Transactions.list_transactions(%{"per_page" => 200})
      assert result.meta.per_page == 100
    end

    test "default sort is date desc" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "First",
        amount: Decimal.new("-1")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-03],
        label: "Last",
        amount: Decimal.new("-2")
      })

      result = Transactions.list_transactions(%{})
      [first, second] = result.data
      assert first.date == "2026-02-03"
      assert second.date == "2026-02-01"
    end

    test "sort_by amount asc" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Big",
        amount: Decimal.new("-100")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Small",
        amount: Decimal.new("-5")
      })

      result = Transactions.list_transactions(%{"sort_by" => "amount", "sort_order" => "asc"})
      assert length(result.data) == 2
      assert hd(result.data).amount == "-100"
    end

    test "sort_by amount desc" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Big",
        amount: Decimal.new("-100")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Small",
        amount: Decimal.new("-5")
      })

      result = Transactions.list_transactions(%{"sort_by" => "amount", "sort_order" => "desc"})
      assert Enum.map(result.data, & &1.amount) == ["-5", "-100"]
    end

    test "sort_by label asc" do
      account = insert_account()
      insert_transaction(%{account_id: account.id, label: "Zebra", amount: Decimal.new("-1")})
      insert_transaction(%{account_id: account.id, label: "Alpha", amount: Decimal.new("-2")})

      result = Transactions.list_transactions(%{"sort_by" => "label", "sort_order" => "asc"})
      assert Enum.map(result.data, & &1.label) == ["Alpha", "Zebra"]
    end

    test "sort_by label desc" do
      account = insert_account()
      insert_transaction(%{account_id: account.id, label: "Zebra", amount: Decimal.new("-1")})
      insert_transaction(%{account_id: account.id, label: "Alpha", amount: Decimal.new("-2")})

      result = Transactions.list_transactions(%{"sort_by" => "label", "sort_order" => "desc"})
      assert Enum.map(result.data, & &1.label) == ["Zebra", "Alpha"]
    end

    test "unknown sort_by with asc sort_order falls back to date asc" do
      account = insert_account()

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-03],
        label: "Third",
        amount: Decimal.new("-3")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "First",
        amount: Decimal.new("-1")
      })

      result = Transactions.list_transactions(%{"sort_by" => "unknown", "sort_order" => "asc"})
      assert Enum.map(result.data, & &1.date) == ["2026-02-01", "2026-02-03"]
    end
  end

  describe "get_transaction/1" do
    test "returns transaction when found" do
      account = insert_account()

      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "Test",
          amount: Decimal.new("-10")
        })

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

    test "defaults currency to EUR when blank" do
      account = insert_account()

      attrs = %{
        account_id: account.id,
        date: ~D[2026-02-15],
        label: "Manual entry",
        original_label: "Manual entry",
        amount: Decimal.new("-25.50"),
        currency: "",
        source: "manual"
      }

      assert {:ok, tx} = Transactions.create_transaction(attrs)
      assert tx.currency == "EUR"
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
             } = errors_on(changeset)
    end

    test "returns error when (account_id, date, amount, original_label) is not unique" do
      account = insert_account()

      attrs = %{
        account_id: account.id,
        date: ~D[2026-02-15],
        label: "Debit",
        original_label: "Debit",
        amount: Decimal.new("-25.50"),
        source: "manual"
      }

      assert {:ok, _} = Transactions.create_transaction(attrs)
      assert {:error, changeset} = Transactions.create_transaction(attrs)
      assert %{account_id: [_]} = errors_on(changeset)
    end
  end

  describe "update_transaction/2" do
    test "updates category and label" do
      account = insert_account()
      cat = insert_category()
      tx = insert_transaction(%{account_id: account.id, label: "Old", amount: Decimal.new("-10")})

      assert {:ok, updated} =
               Transactions.update_transaction(tx, %{category_id: cat.id, label: "New label"})

      assert updated.category_id == cat.id
      assert updated.label == "New label"
    end

    test "returns changeset error for invalid updates" do
      account = insert_account()

      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "Old",
          amount: Decimal.new("-10")
        })

      assert {:error, changeset} = Transactions.update_transaction(tx, %{source: "invalid"})
      assert %{source: [_]} = errors_on(changeset)
    end
  end

  describe "delete_transaction/1" do
    test "deletes by id" do
      account = insert_account()
      tx = insert_transaction(%{account_id: account.id, label: "X", amount: Decimal.new("-1")})

      assert {:ok, _} = Transactions.delete_transaction(tx.id)
      assert {:error, :not_found} = Transactions.get_transaction(tx.id)
    end

    test "returns not_found when deleting unknown id" do
      assert {:error, :not_found} = Transactions.delete_transaction(Ecto.UUID.generate())
    end

    test "deletes by struct" do
      account = insert_account()

      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "X",
          amount: Decimal.new("-1")
        })

      assert {:ok, _} = Transactions.delete_transaction(tx)
      assert {:error, :not_found} = Transactions.get_transaction(tx.id)
    end
  end

  describe "bulk_categorize/2" do
    test "updates category for multiple transactions" do
      account = insert_account()
      cat = insert_category()

      t1 =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "A",
          amount: Decimal.new("-1")
        })

      t2 =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-02],
          label: "B",
          amount: Decimal.new("-2")
        })

      assert {:ok, 2} = Transactions.bulk_categorize([t1.id, t2.id], cat.id)

      assert {:ok, tx1} = Transactions.get_transaction(t1.id)
      assert tx1.category_id == cat.id
      assert {:ok, tx2} = Transactions.get_transaction(t2.id)
      assert tx2.category_id == cat.id
    end

    test "allows uncategorize with nil category_id" do
      account = insert_account()
      cat = insert_category()

      tx =
        insert_transaction(%{
          account_id: account.id,
          label: "A",
          amount: Decimal.new("-1"),
          category_id: cat.id
        })

      assert {:ok, 1} = Transactions.bulk_categorize([tx.id], nil)
      assert {:ok, updated} = Transactions.get_transaction(tx.id)
      assert updated.category_id == nil
    end

    test "returns 0 when list is empty" do
      assert {:ok, 0} = Transactions.bulk_categorize([], Ecto.UUID.generate())
    end

    test "returns 0 when none of the transaction IDs exist" do
      assert {:ok, 0} =
               Transactions.bulk_categorize(
                 [Ecto.UUID.generate(), Ecto.UUID.generate()],
                 Ecto.UUID.generate()
               )
    end
  end

  describe "Transaction.changeset/2 defaults" do
    test "defaults blank currency in existing struct to EUR" do
      changeset = Transaction.changeset(%Transaction{currency: ""}, %{})
      assert get_change(changeset, :currency) == "EUR"
    end
  end
end
