defmodule Moulax.Categories.RulesTest do
  use Moulax.DataCase, async: true

  alias Moulax.Categories.Rules

  describe "list_rules/0" do
    test "returns all rules ordered by priority desc" do
      cat = insert_category(%{name: "Transport", color: "#3b82f6"})
      insert_rule(%{keyword: "LOW", category_id: cat.id, priority: 1})
      insert_rule(%{keyword: "HIGH", category_id: cat.id, priority: 10})

      rules = Rules.list_rules()
      assert length(rules) == 2
      assert hd(rules).keyword == "HIGH"
      assert hd(rules).priority == 10
    end

    test "returns empty list when no rules" do
      assert Rules.list_rules() == []
    end

    test "includes category with id, name, color" do
      cat = insert_category(%{name: "Alimentation", color: "#22c55e"})
      insert_rule(%{keyword: "CARREFOUR", category_id: cat.id, priority: 5})

      [rule] = Rules.list_rules()
      assert rule.keyword == "CARREFOUR"
      assert rule.category.id == cat.id
      assert rule.category.name == "Alimentation"
      assert rule.category.color == "#22c55e"
    end
  end

  describe "create_rule/1" do
    test "creates rule with keyword and category_id" do
      cat = insert_category(%{name: "Abonnements", color: "#f59e0b"})

      assert {:ok, rule} = Rules.create_rule(%{keyword: "SPOTIFY", category_id: cat.id})
      assert rule.keyword == "SPOTIFY"
      assert rule.category.id == cat.id
      assert rule.priority == 0
    end

    test "creates rule with custom priority" do
      cat = insert_category(%{name: "Revenus", color: "#10b981"})

      assert {:ok, rule} =
               Rules.create_rule(%{keyword: "VIR SEPA", category_id: cat.id, priority: 100})

      assert rule.priority == 100
    end

    test "validates required fields" do
      assert {:error, changeset} = Rules.create_rule(%{})
      assert %{keyword: [_], category_id: [_]} = errors_on(changeset)
    end

    test "returns fully formatted category payload" do
      cat = insert_category(%{name: "Utilities", color: "#0ea5e9"})

      assert {:ok, rule} = Rules.create_rule(%{keyword: "EDF", category_id: cat.id, priority: 7})

      assert rule.keyword == "EDF"
      assert rule.priority == 7
      assert rule.category.id == cat.id
      assert rule.category.name == "Utilities"
      assert rule.category.color == "#0ea5e9"
    end
  end

  describe "update_rule/2" do
    test "updates keyword and priority" do
      cat = insert_category(%{name: "Transport", color: "#3b82f6"})
      rule = insert_rule(%{keyword: "SNCF", category_id: cat.id, priority: 5})

      assert {:ok, updated} = Rules.update_rule(rule, %{keyword: "TGV", priority: 20})
      assert updated.keyword == "TGV"
      assert updated.priority == 20
    end

    test "returns changeset error when data is invalid" do
      cat = insert_category(%{name: "Transport", color: "#3b82f6"})
      rule = insert_rule(%{keyword: "SNCF", category_id: cat.id, priority: 5})

      assert {:error, changeset} = Rules.update_rule(rule, %{keyword: nil})
      assert %{keyword: [_]} = errors_on(changeset)
    end

    test "can reassign category and returns updated category payload" do
      from_cat = insert_category(%{name: "Food", color: "#22c55e"})
      to_cat = insert_category(%{name: "Health", color: "#ef4444"})
      rule = insert_rule(%{keyword: "PHARMACY", category_id: from_cat.id, priority: 3})

      assert {:ok, updated} = Rules.update_rule(rule, %{category_id: to_cat.id, priority: 9})

      assert updated.priority == 9
      assert updated.category.id == to_cat.id
      assert updated.category.name == "Health"
      assert updated.category.color == "#ef4444"
    end
  end

  describe "delete_rule/1" do
    test "deletes by id" do
      cat = insert_category(%{name: "Other", color: "#6b7280"})
      rule = insert_rule(%{keyword: "X", category_id: cat.id, priority: 0})

      assert {:ok, _} = Rules.delete_rule(rule.id)
      assert Rules.list_rules() == []
    end

    test "returns not_found when id does not exist" do
      assert {:error, :not_found} = Rules.delete_rule(Ecto.UUID.generate())
    end

    test "deletes by struct" do
      cat = insert_category(%{name: "Other", color: "#6b7280"})
      rule = insert_rule(%{keyword: "Y", category_id: cat.id, priority: 0})

      assert {:ok, _} = Rules.delete_rule(rule)
      assert Rules.list_rules() == []
    end
  end

  describe "match_category/1" do
    test "returns category_id when keyword is substring of label" do
      transport = insert_category(%{name: "Transport", color: "#3b82f6"})
      insert_rule(%{keyword: "SNCF", category_id: transport.id, priority: 10})

      assert Rules.match_category("CARTE 15/02 SNCF PARIS") == transport.id
    end

    test "match is case-insensitive" do
      alimentation = insert_category(%{name: "Alimentation", color: "#22c55e"})
      insert_rule(%{keyword: "carrefour", category_id: alimentation.id, priority: 10})

      assert Rules.match_category("CARTE 10/02 CARREFOUR CITY") == alimentation.id
      assert Rules.match_category("carrefour market") == alimentation.id
    end

    test "higher priority wins when multiple rules match" do
      cat_a = insert_category(%{name: "Category A", color: "#111111"})
      cat_b = insert_category(%{name: "Category B", color: "#222222"})
      insert_rule(%{keyword: "FOO", category_id: cat_a.id, priority: 5})
      insert_rule(%{keyword: "FOOBAR", category_id: cat_b.id, priority: 10})

      # "FOOBAR" has higher priority, so it should match first
      assert Rules.match_category("payment FOOBAR xyz") == cat_b.id
    end

    test "first match by priority order wins" do
      cat_low = insert_category(%{name: "Low", color: "#111111"})
      cat_high = insert_category(%{name: "High", color: "#222222"})
      insert_rule(%{keyword: "SPOTIFY", category_id: cat_low.id, priority: 1})
      insert_rule(%{keyword: "SPOTIFY", category_id: cat_high.id, priority: 10})

      assert Rules.match_category("SPOTIFY AB") == cat_high.id
    end

    test "returns nil when no rule matches" do
      cat = insert_category(%{name: "Transport", color: "#3b82f6"})
      insert_rule(%{keyword: "SNCF", category_id: cat.id, priority: 10})

      assert Rules.match_category("CARTE 10/02 CARREFOUR CITY") == nil
      assert Rules.match_category("RANDOM LABEL") == nil
    end

    test "returns nil for nil or empty label" do
      assert Rules.match_category(nil) == nil
      assert Rules.match_category("") == nil
    end
  end
end
