defmodule Moulax.Tags do
  @moduledoc """
  Context for managing tags.
  """

  import Ecto.Query

  alias Moulax.Repo
  alias Moulax.Tags.Tag
  alias Moulax.Tags.TransactionTag

  @doc """
  Returns all tags ordered by name.
  """
  def list_tags do
    Tag
    |> order_by(asc: :name)
    |> Repo.all()
  end

  @doc """
  Gets a single tag by ID.

  Returns `{:ok, tag}` or `{:error, :not_found}`.
  """
  def get_tag(id) do
    case Repo.get(Tag, id) do
      nil -> {:error, :not_found}
      tag -> {:ok, tag}
    end
  end

  @doc """
  Creates a new tag.
  """
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tag.
  """
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tag. Removes all transaction_tags associations first.
  """
  def delete_tag(%Tag{} = tag) do
    Repo.transaction(fn ->
      from(tt in TransactionTag, where: tt.tag_id == ^tag.id)
      |> Repo.delete_all()

      Repo.delete!(tag)
    end)
  end
end
