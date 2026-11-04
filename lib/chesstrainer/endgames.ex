defmodule Chesstrainer.Endgames do
  @moduledoc """
  The Endgames context.
  """

  import Ecto.Query, warn: false
  alias Chesstrainer.Repo

  alias Chesstrainer.Endgames.Endgame

  @doc """
  Returns the list of endgames.

  ## Examples

      iex> list_endgames()
      [%Endgame{}, ...]

  """
  def list_endgames do
    Repo.all(Endgame)
  end

  @doc """
  Returns a random endgame, or `nil` when none exist.
  """
  def random_endgame do
    Repo.one(from e in Endgame, order_by: fragment("RANDOM()"), limit: 1)
  end

  @curated_count 3

  @doc """
  Returns curated endgames for the landing page, with themes preloaded.

  Curation is the configured list of `:curated_endgame_codes`; codes that do not
  resolve are skipped. The list is topped up with a date-seeded selection from
  the database so it is stable for a given day, and is empty when no endgames
  exist.
  """
  def curated_endgames(count \\ @curated_count) do
    codes = Application.get_env(:chesstrainer, :curated_endgame_codes, [])

    curated =
      codes
      |> Enum.flat_map(&endgame_for_code/1)
      |> Enum.uniq_by(& &1.id)

    fill_curated(curated, count)
  end

  defp endgame_for_code(code) do
    case Repo.get_by(Endgame, public_code: code) do
      nil -> []
      endgame -> [Repo.preload(endgame, :themes)]
    end
  end

  defp fill_curated(endgames, count) when length(endgames) >= count,
    do: Enum.take(endgames, count)

  defp fill_curated(endgames, count) do
    exclude_ids = Enum.map(endgames, & &1.id)
    endgames ++ date_seeded_endgames(exclude_ids, count - length(endgames))
  end

  defp date_seeded_endgames([], limit), do: date_seeded_endgames_query(Endgame, limit)

  defp date_seeded_endgames(exclude_ids, limit) do
    Endgame
    |> where([e], e.id not in ^exclude_ids)
    |> date_seeded_endgames_query(limit)
  end

  defp date_seeded_endgames_query(query, limit) do
    today = Date.utc_today()

    query
    |> preload(:themes)
    |> Repo.all()
    |> Enum.sort_by(fn endgame -> :erlang.phash2({today, endgame.id}) end)
    |> Enum.take(limit)
  end

  @doc """
  Returns the distinct Keys across all endgames, sorted.
  """
  def list_keys do
    Repo.all(from e in Endgame, distinct: true, select: e.key, order_by: [asc: e.key])
  end

  @doc """
  Returns `{key, count}` groups for endgames matching the filters, sorted by key.

  Filters is a map with optional `:themes` (a list of theme ids; an endgame must
  carry any one of them) and `:key` (an exact Key).
  """
  def list_key_groups(filters \\ %{}) do
    Endgame
    |> apply_filters(filters)
    |> group_by([e], e.key)
    |> select([e], {e.key, count(e.id)})
    |> order_by([e], asc: e.key)
    |> Repo.all()
  end

  @doc """
  Returns the endgames for one Key, matching the filters, with themes preloaded.
  """
  def list_endgames_for_key(key, filters \\ %{}) do
    Endgame
    |> apply_filters(filters)
    |> where([e], e.key == ^key)
    |> preload(:themes)
    |> order_by([e], asc: e.fen)
    |> Repo.all()
  end

  defp apply_filters(query, filters) do
    query
    |> filter_themes(Map.get(filters, :themes, []))
    |> filter_key(Map.get(filters, :key))
  end

  defp filter_themes(query, []), do: query

  defp filter_themes(query, theme_ids) do
    endgame_ids =
      from(t in "endgames_themes",
        where: t.theme_id in ^theme_ids,
        select: t.endgame_id
      )

    where(query, [e], e.id in subquery(endgame_ids))
  end

  defp filter_key(query, key) when key in [nil, ""], do: query
  defp filter_key(query, key), do: where(query, [e], e.key == ^key)

  @doc """
  Gets a single endgame.

  Raises `Ecto.NoResultsError` if the Endgame does not exist.

  ## Examples

      iex> get_endgame!(123)
      %Endgame{}

      iex> get_endgame!(456)
      ** (Ecto.NoResultsError)

  """
  def get_endgame!(id), do: Repo.get!(Endgame, id)

  @doc """
  Gets a single endgame by its public code, raising if it does not exist.
  """
  def get_endgame_by_public_code!(public_code) do
    Repo.get_by!(Endgame, public_code: public_code)
  end

  @doc """
  Gets a single endgame by its public code with its themes preloaded.
  """
  def get_endgame_by_public_code_with_themes!(public_code) do
    Endgame
    |> Repo.get_by!(public_code: public_code)
    |> Repo.preload(:themes)
  end

  @doc """
  Finds endgames by database id, public code, or FEN.

  A full FEN matches exactly (after normalisation); a fragment matches any FEN
  containing it. Themes are preloaded. A blank query returns `[]`.
  """
  def search(query) do
    query = String.trim(query || "")

    if query == "" do
      []
    else
      [search_by_id(query), search_by_public_code(query), search_by_fen(query)]
      |> Enum.reject(&is_nil/1)
      |> List.flatten()
      |> Enum.uniq_by(& &1.id)
    end
  end

  defp search_by_id(query) do
    case Ecto.UUID.cast(query) do
      {:ok, id} -> Repo.get(Endgame, id) |> preload_themes()
      :error -> nil
    end
  end

  defp search_by_public_code(query) do
    Repo.get_by(Endgame, public_code: query) |> preload_themes()
  end

  defp search_by_fen(query) do
    pattern = "%" <> escape_like(Chesstrainer.FEN.normalize(query)) <> "%"

    Endgame
    |> where([e], like(e.fen, ^pattern))
    |> preload(:themes)
    |> order_by([e], asc: e.key, asc: e.fen)
    |> Repo.all()
  end

  defp preload_themes(nil), do: nil
  defp preload_themes(endgame), do: Repo.preload(endgame, :themes)

  defp escape_like(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  @doc """
  Creates a endgame.

  ## Examples

      iex> create_endgame(%{field: value})
      {:ok, %Endgame{}}

      iex> create_endgame(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_endgame(attrs, themes \\ []), do: insert_endgame(attrs, themes, 3)

  defp insert_endgame(attrs, themes, attempts) do
    result =
      %Endgame{}
      |> Endgame.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:themes, themes)
      |> Repo.insert()

    case result do
      {:error, changeset} when attempts > 1 ->
        if Keyword.has_key?(changeset.errors, :public_code),
          do: insert_endgame(attrs, themes, attempts - 1),
          else: result

      other ->
        other
    end
  end

  @doc """
  Updates a endgame.

  ## Examples

      iex> update_endgame(endgame, %{field: new_value})
      {:ok, %Endgame{}}

      iex> update_endgame(endgame, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_endgame(%Endgame{} = endgame, attrs, themes \\ []) do
    # ignore fen on update
    attrs = Map.delete(attrs, "fen")

    endgame
    |> Repo.preload(:themes)
    |> Endgame.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:themes, themes)
    |> Repo.update()
  end

  @doc """
  Deletes a endgame.

  ## Examples

      iex> delete_endgame(endgame)
      {:ok, %Endgame{}}

      iex> delete_endgame(endgame)
      {:error, %Ecto.Changeset{}}

  """
  def delete_endgame(%Endgame{} = endgame) do
    Repo.delete(endgame)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking endgame changes.

  ## Examples

      iex> change_endgame(endgame)
      %Ecto.Changeset{data: %Endgame{}}

  """
  def change_endgame(%Endgame{} = endgame, attrs \\ %{}) do
    Endgame.changeset(endgame, attrs)
  end

  @doc """
  Records the start of an attempt, incrementing `times_attempted`.
  """
  def record_attempt(%Endgame{id: id}), do: increment(id, times_attempted: 1)

  @doc """
  Records a solved attempt, incrementing `times_solved`.
  """
  def record_solve(%Endgame{id: id}), do: increment(id, times_solved: 1)

  defp increment(id, increments) do
    Repo.update_all(from(e in Endgame, where: e.id == ^id), inc: increments)

    {:ok, Repo.get!(Endgame, id)}
  end
end
