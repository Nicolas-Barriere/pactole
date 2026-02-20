defmodule Moulax.Currencies do
  @moduledoc """
  Centralized currency list shared by validation and API responses.
  """

  @fiat ~w(EUR USD GBP CHF JPY CAD AUD NOK SEK DKK PLN CZK HUF RON)
  @crypto ~w(BTC ETH SOL USDC USDT XRP BNB ADA)

  @spec fiat() :: [String.t()]
  def fiat, do: @fiat

  @spec crypto() :: [String.t()]
  def crypto, do: @crypto

  @spec codes() :: [String.t()]
  def codes, do: @fiat ++ @crypto

  @spec all() :: %{fiat: [String.t()], crypto: [String.t()]}
  def all do
    %{fiat: @fiat, crypto: @crypto}
  end
end
