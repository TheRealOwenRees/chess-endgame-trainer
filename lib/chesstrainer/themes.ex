defmodule Chesstrainer.Themes do
  @moduledoc """
  The Themes context.
  """

  import Ecto.Query, warn: false
  alias Chesstrainer.Accounts.Policy
  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Attempts
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Repo

  alias Chesstrainer.Themes.Theme
  alias Chesstrainer.Themes.ThemeSuggestion

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

  @doc """
  Searches themes by name within a category.

  Options:

    * `:kind` - restrict to one kind, e.g. `:technique`
    * `:exclude_ids` - omit themes with these ids
  """
  def search(query, category, opts \\ [])

  def search("", _category, _opts), do: []

  def search(query, category, opts) when is_binary(query) do
    case String.trim(query) do
      "" ->
        []

      query ->
        pattern = "%#{query}%"
        kind = Keyword.get(opts, :kind)
        exclude_ids = Keyword.get(opts, :exclude_ids, [])

        Theme
        |> where([t], ilike(t.name, ^pattern) and t.category == ^category)
        |> then(fn q -> if kind, do: where(q, [t], t.kind == ^kind), else: q end)
        |> then(fn q ->
          if exclude_ids == [], do: q, else: where(q, [t], t.id not in ^exclude_ids)
        end)
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

  @link_sources [:curated, :community]

  @doc """
  Links `theme` to many endgames at once with the given source.

  Defaults to `:curated`, which is what the admin tagging workspace writes.
  Existing links are left alone, so re-applying is safe. Returns the number of
  endgames the link was attempted for.
  """
  @spec tag_endgames(Theme.t(), [Ecto.UUID.t()], :curated | :community) ::
          {:ok, non_neg_integer()}
  def tag_endgames(%Theme{id: theme_id}, endgame_ids, source \\ :curated)
      when is_list(endgame_ids) and source in @link_sources do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    endgame_ids
    |> Enum.uniq()
    |> Enum.map(fn endgame_id ->
      %{
        endgame_id: Ecto.UUID.dump!(endgame_id),
        theme_id: theme_id,
        source: to_string(source),
        inserted_at: now
      }
    end)
    |> Enum.chunk_every(5_000)
    |> Enum.each(fn rows ->
      Repo.insert_all("endgames_themes", rows, on_conflict: :nothing)
    end)

    {:ok, length(Enum.uniq(endgame_ids))}
  end

  @doc """
  Removes a link from `theme` to one endgame, but only if it has the given
  source.

  The tagging workspace removes `:curated` links only, so a derived or
  community link can never be deleted by hand. Returns the number removed.
  """
  @spec untag_endgame(Theme.t(), Ecto.UUID.t(), :curated | :community) ::
          {:ok, non_neg_integer()}
  def untag_endgame(%Theme{id: theme_id}, endgame_id, source \\ :curated)
      when source in @link_sources do
    {count, _} =
      Repo.delete_all(
        from l in "endgames_themes",
          where:
            l.theme_id == ^theme_id and l.endgame_id == type(^endgame_id, :binary_id) and
              l.source == ^to_string(source)
      )

    {:ok, count}
  end

  @doc """
  Suggests a technique theme for an endgame on behalf of a signed-in player.

  `attrs` carries either `:theme_id` for an existing theme or `:proposed_name`
  for a new one. The player must have a recorded attempt on the endgame, and
  only technique themes can be suggested. The result is stored as `pending`;
  this never creates an endgame-to-theme link.

  A proposed name that matches an existing theme is folded into a suggestion
  for that theme instead of becoming a duplicate name.
  """
  @spec suggest_theme(Scope.t() | nil, Endgame.t(), map()) ::
          {:ok, ThemeSuggestion.t()} | {:error, atom() | Ecto.Changeset.t()}
  def suggest_theme(scope, endgame, attrs)

  def suggest_theme(nil, _endgame, _attrs), do: {:error, :unauthorized}
  def suggest_theme(%Scope{user: nil}, _endgame, _attrs), do: {:error, :unauthorized}

  def suggest_theme(%Scope{user: %User{} = user}, %Endgame{} = endgame, attrs) do
    with true <- Attempts.attempted?(user.id, endgame.id) || {:error, :not_attempted},
         {:ok, target} <- suggestion_target(endgame, attrs) do
      %ThemeSuggestion{user_id: user.id, endgame_id: endgame.id, status: :pending}
      |> ThemeSuggestion.changeset(target)
      |> Repo.insert()
    end
  end

  @doc """
  Withdraws a player's own pending suggestion.
  """
  @spec withdraw_suggestion(Scope.t() | nil, ThemeSuggestion.t()) ::
          {:ok, ThemeSuggestion.t()} | {:error, :unauthorized | :not_pending}
  def withdraw_suggestion(scope, suggestion)

  def withdraw_suggestion(nil, _suggestion), do: {:error, :unauthorized}
  def withdraw_suggestion(%Scope{user: nil}, _suggestion), do: {:error, :unauthorized}

  def withdraw_suggestion(
        %Scope{user: %User{id: user_id}},
        %ThemeSuggestion{user_id: user_id, status: :pending} = suggestion
      ) do
    Repo.delete(suggestion)
  end

  def withdraw_suggestion(%Scope{user: %User{id: user_id}}, %ThemeSuggestion{user_id: user_id}) do
    {:error, :not_pending}
  end

  def withdraw_suggestion(_scope, _suggestion), do: {:error, :unauthorized}

  @doc """
  The number of pending suggestions for an endgame.
  """
  def pending_suggestion_count(endgame_id) do
    Repo.one(
      from s in ThemeSuggestion,
        where: s.endgame_id == ^endgame_id and s.status == :pending,
        select: count(s.id)
    )
  end

  @doc """
  Pending suggestion counts keyed by existing theme id.
  """
  def pending_suggestion_counts(endgame_id) do
    ThemeSuggestion
    |> where(
      [s],
      s.endgame_id == ^endgame_id and s.status == :pending and not is_nil(s.theme_id)
    )
    |> group_by([s], s.theme_id)
    |> select([s], {s.theme_id, count(s.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  A player's pending suggestions for one endgame, with the suggested theme.
  """
  def pending_suggestions_for_user(endgame_id, user_id) do
    ThemeSuggestion
    |> where(
      [s],
      s.endgame_id == ^endgame_id and s.user_id == ^user_id and s.status == :pending
    )
    |> order_by([s], asc: s.inserted_at)
    |> preload(:theme)
    |> Repo.all()
  end

  @doc """
  Every suggestion a player has made, newest first, for the data export.
  """
  def list_suggestions_for_user(user_id) do
    ThemeSuggestion
    |> where([s], s.user_id == ^user_id)
    |> order_by([s], desc: s.inserted_at)
    |> preload([:endgame, :theme])
    |> Repo.all()
  end

  defp suggestion_target(endgame, attrs) do
    theme_id = Map.get(attrs, :theme_id) || Map.get(attrs, "theme_id")
    name = Map.get(attrs, :proposed_name) || Map.get(attrs, "proposed_name")

    cond do
      present?(theme_id) -> existing_theme_target(endgame, theme_id)
      present?(name) -> proposed_name_target(endgame, name)
      true -> {:error, :blank}
    end
  end

  defp existing_theme_target(endgame, theme_id) do
    case Repo.get(Theme, theme_id) do
      nil ->
        {:error, :unknown_theme}

      %Theme{} = theme ->
        cond do
          theme.category != :endgame -> {:error, :not_suggestible}
          theme.kind != :technique -> {:error, :not_suggestible}
          endgame_theme?(endgame.id, theme.id) -> {:error, :already_tagged}
          true -> {:ok, %{theme_id: theme.id}}
        end
    end
  end

  defp proposed_name_target(endgame, name) do
    name = String.trim(name)

    cond do
      name == "" ->
        {:error, :blank_name}

      String.length(name) > 60 ->
        {:error, :name_too_long}

      true ->
        case find_by_name(name, :endgame) do
          %Theme{kind: :technique} = theme -> existing_theme_target(endgame, theme.id)
          %Theme{} -> {:error, :not_suggestible}
          nil -> {:ok, %{proposed_name: name}}
        end
    end
  end

  defp endgame_theme?(endgame_id, theme_id) do
    Repo.exists?(
      from l in "endgames_themes",
        where: l.endgame_id == type(^endgame_id, :binary_id) and l.theme_id == ^theme_id
    )
  end

  defp present?(value), do: not is_nil(value) and to_string(value) != ""

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
