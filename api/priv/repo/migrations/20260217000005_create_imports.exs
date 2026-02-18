defmodule Moulax.Repo.Migrations.CreateImports do
  use Ecto.Migration

  def change do
    execute(
      "CREATE TYPE import_status AS ENUM ('pending', 'processing', 'completed', 'failed')",
      "DROP TYPE import_status"
    )

    create table(:imports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :account_id, references(:accounts, type: :binary_id), null: false
      add :filename, :string, null: false
      add :rows_total, :integer, default: 0
      add :rows_imported, :integer, default: 0
      add :rows_skipped, :integer, default: 0
      add :rows_errored, :integer, default: 0
      add :status, :import_status, null: false, default: "pending"
      add :error_details, {:array, :map}, default: []

      timestamps()
    end

    create index(:imports, [:account_id])
    create index(:imports, [:status])
  end
end
