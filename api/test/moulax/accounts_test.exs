defmodule Moulax.AccountsTest do
  use Moulax.DataCase, async: true

  import Ecto.Query

  alias Moulax.Accounts
  alias Moulax.Accounts.Account
  alias Moulax.Imports.Import
  alias Moulax.Repo

  describe "list_accounts/0" do
    test "returns only non-archived accounts" do
      _active = insert_account(%{name: "Active", bank: "boursorama", type: "checking"})

      _archived =
        insert_account(%{name: "Archived", bank: "revolut", type: "savings", archived: true})

      accounts = Accounts.list_accounts()

      assert length(accounts) == 1
      assert hd(accounts).name == "Active"
      assert hd(accounts).archived == false
    end

    test "returns empty list when no accounts" do
      assert Accounts.list_accounts() == []
    end

    test "returns enriched fields (balance, transaction_count, last_import_at)" do
      insert_account(%{name: "A", bank: "b", type: "checking", initial_balance: 100})

      [account] = Accounts.list_accounts()

      assert account.balance == "100"
      assert account.transaction_count == 0
      assert account.last_import_at == nil
    end

    test "formats completed import timestamp and nil initial_balance fallback" do
      account = insert_account(%{name: "Raw", bank: "b", type: "checking"})

      Repo.update_all(
        from(a in Account, where: a.id == ^account.id),
        set: [initial_balance: nil]
      )

      %Import{}
      |> Import.changeset(%{account_id: account.id, filename: "x.csv", status: "completed"})
      |> Repo.insert!()

      [listed] = Accounts.list_accounts()
      assert listed.initial_balance == "0.00"
      assert listed.last_import_at =~ "T"
      assert String.ends_with?(listed.last_import_at, "Z")
    end
  end

  describe "get_account/1" do
    test "returns account with computed balance when found" do
      acc = insert_account(%{name: "Boursorama", bank: "boursorama", type: "checking"})

      assert {:ok, account} = Accounts.get_account(acc.id)
      assert account.id == acc.id
      assert account.name == "Boursorama"
      assert account.balance == "0"
      assert account.transaction_count == 0
    end

    test "balance equals initial_balance plus sum of transaction amounts" do
      account =
        insert_account(%{name: "Savings", bank: "b", type: "savings", initial_balance: "1000"})

      insert_transaction(%{account_id: account.id, amount: Decimal.new("500"), source: "manual"})
      insert_transaction(%{account_id: account.id, amount: Decimal.new("-200"), source: "manual"})

      assert {:ok, enriched} = Accounts.get_account(account.id)
      # 1000 + 500 - 200 = 1300
      assert enriched.balance == "1300"
      assert enriched.transaction_count == 2
    end

    test "last_import_at reflects the most recent completed import" do
      account = insert_account(%{name: "Test", bank: "boursorama", type: "checking"})
      insert_import(%{account_id: account.id, status: "completed"})

      assert {:ok, enriched} = Accounts.get_account(account.id)
      assert enriched.last_import_at != nil
    end

    test "last_import_at ignores non-completed imports" do
      account = insert_account(%{name: "Test", bank: "b", type: "checking"})
      insert_import(%{account_id: account.id, status: "pending"})
      insert_import(%{account_id: account.id, status: "failed"})

      assert {:ok, enriched} = Accounts.get_account(account.id)
      assert enriched.last_import_at == nil
    end

    test "returns error when not found" do
      assert {:error, :not_found} = Accounts.get_account(Ecto.UUID.generate())
    end
  end

  describe "fetch_account/1" do
    test "returns ok with raw account struct when found" do
      account = insert_account(%{name: "Test", bank: "b", type: "checking"})

      assert {:ok, found} = Accounts.fetch_account(account.id)
      assert found.id == account.id
      assert %Account{} = found
    end

    test "returns not_found when account does not exist" do
      assert {:error, :not_found} = Accounts.fetch_account(Ecto.UUID.generate())
    end
  end

  describe "create_account/1" do
    test "creates account with required fields" do
      attrs = %{name: "Revolut", bank: "revolut", type: "checking"}

      assert {:ok, %Account{} = account} = Accounts.create_account(attrs)
      assert account.name == "Revolut"
      assert account.bank == "revolut"
      assert account.type == "checking"
      assert Decimal.equal?(account.initial_balance, Decimal.new(0))
      assert account.currency == "EUR"
      assert account.archived == false
    end

    test "creates account with optional fields" do
      attrs = %{
        name: "Savings",
        bank: "ce",
        type: "savings",
        initial_balance: 500,
        currency: "EUR"
      }

      assert {:ok, %Account{} = account} = Accounts.create_account(attrs)
      assert account.initial_balance == Decimal.new(500)
    end

    test "validates required fields" do
      assert {:error, changeset} = Accounts.create_account(%{})
      assert %{name: [_], bank: [_], type: [_]} = errors_on(changeset)
    end

    test "validates type enum" do
      assert {:error, changeset} =
               Accounts.create_account(%{name: "X", bank: "Y", type: "invalid"})

      assert %{type: [_]} = errors_on(changeset)
    end

    test "validates currency inclusion" do
      assert {:error, changeset} =
               Accounts.create_account(%{
                 name: "X",
                 bank: "Y",
                 type: "checking",
                 currency: "XYZ"
               })

      assert %{currency: [_]} = errors_on(changeset)
    end
  end

  describe "update_account/2" do
    test "updates account fields" do
      account = insert_account(%{name: "Old", bank: "b", type: "checking"})

      assert {:ok, updated} = Accounts.update_account(account, %{name: "New"})
      assert updated.name == "New"
    end
  end

  describe "archive_account/1" do
    test "archives by struct" do
      account = insert_account(%{name: "To Archive", bank: "b", type: "checking"})

      assert {:ok, archived} = Accounts.archive_account(account)
      assert archived.archived == true
    end

    test "archives by id" do
      account = insert_account(%{name: "To Archive", bank: "b", type: "checking"})

      assert {:ok, archived} = Accounts.archive_account(account.id)
      assert archived.archived == true
    end

    test "returns not_found when archiving non-existent id" do
      assert {:error, :not_found} = Accounts.archive_account(Ecto.UUID.generate())
    end
  end
end
