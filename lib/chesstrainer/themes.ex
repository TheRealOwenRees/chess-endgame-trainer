defmodule Chesstrainer.Themes do
  @moduledoc """
  The Themes context.
  """

  import Ecto.Query, warn: false
  alias Chesstrainer.Repo

  alias Chesstrainer.Themes.Theme

  @doc """
  Returns the list of themes.

  ## Examples

      iex> list_themes()
      [%Theme{}, ...]

  """
  def list_themes do
    Repo.all(Theme)
  end

  @doc """
  Lists themes for the admin index with their endgame usage count.

  Options:

    * `:search` - case-insensitive match on the theme name
    * `:category` - one of `:endgame`, `:opening`, `:tactic`, or blank for all

  Returns `{theme, usage_count}` tuples sorted by name.
  """
  def list_themes_for_admin(opts \\ []) do
    search = opts |> Keyword.get(:search, "") |> to_string() |> String.trim()
    category = normalize_category(Keyword.get(opts, :category, ""))

    query = from(t in Theme, order_by: [asc: t.name])

    query =
      if search == "" do
        query
      else
        where(query, [t], ilike(t.name, ^"%#{search}%"))
      end

    query =
      if category do
        where(query, [t], t.category == ^category)
      else
        query
      end

    query
    |> join(:left, [t], j in "endgames_themes", on: j.theme_id == t.id)
    |> group_by([t], t.id)
    |> select([t, j], {t, count(j.endgame_id)})
    |> Repo.all()
  end

  @doc """
  Gets a single theme.

  Raises `Ecto.NoResultsError` if the Theme does not exist.

  ## Examples

      iex> get_theme!(123)
      %Theme{}

      iex> get_theme!(456)
      ** (Ecto.NoResultsError)

  """
  def get_theme!(id), do: Repo.get!(Theme, id)

  @doc """
  Creates a theme.

  ## Examples

      iex> create_theme(%{field: value})
      {:ok, %Theme{}}

      iex> create_theme(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_theme(attrs) do
    %Theme{}
    |> Theme.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a theme.

  ## Examples

      iex> update_theme(theme, %{field: new_value})
      {:ok, %Theme{}}

      iex> update_theme(theme, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_theme(%Theme{} = theme, attrs) do
    theme
    |> Theme.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a theme.

  ## Examples

      iex> delete_theme(theme)
      {:ok, %Theme{}}

      iex> delete_theme(theme)
      {:error, %Ecto.Changeset{}}

  """
  def delete_theme(%Theme{} = theme) do
    Repo.delete(theme)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking theme changes.

  ## Examples

      iex> change_theme(theme)
      %Ecto.Changeset{data: %Theme{}}

  """
  def change_theme(%Theme{} = theme, attrs \\ %{}) do
    Theme.changeset(theme, attrs)
  end

  def search("", _category), do: []

  def search(query, category) when is_binary(query) do
    case String.trim(query) do
      "" ->
        []

      query ->
        pattern = "%#{query}%"

        Theme
        |> where([t], ilike(t.name, ^pattern) and t.category == ^category)
        |> order_by([t], asc: t.name)
        |> limit(20)
        |> Repo.all()
    end
  end

  @doc """
  Finds a theme by name (trimmed and case-insensitive) for a category, creating it
  if it does not exist.
  """
  def get_or_create(name, category) when is_binary(name) do
    name = String.trim(name)

    if name == "" do
      {:error, :blank_name}
    else
      case find_by_name(name, category) do
        nil -> create_theme(%{name: name, category: category})
        theme -> {:ok, theme}
      end
    end
  end

  defp find_by_name(name, category) do
    downcased = String.downcase(name)

    Repo.one(
      from t in Theme,
        where: t.category == ^category and fragment("lower(?)", t.name) == ^downcased,
        limit: 1
    )
  end

  @doc """
  Returns the names of the given themes, sorted.
  """
  def names(themes) when is_list(themes) do
    themes |> Enum.map(& &1.name) |> Enum.sort()
  end

  defp normalize_category(category) when category in [:endgame, :opening, :tactic],
    do: category

  defp normalize_category(category) when is_binary(category) do
    Enum.find([:endgame, :opening, :tactic], &(Atom.to_string(&1) == category))
  end

  defp normalize_category(_category), do: nil
end
