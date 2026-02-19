defmodule Moulax.ApplicationTest do
  use ExUnit.Case, async: true

  test "config_change/3 delegates to endpoint and returns :ok" do
    assert :ok = Moulax.Application.config_change(%{}, %{}, [])
  end
end
