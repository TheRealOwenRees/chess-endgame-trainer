defmodule Chesstrainer.AttemptsTest do
  use Chesstrainer.DataCase, async: true

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Attempts
  alias Chesstrainer.Attempts.Attempt
  alias Chesstrainer.Endgames

  describe "record_attempt/3" do
    test "records a solved attempt for a signed-in user" do
      user = user_fixture()
      endgame = endgame_fixture()

      assert {:ok, %Attempt{} = attempt} =
               Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

      assert attempt.user_id == user.id
      assert attempt.endgame_id == endgame.id
      assert attempt.outcome == :solved
      assert is_nil(attempt.rated_at)
    end

    test "records a failed attempt for a signed-in user" do
      user = user_fixture()
      endgame = endgame_fixture()

      assert {:ok, %Attempt{outcome: :failed}} =
               Attempts.record_attempt(Scope.for_user(user), endgame, :failed)
    end

    test "records nothing for an anonymous scope" do
      endgame = endgame_fixture()

      assert :ignored = Attempts.record_attempt(nil, endgame, :solved)
      assert Repo.aggregate(Attempt, :count) == 0
    end
  end

  describe "cascade" do
    test "deleting a user removes their attempts" do
      user = user_fixture()
      endgame = endgame_fixture()
      {:ok, _attempt} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

      Repo.delete!(user)

      assert Repo.aggregate(Attempt, :count) == 0
    end

    test "deleting an endgame removes attempts against it" do
      user = user_fixture()
      endgame = endgame_fixture()
      {:ok, _attempt} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

      assert {:ok, _} = Endgames.delete_endgame(endgame)

      assert Repo.aggregate(Attempt, :count) == 0
    end
  end

  describe "rating-window index" do
    test "rated rows are indexed by user, endgame and rated_at" do
      %{rows: [[indexdef]]} =
        Repo.query!(
          "SELECT indexdef FROM pg_indexes " <>
            "WHERE tablename = 'attempts' AND indexname = 'attempts_user_id_endgame_id_rated_at_index'"
        )

      assert indexdef =~ "WHERE (rated_at IS NOT NULL)"
    end
  end
end
