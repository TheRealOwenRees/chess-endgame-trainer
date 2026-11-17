defmodule Chesstrainer.Themes do
  @moduledoc """
  The Themes context.
  """

  import Ecto.Query, warn: false
  alias Chesstrainer.Accounts.Policy
  alias Chesstrainer.Accounts.Scope
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
  Gets a single endgame theme by its slug.

  Returns `nil` when no endgame theme has that slug.
  """
  def get_theme_by_slug(slug) when is_binary(slug) do
    Repo.one(
      from t in Theme,
        where: t.slug == ^slug and t.category == :endgame,
        limit: 1
    )
  end

  @doc """
  Creates a theme.

  This is the unscoped path used by internal callers such as seeds, fixtures and
  the admin picker, which are already behind an authorization check. Prefer
  `create_theme/2` wherever a scope is available.

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
  Creates a theme on behalf of an administrator.

  Members cannot introduce new theme names; their contribution path is a
  suggestion, which a moderator reviews. Returns `{:error, :unauthorized}`
  for a scope that cannot manage themes.
  """
  def create_theme(%Scope{} = scope, attrs) do
    if Policy.can?(scope, :manage_themes) do
      create_theme(attrs)
    else
      {:error, :unauthorized}
    end
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

  Options:

    * `:kind` - the kind for a newly created theme; defaults to `:technique`

  This is the picker's helper and is expected to run behind an admin check.
  """
  def get_or_create(name, category, opts \\ []) when is_binary(name) do
    name = String.trim(name)

    if name == "" do
      {:error, :blank_name}
    else
      case find_by_name(name, category) do
        nil ->
          create_theme(%{
            name: name,
            category: category,
            kind: Keyword.get(opts, :kind, :technique)
          })

        theme ->
          {:ok, theme}
      end
    end
  end

  @doc """
  Replaces every link to `scoped_theme_ids` with the derived links in `links`.

  This is for themes that are objectively derived: the pass owns its themes
  entirely, so a link's previous source is irrelevant and every link is
  rewritten as `derived`. Links to themes outside `scoped_theme_ids` — curated
  or community — are untouched.

  The operation is a full refresh for the given themes, so it can move an
  endgame between families when a rule changes. `links` is a list of
  `{endgame_id, theme_id}` pairs.
  """
  @spec replace_theme_links([term()], [{Ecto.UUID.t(), term()}]) :: :ok
  def replace_theme_links(scoped_theme_ids, links) when is_list(links) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      if scoped_theme_ids != [] do
        Repo.delete_all(
          from l in "endgames_themes",
            where: l.theme_id in ^scoped_theme_ids
        )
      end

      links
      |> Enum.map(fn {endgame_id, theme_id} ->
        %{
          endgame_id: Ecto.UUID.dump!(endgame_id),
          theme_id: theme_id,
          source: "derived",
          inserted_at: now
        }
      end)
      |> Enum.chunk_every(5_000)
      |> Enum.each(fn rows ->
        Repo.insert_all("endgames_themes", rows, on_conflict: :nothing)
      end)
    end)

    :ok
  end

  @doc """
  Replaces the derived theme links for one endgame.

  Only links whose source is `derived` are removed, so curated and
  community-approved links survive every derivation pass. Links that are
  already present are left alone, which makes the operation idempotent.
  """
  @spec sync_derived_themes(Ecto.UUID.t(), [term()]) :: :ok
  def sync_derived_themes(endgame_id, theme_ids) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      Repo.delete_all(
        from l in "endgames_themes",
          where: l.endgame_id == type(^endgame_id, :binary_id) and l.source == "derived"
      )

      rows =
        theme_ids
        |> Enum.uniq()
        |> Enum.map(fn theme_id ->
          %{
            endgame_id: Ecto.UUID.dump!(endgame_id),
            theme_id: theme_id,
            source: "derived",
            inserted_at: now
          }
        end)

      if rows != [] do
        Repo.insert_all("endgames_themes", rows, on_conflict: :nothing)
      end
    end)

    :ok
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
