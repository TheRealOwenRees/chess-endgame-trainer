defmodule Chesstrainer.Endgames.Tablebase.SanTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.Endgames.Tablebase.San

  @start "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

  test "pawn and piece moves" do
    assert San.for_uci(@start, "e2e4") == "e4"
    assert San.for_uci(@start, "g1f3") == "Nf3"
  end

  test "captures" do
    after_e4_d5 = "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2"
    assert San.for_uci(after_e4_d5, "e4d5") == "exd5"
  end

  test "castling" do
    fen = "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
    assert San.for_uci(fen, "e1g1") == "O-O"
    assert San.for_uci(fen, "e1c1") == "O-O-O"
  end

  test "promotion and check" do
    assert San.for_uci("8/P7/8/8/8/4k3/8/4K3 w - - 0 1", "a7a8q") == "a8=Q"
    assert San.for_uci("4k3/P7/8/8/8/8/8/4K3 w - - 0 1", "a7a8q") == "a8=Q+"
  end

  test "disambiguates by file when two pieces can reach the square" do
    fen = "4k3/8/8/8/8/8/8/1N1NK3 w - - 0 1"
    assert San.for_uci(fen, "b1c3") == "Nbc3"
    assert San.for_uci(fen, "d1c3") == "Ndc3"
  end

  test "checkmate suffix" do
    fen = "6k1/5ppp/8/8/8/8/8/4R1K1 w - - 0 1"
    assert San.for_uci(fen, "e1e8") == "Re8#"
  end

  test "returns nil for an invalid move" do
    assert San.for_uci(@start, "e2e5") == nil
    assert San.for_uci(@start, "zzzz") == nil
  end
end
