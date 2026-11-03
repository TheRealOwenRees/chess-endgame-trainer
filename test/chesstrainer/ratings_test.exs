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
end
