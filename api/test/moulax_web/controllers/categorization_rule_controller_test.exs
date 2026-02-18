defmodule MoulaxWeb.CategorizationRuleControllerTest do
  use MoulaxWeb.ConnCase, async: true

  alias Moulax.Categories.CategorizationRule
  alias Moulax.Categories.Category
  alias Moulax.Repo

  @create_attrs %{
    "keyword" => "SNCF",
    "category_id" => nil,
    "priority" => 10
  }
  @update_attrs %{"keyword" => "TGV", "priority" => 20}
  @invalid_attrs %{"keyword" => nil, "category_id" => nil}

  setup do
    cat = insert_category(%{name: "Transport", color: "#3b82f6"})
    %{category: cat}
  end

  describe "index" do
    test "lists all categorization rules", %{conn: conn, category: cat} do
      _rule = insert_rule("SNCF", cat.id, 10)

      conn = get(conn, ~p"/api/v1/categorization-rules")
      data = json_response(conn, 200)
      assert length(data) == 1
      rule = hd(data)
      assert rule["keyword"] == "SNCF"
      assert rule["priority"] == 10
      assert rule["category"]["id"] == cat.id
      assert rule["category"]["name"] == "Transport"
      assert rule["category"]["color"] == "#3b82f6"
    end

    test "returns empty list when no rules", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/categorization-rules")
      assert json_response(conn, 200) == []
    end
  end

  describe "create" do
    test "creates rule and returns 201 with location", %{conn: conn, category: cat} do
      attrs = Map.put(@create_attrs, "category_id", cat.id)
      conn = post(conn, ~p"/api/v1/categorization-rules", attrs)

      assert %{"id" => _id, "keyword" => "SNCF", "priority" => 10, "category" => cat_payload} =
               json_response(conn, 201)

      assert cat_payload["id"] == cat.id
      assert cat_payload["name"] == "Transport"
      assert [location] = get_resp_header(conn, "location")
      assert location =~ "/api/v1/categorization-rules/"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/categorization-rules", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update" do
    test "updates rule when data is valid", %{conn: conn, category: cat} do
      rule = insert_rule("SNCF", cat.id, 5)

      conn = put(conn, ~p"/api/v1/categorization-rules/#{rule.id}", @update_attrs)
      data = json_response(conn, 200)
      assert data["id"] == rule.id
      assert data["keyword"] == "TGV"
      assert data["priority"] == 20
    end

    test "renders 404 when rule not found", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/categorization-rules/#{Ecto.UUID.generate()}", @update_attrs)
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  describe "delete" do
    test "deletes rule", %{conn: conn, category: cat} do
      rule = insert_rule("SNCF", cat.id, 10)

      conn = delete(conn, ~p"/api/v1/categorization-rules/#{rule.id}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/v1/categorization-rules")
      assert json_response(conn, 200) == []
    end

    test "renders 404 when rule not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/categorization-rules/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  defp insert_category(attrs) do
    %Category{name: attrs.name, color: attrs.color}
    |> Repo.insert!()
  end

  defp insert_rule(keyword, category_id, priority) do
    %CategorizationRule{}
    |> CategorizationRule.changeset(%{
      keyword: keyword,
      category_id: category_id,
      priority: priority
    })
    |> Repo.insert!()
  end
end
