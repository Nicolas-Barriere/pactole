defmodule Moulax.Parsers.ParseError do
  @moduledoc """
  Represents a parsing error for a specific row in a CSV file.
  """

  @type t :: %__MODULE__{
          row: non_neg_integer(),
          message: String.t()
        }

  @enforce_keys [:row, :message]
  defstruct [:row, :message]
end
