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
end
