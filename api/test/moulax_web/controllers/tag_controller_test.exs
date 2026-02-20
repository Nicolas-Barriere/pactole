defmodule MoulaxWeb.TagControllerTest do
  use MoulaxWeb.ConnCase, async: true

  @create_attrs %{"name" => "Alimentation", "color" => "#4CAF50"}
  @update_attrs %{"name" => "Updated Name", "color" => "#FF0000"}
  @invalid_attrs %{"name" => nil, "color" => nil}

  describe "index" do
    test "lists all tags", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/tags")
      assert json_response(conn, 200) == []
    end
  end

  describe "create tag" do
    test "renders tag when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/tags", @create_attrs)

      assert %{
               "id" => id,
               "name" => "Alimentation",
               "color" => "#4CAF50"
             } = json_response(conn, 201)

      assert [location] = get_resp_header(conn, "location")
      assert location =~ "/api/v1/tags/"

      conn = get(conn, ~p"/api/v1/tags/#{id}")
      assert %{"id" => ^id, "name" => "Alimentation"} = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/tags", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors for duplicate name", %{conn: conn} do
      insert_tag(%{name: "Alimentation", color: "#4CAF50"})

      conn = post(conn, ~p"/api/v1/tags", @create_attrs)
      assert json_response(conn, 422)["errors"]["name"] != nil
    end
  end

  describe "show tag" do
    test "renders tag when found", %{conn: conn} do
      tag = insert_tag(%{name: "Alimentation", color: "#4CAF50"})

      conn = get(conn, ~p"/api/v1/tags/#{tag.id}")
      data = json_response(conn, 200)

      assert data["id"] == tag.id
      assert data["name"] == "Alimentation"
      assert data["color"] == "#4CAF50"
    end

    test "renders 404 when tag not found", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/tags/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  describe "update tag" do
    test "renders tag when data is valid", %{conn: conn} do
      tag = insert_tag(%{name: "Alimentation", color: "#4CAF50"})

      conn = put(conn, ~p"/api/v1/tags/#{tag.id}", @update_attrs)
      data = json_response(conn, 200)
      assert data["id"] == tag.id
      assert data["name"] == "Updated Name"
      assert data["color"] == "#FF0000"
    end

    test "renders 404 when tag not found", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/tags/#{Ecto.UUID.generate()}", @update_attrs)
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "renders 422 when data is invalid", %{conn: conn} do
      tag = insert_tag()
      conn = put(conn, ~p"/api/v1/tags/#{tag.id}", %{"color" => "bad"})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete tag" do
    test "deletes chosen tag", %{conn: conn} do
      tag = insert_tag()

      conn = delete(conn, ~p"/api/v1/tags/#{tag.id}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/v1/tags/#{tag.id}")
      assert json_response(conn, 404)
    end

    test "renders 404 when tag not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/tags/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end
end
