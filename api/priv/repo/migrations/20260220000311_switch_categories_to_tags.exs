defmodule Moulax.Repo.Migrations.SwitchCategoriesToTags do
  use Ecto.Migration

  def up do
    # 1. Create transaction_tags join table
    create table(:transaction_tags, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :transaction_id, references(:transactions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :tag_id, references(:categories, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:transaction_tags, [:transaction_id, :tag_id])

    # 2. Migrate existing category_id data into transaction_tags
    execute """
    INSERT INTO transaction_tags (id, transaction_id, tag_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), id, category_id, NOW(), NOW()
    FROM transactions
    WHERE category_id IS NOT NULL
    """

    # 3. Drop category_id from transactions
    drop index(:transactions, [:category_id])

    alter table(:transactions) do
      remove :category_id
    end

    # 4. Rename tables
    rename table(:categories), to: table(:tags)
    rename table(:categorization_rules), to: table(:tagging_rules)

    # 5. Rename category_id column in tagging_rules
    rename table(:tagging_rules), :category_id, to: :tag_id
  end

  def down do
    # Reverse: rename back
    rename table(:tagging_rules), :tag_id, to: :category_id
    rename table(:tagging_rules), to: table(:categorization_rules)
    rename table(:tags), to: table(:categories)

    # Re-add category_id to transactions
    alter table(:transactions) do
      add :category_id, references(:categories, type: :binary_id)
    end

    create index(:transactions, [:category_id])

    # Migrate back (pick the first tag per transaction)
    execute """
    UPDATE transactions t
    SET category_id = (
      SELECT tt.tag_id FROM transaction_tags tt
      WHERE tt.transaction_id = t.id
      LIMIT 1
    )
    """

    # Drop transaction_tags
    drop table(:transaction_tags)
  end
end
