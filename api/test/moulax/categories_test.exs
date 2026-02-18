defmodule Moulax.CategoriesTest do
  use Moulax.DataCase, async: true

  alias Moulax.Categories
  alias Moulax.Categories.Category
  alias Moulax.Repo

  describe "list_categories/0" do
    test "returns all categories ordered by name" do
      insert_category(%{name: "Zebra", color: "#FF0000"})
      insert_category(%{name: "Alpha", color: "#00FF00"})

      categories = Categories.list_categories()

      assert length(categories) == 2
      assert Enum.map(categories, & &1.name) == ["Alpha", "Zebra"]
    end

    test "returns empty list when no categories" do
      assert Categories.list_categories() == []
    end
  end

  describe "get_category/1" do
    test "returns category when found" do
      cat = insert_category(%{name: "Food", color: "#4CAF50"})

      assert {:ok, %Category{} = found} = Categories.get_category(cat.id)
      assert found.id == cat.id
      assert found.name == "Food"
    end

    test "returns error when not found" do
      assert {:error, :not_found} = Categories.get_category(Ecto.UUID.generate())
    end
  end

  describe "create_category/1" do
    test "creates category with valid attrs" do
      attrs = %{name: "Transport", color: "#2196F3"}

      assert {:ok, %Category{} = cat} = Categories.create_category(attrs)
      assert cat.name == "Transport"
      assert cat.color == "#2196F3"
    end

    test "returns error when name is missing" do
      assert {:error, changeset} = Categories.create_category(%{color: "#FF0000"})
      assert %{name: [_]} = errors_on(changeset)
    end

    test "returns error when color is missing" do
      assert {:error, changeset} = Categories.create_category(%{name: "Food"})
      assert %{color: [_]} = errors_on(changeset)
    end

    test "returns error for invalid hex color" do
      assert {:error, changeset} = Categories.create_category(%{name: "Food", color: "red"})
      assert %{color: [_]} = errors_on(changeset)
    end

    test "returns error for duplicate name" do
      insert_category(%{name: "Food", color: "#FF0000"})

      assert {:error, changeset} = Categories.create_category(%{name: "Food", color: "#00FF00"})
      assert %{name: [_]} = errors_on(changeset)
    end
  end

  describe "update_category/2" do
    test "updates category with valid attrs" do
      cat = insert_category(%{name: "Old", color: "#FF0000"})

      assert {:ok, %Category{} = updated} =
               Categories.update_category(cat, %{name: "New", color: "#00FF00"})

      assert updated.name == "New"
      assert updated.color == "#00FF00"
    end

    test "returns error for invalid color" do
      cat = insert_category(%{name: "Food", color: "#FF0000"})

      assert {:error, changeset} = Categories.update_category(cat, %{color: "nope"})
      assert %{color: [_]} = errors_on(changeset)
    end

    test "returns error for duplicate name" do
      insert_category(%{name: "Existing", color: "#FF0000"})
      cat = insert_category(%{name: "Other", color: "#00FF00"})

      assert {:error, changeset} = Categories.update_category(cat, %{name: "Existing"})
      assert %{name: [_]} = errors_on(changeset)
    end
  end

  describe "delete_category/1" do
    test "deletes the category" do
      cat = insert_category(%{name: "ToDelete", color: "#FF0000"})

      assert {:ok, %Category{}} = Categories.delete_category(cat)
      assert {:error, :not_found} = Categories.get_category(cat.id)
    end

    test "nullifies category_id on associated transactions" do
      cat = insert_category(%{name: "Food", color: "#4CAF50"})
      account = insert_account()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {1, _} =
        Repo.insert_all("transactions", [
          %{
            id: Ecto.UUID.bingenerate(),
            account_id: Ecto.UUID.dump!(account.id),
            date: ~D[2026-01-15],
            label: "Grocery",
            original_label: "Grocery",
            amount: Decimal.new("42.50"),
            currency: "EUR",
            category_id: Ecto.UUID.dump!(cat.id),
            source: "manual",
            inserted_at: now,
            updated_at: now
          }
        ])

      assert {:ok, _} = Categories.delete_category(cat)

      [tx] = Repo.all(from(t in "transactions", select: %{category_id: t.category_id}))
      assert tx.category_id == nil
    end
  end

  defp insert_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert!()
  end

  defp insert_account do
    alias Moulax.Accounts.Account

    %Account{}
    |> Account.changeset(%{
      "name" => "Test Account",
      "bank" => "test",
      "type" => "checking"
    })
    |> Repo.insert!()
  end
end
