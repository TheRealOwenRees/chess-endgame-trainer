defmodule Chesstrainer.KeyTest do
  use ExUnit.Case, async: true

  doctest Chesstrainer.Key

  alias Chesstrainer.Key

  describe "from_fen/1" do
    test "derives a rook endgame" do
      assert Key.from_fen("8/8/3k4/8/8/3K1R2/8/8 w - - 0 1") == {:ok, "KR v K"}
    end

    test "is colour-agnostic" do
      white_queen = "8/8/3k1r2/8/8/3K1Q2/8/8 w - - 0 1"
      black_queen = "8/8/3k1q2/8/8/3K1R2/8/8 w - - 0 1"

      assert Key.from_fen(white_queen) == {:ok, "KQ v KR"}
      assert Key.from_fen(black_queen) == {:ok, "KQ v KR"}
    end

    test "puts the side with more material first" do
      assert Key.from_fen("6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1") == {:ok, "KPPP v KPP"}
    end

    test "orders equal-value sides deterministically" do
      white_bishop = "8/8/3k1n2/8/8/3K1B2/8/8 w - - 0 1"
      white_knight = "8/8/3k1b2/8/8/3K1N2/8/8 w - - 0 1"

      assert Key.from_fen(white_bishop) == {:ok, "KB v KN"}
      assert Key.from_fen(white_knight) == {:ok, "KB v KN"}
    end

    test "returns an error for malformed FENs" do
      assert Key.from_fen("not a fen") == {:error, :invalid_fen}
      assert Key.from_fen("8/8/8 w - - 0 1") == {:error, :invalid_fen}
      assert Key.from_fen(nil) == {:error, :invalid_fen}
    end
  end
end
