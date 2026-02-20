defmodule MoulaxWeb.ExchangeRateControllerTest do
  use MoulaxWeb.ConnCase, async: true

  describe "index" do
    test "returns rates for requested base currency", %{conn: conn} do
      now = ~N[2026-02-20 10:00:00]
      older = ~N[2026-02-20 09:00:00]

      insert_exchange_rate(%{to_currency: "EUR", rate: Decimal.new("1"), fetched_at: now})
      insert_exchange_rate(%{to_currency: "USD", rate: Decimal.new("1.08"), fetched_at: now})
      insert_exchange_rate(%{to_currency: "GBP", rate: Decimal.new("0.86"), fetched_at: older})
      insert_exchange_rate(%{to_currency: "BTC", rate: Decimal.new("0.0000235"), fetched_at: now})

      body =
        conn
        |> get("/api/v1/exchange-rates?base=EUR")
        |> json_response(200)

      assert body["base"] == "EUR"
      assert body["fetched_at"] == "2026-02-20T09:00:00Z"
      assert body["rates"]["USD"] == "1.08"
      assert body["rates"]["GBP"] == "0.86"
      assert body["rates"]["BTC"] == "0.0000235"
      refute Map.has_key?(body["rates"], "EUR")
    end

    test "defaults base to EUR when omitted", %{conn: conn} do
      now = ~N[2026-02-20 10:00:00]
      insert_exchange_rate(%{to_currency: "EUR", rate: Decimal.new("1"), fetched_at: now})
      insert_exchange_rate(%{to_currency: "USD", rate: Decimal.new("1.08"), fetched_at: now})

      body =
        conn
        |> get("/api/v1/exchange-rates")
        |> json_response(200)

      assert body["base"] == "EUR"
      assert body["rates"]["USD"] == "1.08"
    end
  end
end
