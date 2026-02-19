defmodule Moulax.Factory do
  @moduledoc """
  Shared test helpers for inserting test data into the database.
  Imported automatically via Moulax.DataCase and MoulaxWeb.ConnCase.
  """

  alias Moulax.Repo
  alias Moulax.Accounts.Account
  alias Moulax.Categories.Category
  alias Moulax.Categories.CategorizationRule
  alias Moulax.Transactions.Transaction
  alias Moulax.Imports.Import

  @doc "Inserts an Account with sensible defaults. Accepts atom-keyed attrs."
  def insert_account(attrs \\ %{}) do
    defaults = %{
      "name" => "Test Account",
      "bank" => "boursorama",
      "type" => "checking",
      "initial_balance" => Decimal.new(0),
      "currency" => "EUR",
      "archived" => false
    }

    merged = Map.merge(defaults, stringify_keys(attrs))
    %Account{} |> Account.changeset(merged) |> Repo.insert!()
  end

  @doc """
  Inserts a Category. Generates a unique name unless one is provided.
  Accepts atom-keyed attrs.
  """
  def insert_category(attrs \\ %{}) do
    defaults = %{name: "Category #{:erlang.unique_integer([:positive])}", color: "#3b82f6"}
    merged = Map.merge(defaults, atomize_keys(attrs))
    %Category{} |> Category.changeset(merged) |> Repo.insert!()
  end

  @doc """
  Inserts a Transaction. Requires at minimum: `account_id`.
  `label` defaults to "Test Transaction"; `original_label` defaults to `label`.
  Accepts atom-keyed attrs.
  """
  def insert_transaction(attrs) do
    attrs = atomize_keys(attrs)
    label = attrs[:label] || "Test Transaction"
    original_label = attrs[:original_label] || label

    defaults = %{
      date: ~D[2026-01-01],
      label: label,
      original_label: original_label,
      amount: Decimal.new("-10.00"),
      currency: "EUR",
      source: "manual",
      category_id: nil
    }

    merged = Map.merge(defaults, attrs)
    %Transaction{} |> Transaction.changeset(merged) |> Repo.insert!()
  end

  @doc """
  Inserts a CategorizationRule with category preloaded.
  Requires `keyword` and `category_id`. Accepts atom-keyed attrs.
  """
  def insert_rule(attrs) do
    defaults = %{priority: 0}
    merged = Map.merge(defaults, atomize_keys(attrs))

    %CategorizationRule{}
    |> CategorizationRule.changeset(merged)
    |> Repo.insert!()
    |> Repo.preload(:category)
  end

  @doc """
  Inserts an Import record. Requires `account_id`.
  `filename` defaults to "test.csv", `status` defaults to "pending".
  Accepts atom-keyed attrs.
  """
  def insert_import(attrs) do
    defaults = %{filename: "test.csv", status: "pending"}
    merged = Map.merge(defaults, atomize_keys(attrs))
    %Import{} |> Import.changeset(merged) |> Repo.insert!()
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
