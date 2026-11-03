defmodule Chesstrainer.SeedsTest do
  use ExUnit.Case, async: true

  alias Chesstrainer.FEN

  Code.require_file("../../priv/repo/seeds/endgames.ex", __DIR__)

  describe "seed endgames" do
    test "are normalised and within tablebase range" do
      for endgame <- Chesstrainer.Repo.Seeds.Endgames.all() do
        fen = FEN.normalize(endgame.fen)

        assert length(String.split(fen, " ")) == 6,
               "seed FEN must have 6 fields: #{endgame.fen}"

        refute String.ends_with?(fen, " 0"),
               "seed FEN keeps fullmove 0 after normalisation: #{endgame.fen}"

        assert FEN.piece_count(fen) <= 7,
               "seed FEN has more than 7 pieces: #{endgame.fen}"
      end
    end
  end
end
