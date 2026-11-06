defmodule Chesstrainer.Repo.Seeds.Endgames.Draw do
  def all do
    [
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
      fen: "6k1/8/6r1/8/5b2/2PR4/4K3/8 w - - 0 1",
      color: :white,
      result: :draw
    },
    %{
      fen: "8/1p3k2/3B4/8/3b2P1/1P6/6K1/8 b - - 0 1",
      color: :white,
      result: :draw
    },
    %{
      fen: "8/k5r1/2N5/PK6/2B5/8/8/8 b - - 0 1",
      color: :black,
      result: :draw
    },
    %{
      fen: "6k1/8/5K2/8/5P1R/r6P/8/8 b - - 0 1",
      color: :black,
      result: :draw
    },
    %{
      fen: "8/8/4k1KP/p5P1/r7/8/8/8 w - - 0 1",
      color: :white,
      result: :draw
    },
    %{
      fen: "8/8/5K2/3kn3/6B1/7P/8/8 b - - 0 1",
      color: :black,
      result: :draw
    },
    %{
      fen: "8/6k1/8/R7/7K/1P6/5r2/8 b - - 0 1",
      color: :black,
      result: :draw
    },
    %{
      fen: "8/7p/6p1/5k2/7N/8/4KP2/8 b - - 0 1",
      color: :black,
      result: :draw
    },
    %{
      fen: "8/6Rp/8/5k2/5p2/5K2/7r/8 b - - 0 1",
      color: :black,
      result: :draw
    },
    %{
      fen: "6k1/3R4/5Kp1/6r1/4P3/8/8/8 b - - 0 1",
      color: :black,
      result: :draw
    },
    %{
      fen: "8/8/7B/8/8/3p4/6Kp/3k1n2 w - - 0 0",
      color: :white,
      result: :draw
    },
    %{
      fen: "7r/8/8/6k1/R6p/6pK/8/8 w - - 0 52",
      color: :white,
      result: :draw
    },
    %{
      fen: "R7/8/8/8/6K1/5p2/5Pk1/4r3 w - - 0 1",
      color: :white,
      result: :draw
    },
    %{
      fen: "8/8/5n2/1P1k4/3p1P2/3P1K2/8/8 w - - 0 0",
      color: :white,
      result: :draw
    },
    %{
      fen: "8/5k2/6R1/4r2p/8/6KP/6P1/8 w - - 5 49",
      color: :white,
      result: :draw
    }
    ]
  end
end
