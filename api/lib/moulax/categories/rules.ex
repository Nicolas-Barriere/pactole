defmodule Moulax.Categories.Rules do
  @moduledoc """
  Context for categorization rules: CRUD and matching engine.
  Given a transaction label, `match_category/1` returns the matching category_id (or nil).
  """
  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.Categories.CategorizationRule
  alias Moulax.Categories.Category

  @doc """
  Returns all rules ordered by priority descending (highest first).
  Each rule includes preloaded category with id, name, color.
  """
  def list_rules do
    CategorizationRule
    |> order_by([r], desc: r.priority)
    |> preload(:category)
    |> Repo.all()
    |> Enum.map(&rule_to_response/1)
  end

  @doc """
  Creates a new categorization rule.
  Returns `{:ok, rule_map}` or `{:error, changeset}`.
  """
  def create_rule(attrs \\ %{}) do
    %CategorizationRule{}
    |> CategorizationRule.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, rule} -> {:ok, rule_to_response(Repo.preload(rule, :category))}
      error -> error
    end
  end

  @doc """
  Updates a rule. Returns `{:ok, rule_map}` or `{:error, changeset}`.
  """
  def update_rule(%CategorizationRule{} = rule, attrs) do
    rule
    |> CategorizationRule.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, rule_to_response(Repo.preload(updated, :category))}
      error -> error
    end
  end

  @doc """
  Fetches a single rule by ID. Returns `{:ok, rule}` or `{:error, :not_found}`.
  """
  def fetch_rule(id) do
    case Repo.get(CategorizationRule, id) do
      nil -> {:error, :not_found}
      rule -> {:ok, rule}
    end
  end

  @doc """
  Deletes a rule. Returns `{:ok, rule}` or `{:error, :not_found}`.
  """
  def delete_rule(id) when is_binary(id) do
    case Repo.get(CategorizationRule, id) do
      nil -> {:error, :not_found}
      rule -> Repo.delete(rule)
    end
  end

  def delete_rule(%CategorizationRule{} = rule) do
    Repo.delete(rule)
  end

  @doc """
  Given a transaction label (string), returns the matching category_id or nil.
  - Rules are evaluated by priority (highest first).
  - Match is case-insensitive substring: rule.keyword in label.
  - Returns the first matching rule's category_id.
  """
  def match_category(nil), do: nil
  def match_category(""), do: nil

  def match_category(label) when is_binary(label) do
    label_lower = String.downcase(label)

    CategorizationRule
    |> order_by([r], desc: r.priority)
    |> preload(:category)
    |> Repo.all()
    |> Enum.find_value(fn rule ->
      keyword_lower = String.downcase(rule.keyword)
      if String.contains?(label_lower, keyword_lower), do: rule.category_id
    end)
  end

  defp rule_to_response(%CategorizationRule{category: %Category{} = cat} = rule) do
    %{
      id: rule.id,
      keyword: rule.keyword,
      category: %{
        id: cat.id,
        name: cat.name,
        color: cat.color
      },
      priority: rule.priority
    }
  end
end
