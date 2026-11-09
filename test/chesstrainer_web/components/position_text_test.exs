defmodule ChesstrainerWeb.Board.PositionTextTest do
  use ExUnit.Case, async: true

  alias ChesstrainerWeb.Board.PositionText

  test "names the side to move and every piece" do
    assert PositionText.summary("8/8/3k4/8/8/3K1R2/8/8 w - - 0 1") ==
             "White to move. White: king on d3, rook on f3. Black: king on d6."
  end

  test "describes black to move" do
    assert PositionText.summary("8/8/3k4/8/8/3K1R2/8/8 b - - 0 1") =~
             "Black to move."
  end

  test "includes pawns and both colours" do
    summary = PositionText.summary("8/8/3k4/8/8/3K1R2/4P3/8 w - - 0 1")

    assert summary =~ "White: king on d3, rook on f3, pawn on e2."
    assert summary =~ "Black: king on d6."
  end

  test "falls back when the FEN cannot be read" do
    assert PositionText.summary("not a fen") == "Chess position."
    assert PositionText.summary(nil) == "Chess position."
  end
end
