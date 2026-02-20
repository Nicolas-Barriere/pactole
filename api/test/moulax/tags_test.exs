defmodule Moulax.TagsTest do
  use Moulax.DataCase, async: true

  alias Moulax.Tags
  alias Moulax.Tags.Tag
  alias Moulax.Tags.TransactionTag

  describe "list_tags/0" do
    test "returns all tags ordered by name" do
      insert_tag(%{name: "Zebra", color: "#FF0000"})
      insert_tag(%{name: "Alpha", color: "#00FF00"})

      tags = Tags.list_tags()

      assert length(tags) == 2
      assert Enum.map(tags, & &1.name) == ["Alpha", "Zebra"]
    end

    test "returns empty list when no tags" do
      assert Tags.list_tags() == []
    end
  end

  describe "get_tag/1" do
    test "returns tag when found" do
      tag = insert_tag(%{name: "Food", color: "#4CAF50"})

      assert {:ok, %Tag{} = found} = Tags.get_tag(tag.id)
      assert found.id == tag.id
      assert found.name == "Food"
    end

    test "returns error when not found" do
      assert {:error, :not_found} = Tags.get_tag(Ecto.UUID.generate())
    end
  end

  describe "create_tag/1" do
    test "creates tag with valid attrs" do
      attrs = %{name: "Transport", color: "#2196F3"}

      assert {:ok, %Tag{} = tag} = Tags.create_tag(attrs)
      assert tag.name == "Transport"
      assert tag.color == "#2196F3"
    end

    test "returns error when name is missing" do
      assert {:error, changeset} = Tags.create_tag(%{color: "#FF0000"})
      assert %{name: [_]} = errors_on(changeset)
    end

    test "returns error when color is missing" do
      assert {:error, changeset} = Tags.create_tag(%{name: "Food"})
      assert %{color: [_]} = errors_on(changeset)
    end

    test "returns error for invalid hex color" do
      assert {:error, changeset} = Tags.create_tag(%{name: "Food", color: "red"})
      assert %{color: [_]} = errors_on(changeset)
    end

    test "returns error for duplicate name" do
      insert_tag(%{name: "Food", color: "#FF0000"})

      assert {:error, changeset} = Tags.create_tag(%{name: "Food", color: "#00FF00"})
      assert %{name: [_]} = errors_on(changeset)
    end
  end

  describe "update_tag/2" do
    test "updates tag with valid attrs" do
      tag = insert_tag(%{name: "Old", color: "#FF0000"})

      assert {:ok, %Tag{} = updated} =
               Tags.update_tag(tag, %{name: "New", color: "#00FF00"})

      assert updated.name == "New"
      assert updated.color == "#00FF00"
    end

    test "returns error for invalid color" do
      tag = insert_tag(%{name: "Food", color: "#FF0000"})

      assert {:error, changeset} = Tags.update_tag(tag, %{color: "nope"})
      assert %{color: [_]} = errors_on(changeset)
    end

    test "returns error for duplicate name" do
      insert_tag(%{name: "Existing", color: "#FF0000"})
      tag = insert_tag(%{name: "Other", color: "#00FF00"})

      assert {:error, changeset} = Tags.update_tag(tag, %{name: "Existing"})
      assert %{name: [_]} = errors_on(changeset)
    end
  end

  describe "delete_tag/1" do
    test "deletes the tag" do
      tag = insert_tag(%{name: "ToDelete", color: "#FF0000"})

      assert {:ok, %Tag{}} = Tags.delete_tag(tag)
      assert {:error, :not_found} = Tags.get_tag(tag.id)
    end

    test "removes transaction_tags associations" do
      tag = insert_tag(%{name: "Food", color: "#4CAF50"})
      account = insert_account()

      tx =
        insert_transaction(%{
          account_id: account.id,
          label: "Grocery",
          amount: Decimal.new("42.50"),
          tag_ids: [tag.id]
        })

      assert Repo.aggregate(TransactionTag, :count) == 1

      assert {:ok, _} = Tags.delete_tag(tag)

      assert Repo.aggregate(TransactionTag, :count) == 0
      assert Repo.get!(Moulax.Transactions.Transaction, tx.id)
    end

    test "raises ConstraintError when tag has linked tagging rules" do
      tag = insert_tag(%{name: "WithRules", color: "#FF0000"})
      insert_rule(%{keyword: "SPOTIFY", tag_id: tag.id, priority: 5})

      assert_raise Ecto.ConstraintError, fn ->
        Tags.delete_tag(tag)
      end
    end
  end
end
