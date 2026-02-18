defmodule Moulax.Parsers do
  @moduledoc """
  Registry for bank CSV parsers.

  Iterates registered parsers and selects the one that can handle
  the given CSV content based on its headers.
  """

  @parsers [
    Moulax.Parsers.Boursorama
  ]

  @doc """
  Detects the appropriate parser for the given CSV content.

  Returns `{:ok, parser_module}` if a matching parser is found,
  or `:error` if no parser can handle the content.
  """
  @spec detect_parser(binary()) :: {:ok, module()} | :error
  def detect_parser(content) when is_binary(content) do
    case Enum.find(@parsers, & &1.detect?(content)) do
      nil -> :error
      parser -> {:ok, parser}
    end
  end
end
