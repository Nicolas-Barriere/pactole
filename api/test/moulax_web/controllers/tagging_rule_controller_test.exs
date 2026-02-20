defmodule MoulaxWeb.TaggingRuleControllerTest do
  use MoulaxWeb.ConnCase, async: true

  @create_attrs %{
    "keyword" => "SNCF",
    "tag_id" => nil,
    "priority" => 10
  }
  @update_attrs %{"keyword" => "TGV", "priority" => 20}
  @invalid_attrs %{"keyword" => nil, "tag_id" => nil}

  setup do
    tag = insert_tag(%{name: "Transport", color: "#3b82f6"})
    %{tag: tag}
  end

  describe "index" do
    test "lists all tagging rules", %{conn: conn, tag: tag} do
      insert_rule(%{keyword: "SNCF", tag_id: tag.id, priority: 10})

      conn = get(conn, ~p"/api/v1/tagging-rules")
      data = json_response(conn, 200)
      assert length(data) == 1
      rule = hd(data)
      assert rule["keyword"] == "SNCF"
      assert rule["priority"] == 10
      assert rule["tag"]["id"] == tag.id
      assert rule["tag"]["name"] == "Transport"
      assert rule["tag"]["color"] == "#3b82f6"
    end

    test "returns empty list when no rules", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/tagging-rules")
      assert json_response(conn, 200) == []
    end
  end

  describe "show" do
    test "returns rule when found", %{conn: conn, tag: tag} do
      rule = insert_rule(%{keyword: "SNCF", tag_id: tag.id, priority: 10})

      conn = get(conn, ~p"/api/v1/tagging-rules/#{rule.id}")
      data = json_response(conn, 200)

      assert data["id"] == rule.id
      assert data["keyword"] == "SNCF"
      assert data["priority"] == 10
      assert data["tag"]["id"] == tag.id
      assert data["tag"]["name"] == "Transport"
    end

    test "returns 404 when rule not found", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/tagging-rules/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  describe "create" do
    test "creates rule and returns 201 with location", %{conn: conn, tag: tag} do
      attrs = Map.put(@create_attrs, "tag_id", tag.id)
      conn = post(conn, ~p"/api/v1/tagging-rules", attrs)

      assert %{"id" => _id, "keyword" => "SNCF", "priority" => 10, "tag" => tag_payload} =
               json_response(conn, 201)

      assert tag_payload["id"] == tag.id
      assert tag_payload["name"] == "Transport"
      assert [location] = get_resp_header(conn, "location")
      assert location =~ "/api/v1/tagging-rules/"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/tagging-rules", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update" do
    test "updates rule when data is valid", %{conn: conn, tag: tag} do
      rule = insert_rule(%{keyword: "SNCF", tag_id: tag.id, priority: 5})

      conn = put(conn, ~p"/api/v1/tagging-rules/#{rule.id}", @update_attrs)
      data = json_response(conn, 200)
      assert data["id"] == rule.id
      assert data["keyword"] == "TGV"
      assert data["priority"] == 20
    end

    test "renders 404 when rule not found", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/tagging-rules/#{Ecto.UUID.generate()}", @update_attrs)
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "renders 422 when data is invalid", %{conn: conn, tag: tag} do
      rule = insert_rule(%{keyword: "SNCF", tag_id: tag.id, priority: 5})

      conn =
        put(conn, ~p"/api/v1/tagging-rules/#{rule.id}", %{
          "tag_id" => Ecto.UUID.generate()
        })

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete" do
    test "deletes rule", %{conn: conn, tag: tag} do
      rule = insert_rule(%{keyword: "SNCF", tag_id: tag.id, priority: 10})

      conn = delete(conn, ~p"/api/v1/tagging-rules/#{rule.id}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/v1/tagging-rules")
      assert json_response(conn, 200) == []
    end

    test "renders 404 when rule not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/tagging-rules/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end
end
