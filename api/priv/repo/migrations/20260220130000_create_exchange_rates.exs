defmodule Moulax.Repo.Migrations.CreateExchangeRates do
  use Ecto.Migration

  def change do
    create table(:exchange_rates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :from_currency, :string, null: false
      add :to_currency, :string, null: false
      add :rate, :decimal, precision: 24, scale: 12, null: false
      add :fetched_at, :naive_datetime, null: false

      timestamps()
    end

    create unique_index(:exchange_rates, [:from_currency, :to_currency])
  end
end
