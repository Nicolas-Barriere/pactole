defmodule MoulaxWeb.ImportControllerTest do
  use MoulaxWeb.ConnCase, async: true

  alias Moulax.TestXlsx

  setup do
    %{account: insert_account(%{name: "Test", bank: "boursorama", type: "checking"})}
  end

  describe "create POST /api/v1/accounts/:account_id/imports" do
    test "imports a valid Boursorama CSV file", %{conn: conn, account: account} do
      csv_path = Path.join([__DIR__, "..", "..", "fixtures", "boursorama_valid.csv"])

      upload = %Plug.Upload{
        path: csv_path,
        filename: "boursorama_feb_2026.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/api/v1/accounts/#{account.id}/imports", %{"file" => upload})
      data = json_response(conn, 201)

      assert data["status"] == "completed"
      assert data["filename"] == "boursorama_feb_2026.csv"
      assert data["rows_imported"] == 4
      assert data["rows_skipped"] == 0
      assert data["rows_errored"] == 0
      assert data["account_id"] == account.id
      assert data["id"] != nil
    end

    test "imports a valid Revolut CSV file", %{conn: conn, account: account} do
      csv_path = Path.join([__DIR__, "..", "..", "fixtures", "revolut_valid.csv"])

      upload = %Plug.Upload{
        path: csv_path,
        filename: "revolut.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/api/v1/accounts/#{account.id}/imports", %{"file" => upload})
      data = json_response(conn, 201)

      assert data["status"] == "completed"
      assert data["rows_imported"] > 0
    end

    test "imports a valid Revolut XLSX file", %{conn: conn, account: account} do
      xlsx_path = TestXlsx.write_tmp_xlsx!(TestXlsx.revolut_rows(), "revolut_controller_create")
      on_exit(fn -> File.rm(xlsx_path) end)

      upload = %Plug.Upload{
        path: xlsx_path,
        filename: "revolut.xlsx",
        content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      }

      conn = post(conn, ~p"/api/v1/accounts/#{account.id}/imports", %{"file" => upload})
      data = json_response(conn, 201)

      assert data["status"] == "completed"
      assert data["rows_imported"] == 2
      assert data["filename"] == "revolut.xlsx"
    end

    test "imports a valid Caisse d'Épargne CSV file", %{conn: conn, account: account} do
      csv_path = Path.join([__DIR__, "..", "..", "fixtures", "ce_valid.csv"])

      upload = %Plug.Upload{
        path: csv_path,
        filename: "ce.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/api/v1/accounts/#{account.id}/imports", %{"file" => upload})
      data = json_response(conn, 201)

      assert data["status"] == "completed"
      assert data["rows_imported"] > 0
    end

    test "returns 422 for unknown CSV format", %{conn: conn, account: account} do
      tmp_path = Path.join(System.tmp_dir!(), "unknown_#{System.unique_integer([:positive])}.csv")
      File.write!(tmp_path, "foo,bar,baz\n1,2,3\n")

      upload = %Plug.Upload{
        path: tmp_path,
        filename: "unknown.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/api/v1/accounts/#{account.id}/imports", %{"file" => upload})
      data = json_response(conn, 422)

      assert data["status"] == "failed"
      assert [%{"message" => msg} | _] = data["error_details"]
      assert msg =~ "Unknown CSV format"
    after
      File.rm(Path.join(System.tmp_dir!(), "unknown_*.csv"))
    end

    test "returns 400 when no file is provided", %{conn: conn, account: account} do
      conn = post(conn, ~p"/api/v1/accounts/#{account.id}/imports", %{})
      data = json_response(conn, 400)

      assert data["errors"]["detail"] == "No CSV file provided"
    end

    test "returns 400 when uploaded file cannot be read", %{conn: conn, account: account} do
      upload = %Plug.Upload{
        path: Path.join(System.tmp_dir!(), "missing_#{System.unique_integer([:positive])}.csv"),
        filename: "missing.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/api/v1/accounts/#{account.id}/imports", %{"file" => upload})
      data = json_response(conn, 400)

      assert data["errors"]["detail"] == "No CSV file provided"
    end

    test "returns 422 when upload metadata is invalid", %{conn: conn, account: account} do
      csv_path = Path.join([__DIR__, "..", "..", "fixtures", "boursorama_valid.csv"])

      upload = %Plug.Upload{
        path: csv_path,
        filename: nil,
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/api/v1/accounts/#{account.id}/imports", %{"file" => upload})
      data = json_response(conn, 422)

      assert "can't be blank" in data["errors"]["filename"]
    end

    test "returns 404 when account does not exist", %{conn: conn} do
      csv_path = Path.join([__DIR__, "..", "..", "fixtures", "boursorama_valid.csv"])

      upload = %Plug.Upload{
        path: csv_path,
        filename: "test.csv",
        content_type: "text/csv"
      }

      conn =
        post(conn, ~p"/api/v1/accounts/#{Ecto.UUID.generate()}/imports", %{"file" => upload})

      assert json_response(conn, 404)["errors"]["detail"] == "Account not found"
    end

    test "duplicate import replaces all rows on second import", %{conn: conn, account: account} do
      csv_path = Path.join([__DIR__, "..", "..", "fixtures", "boursorama_valid.csv"])

      upload = %Plug.Upload{
        path: csv_path,
        filename: "boursorama.csv",
        content_type: "text/csv"
      }

      conn1 = post(conn, ~p"/api/v1/accounts/#{account.id}/imports", %{"file" => upload})
      data1 = json_response(conn1, 201)
      assert data1["rows_imported"] == 4

      conn2 =
        build_conn()
        |> post(~p"/api/v1/accounts/#{account.id}/imports", %{"file" => upload})

      data2 = json_response(conn2, 201)
      assert data2["rows_imported"] == 4
      assert data2["rows_skipped"] == 0
      assert Enum.all?(data2["row_details"], &(&1["status"] == "updated"))
    end
  end

  describe "detect POST /api/v1/imports/detect" do
    test "detects Boursorama bank from CSV file", %{conn: conn} do
      csv_path = Path.join([__DIR__, "..", "..", "fixtures", "boursorama_valid.csv"])

      upload = %Plug.Upload{
        path: csv_path,
        filename: "boursorama_feb_2026.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/api/v1/imports/detect", %{"file" => upload})
      data = json_response(conn, 200)

      assert data["data"]["detected_bank"] == "boursorama"
      assert data["data"]["detected_currency"] == "EUR"
    end

    test "detects Revolut bank from CSV file", %{conn: conn} do
      csv_path = Path.join([__DIR__, "..", "..", "fixtures", "revolut_valid.csv"])

      upload = %Plug.Upload{
        path: csv_path,
        filename: "revolut.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/api/v1/imports/detect", %{"file" => upload})
      data = json_response(conn, 200)

      assert data["data"]["detected_bank"] == "revolut"
      assert data["data"]["detected_currency"] == "EUR"
    end

    test "detects Revolut bank from XLSX file", %{conn: conn} do
      xlsx_path = TestXlsx.write_tmp_xlsx!(TestXlsx.revolut_rows(), "revolut_controller_detect")
      on_exit(fn -> File.rm(xlsx_path) end)

      upload = %Plug.Upload{
        path: xlsx_path,
        filename: "revolut.xlsx",
        content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      }

      conn = post(conn, ~p"/api/v1/imports/detect", %{"file" => upload})
      data = json_response(conn, 200)

      assert data["data"]["detected_bank"] == "revolut"
      assert data["data"]["detected_currency"] == "EUR"
    end

    test "detects Caisse d'Epargne bank from CSV file", %{conn: conn} do
      csv_path = Path.join([__DIR__, "..", "..", "fixtures", "ce_valid.csv"])

      upload = %Plug.Upload{
        path: csv_path,
        filename: "ce.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/api/v1/imports/detect", %{"file" => upload})
      data = json_response(conn, 200)

      assert data["data"]["detected_bank"] == "caisse_depargne"
      assert data["data"]["detected_currency"] == "EUR"
    end

    test "returns 422 for unknown CSV format", %{conn: conn} do
      tmp_path =
        Path.join(System.tmp_dir!(), "unknown_detect_#{System.unique_integer([:positive])}.csv")

      File.write!(tmp_path, "foo,bar,baz\n1,2,3\n")

      upload = %Plug.Upload{
        path: tmp_path,
        filename: "unknown.csv",
        content_type: "text/csv"
      }

      conn = post(conn, ~p"/api/v1/imports/detect", %{"file" => upload})
      data = json_response(conn, 422)

      assert data["status"] == "failed"
      assert [%{"message" => msg} | _] = data["error_details"]
      assert msg =~ "Unknown CSV format"
    after
      File.rm(Path.join(System.tmp_dir!(), "unknown_detect_*.csv"))
    end

    test "returns 400 when no file is provided", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/imports/detect", %{})
      data = json_response(conn, 400)

      assert data["errors"]["detail"] == "No CSV file provided"
    end
  end

  describe "show GET /api/v1/imports/:id" do
    test "returns import details", %{conn: conn, account: account} do
      {:ok, import_record} = Moulax.Imports.create_import(account.id, "test.csv")

      conn = get(conn, ~p"/api/v1/imports/#{import_record.id}")
      data = json_response(conn, 200)

      assert data["id"] == import_record.id
      assert data["filename"] == "test.csv"
      assert data["status"] == "pending"
    end

    test "returns 404 for non-existent import", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/imports/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["errors"]["detail"] == "Not Found"
    end

    test "returns outcomes and linked transactions for completed import", %{
      conn: conn,
      account: account
    } do
      csv_path = Path.join([__DIR__, "..", "..", "fixtures", "boursorama_valid.csv"])

      upload = %Plug.Upload{
        path: csv_path,
        filename: "statement.csv",
        content_type: "text/csv"
      }

      create_conn = post(conn, ~p"/api/v1/accounts/#{account.id}/imports", %{"file" => upload})
      created = json_response(create_conn, 201)

      detail_conn = build_conn() |> get(~p"/api/v1/imports/#{created["id"]}")
      data = json_response(detail_conn, 200)

      assert is_list(data["row_details"])
      assert is_list(data["transactions"])
      assert length(data["transactions"]) == 4
      assert data["outcomes"] == %{"added" => 4, "updated" => 0, "ignored" => 0, "error" => 0}
    end
  end

  describe "index GET /api/v1/accounts/:account_id/imports" do
    test "returns imports for account", %{conn: conn, account: account} do
      {:ok, _} = Moulax.Imports.create_import(account.id, "first.csv")
      {:ok, _} = Moulax.Imports.create_import(account.id, "second.csv")

      conn = get(conn, ~p"/api/v1/accounts/#{account.id}/imports")
      data = json_response(conn, 200)

      assert length(data["data"]) == 2
    end

    test "returns 404 for non-existent account", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/accounts/#{Ecto.UUID.generate()}/imports")
      assert json_response(conn, 404)["errors"]["detail"] == "Account not found"
    end

    test "returns empty list for account with no imports", %{conn: conn, account: account} do
      conn = get(conn, ~p"/api/v1/accounts/#{account.id}/imports")
      data = json_response(conn, 200)
      assert data["data"] == []
    end
  end

  describe "index GET /api/v1/imports" do
    test "returns all imports newest first", %{conn: conn} do
      account = insert_account()
      {:ok, first} = Moulax.Imports.create_import(account.id, "first.csv")
      {:ok, second} = Moulax.Imports.create_import(account.id, "second.csv")

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      older = NaiveDateTime.add(now, -10, :second)

      Moulax.Repo.query!(
        "UPDATE imports SET inserted_at = $1, updated_at = $1 WHERE id = '#{first.id}'::uuid",
        [older]
      )

      Moulax.Repo.query!(
        "UPDATE imports SET inserted_at = $1, updated_at = $1 WHERE id = '#{second.id}'::uuid",
        [now]
      )

      conn = get(conn, ~p"/api/v1/imports")
      data = json_response(conn, 200)

      assert data["meta"]["page"] == 1
      assert data["meta"]["per_page"] == 20
      assert data["meta"]["total_count"] == 2
      assert data["meta"]["total_pages"] == 1
      assert Enum.map(data["data"], & &1["id"]) == [second.id, first.id]
      assert Enum.all?(data["data"], &is_binary(&1["account_name"]))
      assert Enum.all?(data["data"], &is_map(&1["outcomes"]))
    end

    test "supports pagination params", %{conn: conn} do
      account = insert_account()
      {:ok, _} = Moulax.Imports.create_import(account.id, "a.csv")
      {:ok, _} = Moulax.Imports.create_import(account.id, "b.csv")
      {:ok, _} = Moulax.Imports.create_import(account.id, "c.csv")

      conn = get(conn, ~p"/api/v1/imports?page=2&per_page=1")
      data = json_response(conn, 200)

      assert data["meta"]["page"] == 2
      assert data["meta"]["per_page"] == 1
      assert data["meta"]["total_count"] == 3
      assert data["meta"]["total_pages"] == 3
      assert length(data["data"]) == 1
    end
  end
end
