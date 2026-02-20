defmodule MoulaxWeb.CurrencyController do
  use MoulaxWeb, :controller

  alias Moulax.Currencies

  @doc """
  GET /api/v1/currencies
  """
  def index(conn, _params) do
    json(conn, Currencies.all())
  end
end
