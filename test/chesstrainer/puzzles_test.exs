defmodule Chesstrainer.PuzzlesTest do
  use Chesstrainer.DataCase, async: true

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures
  import Chesstrainer.ThemesFixtures

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Attempts
  alias Chesstrainer.Endgames
  alias Chesstrainer.Puzzles
  alias Chesstrainer.Repo

  # The shared `endgame_fixture/1` picks one of six FENs at random-ish, which
  # can collide when one test creates several endgames under async load. Pin
  # distinct FENs here instead.
  @fens [
    "4k3/8/8/8/8/8/8/1K6 w - - 0 1",
    "4k3/8/8/8/8/8/8/2K5 w - - 0 1",
    "4k3/8/8/8/8/8/8/3K4 w - - 0 1",
    "4k3/8/8/8/8/8/8/4K3 w - - 0 1"
  ]

  defp endgame_at(rating, index) do
    endgame_fixture(fen: Enum.fetch!(@fens, index), rating: rating)
  end

  defp attempt_days_ago(user, endgame, days) do
    {:ok, attempt} = Attempts.record_attempt(Scope.for_user(user), endgame, :solved)

    attempt
    |> Ecto.Changeset.change(
      inserted_at: DateTime.utc_now() |> DateTime.add(-days, :day) |> DateTime.truncate(:second)
    )
    |> Repo.update!()
  end

  describe "difficulty_target/2" do
    test "centres on the rating and offsets easy and hard" do
      assert Puzzles.difficulty_target(1500, :medium) == 1500
      assert Puzzles.difficulty_target(1500, :easy) == 1300
      assert Puzzles.difficulty_target(1500, :hard) == 1700
    end
  end

  describe "selection settings" do
    test "uses the configured spread and repeat window" do
      assert Puzzles.spread() == 150
      assert Puzzles.repeat_window_days() == 30
    end
  end

  describe "next_endgame/3" do
    test "draws far more often from near the user's rating" do
      user = user_fixture()
      near = endgame_at(1500, 0)
      _far = endgame_at(4000, 1)

      for _ <- 1..50 do
        assert Puzzles.next_endgame(user, :medium).id == near.id
      end
    end

    test "easy never serves above the user's rating plus the spread" do
      user = user_fixture()
      easy = endgame_at(1300, 0)
      _too_hard = endgame_at(3000, 1)

      assert Puzzles.next_endgame(user, :easy).id == easy.id
    end

    test "hard never serves below the user's rating minus the spread" do
      user = user_fixture()
      hard = endgame_at(1700, 0)
      _too_easy = endgame_at(100, 1)

      assert Puzzles.next_endgame(user, :hard).id == hard.id
    end

    test "prefers endgames not attempted inside the repeat window" do
      user = user_fixture()
      attempted = endgame_at(1500, 0)
      fresh = endgame_at(1500, 1)

      attempt_days_ago(user, attempted, 1)

      assert Puzzles.next_endgame(user, :medium).id == fresh.id
    end

    test "serves an endgame again once its attempt is outside the repeat window" do
      user = user_fixture()
      only = endgame_at(1500, 0)

      attempt_days_ago(user, only, 31)

      assert Puzzles.next_endgame(user, :medium).id == only.id
    end

    test "falls back to the least recently attempted endgame when all are excluded" do
      user = user_fixture()
      older = endgame_at(1500, 0)
      newer = endgame_at(1500, 1)

      attempt_days_ago(user, older, 20)
      attempt_days_ago(user, newer, 10)

      assert Puzzles.next_endgame(user, :medium).id == older.id
    end

    test "skips endgames already served in the session" do
      user = user_fixture()
      served = endgame_at(1500, 0)
      other = endgame_at(1500, 1)

      assert Puzzles.next_endgame(user, :medium, exclude_ids: [served.id]).id == other.id
    end

    test "returns nil when every endgame has been served and attempted" do
      user = user_fixture()
      only = endgame_at(1500, 0)

      attempt_days_ago(user, only, 1)

      assert Puzzles.next_endgame(user, :medium, exclude_ids: [only.id]) == nil
    end

    test "returns nil when no endgames exist" do
      user = user_fixture()

      assert Puzzles.next_endgame(user, :medium) == nil
    end

    test "restricts selection to a theme, including the fallback" do
      user = user_fixture()
      themed = endgame_at(1500, 0)
      _unrelated = endgame_at(1500, 1)
      theme = theme_fixture(%{name: "Lucena"})
      {:ok, _} = Endgames.update_endgame(themed, %{}, [theme])

      for _ <- 1..20 do
        assert Puzzles.next_endgame(user, :medium, theme_id: theme.id).id == themed.id
      end

      assert Puzzles.next_endgame(user, :medium,
               theme_id: theme.id,
               exclude_ids: [themed.id]
             ) == nil

      assert Puzzles.next_endgame(user, :medium, theme_id: theme.id) != nil
    end
  end
end
