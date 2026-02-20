defmodule Moulax.ExchangeRatesTest do
  use Moulax.DataCase, async: true

  alias Moulax.ExchangeRates

  describe "list_rates/1" do
    test "returns direct rates when base is EUR and oldest fetched_at" do
      now = ~N[2026-02-20 10:00:00]
      older = ~N[2026-02-20 08:00:00]

      insert_exchange_rate(%{to_currency: "EUR", rate: Decimal.new("1"), fetched_at: now})
      insert_exchange_rate(%{to_currency: "USD", rate: Decimal.new("1.08"), fetched_at: now})
      insert_exchange_rate(%{to_currency: "GBP", rate: Decimal.new("0.86"), fetched_at: older})
      insert_exchange_rate(%{to_currency: "BTC", rate: Decimal.new("0.0000235"), fetched_at: now})

      result = ExchangeRates.list_rates("eur")

      assert result.base == "EUR"
      assert result.fetched_at == "2026-02-20T08:00:00Z"
      assert result.rates["USD"] == "1.08"
      assert result.rates["GBP"] == "0.86"
      assert result.rates["BTC"] == "0.0000235"
      refute Map.has_key?(result.rates, "EUR")
    end

    test "returns computed cross rates for non-EUR base" do
      now = ~N[2026-02-20 10:00:00]

      insert_exchange_rate(%{to_currency: "EUR", rate: Decimal.new("1"), fetched_at: now})
      insert_exchange_rate(%{to_currency: "USD", rate: Decimal.new("1.08"), fetched_at: now})
      insert_exchange_rate(%{to_currency: "GBP", rate: Decimal.new("0.90"), fetched_at: now})

      result = ExchangeRates.list_rates("usd")

      assert result.base == "USD"

      assert Decimal.equal?(
               Decimal.new(result.rates["EUR"]),
               Decimal.div(Decimal.new("1"), Decimal.new("1.08"))
             )

      assert Decimal.equal?(
               Decimal.new(result.rates["GBP"]),
               Decimal.div(Decimal.new("0.90"), Decimal.new("1.08"))
             )

      refute Map.has_key?(result.rates, "USD")
    end
  end

  describe "get_rate/2" do
    test "returns 1 for same currency" do
      assert {:ok, rate} = ExchangeRates.get_rate("usd", "USD")
      assert Decimal.equal?(rate, Decimal.new("1"))
    end

    test "returns computed cross rate and error when missing" do
      now = ~N[2026-02-20 10:00:00]

      insert_exchange_rate(%{to_currency: "EUR", rate: Decimal.new("1"), fetched_at: now})
      insert_exchange_rate(%{to_currency: "USD", rate: Decimal.new("1.2"), fetched_at: now})
      insert_exchange_rate(%{to_currency: "GBP", rate: Decimal.new("0.9"), fetched_at: now})

      assert {:ok, rate} = ExchangeRates.get_rate("usd", "gbp")
      assert Decimal.equal?(rate, Decimal.new("0.75"))

      assert {:error, :rate_not_found} = ExchangeRates.get_rate("usd", "jpy")
    end
  end
end
