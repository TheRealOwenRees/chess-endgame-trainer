defmodule Chesstrainer.Puzzles do
  @moduledoc """
  Selects endgames to serve as puzzles.

  Difficulty is a bias, not a filter. Every endgame is weighted by how close its
  rating is to a target derived from the user's rating — the user's own rating
  for `:medium`, below it for `:easy` and above it for `:hard` — and one
  candidate is drawn from that weighted distribution. Nearby endgames are much
  more likely, but the whole library stays reachable, so a thin region around
  the user's rating can never leave the pool empty.

  Endgames the user has attempted inside the repeat window are skipped, as is
  anything passed in `:exclude_ids` (the puzzles already served in a session).
  Only when every candidate is excluded does selection fall back to the least
  recently attempted endgame, so the repeat is the most overdue one rather than
  an arbitrary one.

  The same endgame is therefore easy for one player and hard for another: a
  rating is what makes the two comparable.
  """

  import Ecto.Query, warn: false

  alias Chesstrainer.Repo
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Attempts
  alias Chesstrainer.Attempts.Attempt
  alias Chesstrainer.Endgames.Endgame

  @default_spread 150
  @default_repeat_window_days 30
  @default_targets [easy: -200, medium: 0, hard: 200]
  @difficulties [:easy, :medium, :hard]

  @doc "The difficulties a session can be played at."
  def difficulties, do: @difficulties

  @doc """
  How far, in rating points, a puzzle's likelihood falls off from the target.

  A larger spread draws more widely around the target. Configured under
  `:chesstrainer, :puzzles, :spread`.
  """
  def spread, do: setting(:spread, @default_spread)

  @doc """
  The minimum gap, in days, before the same endgame may be served again.

  Configured under `:chesstrainer, :puzzles, :repeat_window_days`.
  """
  def repeat_window_days, do: setting(:repeat_window_days, @default_repeat_window_days)

  @doc """
  The rating `difficulty` aims at, given the player's `rating`.

  The offsets are configured under `:chesstrainer, :puzzles, :targets`.
  """
  def difficulty_target(rating, difficulty) when difficulty in @difficulties do
    rating + Keyword.fetch!(setting(:targets, @default_targets), difficulty)
  end

  @doc """
  Picks the next puzzle for `user` at `difficulty`, using `user.rating` as the
  baseline.

  `:exclude_ids` (default `[]`) skips endgames by id — used for the puzzles
  already served in this session. Returns `nil` when no endgame exists at all.
  """
  def next_endgame(%User{} = user, difficulty, opts \\ [])
      when difficulty in @difficulties do
    exclude_ids = Keyword.get(opts, :exclude_ids, [])
    recent_ids = Attempts.recent_endgame_ids(user.id, repeat_window_days())
    target = difficulty_target(user.rating, difficulty)

    Endgame
    |> on_side_of(user.rating, difficulty)
    |> skip_ids(exclude_ids ++ recent_ids)
    |> weighted_one(target)
    |> case do
      nil -> least_recently_attempted(user.id, exclude_ids)
      endgame -> endgame
    end
  end

  # Keep the labels honest: "easy" never serves above the user's rating plus the
  # spread, and "hard" never below it minus the spread. "medium" is open, which
  # is what lets it reach the rest of the library.
  defp on_side_of(query, _rating, :medium), do: query

  defp on_side_of(query, rating, :easy),
    do: where(query, [e], e.rating <= ^(rating + spread()))

  defp on_side_of(query, rating, :hard),
    do: where(query, [e], e.rating >= ^(rating - spread()))

  # Draw one row with probability proportional to
  # `exp(-|rating - target| / spread)`: an exponential race, where the row with
  # the smallest `-ln(U) / weight` wins.
  defp weighted_one(query, target) do
    spread = spread() * 1.0
    target = target * 1.0

    query
    |> order_by(
      [e],
      fragment("-ln(1 - random()) * exp(abs(? - ?) / ?)", e.rating, ^target, ^spread)
    )
    |> limit(1)
    |> Repo.one()
  end

  # Every candidate is excluded, so the repeat window is overruled: serve
  # whatever the user has waited longest to see again.
  defp least_recently_attempted(user_id, exclude_ids) do
    attempted =
      Attempt
      |> where([a], a.user_id == ^user_id)
      |> group_by([a], a.endgame_id)
      |> select([a], %{endgame_id: a.endgame_id, last_at: max(a.inserted_at)})

    Endgame
    |> skip_ids(exclude_ids)
    |> join(:left, [e], a in subquery(attempted), on: a.endgame_id == e.id)
    |> order_by([_e, a], asc_nulls_first: a.last_at)
    |> order_by([e], fragment("random()"))
    |> limit(1)
    |> Repo.one()
  end

  defp skip_ids(query, []), do: query
  defp skip_ids(query, ids), do: where(query, [e], e.id not in ^ids)

  defp setting(key, default) do
    :chesstrainer
    |> Application.get_env(:puzzles, [])
    |> Keyword.get(key, default)
  end
end
