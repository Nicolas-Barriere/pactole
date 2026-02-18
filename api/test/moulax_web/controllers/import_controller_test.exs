defmodule MoulaxWeb.ImportControllerTest do
  use MoulaxWeb.ConnCase, async: true

  alias Moulax.Accounts.Account
  alias Moulax.Repo

  setup do
    account =
      %Account{}
      |> Account.changeset(%{name: "Test", bank: "boursorama", type: "checking"})
      |> Repo.insert!()

    %{account: account}
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

    test "duplicate import skips all rows on second import", %{conn: conn, account: account} do
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
      assert data2["rows_imported"] == 0
      assert data2["rows_skipped"] == 4
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
end
