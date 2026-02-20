defmodule Moulax.Tags.TransactionTag do
  @moduledoc """
  Join schema linking transactions to tags (many-to-many).
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Moulax.Tags.Tag
  alias Moulax.Transactions.Transaction

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transaction_tags" do
    belongs_to :transaction, Transaction
    belongs_to :tag, Tag

    timestamps()
  end

  @doc false
  def changeset(transaction_tag, attrs) do
    transaction_tag
    |> cast(attrs, [:transaction_id, :tag_id])
    |> validate_required([:transaction_id, :tag_id])
    |> foreign_key_constraint(:transaction_id)
    |> foreign_key_constraint(:tag_id)
    |> unique_constraint([:transaction_id, :tag_id])
  end
end
