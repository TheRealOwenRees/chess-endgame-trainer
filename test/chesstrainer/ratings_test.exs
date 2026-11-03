defmodule Chesstrainer.RatingsTest do
  use Chesstrainer.DataCase, async: true

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Attempts
  alias Chesstrainer.Attempts.Attempt
  alias Chesstrainer.Endgames.Endgame
  alias Chesstrainer.Ratings

  describe "rate_attempt/1" do
    test "a solve raises the user's rating and lowers the endgame's" do
      user = user_fixture()
      endgame = endgame_fixture(rating: 1800)
      {:ok, attempt} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

      assert {:ok, %{user: rated_user, endgame: rated_endgame, attempt: rated_attempt}} =
               Ratings.rate_attempt(attempt)

      assert rated_user.rating > 1500.0
      assert rated_endgame.rating < 1800.0
      assert is_float(rated_user.rating)
      assert is_float(rated_user.rating_deviation)
      assert is_float(rated_endgame.rating)
      assert is_float(rated_endgame.rating_deviation)
      refute is_nil(rated_attempt.rated_at)
    end

    test "a fail lowers the user's rating and raises the endgame's" do
      user = user_fixture()
      endgame = endgame_fixture(rating: 1800)
      {:ok, attempt} = Attempts.record_attempt(Scope.for_user(user), endgame, :failed)

      assert {:ok, %{user: rated_user, endgame: rated_endgame}} = Ratings.rate_attempt(attempt)

      assert rated_user.rating < 1500.0
      assert rated_endgame.rating > 1800.0
    end

    test "persists both ratings and stamps the attempt as rated" do
      user = user_fixture()
      endgame = endgame_fixture(rating: 1800)
      {:ok, attempt} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

      {:ok, _} = Ratings.rate_attempt(attempt)

      assert Repo.get!(User, user.id).rating > 1500.0
      assert Repo.get!(Endgame, endgame.id).rating < 1800.0
      assert Repo.get!(Attempt, attempt.id).rated_at
    end
  end

  describe "rating window" do
    test "skips a replay inside the window and leaves the attempt unrated" do
      user = user_fixture()
      endgame = endgame_fixture(rating: 1800)

      {:ok, first} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)
      {:ok, _} = Ratings.rate_attempt(first)
      rated_user = Repo.get!(User, user.id)
      rated_endgame = Repo.get!(Endgame, endgame.id)

      {:ok, replay} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

      assert {:skipped, %Attempt{rated_at: nil}} = Ratings.rate_attempt(replay)

      assert Repo.get!(User, user.id).rating == rated_user.rating
      assert Repo.get!(Endgame, endgame.id).rating == rated_endgame.rating
      assert Repo.get!(Attempt, replay.id).rated_at == nil
    end

    test "rates a replay after the window" do
      user = user_fixture()
      endgame = endgame_fixture(rating: 1800)

      {:ok, first} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)
      {:ok, _} = Ratings.rate_attempt(first)
      backdate!(first, 8)

      {:ok, replay} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

      assert {:ok, %{attempt: %Attempt{rated_at: rated_at}}} = Ratings.rate_attempt(replay)
      refute is_nil(rated_at)
    end
  end

  describe "inactivity" do
    test "a longer absence produces a larger rating change" do
      short =
        rating_delta_after_gap(
          8,
          "4k3/8/8/8/8/8/1K6/8 w - - 0 1",
          "4k3/8/8/8/8/8/2K5/8 w - - 0 1"
        )

      long =
        rating_delta_after_gap(
          90,
          "4k3/8/8/8/8/8/3K4/8 w - - 0 1",
          "4k3/8/8/8/8/8/4K3/8 w - - 0 1"
        )

      assert long > short
    end
  end

  defp rating_delta_after_gap(days, prior_fen, target_fen) do
    {:ok, user} =
      user_fixture()
      |> Ecto.Changeset.change(rating: 1500.0, rating_deviation: 100.0)
      |> Repo.update()

    # A prior rated result on another endgame `days` ago, without changing the
    # user's rating, so only the inactivity inflation differs between runs.
    prior_endgame = endgame_fixture(fen: prior_fen)
    {:ok, prior} = Attempts.record_attempt(Scope.for_user(user), prior_endgame, :solved)
    backdate!(prior, days)

    target = endgame_fixture(fen: target_fen, rating: 1500.0)
    {:ok, attempt} = Attempts.record_attempt(Scope.for_user(user), target, :solved)
    {:ok, %{user: rated}} = Ratings.rate_attempt(attempt)

    rated.rating - 1500.0
  end

  defp backdate!(attempt, days) do
    attempt
    |> Ecto.Changeset.change(
      rated_at: DateTime.add(DateTime.utc_now(:second), -days * 86_400, :second)
    )
    |> Repo.update!()
  end
end
