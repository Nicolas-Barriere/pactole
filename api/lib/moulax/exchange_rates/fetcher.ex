defmodule Moulax.ExchangeRates.Fetcher do
  @moduledoc """
  Periodically fetches fiat and crypto rates and upserts them into exchange_rates.
  """
  use GenServer

  require Logger

  alias Moulax.Currencies
  alias Moulax.ExchangeRates

  @eur "EUR"
  @fiat_fetch_interval_ms :timer.hours(24)
  @crypto_fetch_interval_ms :timer.minutes(30)

  @crypto_id_to_currency %{
    "bitcoin" => "BTC",
    "ethereum" => "ETH",
    "solana" => "SOL",
    "usd-coin" => "USDC",
    "tether" => "USDT",
    "ripple" => "XRP",
    "binancecoin" => "BNB",
    "cardano" => "ADA"
  }

  @crypto_ids Map.keys(@crypto_id_to_currency)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    send(self(), :fetch_fiat_rates)
    send(self(), :fetch_crypto_rates)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:fetch_fiat_rates, state) do
    maybe_fetch_fiat_rates()
    Process.send_after(self(), :fetch_fiat_rates, @fiat_fetch_interval_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info(:fetch_crypto_rates, state) do
    maybe_fetch_crypto_rates()
    Process.send_after(self(), :fetch_crypto_rates, @crypto_fetch_interval_ms)
    {:noreply, state}
  end

  defp maybe_fetch_fiat_rates do
    fiat_symbols =
      Currencies.fiat()
      |> Enum.reject(&(&1 == @eur))
      |> Enum.join(",")

    case Req.get("https://api.frankfurter.app/latest",
           params: [base: @eur, symbols: fiat_symbols]
         ) do
      {:ok, %{status: 200, body: %{"rates" => rates}}} ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        rows =
          rates
          |> Enum.map(fn {to_currency, rate} ->
            %{
              id: Ecto.UUID.generate(),
              from_currency: @eur,
              to_currency: to_currency,
              rate: decimal_from_number(rate),
              fetched_at: now,
              inserted_at: now,
              updated_at: now
            }
          end)
          |> prepend_eur_pivot(now)

        ExchangeRates.upsert_rates(rows)
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.warning("Fiat rates fetch failed with status #{status}: #{inspect(body)}")
        :error

      {:error, reason} ->
        Logger.warning("Fiat rates fetch failed: #{inspect(reason)}")
        :error
    end
  end

  defp maybe_fetch_crypto_rates do
    params = [
      ids: Enum.join(@crypto_ids, ","),
      vs_currencies: "eur"
    ]

    case Req.get("https://api.coingecko.com/api/v3/simple/price", params: params) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        rows =
          body
          |> Enum.flat_map(fn {id, values} ->
            case {Map.get(@crypto_id_to_currency, id), values} do
              {nil, _} ->
                []

              {currency, %{"eur" => eur_price}} ->
                if valid_positive_number?(eur_price) do
                  # CoinGecko gives 1 crypto in EUR; we store 1 EUR in crypto.
                  eur_to_crypto = Decimal.div(Decimal.new("1"), decimal_from_number(eur_price))

                  [
                    %{
                      id: Ecto.UUID.generate(),
                      from_currency: @eur,
                      to_currency: currency,
                      rate: eur_to_crypto,
                      fetched_at: now,
                      inserted_at: now,
                      updated_at: now
                    }
                  ]
                else
                  []
                end

              _ ->
                []
            end
          end)
          |> prepend_eur_pivot(now)

        ExchangeRates.upsert_rates(rows)
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.warning("Crypto rates fetch failed with status #{status}: #{inspect(body)}")
        :error

      {:error, reason} ->
        Logger.warning("Crypto rates fetch failed: #{inspect(reason)}")
        :error
    end
  end

  defp prepend_eur_pivot(rows, now) do
    [
      %{
        id: Ecto.UUID.generate(),
        from_currency: @eur,
        to_currency: @eur,
        rate: Decimal.new("1"),
        fetched_at: now,
        inserted_at: now,
        updated_at: now
      }
      | rows
    ]
  end

  defp decimal_from_number(value) when is_integer(value), do: Decimal.new(value)
  defp decimal_from_number(value) when is_float(value), do: Decimal.from_float(value)
  defp decimal_from_number(value) when is_binary(value), do: Decimal.new(value)

  defp valid_positive_number?(value) when is_integer(value), do: value > 0
  defp valid_positive_number?(value) when is_float(value), do: value > 0.0

  defp valid_positive_number?(value) when is_binary(value),
    do: Decimal.compare(Decimal.new(value), 0) == :gt

  defp valid_positive_number?(_), do: false
end
