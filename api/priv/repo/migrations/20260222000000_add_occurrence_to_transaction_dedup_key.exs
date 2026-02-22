defmodule Moulax.Repo.Migrations.AddOccurrenceToTransactionDedupKey do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :occurrence, :integer, null: false, default: 1
    end

    drop_if_exists(
      index(:transactions, [:account_id, :date, :amount, :original_label],
        name: :transactions_account_date_amount_original_label_index
      )
    )

    create unique_index(
             :transactions,
             [:account_id, :date, :amount, :original_label, :occurrence],
             name: :transactions_account_date_amount_original_label_occ_idx
           )
  end
end
