defmodule MoulaxWeb.TransactionControllerTest do
  use MoulaxWeb.ConnCase, async: true

  setup do
    account = insert_account()
    %{account: account}
  end

  describe "index (nested) GET /api/v1/accounts/:account_id/transactions" do
    test "returns paginated data and meta", %{conn: conn, account: account} do
      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Shop",
        amount: Decimal.new("-10.00")
      })

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
      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "A",
        amount: Decimal.new("-1")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-02],
        label: "B",
        amount: Decimal.new("-2")
      })

      conn = get(conn, ~p"/api/v1/transactions")
      body = json_response(conn, 200)
      assert length(body["data"]) == 2
      assert body["meta"]["total_count"] == 2
    end

    test "accepts query params for filtering", %{conn: conn, account: account} do
      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "CARREFOUR",
        amount: Decimal.new("-10")
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-02],
        label: "SNCF",
        amount: Decimal.new("-20")
      })

      conn = get(conn, "/api/v1/transactions?search=carrefour")
      body = json_response(conn, 200)
      assert body["meta"]["total_count"] == 1
      assert hd(body["data"])["label"] == "CARREFOUR"
    end

    test "filters by import_id", %{conn: conn, account: account} do
      import_record = insert_import(%{account_id: account.id, filename: "statement.csv"})
      other_import = insert_import(%{account_id: account.id, filename: "other.csv"})

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Imported A",
        amount: Decimal.new("-10"),
        source: "csv_import",
        import_id: import_record.id
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-02],
        label: "Imported B",
        amount: Decimal.new("-20"),
        source: "csv_import",
        import_id: other_import.id
      })

      conn = get(conn, "/api/v1/transactions?import_id=#{import_record.id}")
      body = json_response(conn, 200)
      assert body["meta"]["total_count"] == 1
      assert hd(body["data"])["import_id"] == import_record.id
    end

    test "accepts account_ids csv query param", %{conn: conn} do
      a1 = insert_account()
      a2 = insert_account()
      a3 = insert_account()

      insert_transaction(%{
        account_id: a1.id,
        date: ~D[2026-02-01],
        label: "A",
        amount: Decimal.new("-1")
      })

      insert_transaction(%{
        account_id: a2.id,
        date: ~D[2026-02-01],
        label: "B",
        amount: Decimal.new("-2")
      })

      insert_transaction(%{
        account_id: a3.id,
        date: ~D[2026-02-01],
        label: "C",
        amount: Decimal.new("-3")
      })

      conn = get(conn, "/api/v1/transactions?account_ids=#{a1.id},#{a2.id}")
      body = json_response(conn, 200)
      assert body["meta"]["total_count"] == 2
    end

    test "accepts tag_ids csv query param", %{conn: conn, account: account} do
      groceries = insert_tag()
      transport = insert_tag()

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Groceries",
        amount: Decimal.new("-1"),
        tag_ids: [groceries.id]
      })

      insert_transaction(%{
        account_id: account.id,
        date: ~D[2026-02-01],
        label: "Transport",
        amount: Decimal.new("-2"),
        tag_ids: [transport.id]
      })

      conn = get(conn, "/api/v1/transactions?tag_ids=#{groceries.id},#{transport.id}")
      body = json_response(conn, 200)
      assert body["meta"]["total_count"] == 2
    end
  end

  describe "show GET /api/v1/transactions/:id" do
    test "returns transaction when found", %{conn: conn, account: account} do
      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-15],
          label: "Test",
          amount: Decimal.new("-42.50")
        })

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

    test "returns import reference when present", %{conn: conn, account: account} do
      import_record = insert_import(%{account_id: account.id, filename: "statement.csv"})

      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-15],
          label: "Imported transaction",
          amount: Decimal.new("-42.50"),
          source: "csv_import",
          import_id: import_record.id
        })

      conn = get(conn, ~p"/api/v1/transactions/#{tx.id}")
      data = json_response(conn, 200)
      assert data["import_id"] == import_record.id
      assert data["import"] == %{"id" => import_record.id, "filename" => "statement.csv"}
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
      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "Old",
          amount: Decimal.new("-10")
        })

      tag = insert_tag()
      other_account = insert_account()

      conn =
        put(conn, ~p"/api/v1/transactions/#{tx.id}", %{
          "account_id" => other_account.id,
          "date" => "2026-02-03",
          "label" => "Updated label",
          "amount" => "-12.34",
          "tag_ids" => [tag.id]
        })

      data = json_response(conn, 200)
      assert data["label"] == "Updated label"
      assert data["account_id"] == other_account.id
      assert data["date"] == "2026-02-03"
      assert data["amount"] == "-12.34"
      assert [%{"id" => tag_id}] = data["tags"]
      assert tag_id == tag.id
    end

    test "returns 404 when transaction not found", %{conn: conn} do
      conn = put(conn, ~p"/api/v1/transactions/#{Ecto.UUID.generate()}", %{"label" => "X"})
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "returns 422 when update payload is invalid", %{conn: conn, account: account} do
      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "Old",
          amount: Decimal.new("-10")
        })

      conn =
        put(conn, ~p"/api/v1/transactions/#{tx.id}", %{
          "tag_ids" => [Ecto.UUID.generate()]
        })

      assert json_response(conn, 422)["errors"] != %{}
    end

    test "blocks editing non-manual transaction fields", %{conn: conn, account: account} do
      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "Imported",
          amount: Decimal.new("-10"),
          source: "csv_import"
        })

      conn =
        put(conn, ~p"/api/v1/transactions/#{tx.id}", %{
          "label" => "Should fail"
        })

      assert json_response(conn, 422)["errors"]["detail"] ==
               "Only manual transactions can be edited"
    end

    test "allows tag updates on non-manual transactions", %{conn: conn, account: account} do
      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "Imported",
          amount: Decimal.new("-10"),
          source: "csv_import"
        })

      tag = insert_tag()

      conn =
        put(conn, ~p"/api/v1/transactions/#{tx.id}", %{
          "tag_ids" => [tag.id]
        })

      data = json_response(conn, 200)
      assert [%{"id" => tag_id}] = data["tags"]
      assert tag_id == tag.id
    end
  end

  describe "bulk_tag PATCH /api/v1/transactions/bulk-tag" do
    test "updates tags for given transaction ids", %{conn: conn, account: account} do
      t1 =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "A",
          amount: Decimal.new("-1")
        })

      t2 =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-02],
          label: "B",
          amount: Decimal.new("-2")
        })

      tag = insert_tag()

      conn =
        patch(conn, ~p"/api/v1/transactions/bulk-tag", %{
          "transaction_ids" => [t1.id, t2.id],
          "tag_ids" => [tag.id]
        })

      data = json_response(conn, 200)
      assert data["updated_count"] == 2
    end
  end

  describe "delete DELETE /api/v1/transactions/:id" do
    test "deletes transaction", %{conn: conn, account: account} do
      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "X",
          amount: Decimal.new("-1")
        })

      conn = delete(conn, ~p"/api/v1/transactions/#{tx.id}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/v1/transactions/#{tx.id}")
      assert json_response(conn, 404)
    end

    test "returns 404 when not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/transactions/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "blocks deleting non-manual transaction", %{conn: conn, account: account} do
      tx =
        insert_transaction(%{
          account_id: account.id,
          date: ~D[2026-02-01],
          label: "Imported",
          amount: Decimal.new("-1"),
          source: "csv_import"
        })

      conn = delete(conn, ~p"/api/v1/transactions/#{tx.id}")

      assert json_response(conn, 422)["errors"]["detail"] ==
               "Only manual transactions can be deleted"
    end
  end
end
