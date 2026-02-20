defmodule MoulaxWeb.CurrencyControllerTest do
  use MoulaxWeb.ConnCase, async: true

  describe "index" do
    test "returns grouped fiat and crypto currencies", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/currencies")
      body = json_response(conn, 200)

      assert is_list(body["fiat"])
      assert is_list(body["crypto"])
      assert "EUR" in body["fiat"]
      assert "BTC" in body["crypto"]
    end
  end
end
