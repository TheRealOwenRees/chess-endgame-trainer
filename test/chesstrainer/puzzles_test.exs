defmodule Chesstrainer.PuzzlesTest do
  use Chesstrainer.DataCase, async: true

  import Chesstrainer.AccountsFixtures
  import Chesstrainer.EndgamesFixtures

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Attempts
  alias Chesstrainer.Puzzles

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

  describe "difficulty_range/2" do
    test "is centred on the rating and open-ended at the extremes" do
      assert Puzzles.difficulty_range(1500, :medium) == {1400, 1600}
      assert Puzzles.difficulty_range(1500, :easy) == {nil, 1400}
      assert Puzzles.difficulty_range(1500, :hard) == {1600, nil}
    end
  end

  describe "next_endgame/3" do
    test "medium picks an endgame within the band" do
      user = user_fixture()
      in_band = endgame_at(1550, 0)
      _out_of_band = endgame_at(1900, 1)

      assert Puzzles.next_endgame(user, :medium).id == in_band.id
    end

    test "easy picks an endgame below the user's rating" do
      user = user_fixture()
      easy = endgame_at(1300, 0)
      _medium = endgame_at(1500, 1)

      assert Puzzles.next_endgame(user, :easy).id == easy.id
    end

    test "hard picks an endgame above the user's rating" do
      user = user_fixture()
      hard = endgame_at(1700, 0)
      _medium = endgame_at(1500, 1)

      assert Puzzles.next_endgame(user, :hard).id == hard.id
    end

    test "falls back to the nearest endgame when the band is empty" do
      user = user_fixture()
      only = endgame_at(2200, 0)

      assert Puzzles.next_endgame(user, :medium).id == only.id
    end

    test "prefers endgames not attempted in the last 30 days" do
      user = user_fixture()
      attempted = endgame_at(1500, 0)
      fresh = endgame_at(1500, 1)

      {:ok, _} = Attempts.record_attempt(Scope.for_user(user), attempted, :solved)

      assert Puzzles.next_endgame(user, :medium).id == fresh.id
    end

    test "falls back to a recent endgame once the fresh pool is empty" do
      user = user_fixture()
      only = endgame_at(1500, 0)

      {:ok, _} = Attempts.record_attempt(Scope.for_user(user), only, :solved)

      assert Puzzles.next_endgame(user, :medium).id == only.id
    end

    test "skips excluded ids" do
      user = user_fixture()
      excluded = endgame_at(1500, 0)
      other = endgame_at(1500, 1)

      assert Puzzles.next_endgame(user, :medium, exclude_ids: [excluded.id]).id == other.id
    end

    test "returns nil when no endgames exist" do
      user = user_fixture()

      assert Puzzles.next_endgame(user, :medium) == nil
    end
  end
end
