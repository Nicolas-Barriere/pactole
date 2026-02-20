defmodule MoulaxWeb.ExchangeRateController do
  use MoulaxWeb, :controller

  alias Moulax.ExchangeRates

  @doc """
  GET /api/v1/exchange-rates?base=EUR
  """
  def index(conn, params) do
    base = params["base"] || "EUR"
    json(conn, ExchangeRates.list_rates(base))
  end
end
