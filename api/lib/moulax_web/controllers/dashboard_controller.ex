defmodule MoulaxWeb.DashboardController do
  use MoulaxWeb, :controller

  alias Moulax.Dashboard

  def summary(conn, _params) do
    json(conn, Dashboard.summary())
  end

  def spending(conn, params) do
    month = params["month"] || current_month()
    json(conn, Dashboard.spending(month))
  end

  def trends(conn, params) do
    months = parse_positive_int(params["months"], 12)
    json(conn, Dashboard.trends(months))
  end

  def top_expenses(conn, params) do
    month = params["month"] || current_month()
    limit = parse_positive_int(params["limit"], 5)
    json(conn, Dashboard.top_expenses(month, limit))
  end

  defp current_month do
    today = Date.utc_today()
    m = today.month |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{today.year}-#{m}"
  end

  defp parse_positive_int(nil, default), do: default

  defp parse_positive_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end

  defp parse_positive_int(val, _default) when is_integer(val) and val > 0, do: val
  defp parse_positive_int(_, default), do: default
end
