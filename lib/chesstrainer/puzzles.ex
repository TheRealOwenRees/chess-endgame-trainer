defmodule Chesstrainer.Puzzles do
  @moduledoc """
  Selects endgames to serve as puzzles.

  A puzzle is played at one of three difficulties — `:easy`, `:medium` or
  `:hard` — defined relative to the current user's rating: `:medium` is within
  a configurable band of the user's rating, `:easy` below it and `:hard` above
  it. The same endgame is therefore easy for one player and hard for another.

  Selection prefers endgames the user has not attempted in the last 30 days.
  When that pool is empty it falls back to any endgame in the band; the rating
  window keeps a recent replay unrated until it expires.
  """

  import Ecto.Query, warn: false

  alias Chesstrainer.Repo
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Attempts
  alias Chesstrainer.Endgames.Endgame

  @default_band_width 100
  @difficulties [:easy, :medium, :hard]

  @doc "The difficulties a session can be played at."
  def difficulties, do: @difficulties

  @doc """
  The half-width of the medium band, in rating points.

  Configured under `:chesstrainer, :puzzles, :band_width`.
  """
  def band_width do
    :chesstrainer
    |> Application.get_env(:puzzles, [])
    |> Keyword.get(:band_width, @default_band_width)
  end

  @doc """
  The `{min, max}` rating range for `difficulty` relative to `rating`.

  A `nil` bound is open-ended.
  """
  def difficulty_range(rating, difficulty) when difficulty in @difficulties do
    width = band_width()

    case difficulty do
      :easy -> {nil, rating - width}
      :medium -> {rating - width, rating + width}
      :hard -> {rating + width, nil}
    end
  end

  @doc """
  Picks the next puzzle for `user` at `difficulty`, using `user.rating` as the
  baseline.

  `:exclude_ids` (default `[]`) skips endgames by id — used to avoid repeating
  the puzzle just played. Returns `nil` when no endgame exists at all.
  """
  def next_endgame(%User{} = user, difficulty, opts \\ [])
      when difficulty in @difficulties do
    exclude_ids = Keyword.get(opts, :exclude_ids, [])
    band = difficulty_range(user.rating, difficulty)
    recent_ids = Attempts.recent_endgame_ids(user.id)

    fresh =
      Endgame
      |> in_band(band)
      |> skip_ids(exclude_ids)
      |> skip_ids(recent_ids)
      |> random_one()

    fresh || fallback(user.rating, band, exclude_ids)
  end

  defp fallback(rating, band, exclude_ids) do
    Endgame
    |> in_band(band)
    |> skip_ids(exclude_ids)
    |> random_one()
    |> case do
      nil -> nearest(rating, exclude_ids)
      endgame -> endgame
    end
  end

  defp nearest(rating, exclude_ids) do
    Endgame
    |> skip_ids(exclude_ids)
    |> order_by([e], asc: fragment("ABS(? - ?)", e.rating, ^rating))
    |> limit(1)
    |> Repo.one()
  end

  defp random_one(query) do
    query
    |> order_by([e], fragment("RANDOM()"))
    |> limit(1)
    |> Repo.one()
  end

  defp in_band(query, {nil, max}), do: where(query, [e], e.rating <= ^max)
  defp in_band(query, {min, nil}), do: where(query, [e], e.rating >= ^min)

  defp in_band(query, {min, max}),
    do: where(query, [e], e.rating >= ^min and e.rating <= ^max)

  defp skip_ids(query, []), do: query
  defp skip_ids(query, ids), do: where(query, [e], e.id not in ^ids)
end
