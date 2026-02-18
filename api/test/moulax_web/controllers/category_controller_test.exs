defmodule MoulaxWeb.CategoryControllerTest do
  use MoulaxWeb.ConnCase, async: true

  alias Moulax.Categories.Category
  alias Moulax.Repo

  @create_attrs %{"name" => "Alimentation", "color" => "#4CAF50"}
  @update_attrs %{"name" => "Updated Name", "color" => "#FF0000"}
  @invalid_attrs %{"name" => nil, "color" => nil}

  describe "index" do
    test "lists all categories", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/categories")
      assert json_response(conn, 200) == []
    end
  end

  describe "create category" do
    test "renders category when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/categories", @create_attrs)

      assert %{
               "id" => id,
               "name" => "Alimentation",
               "color" => "#4CAF50"
             } = json_response(conn, 201)

      assert [location] = get_resp_header(conn, "location")
      assert location =~ "/api/v1/categories/"

      conn = get(conn, ~p"/api/v1/categories/#{id}")
      assert %{"id" => ^id, "name" => "Alimentation"} = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/categories", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    test "renders errors for duplicate name", %{conn: conn} do
      insert_category()

      conn = post(conn, ~p"/api/v1/categories", @create_attrs)
      assert json_response(conn, 422)["errors"]["name"] != nil
    end
  end

  describe "show category" do
    test "renders category when found", %{conn: conn} do
      category = insert_category()

      conn = get(conn, ~p"/api/v1/categories/#{category.id}")
      data = json_response(conn, 200)

      assert data["id"] == category.id
      assert data["name"] == "Alimentation"
      assert data["color"] == "#4CAF50"
    end

    test "renders 404 when category not found", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/categories/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  describe "update category" do
    test "renders category when data is valid", %{conn: conn} do
      category = insert_category()

      conn = put(conn, ~p"/api/v1/categories/#{category.id}", @update_attrs)
      data = json_response(conn, 200)
      assert data["id"] == category.id
      assert data["name"] == "Updated Name"
      assert data["color"] == "#FF0000"
    end

    test "renders 404 when category not found", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/categories/#{Ecto.UUID.generate()}", @update_attrs)
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "renders 422 when data is invalid", %{conn: conn} do
      category = insert_category()
      conn = put(conn, ~p"/api/v1/categories/#{category.id}", %{"color" => "bad"})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete category" do
    test "deletes chosen category", %{conn: conn} do
      category = insert_category()

      conn = delete(conn, ~p"/api/v1/categories/#{category.id}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/v1/categories/#{category.id}")
      assert json_response(conn, 404)
    end

    test "renders 404 when category not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/categories/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  defp insert_category do
    %Category{}
    |> Category.changeset(%{"name" => "Alimentation", "color" => "#4CAF50"})
    |> Repo.insert!()
  end
end
