defmodule Moulax.Repo.Migrations.AddRowDetailsToImports do
  use Ecto.Migration

  def change do
    alter table(:imports) do
      add :row_details, {:array, :map}, default: []
    end
  end
end
