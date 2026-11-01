defmodule Chesstrainer.Tags do
  @moduledoc """
  The Tags context.
  """

  import Ecto.Query, warn: false
  alias Chesstrainer.Repo

  alias Chesstrainer.Tags.Tag

  @doc """
  Returns the list of tags.

  ## Examples

      iex> list_tags()
      [%Tag{}, ...]

  """
  def list_tags do
    Repo.all(Tag)
  end

  @doc """
  Gets a single tag.

  Raises `Ecto.NoResultsError` if the Tag does not exist.

  ## Examples

      iex> get_tag!(123)
      %Tag{}

      iex> get_tag!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tag!(id), do: Repo.get!(Tag, id)

  @doc """
  Creates a tag.

  ## Examples

      iex> create_tag(%{field: value})
      {:ok, %Tag{}}

      iex> create_tag(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tag(attrs) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tag.

  ## Examples

      iex> update_tag(tag, %{field: new_value})
      {:ok, %Tag{}}

      iex> update_tag(tag, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tag.

  ## Examples

      iex> delete_tag(tag)
      {:ok, %Tag{}}

      iex> delete_tag(tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag changes.

  ## Examples

      iex> change_tag(tag)
      %Ecto.Changeset{data: %Tag{}}

  """
  def change_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end

  def search("", _category), do: []

  def search(query, category) when is_binary(query) do
    case String.trim(query) do
      "" ->
        []

      query ->
        pattern = "%#{query}%"

        Tag
        |> where([t], ilike(t.name, ^pattern) and t.category == ^category)
        |> order_by([t], asc: t.name)
        |> limit(20)
        |> Repo.all()
    end
  end

  @doc """
  Finds a tag by name (trimmed and case-insensitive) for a category, creating it
  if it does not exist.
  """
  def get_or_create(name, category) when is_binary(name) do
    name = String.trim(name)

    if name == "" do
      {:error, :blank_name}
    else
      case find_by_name(name, category) do
        nil -> create_tag(%{name: name, category: category})
        tag -> {:ok, tag}
      end
    end
  end

  defp find_by_name(name, category) do
    downcased = String.downcase(name)

    Repo.one(
      from t in Tag,
        where: t.category == ^category and fragment("lower(?)", t.name) == ^downcased,
        limit: 1
    )
  end

  @doc """
  Returns the names of the given tags, sorted.
  """
  def names(tags) when is_list(tags) do
    tags |> Enum.map(& &1.name) |> Enum.sort()
  end
end
