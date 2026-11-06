defmodule Chesstrainer.Repo.Seeds.Endgames.Win do
  def all do
    [
    %{
      fen: "8/8/3k4/8/8/3K1R2/8/8 w - - 0 1",
      color: :white,
      message: "Rook vs king endgame",
      notes: "Basic rook endgame",
      result: :win,
      themes: ["rook endgame"]
    },
    %{
      fen: "8/8/8/1P4p1/5k2/5p2/P6K/8 b - - 0 0",
      color: :black,
      result: :win
    },
     %{
      fen: "8/8/8/2p1k3/P6R/1K6/6rP/8 w - - 0 0",
      color: :white,
      result: :win
    },
     %{
      fen: "8/7p/6p1/8/k7/8/2K3P1/8 b - - 0 0",
      color: :black,
      result: :win
    },
    %{
      fen: "R7/8/8/6p1/4k3/3rPp1P/8/6K1 b - - 0 1",
      color: :black,
      result: :win
    },
     %{
      fen: "8/8/7k/8/8/8/5q2/3B2RK b - - 0 1",
      color: :black,
      result: :win
    },
     %{
      fen: "6K1/8/5P1k/2R5/1r6/8/2p5/8 w - - 0 0",
      color: :white,
      result: :win
    },
     %{
      fen: "8/r7/5PK1/3k4/p7/8/1R6/8 w - - 0 1",
      color: :white,
      result: :win
    },
    %{
      fen: "R7/P4r2/5k2/3Kp3/8/8/8/8 w - - 0 0",
      color: :white,
      result: :win
    },
        %{
      fen: "8/B2k4/1P3K2/3bP3/8/8/8/8 w - - 0 1",
      color: :white,
      result: :win
    },
    ]
  end
end
