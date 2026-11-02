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
  Creates a endgame.

  ## Examples

      iex> create_endgame(%{field: value})
      {:ok, %Endgame{}}

      iex> create_endgame(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_endgame(attrs, themes \\ []) do
    %Endgame{}
    |> Endgame.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:themes, themes)
    |> Repo.insert()
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
