defmodule Chesstrainer.Repo.Seeds.Endgames do
  def all do
    [
      %{
      fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1",
      color: :white,
      message: "Rook vs king endgame",
      notes: "Basic rook endgame",
      result: :win
    },
    %{
      fen: "3k4/2n2B2/1KP5/2B2p2/5b1p/7P/8/8 b - - 0 0",
      color: :black,
      result: :win
    },
    %{
      fen: "r7/4R2P/3p4/3k1K2/2p5/8/8/8 b - - 0 0",
      color: :black,
      result: :draw
    },
    %{
      fen: "8/8/5p2/1P1K1k2/8/2r5/8/7R w - - 0 0",
      color: :white,
      result: :draw
    },
    %{
      fen: "5n2/R7/4pk2/8/5PK1/8/8/8 b - - 0 0",
      color: :black,
      result: :draw
    },
    %{
      fen: "5k2/R7/3K4/4p3/5P2/8/8/5r2 w - - 0 1",
      color: :white,
      result: :draw
    },
    %{
      fen: "5k2/8/p7/4K1P1/P4R2/6r1/8/8 b - - 0 1",
      color: :black,
      result: :draw
    },
    %{
      fen: "8/8/8/1P4p1/5k2/5p2/P6K/8 b - - 0 0",
      color: :black,
      result: :win
    }
  ]
  end
end
