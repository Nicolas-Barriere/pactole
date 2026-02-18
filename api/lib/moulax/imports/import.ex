defmodule Moulax.Imports.Import do
  @moduledoc """
  Ecto schema for a CSV import record.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias Moulax.Accounts.Account

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          account_id: Ecto.UUID.t(),
          filename: String.t(),
          rows_total: non_neg_integer(),
          rows_imported: non_neg_integer(),
          rows_skipped: non_neg_integer(),
          rows_errored: non_neg_integer(),
          status: String.t(),
          error_details: [map()] | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "imports" do
    field :filename, :string
    field :rows_total, :integer, default: 0
    field :rows_imported, :integer, default: 0
    field :rows_skipped, :integer, default: 0
    field :rows_errored, :integer, default: 0
    field :status, :string, default: "pending"
    field :error_details, {:array, :map}

    belongs_to :account, Account

    timestamps()
  end

  @statuses ~w(pending processing completed failed)

  @doc false
  def changeset(import_record, attrs) do
    import_record
    |> cast(attrs, [
      :filename,
      :rows_total,
      :rows_imported,
      :rows_skipped,
      :rows_errored,
      :status,
      :error_details,
      :account_id
    ])
    |> validate_required([:filename, :account_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:account_id)
  end
end
