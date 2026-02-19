defmodule MoulaxWeb.TelemetryTest do
  use ExUnit.Case, async: true

  test "metrics/0 returns expected metric definitions" do
    metrics = MoulaxWeb.Telemetry.metrics()

    assert is_list(metrics)
    assert Enum.any?(metrics, &(&1.name == [:phoenix, :endpoint, :start, :system_time]))
    assert Enum.any?(metrics, &(&1.name == [:moulax, :repo, :query, :total_time]))
    assert Enum.any?(metrics, &(&1.name == [:vm, :memory, :total]))
  end
end
