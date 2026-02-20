defmodule Moulax.Repo.Migrations.EnforceSupportedCurrencies do
  use Ecto.Migration

  @currencies ~w(EUR USD GBP CHF JPY CAD AUD NOK SEK DKK PLN CZK HUF RON BTC ETH SOL USDC USDT XRP BNB ADA)
  @currency_sql_list Enum.map_join(@currencies, ",", &"'#{&1}'")
  @currency_check "currency IN (#{@currency_sql_list})"

  def up do
    execute("""
    UPDATE accounts
    SET currency = 'EUR'
    WHERE currency IS NULL
       OR UPPER(currency) NOT IN (#{@currency_sql_list})
    """)

    execute("""
    UPDATE transactions
    SET currency = 'EUR'
    WHERE currency IS NULL
       OR UPPER(currency) NOT IN (#{@currency_sql_list})
    """)

    execute("""
    UPDATE accounts
    SET currency = UPPER(currency)
    WHERE currency <> UPPER(currency)
      AND UPPER(currency) IN (#{@currency_sql_list})
    """)

    execute("""
    UPDATE transactions
    SET currency = UPPER(currency)
    WHERE currency <> UPPER(currency)
      AND UPPER(currency) IN (#{@currency_sql_list})
    """)

    create constraint(:accounts, :accounts_currency_valid, check: @currency_check)
    create constraint(:transactions, :transactions_currency_valid, check: @currency_check)
  end

  def down do
    drop constraint(:transactions, :transactions_currency_valid)
    drop constraint(:accounts, :accounts_currency_valid)
  end
end
