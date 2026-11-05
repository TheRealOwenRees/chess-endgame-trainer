defmodule Chesstrainer.Attempts do
  @moduledoc """
  The Attempts context: a per-user history of finished playthroughs.
  """

  import Ecto.Query, warn: false

  alias Chesstrainer.Repo
  alias Chesstrainer.Accounts.{Scope, User}
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Attempts.Attempt

  @doc """
  Records a finished attempt for the signed-in user in `scope`.

  Anonymous scopes record nothing and return `:ignored`.
  """
  def record_attempt(nil, _endgame, _outcome), do: :ignored

  def record_attempt(%Scope{user: nil}, _endgame, _outcome), do: :ignored

  def record_attempt(%Scope{user: %User{} = user}, %Endgame{} = endgame, outcome)
      when outcome in [:solved, :failed] do
    %Attempt{user_id: user.id, endgame_id: endgame.id}
    |> Attempt.changeset(%{outcome: outcome})
    |> Repo.insert()
  end

  @doc """
  The timestamp of the most recent rated attempt for a user/endgame pair, or nil.
  """
  def last_rated_at(user_id, endgame_id) do
    Attempt
    |> where([a], a.user_id == ^user_id and a.endgame_id == ^endgame_id)
    |> rated()
    |> select([a], max(a.rated_at))
    |> Repo.one()
  end

  @doc """
  The timestamp of the most recent rated attempt for a user, or nil.
  """
  def last_rated_at_for_user(user_id) do
    Attempt
    |> where([a], a.user_id == ^user_id)
    |> rated()
    |> select([a], max(a.rated_at))
    |> Repo.one()
  end

  @doc """
  The timestamp of the most recent rated attempt on an endgame, or nil.
  """
  def last_rated_at_for_endgame(endgame_id) do
    Attempt
    |> where([a], a.endgame_id == ^endgame_id)
    |> rated()
    |> select([a], max(a.rated_at))
    |> Repo.one()
  end

  @doc """
  Returns the number of users who have recorded at least one attempt.

  A retry does not count twice: the count is over distinct users.
  """
  def count_users_with_attempts do
    Attempt
    |> select([a], count(a.user_id, :distinct))
    |> Repo.one()
  end

  @doc """
  The distinct endgame ids `user_id` has attempted in the last `days` days.

  Used by puzzle selection to prefer fresh puzzles; a retry still counts as an
  attempt, even though the rating window leaves it unrated.
  """
  def recent_endgame_ids(user_id, days \\ 30) do
    cutoff = DateTime.add(DateTime.utc_now(), -days, :day)

    Attempt
    |> where([a], a.user_id == ^user_id and a.inserted_at >= ^cutoff)
    |> distinct(true)
    |> select([a], a.endgame_id)
    |> Repo.all()
  end

  defp rated(query), do: where(query, [a], not is_nil(a.rated_at))
end
