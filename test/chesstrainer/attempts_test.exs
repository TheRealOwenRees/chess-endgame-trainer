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

  describe "count_users_with_attempts/0" do
    test "counts distinct users who have recorded an attempt" do
      first = user_fixture()
      second = user_fixture()
      endgame = endgame_fixture()

      {:ok, _} = Attempts.record_attempt(Scope.for_user(first), endgame, :solved)
      {:ok, _} = Attempts.record_attempt(Scope.for_user(first), endgame, :failed)
      {:ok, _} = Attempts.record_attempt(Scope.for_user(second), endgame, :solved)

      assert Attempts.count_users_with_attempts() == 2
    end

    test "ignores users without attempts" do
      user_fixture()

      assert Attempts.count_users_with_attempts() == 0
    end
  end

  describe "stats_for_user/1" do
    test "summarises attempts, outcomes and distinct puzzles" do
      user = user_fixture()
      first = endgame_fixture()
      second = endgame_fixture()

      {:ok, _} = Attempts.record_attempt(Scope.for_user(user), first, :solved)
      {:ok, _} = Attempts.record_attempt(Scope.for_user(user), first, :failed)
      {:ok, _} = Attempts.record_attempt(Scope.for_user(user), second, :solved)

      assert %{attempts: 3, solved: 2, failed: 1, endgames: 2} =
               Attempts.stats_for_user(user.id)
    end

    test "returns zeroes for a user with no attempts" do
      user = user_fixture()

      assert %{attempts: 0, solved: 0, failed: 0, endgames: 0} =
               Attempts.stats_for_user(user.id)
    end
  end

  describe "list_attempts_for_user/2" do
    test "returns the user's attempts newest first with endgames preloaded" do
      user = user_fixture()
      first = endgame_fixture(fen: "8/8/3k4/8/8/3K1Q2/8/8 w - - 0 1")
      second = endgame_fixture(fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1")
      {:ok, first_attempt} = Attempts.record_attempt(Scope.for_user(user), first, :solved)
      {:ok, second_attempt} = Attempts.record_attempt(Scope.for_user(user), second, :failed)

      # Attempts within the same second would otherwise tie on `inserted_at`.
      Repo.update_all(from(a in Attempt, where: a.id == ^first_attempt.id),
        set: [inserted_at: ~N[2026-01-01 00:00:00]]
      )

      Repo.update_all(from(a in Attempt, where: a.id == ^second_attempt.id),
        set: [inserted_at: ~N[2026-01-02 00:00:00]]
      )

      attempts = Attempts.list_attempts_for_user(user.id)

      assert Enum.map(attempts, & &1.id) == [second_attempt.id, first_attempt.id]
      assert Enum.all?(attempts, &match?(%Chesstrainer.Endgames.Endgame{}, &1.endgame))
    end

    test "excludes other users and honours the limit" do
      user = user_fixture()
      other = user_fixture()
      endgame = endgame_fixture()

      {:ok, _} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)
      {:ok, _} = Attempts.record_attempt(Scope.for_user(user), endgame, :failed)
      {:ok, _} = Attempts.record_attempt(Scope.for_user(other), endgame, :solved)

      assert length(Attempts.list_attempts_for_user(user.id)) == 2
      assert length(Attempts.list_attempts_for_user(user.id, limit: 1)) == 1
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
