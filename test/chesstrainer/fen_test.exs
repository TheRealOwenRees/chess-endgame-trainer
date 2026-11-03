defmodule Chesstrainer.FENTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.FEN

  describe "color_from_fen/1" do
    test "extracts white from the active-color field" do
      assert FEN.color_from_fen("8/8/3k4/8/8/3K1R2/8/8 w - - 0 1") == :white
    end

    test "extracts black from the active-color field" do
      assert FEN.color_from_fen("6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1") == :black
    end

    test "returns nil when the active-color field is missing" do
      assert FEN.color_from_fen("8/8/8/8/8/8/8/8") == nil
    end
  end

  describe "normalize/1" do
    test "trims surrounding whitespace" do
      fen = "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
      assert FEN.normalize("  \n" <> fen <> "\t\n") == fen
    end

    test "rewrites fullmove 0 to 1" do
      fen = "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 0"
      assert FEN.normalize(fen) == "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1"
    end

    test "rewrites fullmove 0 even when the FEN has surrounding whitespace" do
      fen = "\n 6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 0 \t"
      assert FEN.normalize(fen) == "6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 1"
    end

    test "leaves a non-zero fullmove untouched" do
      fen = "8/8/3k4/8/8/3K1R2/8/8 w - - 0 5"
      assert FEN.normalize(fen) == fen
    end

    test "leaves a standard starting position untouched" do
      fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
      assert FEN.normalize(fen) == fen
    end

    test "passes through a non-FEN string unchanged" do
      assert FEN.normalize("not a fen") == "not a fen"
    end

    test "passes through a partial FEN (fewer than 6 fields) unchanged" do
      fen = "8/8/3k4/8/8/3K1R2/8/8 w - -"
      assert FEN.normalize(fen) == fen
    end

    test "passes through a FEN with a leading-zero fullmove unchanged" do
      # Fullmove 0 only matches the literal "0"; leading zeros stay so the
      # validator can surface them rather than silently masking the typo.
      fen = "8/8/3k4/8/8/3K1R2/8/8 w - - 0 00"
      assert FEN.normalize(fen) == fen
    end
  end

  describe "position_key/1" do
    test "drops the halfmove and fullmove clocks" do
      assert FEN.position_key("8/8/3k4/8/8/3K1R2/8/8 w - - 0 1") ==
               "8/8/3k4/8/8/3K1R2/8/8 w - -"
    end

    test "shares a key for FENs that differ only in the clocks" do
      a = "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
      b = "8/8/3k4/8/8/3K1R2/8/8 w - - 37 99"

      assert FEN.position_key(a) == FEN.position_key(b)
    end

    test "keeps board, side to move, castling and en-passant distinct" do
      base = "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"

      refute FEN.position_key(base) == FEN.position_key("8/8/3k4/8/8/3K1R2/8/8 b - - 0 1")
      refute FEN.position_key(base) == FEN.position_key("8/8/3k4/8/8/3K1R3/8/8 w - - 0 1")
      refute FEN.position_key(base) == FEN.position_key("8/8/3k4/8/8/3K1R2/8/8 w K - 0 1")
      refute FEN.position_key(base) == FEN.position_key("8/8/3k4/8/8/3K1R2/8/8 w - e3 0 1")
    end

    test "trims surrounding whitespace" do
      assert FEN.position_key("  8/8/3k4/8/8/3K1R2/8/8 w - - 0 1\n") ==
               "8/8/3k4/8/8/3K1R2/8/8 w - -"
    end

    test "passes through a non-FEN string" do
      assert FEN.position_key("not a fen") == "not a fen"
    end
  end

  describe "piece_count/1" do
    test "counts kings and pieces, ignoring empty squares and slashes" do
      assert FEN.piece_count("8/8/3k4/8/8/3K1R2/8/8 w - - 0 1") == 3
    end

    test "counts a full seven-piece position" do
      assert FEN.piece_count("6k1/5p2/6p1/8/7p/8/6PP/6K1 b - - 0 0") == 7
    end

    test "counts a position beyond the tablebase range" do
      assert FEN.piece_count("3k4/2n2B2/1KP5/2B2p2/5b1p/7P/8/8 b - - 0 1") == 10
    end

    test "counts a board field without clocks" do
      assert FEN.piece_count("8/8/3k4/8/8/3K1R2/8/8") == 3
    end

    test "returns nil for a malformed board" do
      assert FEN.piece_count("not a fen") == nil
      assert FEN.piece_count(nil) == nil
    end
  end
end
