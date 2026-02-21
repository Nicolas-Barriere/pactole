defmodule Moulax.Repo.Migrations.AddImportIdToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :import_id, references(:imports, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:transactions, [:import_id])
  end
end
