defmodule MoulaxWeb.AccountControllerTest do
  use MoulaxWeb.ConnCase, async: true

  alias Moulax.Accounts.Account
  alias Moulax.Repo

  @create_attrs %{
    "name" => "Boursorama Checking",
    "bank" => "boursorama",
    "type" => "checking",
    "initial_balance" => "0",
    "currency" => "EUR"
  }
  @update_attrs %{"name" => "Updated Name"}
  @invalid_attrs %{"name" => nil, "bank" => nil, "type" => "invalid"}

  describe "index" do
    test "lists all non-archived accounts", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/accounts")
      assert json_response(conn, 200) == []
    end

    test "archived accounts are excluded from list", %{conn: conn} do
      {:ok, _} =
        %Account{}
        |> Account.changeset(%{
          "name" => "Archived",
          "bank" => "b",
          "type" => "checking",
          "archived" => true
        })
        |> Repo.insert()

      conn = get(conn, ~p"/api/v1/accounts")
      assert json_response(conn, 200) == []
    end
  end

  describe "create account" do
    test "renders account when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/accounts", @create_attrs)

      assert %{
               "id" => id,
               "name" => "Boursorama Checking",
               "bank" => "boursorama",
               "type" => "checking"
             } =
               json_response(conn, 201)

      assert [location] = get_resp_header(conn, "location")
      assert location =~ "/api/v1/accounts/"

      conn = get(conn, ~p"/api/v1/accounts/#{id}")
      assert %{"id" => ^id, "balance" => "0", "transaction_count" => 0} = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/accounts", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "show account" do
    test "renders account when found", %{conn: conn} do
      account = insert_account()

      conn = get(conn, ~p"/api/v1/accounts/#{account.id}")
      data = json_response(conn, 200)

      assert data["id"] == account.id
      assert data["name"] == account.name
      assert data["balance"] == "0"
      assert data["transaction_count"] == 0
    end

    test "renders 404 when account not found", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/accounts/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  describe "update account" do
    test "renders account when data is valid", %{conn: conn} do
      account = insert_account()

      conn = put(conn, ~p"/api/v1/accounts/#{account.id}", @update_attrs)
      data = json_response(conn, 200)
      assert data["id"] == account.id
      assert data["name"] == "Updated Name"
    end

    test "renders 404 when account not found", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/accounts/#{Ecto.UUID.generate()}", @update_attrs)
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "renders 422 when data is invalid", %{conn: conn} do
      account = insert_account()
      conn = put(conn, ~p"/api/v1/accounts/#{account.id}", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete account" do
    test "deletes (archives) chosen account", %{conn: conn} do
      account = insert_account()

      conn = delete(conn, ~p"/api/v1/accounts/#{account.id}")
      assert response(conn, 204)

      # Account is soft-deleted (archived); list should not return it
      conn = get(conn, ~p"/api/v1/accounts")
      assert json_response(conn, 200) == []
    end

    test "renders 404 when account not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/accounts/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  defp insert_account do
    %Account{}
    |> Account.changeset(%{"name" => "Test", "bank" => "test", "type" => "checking"})
    |> Repo.insert!()
  end
end
