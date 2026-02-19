defmodule Moulax.Parsers.Parser do
  @moduledoc """
  Behaviour for bank CSV parsers.

  Each bank parser implements `detect?/1` to identify CSV files
  it can handle, and `parse/1` to extract transaction data from CSV content.
  """

  alias Moulax.Parsers.ParseError

  @type parsed_row :: %{
          date: Date.t(),
          label: String.t(),
          original_label: String.t(),
          amount: Decimal.t(),
          currency: String.t()
        }

  @doc """
  Returns true if the given CSV content is handled by this parser.
  """
  @callback detect?(binary()) :: boolean()

  @doc """
  Parses CSV content into a list of transaction attribute maps.
  """
  @callback parse(binary()) :: {:ok, [parsed_row()]} | {:error, [ParseError.t()]}

  @doc """
  Returns the identifier of the bank for this parser.
  """
  @callback bank() :: String.t()
end
