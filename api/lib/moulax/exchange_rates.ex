defmodule Moulax.ExchangeRates do
  @moduledoc """
  Context for reading and persisting exchange rates.
  """
  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.ExchangeRates.ExchangeRate

  @eur "EUR"
  @one Decimal.new("1")

  @spec list_rates(String.t()) :: %{base: String.t(), rates: map(), fetched_at: String.t() | nil}
  def list_rates(base_currency) when is_binary(base_currency) do
    base = normalize_currency(base_currency)
    eur_rates = eur_rates_map()

    rates =
      eur_rates
      |> Map.keys()
      |> Enum.uniq()
      |> Enum.reject(&(&1 == base))
      |> Enum.reduce(%{}, fn to_currency, acc ->
        case get_cross_rate(base, to_currency, eur_rates) do
          {:ok, rate} -> Map.put(acc, to_currency, format_decimal(rate))
          :error -> acc
        end
      end)

    %{
      base: base,
      rates: rates,
      fetched_at: oldest_fetched_at_iso8601(eur_rates, base, Map.keys(rates))
    }
  end

  @spec get_rate(String.t(), String.t()) :: {:ok, Decimal.t()} | {:error, :rate_not_found}
  def get_rate(from_currency, to_currency)
      when is_binary(from_currency) and is_binary(to_currency) do
    from = normalize_currency(from_currency)
    to = normalize_currency(to_currency)

    if from == to do
      {:ok, @one}
    else
      case get_cross_rate(from, to, eur_rates_map()) do
        {:ok, rate} -> {:ok, rate}
        :error -> {:error, :rate_not_found}
      end
    end
  end

  @spec upsert_rates([map()]) :: {non_neg_integer(), nil | [term()]}
  def upsert_rates(rows) when is_list(rows) do
    Repo.insert_all(
      ExchangeRate,
      rows,
      on_conflict: :replace_all,
      conflict_target: [:from_currency, :to_currency]
    )
  end

  defp eur_rates_map do
    from(r in ExchangeRate,
      where: r.from_currency == @eur,
      select: {r.to_currency, r.rate, r.fetched_at}
    )
    |> Repo.all()
    |> Map.new(fn {to_currency, rate, fetched_at} ->
      {to_currency, %{rate: rate, fetched_at: fetched_at}}
    end)
    |> Map.put_new(@eur, %{rate: @one, fetched_at: nil})
  end

  defp get_cross_rate(@eur, to_currency, eur_rates) do
    case Map.fetch(eur_rates, to_currency) do
      {:ok, %{rate: rate}} -> {:ok, rate}
      :error -> :error
    end
  end

  defp get_cross_rate(from_currency, @eur, eur_rates) do
    case Map.fetch(eur_rates, from_currency) do
      {:ok, %{rate: from_rate}} ->
        if Decimal.eq?(from_rate, 0) do
          :error
        else
          {:ok, Decimal.div(@one, from_rate)}
        end

      :error ->
        :error
    end
  end

  defp get_cross_rate(from_currency, to_currency, eur_rates) do
    with {:ok, %{rate: to_rate}} <- Map.fetch(eur_rates, to_currency),
         {:ok, %{rate: from_rate}} <- Map.fetch(eur_rates, from_currency),
         false <- Decimal.eq?(from_rate, 0) do
      {:ok, Decimal.div(to_rate, from_rate)}
    else
      _ -> :error
    end
  end

  defp oldest_fetched_at_iso8601(eur_rates, base, rate_currencies) do
    currencies = Enum.uniq([base | rate_currencies])

    oldest =
      currencies
      |> Enum.map(&Map.get(eur_rates, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.fetched_at)
      |> Enum.reject(&is_nil/1)
      |> Enum.min(fn -> nil end)

    case oldest do
      nil ->
        nil

      naive ->
        naive
        |> DateTime.from_naive!("Etc/UTC")
        |> DateTime.to_iso8601()
    end
  end

  defp normalize_currency(currency), do: currency |> String.trim() |> String.upcase()

  defp format_decimal(%Decimal{} = decimal) do
    decimal
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end
end
