defmodule Moulax.Tags.Rules do
  @moduledoc """
  Context for tagging rules: CRUD and matching engine.
  Given a transaction label, `match_tags/1` returns all matching tag_ids.
  """
  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.Tags.TaggingRule
  alias Moulax.Tags.Tag
  alias Moulax.Tags.TransactionTag

  @doc """
  Returns all rules ordered by priority descending (highest first).
  Each rule includes preloaded tag with id, name, color.
  """
  def list_rules do
    TaggingRule
    |> order_by([r], desc: r.priority)
    |> preload(:tag)
    |> Repo.all()
    |> Enum.map(&rule_to_response/1)
  end

  @doc """
  Creates a new tagging rule.
  Returns `{:ok, rule_map}` or `{:error, changeset}`.
  """
  def create_rule(attrs \\ %{}) do
    %TaggingRule{}
    |> TaggingRule.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, rule} -> {:ok, rule_to_response(Repo.preload(rule, :tag))}
      error -> error
    end
  end

  @doc """
  Updates a rule. Returns `{:ok, rule_map}` or `{:error, changeset}`.
  """
  def update_rule(%TaggingRule{} = rule, attrs) do
    rule
    |> TaggingRule.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, rule_to_response(Repo.preload(updated, :tag))}
      error -> error
    end
  end

  @doc """
  Gets a single rule by ID with tag preloaded and formatted.
  Returns `{:ok, rule_map}` or `{:error, :not_found}`.
  """
  def get_rule(id) do
    case Repo.get(TaggingRule, id) do
      nil -> {:error, :not_found}
      rule -> {:ok, rule_to_response(Repo.preload(rule, :tag))}
    end
  end

  @doc """
  Fetches a single rule by ID. Returns `{:ok, rule}` or `{:error, :not_found}`.
  """
  def fetch_rule(id) do
    case Repo.get(TaggingRule, id) do
      nil -> {:error, :not_found}
      rule -> {:ok, rule}
    end
  end

  @doc """
  Deletes a rule. Returns `{:ok, rule}` or `{:error, :not_found}`.
  """
  def delete_rule(id) when is_binary(id) do
    case Repo.get(TaggingRule, id) do
      nil -> {:error, :not_found}
      rule -> Repo.delete(rule)
    end
  end

  def delete_rule(%TaggingRule{} = rule) do
    Repo.delete(rule)
  end

  @doc """
  Given a transaction label (string), returns all matching tag_ids.
  Rules are evaluated by priority (highest first). All matching rules
  contribute their tag_id (duplicates removed).
  """
  def match_tags(nil), do: []
  def match_tags(""), do: []

  def match_tags(label) when is_binary(label) do
    label_lower = String.downcase(label)

    TaggingRule
    |> order_by([r], desc: r.priority)
    |> Repo.all()
    |> Enum.filter(fn rule ->
      keyword_lower = String.downcase(rule.keyword)
      String.contains?(label_lower, keyword_lower)
    end)
    |> Enum.map(& &1.tag_id)
    |> Enum.uniq()
  end

  @doc """
  Applies all rules to transactions that currently have no tags.
  Returns `{:ok, tagged_count}`.
  """
  def apply_rules_to_untagged do
    tagged_ids =
      from(tt in TransactionTag, select: tt.transaction_id, distinct: true)
      |> Repo.all()
      |> MapSet.new()

    untagged =
      Moulax.Transactions.Transaction
      |> Repo.all()
      |> Enum.reject(fn t -> MapSet.member?(tagged_ids, t.id) end)

    count =
      Enum.reduce(untagged, 0, fn t, acc ->
        tag_ids = match_tags(t.label)

        if tag_ids == [] do
          acc
        else
          Moulax.Transactions.set_transaction_tags(t.id, tag_ids)
          acc + 1
        end
      end)

    {:ok, count}
  end

  defp rule_to_response(%TaggingRule{tag: %Tag{} = tag} = rule) do
    %{
      id: rule.id,
      keyword: rule.keyword,
      tag_id: rule.tag_id,
      tag: %{
        id: tag.id,
        name: tag.name,
        color: tag.color
      },
      priority: rule.priority
    }
  end
end
