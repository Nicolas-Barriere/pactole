defmodule Moulax.Tags.RulesTest do
  use Moulax.DataCase, async: true

  alias Moulax.Tags.Rules

  describe "list_rules/0" do
    test "returns all rules ordered by priority desc" do
      tag = insert_tag(%{name: "Transport", color: "#3b82f6"})
      insert_rule(%{keyword: "LOW", tag_id: tag.id, priority: 1})
      insert_rule(%{keyword: "HIGH", tag_id: tag.id, priority: 10})

      rules = Rules.list_rules()
      assert length(rules) == 2
      assert hd(rules).keyword == "HIGH"
      assert hd(rules).priority == 10
    end

    test "returns empty list when no rules" do
      assert Rules.list_rules() == []
    end

    test "includes tag with id, name, color" do
      tag = insert_tag(%{name: "Alimentation", color: "#22c55e"})
      insert_rule(%{keyword: "CARREFOUR", tag_id: tag.id, priority: 5})

      [rule] = Rules.list_rules()
      assert rule.keyword == "CARREFOUR"
      assert rule.tag.id == tag.id
      assert rule.tag.name == "Alimentation"
      assert rule.tag.color == "#22c55e"
    end
  end

  describe "create_rule/1" do
    test "creates rule with keyword and tag_id" do
      tag = insert_tag(%{name: "Abonnements", color: "#f59e0b"})

      assert {:ok, rule} = Rules.create_rule(%{keyword: "SPOTIFY", tag_id: tag.id})
      assert rule.keyword == "SPOTIFY"
      assert rule.tag.id == tag.id
      assert rule.priority == 0
    end

    test "creates rule with custom priority" do
      tag = insert_tag(%{name: "Revenus", color: "#10b981"})

      assert {:ok, rule} =
               Rules.create_rule(%{keyword: "VIR SEPA", tag_id: tag.id, priority: 100})

      assert rule.priority == 100
    end

    test "validates required fields" do
      assert {:error, changeset} = Rules.create_rule(%{})
      assert %{keyword: [_], tag_id: [_]} = errors_on(changeset)
    end

    test "returns fully formatted tag payload" do
      tag = insert_tag(%{name: "Utilities", color: "#0ea5e9"})

      assert {:ok, rule} = Rules.create_rule(%{keyword: "EDF", tag_id: tag.id, priority: 7})

      assert rule.keyword == "EDF"
      assert rule.priority == 7
      assert rule.tag.id == tag.id
      assert rule.tag.name == "Utilities"
      assert rule.tag.color == "#0ea5e9"
    end
  end

  describe "update_rule/2" do
    test "updates keyword and priority" do
      tag = insert_tag(%{name: "Transport", color: "#3b82f6"})
      rule = insert_rule(%{keyword: "SNCF", tag_id: tag.id, priority: 5})

      assert {:ok, updated} = Rules.update_rule(rule, %{keyword: "TGV", priority: 20})
      assert updated.keyword == "TGV"
      assert updated.priority == 20
    end

    test "returns changeset error when data is invalid" do
      tag = insert_tag(%{name: "Transport", color: "#3b82f6"})
      rule = insert_rule(%{keyword: "SNCF", tag_id: tag.id, priority: 5})

      assert {:error, changeset} = Rules.update_rule(rule, %{keyword: nil})
      assert %{keyword: [_]} = errors_on(changeset)
    end

    test "can reassign tag and returns updated tag payload" do
      from_tag = insert_tag(%{name: "Food", color: "#22c55e"})
      to_tag = insert_tag(%{name: "Health", color: "#ef4444"})
      rule = insert_rule(%{keyword: "PHARMACY", tag_id: from_tag.id, priority: 3})

      assert {:ok, updated} = Rules.update_rule(rule, %{tag_id: to_tag.id, priority: 9})

      assert updated.priority == 9
      assert updated.tag.id == to_tag.id
      assert updated.tag.name == "Health"
      assert updated.tag.color == "#ef4444"
    end

    test "updates only keyword and keeps tag payload preloaded" do
      tag = insert_tag(%{name: "Bills", color: "#64748b"})
      rule = insert_rule(%{keyword: "EDF", tag_id: tag.id, priority: 1})

      assert {:ok, updated} = Rules.update_rule(rule, %{keyword: "ENGIE"})

      assert updated.keyword == "ENGIE"
      assert updated.tag.id == tag.id
      assert updated.tag.name == "Bills"
      assert updated.tag.color == "#64748b"
    end
  end

  describe "get_rule/1" do
    test "returns formatted rule with tag when found" do
      tag = insert_tag(%{name: "Phone", color: "#8b5cf6"})
      rule = insert_rule(%{keyword: "FREE", tag_id: tag.id, priority: 4})

      assert {:ok, got} = Rules.get_rule(rule.id)
      assert got.id == rule.id
      assert got.keyword == "FREE"
      assert got.priority == 4
      assert got.tag.id == tag.id
      assert got.tag.name == "Phone"
      assert got.tag.color == "#8b5cf6"
    end

    test "returns not_found when missing" do
      assert {:error, :not_found} = Rules.get_rule(Ecto.UUID.generate())
    end
  end

  describe "delete_rule/1" do
    test "deletes by id" do
      tag = insert_tag(%{name: "Other", color: "#6b7280"})
      rule = insert_rule(%{keyword: "X", tag_id: tag.id, priority: 0})

      assert {:ok, _} = Rules.delete_rule(rule.id)
      assert Rules.list_rules() == []
    end

    test "returns not_found when id does not exist" do
      assert {:error, :not_found} = Rules.delete_rule(Ecto.UUID.generate())
    end

    test "deletes by struct" do
      tag = insert_tag(%{name: "Other", color: "#6b7280"})
      rule = insert_rule(%{keyword: "Y", tag_id: tag.id, priority: 0})

      assert {:ok, _} = Rules.delete_rule(rule)
      assert Rules.list_rules() == []
    end
  end

  describe "match_tags/1" do
    test "returns tag_ids when keyword is substring of label" do
      transport = insert_tag(%{name: "Transport", color: "#3b82f6"})
      insert_rule(%{keyword: "SNCF", tag_id: transport.id, priority: 10})

      assert Rules.match_tags("CARTE 15/02 SNCF PARIS") == [transport.id]
    end

    test "match is case-insensitive" do
      alimentation = insert_tag(%{name: "Alimentation", color: "#22c55e"})
      insert_rule(%{keyword: "carrefour", tag_id: alimentation.id, priority: 10})

      assert Rules.match_tags("CARTE 10/02 CARREFOUR CITY") == [alimentation.id]
      assert Rules.match_tags("carrefour market") == [alimentation.id]
    end

    test "returns all matching tag_ids (multiple rules can match)" do
      transport = insert_tag(%{name: "Transport", color: "#111111"})
      travel = insert_tag(%{name: "Travel", color: "#222222"})
      insert_rule(%{keyword: "SNCF", tag_id: transport.id, priority: 10})
      insert_rule(%{keyword: "PARIS", tag_id: travel.id, priority: 5})

      result = Rules.match_tags("SNCF PARIS TGV")
      assert transport.id in result
      assert travel.id in result
    end

    test "deduplicates tag_ids when multiple rules point to same tag" do
      tag = insert_tag(%{name: "Transport", color: "#222222"})
      insert_rule(%{keyword: "SNCF", tag_id: tag.id, priority: 10})
      insert_rule(%{keyword: "TGV", tag_id: tag.id, priority: 5})

      assert Rules.match_tags("SNCF TGV PARIS") == [tag.id]
    end

    test "returns empty list when no rule matches" do
      tag = insert_tag(%{name: "Transport", color: "#3b82f6"})
      insert_rule(%{keyword: "SNCF", tag_id: tag.id, priority: 10})

      assert Rules.match_tags("CARTE 10/02 CARREFOUR CITY") == []
      assert Rules.match_tags("RANDOM LABEL") == []
    end

    test "returns empty list for nil or empty label" do
      assert Rules.match_tags(nil) == []
      assert Rules.match_tags("") == []
    end
  end
end
