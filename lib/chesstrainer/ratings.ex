defmodule Chesstrainer.Ratings do
  @moduledoc """
  Applies Glicko rating updates to a finished attempt.

  Both sides are rated: the user as the player and the endgame as the
  opponent, then the reverse so the endgame's difficulty tracks its results.
  """

  alias Chesstrainer.Repo
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Attempts.Attempt

  @default_system_constant 0.8

  @doc """
  Rates both sides of a finished attempt and stamps it as rated.

  A solve scores 1 for the user and 0 for the endgame; a failure scores 0 for
  the user and 1 for the endgame. Returns the updated user, endgame and attempt.
  """
  def rate_attempt(%Attempt{outcome: outcome} = attempt) do
    user = Repo.get!(User, attempt.user_id)
    endgame = Repo.get!(Endgame, attempt.endgame_id)

    score = score_for(outcome)
    user_player = player(user)
    endgame_player = player(endgame)

    new_user =
      Glicko.new_rating(user_player, [Glicko.Result.new(endgame_player, score)], opts())

    new_endgame =
      Glicko.new_rating(endgame_player, [Glicko.Result.new(user_player, 1.0 - score)], opts())

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
        |> Ecto.Changeset.change(rated_at: DateTime.utc_now(:second))
        |> Repo.update!()

      %{user: user, endgame: endgame, attempt: attempt}
    end)
  end

  defp player(%{rating: rating, rating_deviation: rating_deviation}) do
    Glicko.Player.new_v1(rating: rating, rating_deviation: rating_deviation)
  end

  defp score_for(:solved), do: 1.0
  defp score_for(:failed), do: 0.0

  defp opts do
    ratings = Application.get_env(:chesstrainer, :ratings, [])
    [system_constant: Keyword.get(ratings, :system_constant, @default_system_constant)]
  end
end
