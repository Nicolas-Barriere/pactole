defmodule MoulaxWeb.TransactionControllerTest do
  use MoulaxWeb.ConnCase, async: true

  alias Moulax.Transactions.Transaction
  alias Moulax.Accounts.Account
  alias Moulax.Categories.Category
  alias Moulax.Repo

  setup do
    account = insert_account()
    %{account: account}
  end

  describe "index (nested) GET /api/v1/accounts/:account_id/transactions" do
    test "returns paginated data and meta", %{conn: conn, account: account} do
      _tx = insert_transaction(account.id, "2026-02-01", "Shop", "-10.00")

      conn = get(conn, ~p"/api/v1/accounts/#{account.id}/transactions")
      body = json_response(conn, 200)
      assert %{"data" => data, "meta" => meta} = body
      assert length(data) == 1
      assert meta["page"] == 1
      assert meta["per_page"] == 50
      assert meta["total_count"] == 1
      assert meta["total_pages"] == 1
      [tx] = data
      assert tx["label"] == "Shop"
      assert tx["amount"] == "-10.00"
    end

    test "returns empty data when no transactions", %{conn: conn, account: account} do
      conn = get(conn, ~p"/api/v1/accounts/#{account.id}/transactions")
      body = json_response(conn, 200)
      assert body["data"] == []
      assert body["meta"]["total_count"] == 0
    end
  end

  describe "index (global) GET /api/v1/transactions" do
    test "returns all transactions with filters", %{conn: conn, account: account} do
      insert_transaction(account.id, "2026-02-01", "A", "-1")
      insert_transaction(account.id, "2026-02-02", "B", "-2")

      conn = get(conn, ~p"/api/v1/transactions")
      body = json_response(conn, 200)
      assert length(body["data"]) == 2
      assert body["meta"]["total_count"] == 2
    end

    test "accepts query params for filtering", %{conn: conn, account: account} do
      insert_transaction(account.id, "2026-02-01", "CARREFOUR", "-10")
      insert_transaction(account.id, "2026-02-02", "SNCF", "-20")

      conn = get(conn, "/api/v1/transactions?search=carrefour")
      body = json_response(conn, 200)
      assert body["meta"]["total_count"] == 1
      assert hd(body["data"])["label"] == "CARREFOUR"
    end
  end

  describe "show GET /api/v1/transactions/:id" do
    test "returns transaction when found", %{conn: conn, account: account} do
      tx = insert_transaction(account.id, "2026-02-15", "Test", "-42.50")

      conn = get(conn, ~p"/api/v1/transactions/#{tx.id}")
      data = json_response(conn, 200)
      assert data["id"] == tx.id
      assert data["label"] == "Test"
      assert data["amount"] == "-42.50"
    end

    test "returns 404 when not found", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/transactions/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  describe "create POST /api/v1/accounts/:account_id/transactions" do
    test "creates manual transaction and returns 201", %{conn: conn, account: account} do
      conn =
        post(conn, ~p"/api/v1/accounts/#{account.id}/transactions", %{
          "date" => "2026-02-20",
          "label" => "Manual entry",
          "amount" => "-15.00"
        })

      data = json_response(conn, 201)
      assert %{"id" => _id, "label" => "Manual entry", "source" => "manual"} = data
      assert data["amount"] in ["-15.00", "−15.00"]

      assert [location] = get_resp_header(conn, "location")
      assert location =~ "/api/v1/transactions/"
    end

    test "renders 422 when data is invalid", %{conn: conn, account: account} do
      conn = post(conn, ~p"/api/v1/accounts/#{account.id}/transactions", %{})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update PUT /api/v1/transactions/:id" do
    test "updates transaction", %{conn: conn, account: account} do
      tx = insert_transaction(account.id, "2026-02-01", "Old", "-10")
      cat = insert_category()

      conn =
        put(conn, ~p"/api/v1/transactions/#{tx.id}", %{
          "label" => "Updated label",
          "category_id" => cat.id
        })

      data = json_response(conn, 200)
      assert data["label"] == "Updated label"
      assert data["category_id"] == cat.id
    end

    test "returns 404 when transaction not found", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/transactions/#{Ecto.UUID.generate()}", %{"label" => "X"})
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  describe "bulk_categorize PATCH /api/v1/transactions/bulk-categorize" do
    test "updates category for given transaction ids", %{conn: conn, account: account} do
      t1 = insert_transaction(account.id, "2026-02-01", "A", "-1")
      t2 = insert_transaction(account.id, "2026-02-02", "B", "-2")
      cat = insert_category()

      conn =
        patch(conn, ~p"/api/v1/transactions/bulk-categorize", %{
          "transaction_ids" => [t1.id, t2.id],
          "category_id" => cat.id
        })

      data = json_response(conn, 200)
      assert data["updated_count"] == 2
    end
  end

  describe "delete DELETE /api/v1/transactions/:id" do
    test "deletes transaction", %{conn: conn, account: account} do
      tx = insert_transaction(account.id, "2026-02-01", "X", "-1")

      conn = delete(conn, ~p"/api/v1/transactions/#{tx.id}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/v1/transactions/#{tx.id}")
      assert json_response(conn, 404)
    end

    test "returns 404 when not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/transactions/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end
  end

  defp insert_account do
    %Account{}
    |> Account.changeset(%{name: "Test", bank: "test", type: "checking"})
    |> Repo.insert!()
  end

  defp insert_category do
    %Category{name: "Test Cat", color: "#3b82f6"}
    |> Repo.insert!()
  end

  defp insert_transaction(account_id, date_str, label, amount_str, category_id \\ nil) do
    %Transaction{}
    |> Transaction.changeset(%{
      account_id: account_id,
      date: Date.from_iso8601!(date_str),
      label: label,
      original_label: label,
      amount: Decimal.new(amount_str),
      source: "manual",
      category_id: category_id
    })
    |> Repo.insert!()
  end
end
