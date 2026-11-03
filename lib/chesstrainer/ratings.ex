defmodule Chesstrainer.Ratings do
  @moduledoc """
  Applies Glicko rating updates to a finished attempt.

  Both sides are rated: the user as the player and the endgame as the opponent,
  then the reverse so the endgame's difficulty tracks its results.

  An attempt only changes ratings when the same user/endgame pair has not been
  rated inside the rating window. When it does rate, each side's deviation is
  widened in proportion to how long that side has been inactive, so a return
  after a long gap moves ratings further than a quick return.
  """

  alias Chesstrainer.Repo
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Attempts
  alias Chesstrainer.Attempts.Attempt

  @default_system_constant 0.8
  @default_window_days 7
  @default_rd_inflation_c 10.0
  @max_rd 350.0
  @seconds_per_day 86_400

  @doc """
  Rates both sides of a finished attempt and stamps it as rated.

  A solve scores 1 for the user and 0 for the endgame; a failure scores 0 for
  the user and 1 for the endgame. Returns `{:ok, %{user, endgame, attempt}}`, or
  `{:skipped, attempt}` when the pair was already rated inside the window.
  """
  def rate_attempt(%Attempt{outcome: outcome} = attempt) do
    now = DateTime.utc_now(:second)

    if rate?(attempt, now) do
      user = Repo.get!(User, attempt.user_id)
      endgame = Repo.get!(Endgame, attempt.endgame_id)

      user_rd =
        inflate(
          user.rating_deviation,
          elapsed_days(now, Attempts.last_rated_at_for_user(user.id))
        )

      endgame_rd =
        inflate(
          endgame.rating_deviation,
          elapsed_days(now, Attempts.last_rated_at_for_endgame(endgame.id))
        )

      user_player = player(user.rating, user_rd)
      endgame_player = player(endgame.rating, endgame_rd)

      score = score_for(outcome)

      new_user =
        Glicko.new_rating(user_player, [Glicko.Result.new(endgame_player, score)], opts())

      new_endgame =
        Glicko.new_rating(endgame_player, [Glicko.Result.new(user_player, 1.0 - score)], opts())

      persist(user, endgame, attempt, new_user, new_endgame, now)
    else
      {:skipped, attempt}
    end
  end

  defp rate?(attempt, now) do
    case Attempts.last_rated_at(attempt.user_id, attempt.endgame_id) do
      nil -> true
      last -> DateTime.diff(now, last, :second) >= window_days() * @seconds_per_day
    end
  end

  defp persist(user, endgame, attempt, new_user, new_endgame, now) do
    Repo.transaction(fn ->
      user =
        user
        |> Ecto.Changeset.change(
          rating: new_user.rating,
          rating_deviation: new_user.rating_deviation
        )
        |> Repo.update!()

      endgame =
        endgame
        |> Ecto.Changeset.change(
          rating: new_endgame.rating,
          rating_deviation: new_endgame.rating_deviation
        )
        |> Repo.update!()

      attempt =
        attempt
        |> Ecto.Changeset.change(rated_at: now)
        |> Repo.update!()

      %{user: user, endgame: endgame, attempt: attempt}
    end)
  end

  defp player(rating, rating_deviation) do
    Glicko.Player.new_v1(rating: rating, rating_deviation: rating_deviation)
  end

  # Widen a deviation by the time since that side last had a rated result,
  # capped at the Glicko maximum.
  defp inflate(rd, days) when days <= 0.0, do: rd

  defp inflate(rd, days) do
    c = rd_inflation_c()
    min(:math.sqrt(rd * rd + c * c * days), @max_rd)
  end

  defp elapsed_days(_now, nil), do: 0.0

  defp elapsed_days(now, last) do
    max(DateTime.diff(now, last, :second), 0) / @seconds_per_day
  end

  defp score_for(:solved), do: 1.0
  defp score_for(:failed), do: 0.0

  defp opts, do: [system_constant: system_constant()]

  defp config, do: Application.get_env(:chesstrainer, :ratings, [])
  defp system_constant, do: Keyword.get(config(), :system_constant, @default_system_constant)
  defp window_days, do: Keyword.get(config(), :window_days, @default_window_days)
  defp rd_inflation_c, do: Keyword.get(config(), :rd_inflation_c, @default_rd_inflation_c)
end
