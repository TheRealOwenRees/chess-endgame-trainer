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
  def create_endgame(attrs) do
    %Endgame{}
    |> Endgame.changeset(attrs)
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
  def update_endgame(%Endgame{} = endgame, attrs) do
    # ignore fen on update
    attrs = Map.delete(attrs, "fen")

    endgame
    |> Endgame.changeset(attrs)
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

  def add_tag(endgame, tag) do
    endgame
    |> Repo.preload(:tags)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, [tag | endgame.tags])
    |> Repo.update()
  end

  def remove_tag(endgame, tag) do
    endgame
    |> Repo.preload(:tags)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, endgame.tags -- [tag])
    |> Repo.update()
  end
end
